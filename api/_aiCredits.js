// AI Studio plan accounting. Talks to the SECURITY DEFINER functions in
// supabase/migrations/20261030000000_ai_plans.sql through PostgREST with the
// service-role key (server only, never shipped in the app). Limits come from
// public.ai_plan_limits, so nothing here hard-codes a plan's numbers.
// Contract: docs/subscriptions_contract.md.

function _config() {
  const url = (process.env.SUPABASE_URL || '').trim();
  // The Vercel project defines the service key as SUPABASE_SECRET_KEY (Supabase's newer name);
  // without this fallback every generation returned 503 credits_unavailable.
  const key = (process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SECRET_KEY || '').trim();
  return url && key ? { url, key } : null;
}

/** Service-role PostgREST request. `path` is relative to /rest/v1/. */
async function serviceFetch(path, init = {}) {
  const cfg = _config();
  if (!cfg) throw new Error('credits_not_configured');
  return fetch(`${cfg.url}/rest/v1/${path}`, {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      apikey: cfg.key,
      Authorization: `Bearer ${cfg.key}`,
      ...(init.headers || {}),
    },
  });
}

async function _rpc(name, args) {
  const resp = await serviceFetch(`rpc/${name}`, { method: 'POST', body: JSON.stringify(args) });
  if (!resp.ok) throw new Error(`credits_rpc_${name}_${resp.status}`);
  const text = await resp.text();
  if (!text) return null; // void functions
  const data = JSON.parse(text);
  return Array.isArray(data) ? data[0] : data;
}

/** DB row (snake_case) -> contract usage object, plus the keys old app builds read. */
function toUsage(r) {
  const dailyLeft = Math.max(r.daily_limit - r.daily_used, 0);
  const monthlyLeft = r.monthly_limit == null ? null : Math.max(r.monthly_limit - r.monthly_used, 0);
  return {
    plan: r.plan,
    source: r.source,
    periodEnd: r.period_end,
    trialEndsAt: r.trial_ends_at,
    monthlyLimit: r.monthly_limit,
    monthlyUsed: r.monthly_used,
    dailyLimit: r.daily_limit,
    dailyUsed: r.daily_used,
    resetsAt: r.resets_at,
    // Legacy (pre-plans builds): a balance and a daily allowance.
    creditsRemaining: monthlyLeft == null ? dailyLeft : monthlyLeft,
    dailyRemaining: monthlyLeft == null ? dailyLeft : Math.min(dailyLeft, monthlyLeft),
  };
}

/** Spend one render. Resolves { ok, reason, usage }. */
async function consume(userId) {
  const r = await _rpc('consume_ai_render', { p_user: userId });
  return { ok: r.ok, reason: r.reason, usage: toUsage(r) };
}

async function refund(userId) {
  await _rpc('refund_ai_render', { p_user: userId });
}

/** Read-only usage object (does not spend anything). */
async function status(userId) {
  return toUsage(await _rpc('get_ai_usage', { p_user: userId }));
}

/**
 * Record one Gemini call in public.ai_usage_events (admin "AI Usage" screen,
 * supabase/migrations/20261031000000_ai_usage_events.sql). `usageMetadata` is
 * Gemini's response field; userId null = guest. Never throws and never logs
 * user data: a failed insert must not affect the user's request.
 */
async function logUsage({ userId, kind, model, usageMetadata, ok }) {
  const u = usageMetadata || {};
  const n = (v) => (Number.isFinite(v) ? Math.round(v) : null);
  try {
    const resp = await serviceFetch('ai_usage_events', {
      method: 'POST',
      headers: { Prefer: 'return=minimal' },
      body: JSON.stringify({
        user_id: userId || null,
        kind,
        model: model || null,
        prompt_tokens: n(u.promptTokenCount),
        output_tokens: n(u.candidatesTokenCount),
        total_tokens: n(u.totalTokenCount),
        ok: ok !== false,
      }),
      signal: AbortSignal.timeout(3000),
    });
    if (!resp.ok) console.error('[aiUsage] insert failed', resp.status);
  } catch (e) {
    console.error('[aiUsage] insert failed', e.name);
  }
}

module.exports = { consume, refund, status, toUsage, serviceFetch, logUsage };
