// Run: node --test test/api/security_hardening.test.js
// CORS allow-list, no upstream/internal error text in responses, prompt fields capped.
const test = require('node:test');
const assert = require('node:assert');

process.env.GEMINI_API_KEY = 'test-key';
process.env.SUPABASE_URL = 'https://example.supabase.co';
process.env.SUPABASE_ANON_KEY = 'anon';
process.env.SUPABASE_SERVICE_ROLE_KEY = 'service';

const aarna = require('../../api/aarna.js');
const viz = require('../../api/generate-visualization.js');
const PNG = 'data:image/png;base64,iVBORw0KGgo=';
const usage = { plan: 'free', source: null, period_end: null, trial_ends_at: null, monthly_limit: 3, monthly_used: 1, daily_limit: 3, daily_used: 1, resets_at: null };

function mockRes() {
  return { code: null, body: null, headers: {}, setHeader(k, v) { this.headers[k] = v; }, status(c) { this.code = c; return this; }, json(b) { this.body = b; return this; }, end() {} };
}

function mockFetch(gemini) {
  const sent = [];
  global.fetch = async (url, opts) => {
    if (url.endsWith('/auth/v1/user')) return { ok: true, json: async () => ({ id: 'u1' }) };
    if (url.includes('/rpc/consume_ai_render')) return { ok: true, text: async () => JSON.stringify([{ ok: true, reason: null, ...usage }]) };
    if (url.includes('/rpc/refund_ai_render')) return { ok: true, text: async () => '' };
    if (url.includes('/rest/v1/ai_usage_events')) return { ok: true, status: 201 };
    if (url.includes('/rest/v1/stones')) return { ok: true, json: async () => [] };
    if (url.includes('generativelanguage')) { sent.push(JSON.parse(opts.body)); return gemini(); }
    throw new Error('unexpected ' + url);
  };
  return sent;
}

test('aarna refuses a foreign *.vercel.app origin, allows this project and native apps', async () => {
  mockFetch(() => ({ ok: true, json: async () => ({ candidates: [{ content: { parts: [{ text: 'hi' }] } }] }) }));
  for (const [origin, want] of [
    ['https://evil-attacker.vercel.app', 403],
    ['https://grazia-stones.vercel.app.evil.com', 403],
    ['https://grazia-stones-git-main-raghavshah.vercel.app', 200],
    [undefined, 200], // Flutter app on a phone sends no Origin
  ]) {
    const res = mockRes();
    await aarna({ method: 'POST', headers: origin ? { origin } : {}, body: { message: 'hello' }, socket: { remoteAddress: origin || 'native' } }, res);
    assert.equal(res.code, want, String(origin));
  }
});

test('render failure does not echo the upstream error body', async () => {
  mockFetch(() => ({ ok: false, status: 403, text: async () => 'API key not valid for project 123456789' }));
  const res = mockRes();
  await viz({ method: 'POST', headers: { authorization: 'Bearer t' }, body: { image: PNG, stoneName: 'X' }, socket: {} }, res);
  assert.equal(res.code, 502);
  assert.ok(!JSON.stringify(res.body).includes('123456789'));
});

test('stone name / colour / finish are capped before they reach the prompt', async () => {
  const sent = mockFetch(() => ({ ok: true, json: async () => ({ candidates: [{ content: { parts: [{ inlineData: { mimeType: 'image/png', data: 'AA' } }] } }] }) }));
  const res = mockRes();
  const long = 'A'.repeat(5000);
  await viz({ method: 'POST', headers: { authorization: 'Bearer t2' }, body: { image: PNG, stoneName: long, color: long, finish: { evil: 1 } }, socket: {} }, res);
  assert.equal(res.code, 200);
  const prompt = sent[0].contents[0].parts[0].text;
  assert.ok(!prompt.includes('A'.repeat(81)));
  assert.ok(!prompt.includes('[object Object]'));
});
