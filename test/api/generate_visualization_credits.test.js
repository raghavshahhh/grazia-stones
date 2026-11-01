// Run: node --test test/api/generate_visualization_credits.test.js
// Checks the AI Studio gate: login required, daily/monthly plan limits (402), refund on failure.
const test = require('node:test');
const assert = require('node:assert');

process.env.GEMINI_API_KEY = 'test-key';
process.env.SUPABASE_URL = 'https://example.supabase.co';
process.env.SUPABASE_ANON_KEY = 'anon';
process.env.SUPABASE_SERVICE_ROLE_KEY = 'service';

const handler = require('../../api/generate-visualization.js');
const PNG = 'data:image/png;base64,iVBORw0KGgo=';

function call(headers, rpc) {
  const calls = [];
  global.fetch = async (url, opts) => {
    calls.push(url);
    if (url.endsWith('/auth/v1/user')) return { ok: true, json: async () => ({ id: 'u1' }) };
    if (url.includes('/rpc/consume_ai_render')) return { ok: true, text: async () => JSON.stringify([rpc]) };
    if (url.includes('/rpc/refund_ai_render')) return { ok: true, text: async () => '' };
    if (url.includes('/rest/v1/ai_usage_events')) return { ok: true, status: 201 };
    if (url.includes('generativelanguage')) return { ok: false, status: 500, text: async () => 'boom' };
    throw new Error('unexpected ' + url);
  };
  const res = { code: null, body: null, setHeader() {}, status(c) { this.code = c; return this; }, json(b) { this.body = b; return this; }, end() {} };
  const req = { method: 'POST', headers, body: { image: PNG, designImage: PNG, stoneName: 'X' }, socket: {} };
  return handler(req, res).then(() => ({ res, calls }));
}

test('guest is refused before any credit or Gemini call', async () => {
  const { res, calls } = await call({}, {});
  assert.equal(res.code, 401);
  assert.equal(res.body.code, 'login_required');
  assert.ok(!calls.some((u) => u.includes('generativelanguage')));
});

const usage = { plan: 'free', source: null, period_end: null, trial_ends_at: null, monthly_limit: 3, monthly_used: 1, daily_limit: 3, daily_used: 3, resets_at: null };

test('daily limit returns 402 and never calls Gemini', async () => {
  const { res, calls } = await call({ authorization: 'Bearer t' }, { ok: false, reason: 'daily_limit', ...usage });
  assert.equal(res.code, 402);
  assert.equal(res.body.code, 'daily_limit');
  assert.equal(res.body.usage.dailyUsed, 3);
  assert.ok(!calls.some((u) => u.includes('generativelanguage')));
});

test('monthly limit returns 402', async () => {
  const { res } = await call({ authorization: 'Bearer t' }, { ok: false, reason: 'monthly_limit', ...usage, monthly_used: 3 });
  assert.equal(res.code, 402);
  assert.equal(res.body.code, 'monthly_limit');
});

test('render is refunded and logged as failed when Gemini fails', async () => {
  const { res, calls } = await call({ authorization: 'Bearer t' }, { ok: true, reason: null, ...usage, daily_used: 1 });
  assert.equal(res.code, 502);
  assert.ok(calls.some((u) => u.includes('/rpc/refund_ai_render')));
  assert.ok(calls.some((u) => u.includes('/rest/v1/ai_usage_events')));
});
