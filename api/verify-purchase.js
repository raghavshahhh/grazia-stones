// POST /api/verify-purchase  (auth required)
// Body: { platform: 'android' | 'ios', productId, purchaseToken }
//   iOS: purchaseToken is the StoreKit transaction id.
//
// Verifies a Plus / Pro store subscription with Google or Apple server-side,
// then upserts public.subscriptions with the service role and returns the
// user's usage object. The client's claimed plan is never trusted: the plan is
// derived from the verified productId. A purchase already bound to another
// account is refused. Contract: docs/subscriptions_contract.md.
//
// No npm dependencies: the OAuth / App Store JWTs are signed with node:crypto.

const crypto = require('node:crypto');
const { verifyRequestAuth } = require('./_supabaseAuth');
const credits = require('./_aiCredits');

const ANDROID_PACKAGE = 'com.graziastones.grazia_stones';
const PRODUCT_PLANS = { grazia_plus_monthly: 'plus', grazia_pro_monthly: 'pro' };
const ANDROID_OK_STATES = ['SUBSCRIPTION_STATE_ACTIVE', 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD'];
const PLAY_API = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${ANDROID_PACKAGE}/purchases`;
const APPLE_HOSTS = ['https://api.storekit.itunes.apple.com', 'https://api.storekit-sandbox.itunes.apple.com'];

class HttpError extends Error {
  constructor(status, code, message) {
    super(message || code);
    this.status = status;
    this.code = code;
  }
}

const b64url = (input) => Buffer.from(input).toString('base64url');

function signJwt(header, payload, privateKey, alg) {
  const data = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(payload))}`;
  const sig =
    alg === 'ES256'
      ? crypto.sign('sha256', Buffer.from(data), { key: privateKey, dsaEncoding: 'ieee-p1363' })
      : crypto.sign('RSA-SHA256', Buffer.from(data), privateKey);
  return `${data}.${sig.toString('base64url')}`;
}

// Env vars often hold PEM keys with literal "\n".
const pem = (s) => (s || '').replace(/\\n/g, '\n').trim();

// ---------------------------------------------------------------------------
// Android: Google Play Developer API
// ---------------------------------------------------------------------------
let _googleToken = null; // { token, exp } cached per warm function instance

async function googleAccessToken() {
  if (_googleToken && _googleToken.exp > Date.now() + 60_000) return _googleToken.token;
  let sa;
  try {
    sa = JSON.parse(process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON || '');
  } catch {
    sa = null;
  }
  if (!sa || !sa.client_email || !sa.private_key) {
    throw new HttpError(503, 'android_verification_not_configured');
  }
  const tokenUri = sa.token_uri || 'https://oauth2.googleapis.com/token';
  const now = Math.floor(Date.now() / 1000);
  const assertion = signJwt(
    { alg: 'RS256', typ: 'JWT' },
    {
      iss: sa.client_email,
      scope: 'https://www.googleapis.com/auth/androidpublisher',
      aud: tokenUri,
      iat: now,
      exp: now + 3600,
    },
    pem(sa.private_key),
    'RS256',
  );
  const resp = await fetch(tokenUri, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }),
  });
  if (!resp.ok) {
    console.error('[verify-purchase] google oauth failed', resp.status);
    throw new HttpError(502, 'store_unavailable');
  }
  const data = await resp.json();
  _googleToken = { token: data.access_token, exp: Date.now() + (data.expires_in || 3600) * 1000 };
  return _googleToken.token;
}

/** Pure check of a subscriptionsv2 resource. Returns { plan, periodEnd } or throws HttpError. */
function checkAndroidSubscription(sub, productId, now = Date.now()) {
  if (!ANDROID_OK_STATES.includes(sub.subscriptionState)) {
    throw new HttpError(400, 'purchase_not_active');
  }
  const items = (sub.lineItems || []).filter((li) => li.productId === productId);
  if (!items.length) throw new HttpError(400, 'product_mismatch');
  const expiry = Math.max(...items.map((li) => Date.parse(li.expiryTime) || 0));
  if (!(expiry > now)) throw new HttpError(400, 'purchase_expired');
  return { plan: PRODUCT_PLANS[productId], periodEnd: new Date(expiry).toISOString() };
}

