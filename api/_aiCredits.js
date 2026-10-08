// AI Studio credit accounting. Talks to the SECURITY DEFINER functions in
// supabase/migrations/20261009000000_ai_credits.sql through PostgREST with the
// service-role key (server only, never shipped in the app).

const DAILY_LIMIT = 3;
const SIGNUP_CREDITS = 12;

function _config() {
  const url = (process.env.SUPABASE_URL || '').trim();
  const key = (process.env.SUPABASE_SERVICE_ROLE_KEY || '').trim();
  return url && key ? { url, key } : null;
}

async function _rpc(name, args) {
  const cfg = _config();
  if (!cfg) throw new Error('credits_not_configured');
  const resp = await fetch(`${cfg.url}/rest/v1/rpc/${name}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      apikey: cfg.key,
      Authorization: `Bearer ${cfg.key}`,
    },
    body: JSON.stringify(args),
  });
  if (!resp.ok) throw new Error(`credits_rpc_${name}_${resp.status}`);
  const data = await resp.json();
  return Array.isArray(data) ? data[0] : data;
}

const _limits = { p_daily_limit: DAILY_LIMIT, p_signup_credits: SIGNUP_CREDITS };

/** Spend one credit. Resolves { ok, reason, creditsRemaining, dailyRemaining }. */
async function consume(userId) {
  const r = await _rpc('consume_ai_credit', { p_user: userId, ..._limits });
  return {
    ok: r.ok,
    reason: r.reason,
    creditsRemaining: r.credits_remaining,
    dailyRemaining: r.daily_remaining,
  };
}

async function refund(userId) {
  await _rpc('refund_ai_credit', { p_user: userId });
}

async function status(userId) {
  const r = await _rpc('get_ai_credits', { p_user: userId, ..._limits });
  return { creditsRemaining: r.credits_remaining, dailyRemaining: r.daily_remaining };
}

module.exports = { consume, refund, status, DAILY_LIMIT, SIGNUP_CREDITS };
