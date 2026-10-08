// Run: node --test test/api/generate_visualization_credits.test.js
// Checks the AI Studio gate: login required, daily/total limits, refund on failure.
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
    if (url.includes('/rpc/consume_ai_credit')) return { ok: true, json: async () => [rpc] };
    if (url.includes('/rpc/refund_ai_credit')) return { ok: true, json: async () => null };
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

test('daily limit returns 429 and never calls Gemini', async () => {
  const { res, calls } = await call({ authorization: 'Bearer t' }, { ok: false, reason: 'daily_limit', credits_remaining: 9, daily_remaining: 0 });
  assert.equal(res.code, 429);
  assert.equal(res.body.code, 'daily_limit');
  assert.ok(!calls.some((u) => u.includes('generativelanguage')));
});

test('no credits left returns 429', async () => {
  const { res } = await call({ authorization: 'Bearer t' }, { ok: false, reason: 'no_credits', credits_remaining: 0, daily_remaining: 3 });
  assert.equal(res.code, 429);
  assert.equal(res.body.code, 'no_credits');
});

test('credit is refunded when Gemini fails', async () => {
  const { res, calls } = await call({ authorization: 'Bearer t' }, { ok: true, reason: null, credits_remaining: 11, daily_remaining: 2 });
  assert.equal(res.code, 502);
  assert.ok(calls.some((u) => u.includes('/rpc/refund_ai_credit')));
});