async function verifyAndroid(productId, purchaseToken) {
  const token = await googleAccessToken();
  const headers = { Authorization: `Bearer ${token}` };
  const resp = await fetch(`${PLAY_API}/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`, { headers });
  if ([400, 404, 410].includes(resp.status)) throw new HttpError(400, 'invalid_purchase');
  if (!resp.ok) {
    console.error('[verify-purchase] play get failed', resp.status);
    throw new HttpError(502, 'store_unavailable');
  }
  const sub = await resp.json();
  const { plan, periodEnd } = checkAndroidSubscription(sub, productId);

  // Play refunds purchases that are not acknowledged within 3 days. Done after
  // the DB write (see handler) so a failed write never leaves a paid user
  // acknowledged-but-unentitled without a retry path; the app can call again.
  const acknowledge =
    sub.acknowledgementState === 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED'
      ? null
      : async () => {
          const ack = await fetch(
            `${PLAY_API}/subscriptions/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(purchaseToken)}:acknowledge`,
            { method: 'POST', headers: { ...headers, 'Content-Type': 'application/json' }, body: '{}' },
          );
          if (!ack.ok) console.error('[verify-purchase] play acknowledge failed', ack.status);
        };

  return { plan, periodEnd, source: 'google_play', bindKey: purchaseToken, acknowledge };
}

// ---------------------------------------------------------------------------
// iOS: App Store Server API
// ---------------------------------------------------------------------------
function appleConfig() {
  const cfg = {
    issuerId: (process.env.APPSTORE_ISSUER_ID || '').trim(),
    keyId: (process.env.APPSTORE_KEY_ID || '').trim(),
    privateKey: pem(process.env.APPSTORE_PRIVATE_KEY),
    bundleId: (process.env.APPSTORE_BUNDLE_ID || '').trim(),
  };
  return Object.values(cfg).every(Boolean) ? cfg : null;
}

/**
 * Decodes a JWS (signedTransactionInfo). Also checks the signature against the
 * x5c leaf certificate and that each certificate is signed by the next one.
 * ponytail: the chain is not pinned to Apple Root CA G3; trust comes from
 * fetching the JWS from Apple's API over TLS with our own key. Pin the root if
 * JWS ever arrives from the client or from RTDN.
 */
function decodeJws(jws) {
  const parts = String(jws).split('.');
  if (parts.length !== 3) throw new HttpError(502, 'store_bad_response');
  const header = JSON.parse(Buffer.from(parts[0], 'base64url').toString('utf8'));
  const payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
  if (Array.isArray(header.x5c) && header.x5c.length) {
    const certs = header.x5c.map((c) => new crypto.X509Certificate(Buffer.from(c, 'base64')));
    const okSig = crypto.verify(
      'sha256',
      Buffer.from(`${parts[0]}.${parts[1]}`),
      { key: certs[0].publicKey, dsaEncoding: 'ieee-p1363' },
      Buffer.from(parts[2], 'base64url'),
    );
    const okChain = certs.every((c, i) => i === certs.length - 1 || c.verify(certs[i + 1].publicKey));
    if (!okSig || !okChain) throw new HttpError(502, 'store_bad_signature');
  }
  return payload;
}

/** Pure check of a decoded JWSTransactionDecodedPayload. */
function checkAppleTransaction(tx, productId, bundleId, now = Date.now()) {
  if (tx.bundleId !== bundleId) throw new HttpError(400, 'bundle_mismatch');
  if (tx.productId !== productId) throw new HttpError(400, 'product_mismatch');
  if (tx.revocationDate) throw new HttpError(400, 'purchase_revoked');
  if (!(Number(tx.expiresDate) > now)) throw new HttpError(400, 'purchase_expired');
  return {
    plan: PRODUCT_PLANS[productId],
    periodEnd: new Date(Number(tx.expiresDate)).toISOString(),
    // originalTransactionId is the same for every renewal of one subscription.
    bindKey: String(tx.originalTransactionId || tx.transactionId),
  };
}

async function verifyIos(productId, transactionId) {
  const cfg = appleConfig();
  if (!cfg) throw new HttpError(503, 'ios_verification_not_configured');
  const now = Math.floor(Date.now() / 1000);
  const jwt = signJwt(
    { alg: 'ES256', kid: cfg.keyId, typ: 'JWT' },
    { iss: cfg.issuerId, iat: now, exp: now + 300, aud: 'appstoreconnect-v1', bid: cfg.bundleId },
    cfg.privateKey,
    'ES256',
  );

  // Production first, then sandbox (TestFlight / App Review), as Apple recommends.
  let body = null;
  for (const host of APPLE_HOSTS) {
    const resp = await fetch(`${host}/inApps/v1/transactions/${encodeURIComponent(transactionId)}`, {
      headers: { Authorization: `Bearer ${jwt}` },
    });
    if (resp.status === 404) continue;
    if (!resp.ok) {
      console.error('[verify-purchase] app store get failed', resp.status);
      throw new HttpError(resp.status === 400 ? 400 : 502, resp.status === 400 ? 'invalid_purchase' : 'store_unavailable');
    }
    body = await resp.json();
    break;
  }
  if (!body || !body.signedTransactionInfo) throw new HttpError(400, 'invalid_purchase');

  const tx = decodeJws(body.signedTransactionInfo);
  return { ...checkAppleTransaction(tx, productId, cfg.bundleId), source: 'app_store', acknowledge: null };
}

