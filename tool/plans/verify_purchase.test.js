// Offline tests for api/verify-purchase.js and api/_aiCredits.js.
// Every network call is mocked; nothing reaches Google, Apple or Supabase.
// Run: node --test tool/plans/verify_purchase.test.js
const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const path = require('node:path');

const api = path.join(__dirname, '..', '..', 'api');
const handler = require(path.join(api, 'verify-purchase.js'));
const credits = require(path.join(api, '_aiCredits.js'));
const { checkAndroidSubscription, checkAppleTransaction, decodeJws, signJwt } = handler._test;

const USER = '11111111-1111-1111-1111-111111111111';
const future = new Date(Date.now() + 86400_000).toISOString();
const usageRow = {
  plan: 'plus', source: 'google_play', period_end: future, trial_ends_at: null,
  monthly_limit: 60, monthly_used: 12, daily_limit: 10, daily_used: 2, resets_at: future,
};

test('android subscription checks', () => {
  const sub = { subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE', lineItems: [{ productId: 'grazia_pro_monthly', expiryTime: future }] };
  assert.deepEqual(checkAndroidSubscription(sub, 'grazia_pro_monthly'), { plan: 'pro', periodEnd: future });
  assert.equal(checkAndroidSubscription({ ...sub, subscriptionState: 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD' }, 'grazia_pro_monthly').plan, 'pro');
  assert.throws(() => checkAndroidSubscription({ ...sub, subscriptionState: 'SUBSCRIPTION_STATE_EXPIRED' }, 'grazia_pro_monthly'), { code: 'purchase_not_active' });
  assert.throws(() => checkAndroidSubscription(sub, 'grazia_plus_monthly'), { code: 'product_mismatch' });
  const past = { ...sub, lineItems: [{ productId: 'grazia_pro_monthly', expiryTime: '2020-01-01T00:00:00Z' }] };
  assert.throws(() => checkAndroidSubscription(past, 'grazia_pro_monthly'), { code: 'purchase_expired' });
});

test('apple transaction checks', () => {
  const tx = { bundleId: 'com.x', productId: 'grazia_plus_monthly', expiresDate: Date.now() + 1e6, originalTransactionId: '100', transactionId: '200' };
  assert.equal(checkAppleTransaction(tx, 'grazia_plus_monthly', 'com.x').bindKey, '100');
  assert.throws(() => checkAppleTransaction(tx, 'grazia_plus_monthly', 'com.y'), { code: 'bundle_mismatch' });
  assert.throws(() => checkAppleTransaction(tx, 'grazia_pro_monthly', 'com.x'), { code: 'product_mismatch' });
  assert.throws(() => checkAppleTransaction({ ...tx, expiresDate: Date.now() - 1 }, 'grazia_plus_monthly', 'com.x'), { code: 'purchase_expired' });
  assert.throws(() => checkAppleTransaction({ ...tx, revocationDate: 1 }, 'grazia_plus_monthly', 'com.x'), { code: 'purchase_revoked' });
});

test('ES256 JWT signature verifies and JWS payload decodes', () => {
  const { privateKey, publicKey } = crypto.generateKeyPairSync('ec', { namedCurve: 'P-256' });
  const jwt = signJwt({ alg: 'ES256' }, { a: 1 }, privateKey, 'ES256');
  const [h, p, s] = jwt.split('.');
  assert.ok(crypto.verify('sha256', Buffer.from(`${h}.${p}`), { key: publicKey, dsaEncoding: 'ieee-p1363' }, Buffer.from(s, 'base64url')));
  assert.deepEqual(decodeJws(jwt), { a: 1 });
});

test('JWS with x5c: valid signature passes, tampered payload fails', (t) => {
  const { execFileSync } = require('node:child_process');
  const fs = require('node:fs');
  const os = require('node:os');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'jws-'));
  try {
    execFileSync('openssl', ['req', '-x509', '-newkey', 'ec', '-pkeyopt', 'ec_paramgen_curve:P-256', '-nodes',
      '-keyout', path.join(dir, 'k.pem'), '-out', path.join(dir, 'c.pem'), '-subj', '/CN=test', '-days', '1'], { stdio: 'ignore' });
  } catch {
    t.skip('openssl not available');
    return;
  }
  const key = fs.readFileSync(path.join(dir, 'k.pem'));
  const der = new crypto.X509Certificate(fs.readFileSync(path.join(dir, 'c.pem'))).raw.toString('base64');
  const jws = signJwt({ alg: 'ES256', x5c: [der] }, { productId: 'grazia_plus_monthly' }, key, 'ES256');
  assert.equal(decodeJws(jws).productId, 'grazia_plus_monthly');
  const [h, , sig] = jws.split('.');
  const forged = `${h}.${Buffer.from(JSON.stringify({ productId: 'grazia_pro_monthly' })).toString('base64url')}.${sig}`;
  assert.throws(() => decodeJws(forged), { code: 'store_bad_signature' });
  fs.rmSync(dir, { recursive: true });
});

test('toUsage maps rows and legacy keys', () => {
  const u = credits.toUsage(usageRow);
  assert.equal(u.monthlyUsed, 12);
  assert.equal(u.creditsRemaining, 48);
  assert.equal(u.dailyRemaining, 8);
  const trial = credits.toUsage({ ...usageRow, plan: 'trial', monthly_limit: null, monthly_used: 30, daily_used: 4 });
  assert.equal(trial.creditsRemaining, 6);
});

// --- handler with mocked fetch ---------------------------------------------
function mockRes() {
  return {
    statusCode: 0, body: null, headers: {},
    setHeader(k, v) { this.headers[k] = v; },
    status(c) { this.statusCode = c; return this; },
    json(b) { this.body = b; return this; },
    end() { return this; },
  };
}

function setupFetch({ boundTo = [], ackState = 'ACKNOWLEDGEMENT_STATE_PENDING' } = {}) {
  const calls = [];
  global.fetch = async (url, init = {}) => {
    calls.push({ url: String(url), method: init.method || 'GET', body: init.body });
    const json = (status, b) => ({ ok: status < 300, status, json: async () => b, text: async () => JSON.stringify(b) });
    const u = String(url);
    if (u.endsWith('/auth/v1/user')) return json(200, { id: USER });
    if (u.startsWith('https://oauth2.googleapis.com/token')) return json(200, { access_token: 'gtok', expires_in: 3600 });
    if (u.includes('/subscriptionsv2/tokens/')) {
      return json(200, { subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE', acknowledgementState: ackState, lineItems: [{ productId: 'grazia_plus_monthly', expiryTime: future }] });
    }
    if (u.includes(':acknowledge')) return json(200, {});
    if (u.includes('/rest/v1/subscriptions?select=')) return json(200, boundTo.map((id) => ({ user_id: id })));
    if (u.includes('/rest/v1/subscriptions?on_conflict')) return json(201, '');
    if (u.includes('/rest/v1/rpc/get_ai_usage')) return json(200, [usageRow]);
    throw new Error(`unexpected fetch ${u}`);
  };
  return calls;
}

const req = (body) => ({ method: 'POST', headers: { authorization: 'Bearer user-jwt' }, body });

test.before(() => {
  const { privateKey } = crypto.generateKeyPairSync('rsa', { modulusLength: 2048 });
  process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON = JSON.stringify({
    client_email: 'svc@test.iam.gserviceaccount.com',
    private_key: privateKey.export({ type: 'pkcs8', format: 'pem' }),
  });
  process.env.SUPABASE_URL = 'https://example.supabase.test';
  process.env.SUPABASE_ANON_KEY = 'anon';
  process.env.SUPABASE_SERVICE_ROLE_KEY = 'service';
  for (const k of ['APPSTORE_ISSUER_ID', 'APPSTORE_KEY_ID', 'APPSTORE_PRIVATE_KEY', 'APPSTORE_BUNDLE_ID']) delete process.env[k];
});

test('android purchase: verifies, upserts, acknowledges, returns usage', async () => {
  const calls = setupFetch();
  const res = mockRes();
  await handler(req({ platform: 'android', productId: 'grazia_plus_monthly', purchaseToken: 'tok.abc-1' }), res);
  assert.equal(res.statusCode, 200, JSON.stringify(res.body));
  assert.equal(res.body.usage.plan, 'plus');
  const upsert = calls.find((c) => c.url.includes('on_conflict=user_id'));
  const row = JSON.parse(upsert.body);
  assert.equal(row.plan, 'plus');
  assert.equal(row.source, 'google_play');
  assert.equal(row.purchase_token, 'tok.abc-1');
  const ackIdx = calls.findIndex((c) => c.url.includes(':acknowledge'));
  assert.ok(ackIdx > calls.indexOf(upsert), 'acknowledge after DB write');
});

test('android purchase already acknowledged is not acknowledged again', async () => {
  const calls = setupFetch({ ackState: 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED' });
  const res = mockRes();
  await handler(req({ platform: 'android', productId: 'grazia_plus_monthly', purchaseToken: 'tok' }), res);
  assert.equal(res.statusCode, 200);
  assert.ok(!calls.some((c) => c.url.includes(':acknowledge')));
});

test('token bound to another user is refused', async () => {
  const calls = setupFetch({ boundTo: ['22222222-2222-2222-2222-222222222222'] });
  const res = mockRes();
  await handler(req({ platform: 'android', productId: 'grazia_plus_monthly', purchaseToken: 'tok' }), res);
  assert.equal(res.statusCode, 409);
  assert.equal(res.body.code, 'purchase_bound_to_other_user');
  assert.ok(!calls.some((c) => c.url.includes('on_conflict')));
});

test('productId the plan comes from must match the purchase', async () => {
  setupFetch();
  const res = mockRes();
  await handler(req({ platform: 'android', productId: 'grazia_pro_monthly', purchaseToken: 'tok' }), res);
  assert.equal(res.statusCode, 400);
  assert.equal(res.body.code, 'product_mismatch');
});

test('unknown product and bad input rejected', async () => {
  setupFetch();
  let res = mockRes();
  await handler(req({ platform: 'android', productId: 'free_money', purchaseToken: 'tok' }), res);
  assert.equal(res.body.code, 'unknown_product');
  res = mockRes();
  await handler(req({ platform: 'web', productId: 'grazia_plus_monthly', purchaseToken: 'tok' }), res);
  assert.equal(res.statusCode, 400);
});

test('ios without APPSTORE_* env returns 503', async () => {
  setupFetch();
  const res = mockRes();
  await handler(req({ platform: 'ios', productId: 'grazia_plus_monthly', purchaseToken: '2000000123' }), res);
  assert.equal(res.statusCode, 503);
  assert.equal(res.body.code, 'ios_verification_not_configured');
});

test('login required', async () => {
  setupFetch();
  const res = mockRes();
  await handler({ method: 'POST', headers: {}, body: {} }, res);
  assert.equal(res.statusCode, 401);
});