// ---------------------------------------------------------------------------
// Persistence
// ---------------------------------------------------------------------------
async function bindSubscription(userId, productId, v) {
  const existing = await credits.serviceFetch(
    `subscriptions?select=user_id&purchase_token=eq.${encodeURIComponent(v.bindKey)}`,
  );
  if (!existing.ok) throw new Error(`subscriptions_lookup_${existing.status}`);
  const rows = await existing.json();
  if (rows.some((r) => r.user_id !== userId)) throw new HttpError(409, 'purchase_bound_to_other_user');

  const resp = await credits.serviceFetch('subscriptions?on_conflict=user_id', {
    method: 'POST',
    headers: { Prefer: 'resolution=merge-duplicates,return=minimal' },
    body: JSON.stringify({
      user_id: userId,
      plan: v.plan,
      source: v.source,
      status: 'active',
      product_id: productId,
      purchase_token: v.bindKey,
      period_end: v.periodEnd,
      updated_at: new Date().toISOString(),
    }),
  });
  // 409 = the partial unique index on purchase_token (lost a race with another account).
  if (resp.status === 409) throw new HttpError(409, 'purchase_bound_to_other_user');
  if (!resp.ok) throw new Error(`subscriptions_upsert_${resp.status}`);
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------
const RATE_LIMIT_WINDOW_MS = 60_000;
const RATE_LIMIT_MAX = 10;
const _hits = new Map();
function _isRateLimited(key) {
  const now = Date.now();
  const hit = _hits.get(key);
  if (!hit || now - hit.windowStart > RATE_LIMIT_WINDOW_MS) {
    _hits.set(key, { windowStart: now, count: 1 });
    return false;
  }
  return ++hit.count > RATE_LIMIT_MAX;
}

async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  if (req.method === 'OPTIONS') {
    res.status(204).end();
    return;
  }
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  const auth = await verifyRequestAuth(req);
  if (auth.invalid) {
    res.status(401).json({ error: 'Invalid or expired session' });
    return;
  }
  if (!auth.authenticated) {
    res.status(401).json({ error: 'Login required', code: 'login_required' });
    return;
  }
  if (_isRateLimited(auth.userId)) {
    res.status(429).json({ error: 'Too many requests' });
    return;
  }

  const { platform, productId, purchaseToken } = req.body || {};
  if (!['android', 'ios'].includes(platform)) {
    res.status(400).json({ error: 'platform must be android or ios', code: 'bad_request' });
    return;
  }
  if (typeof productId !== 'string' || !PRODUCT_PLANS[productId]) {
    res.status(400).json({ error: 'Unknown product', code: 'unknown_product' });
    return;
  }
  const tokenOk =
    typeof purchaseToken === 'string' &&
    (platform === 'ios' ? /^\d{1,32}$/.test(purchaseToken) : purchaseToken.length > 0 && purchaseToken.length <= 4096);
  if (!tokenOk) {
    res.status(400).json({ error: 'Invalid purchaseToken', code: 'bad_request' });
    return;
  }

  try {
    const v = platform === 'android' ? await verifyAndroid(productId, purchaseToken) : await verifyIos(productId, purchaseToken);
    await bindSubscription(auth.userId, productId, v);
    if (v.acknowledge) await v.acknowledge();
    res.status(200).json({ ok: true, usage: await credits.status(auth.userId) });
  } catch (err) {
    if (err instanceof HttpError) {
      res.status(err.status).json({ error: err.message, code: err.code });
      return;
    }
    console.error('[verify-purchase] failed', err.message);
    res.status(500).json({ error: 'Purchase verification failed', code: 'verification_failed' });
  }
}

module.exports = handler;
// Exposed for tool/plans/verify_purchase.test.js only.
module.exports._test = { checkAndroidSubscription, checkAppleTransaction, decodeJws, signJwt, PRODUCT_PLANS, HttpError };
