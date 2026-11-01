// Offline tests: api/generate-visualization.js and api/aarna.js record each Gemini
// call in public.ai_usage_events, and a failing insert never breaks the request.
// Every network call is mocked; nothing reaches Google or Supabase.
// Run: node --test tool/plans/ai_usage_log.test.js
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');

process.env.GEMINI_API_KEY = 'test-key';
process.env.SUPABASE_URL = 'https://example.supabase.test';
process.env.SUPABASE_ANON_KEY = 'anon';
process.env.SUPABASE_SERVICE_ROLE_KEY = 'service';

const api = path.join(__dirname, '..', '..', 'api');
const render = require(path.join(api, 'generate-visualization.js'));
const aarna = require(path.join(api, 'aarna.js'));

const USER = '11111111-1111-1111-1111-111111111111';
const PNG = 'data:image/png;base64,iVBORw0KGgo=';
const usageRow = {
  ok: true, reason: null, plan: 'trial', source: null, period_end: null, trial_ends_at: null,
  monthly_limit: null, monthly_used: 1, daily_limit: 10, daily_used: 1, resets_at: null,
};
const meta = { promptTokenCount: 1200, candidatesTokenCount: 1290, totalTokenCount: 2600 };

function mockRes() {
  return {
    statusCode: 0, body: null,
    setHeader() {},
    status(c) { this.statusCode = c; return this; },
    json(b) { this.body = b; return this; },
    end() { return this; },
  };
}

/** gemini: the generateContent JSON body; logStatus: insert response status, or 'throw'. */
function setupFetch({ gemini, logStatus = 201 }) {
  const inserts = [];
  global.fetch = async (url, init = {}) => {
    const u = String(url);
    const json = (status, b) => ({ ok: status < 300, status, json: async () => b, text: async () => JSON.stringify(b) });
    if (u.endsWith('/auth/v1/user')) return json(200, { id: USER });
    if (u.includes('/rpc/consume_ai_render')) return json(200, [usageRow]);
    if (u.includes('/rpc/refund_ai_render')) return { ok: true, status: 204, text: async () => '' };
    if (u.includes('generativelanguage')) return json(200, gemini);
    if (u.endsWith('/rest/v1/ai_usage_events')) {
      if (logStatus === 'throw') throw new Error('network down');
      inserts.push({ body: JSON.parse(init.body), headers: init.headers });
      return { ok: logStatus < 300, status: logStatus };
    }
    throw new Error(`unexpected fetch ${u}`);
  };
  return inserts;
}

const quiet = (t) => t.mock.method(console, 'error', () => {});

test('render: success logs one row with tokens, model and user', async () => {
  const inserts = setupFetch({
    gemini: { candidates: [{ content: { parts: [{ inlineData: { mimeType: 'image/png', data: 'AAAA' } }] } }], usageMetadata: meta },
  });
  const res = mockRes();
  await render({ method: 'POST', headers: { authorization: 'Bearer t' }, body: { image: PNG, stoneName: 'Verona' }, socket: {} }, res);
  assert.equal(res.statusCode, 200);
  assert.equal(inserts.length, 1);
  assert.deepEqual(inserts[0].body, {
    user_id: USER, kind: 'render', model: 'gemini-3.1-flash-image',
    prompt_tokens: 1200, output_tokens: 1290, total_tokens: 2600, ok: true,
  });
  assert.equal(inserts[0].headers.Authorization, 'Bearer service');
});

test('render: no image returned is logged as failed with its tokens', async () => {
  const inserts = setupFetch({ gemini: { candidates: [{ content: { parts: [{ text: 'no' }] } }], usageMetadata: meta } });
  const res = mockRes();
  await render({ method: 'POST', headers: { authorization: 'Bearer t' }, body: { image: PNG, stoneName: 'Verona' }, socket: {} }, res);
  assert.equal(res.statusCode, 502);
  assert.equal(inserts[0].body.ok, false);
  assert.equal(inserts[0].body.total_tokens, 2600);
});

test('render: a failing insert does not change the response', async (t) => {
  quiet(t);
  for (const logStatus of [500, 'throw']) {
    setupFetch({
      gemini: { candidates: [{ content: { parts: [{ inline_data: { mime_type: 'image/png', data: 'AAAA' } }] } }] },
      logStatus,
    });
    const res = mockRes();
    await render({ method: 'POST', headers: { authorization: 'Bearer t' }, body: { image: PNG, stoneName: 'Verona' }, socket: {} }, res);
    assert.equal(res.statusCode, 200, String(logStatus));
    assert.ok(res.body.resultImage.startsWith('data:image/png;base64,'));
  }
});

test('aarna: signed-in chat logs user and tokens; guest logs user_id null', async () => {
  const gemini = { candidates: [{ content: { parts: [{ text: 'Hello!' }] } }], usageMetadata: { promptTokenCount: 5000, candidatesTokenCount: 20, totalTokenCount: 5100 } };
  let inserts = setupFetch({ gemini });
  let res = mockRes();
  await aarna({ method: 'POST', headers: { authorization: 'Bearer t' }, body: { message: 'hi' }, socket: {} }, res);
  assert.equal(res.statusCode, 200);
  assert.deepEqual(inserts[0].body, {
    user_id: USER, kind: 'chat', model: 'gemini-3-flash-preview',
    prompt_tokens: 5000, output_tokens: 20, total_tokens: 5100, ok: true,
  });

  inserts = setupFetch({ gemini });
  res = mockRes();
  await aarna({ method: 'POST', headers: { 'x-forwarded-for': '10.0.0.9' }, body: { message: 'hi' }, socket: {} }, res);
  assert.equal(res.statusCode, 200);
  assert.equal(inserts[0].body.user_id, null);
});

test('aarna: missing usageMetadata logs null tokens; failing insert still answers', async (t) => {
  quiet(t);
  const inserts = setupFetch({ gemini: { candidates: [{ content: { parts: [{ text: 'Hi' }] } }] } });
  let res = mockRes();
  await aarna({ method: 'POST', headers: { authorization: 'Bearer t' }, body: { message: 'hi' }, socket: {} }, res);
  assert.equal(inserts[0].body.total_tokens, null);

  setupFetch({ gemini: { candidates: [{ content: { parts: [{ text: 'Hi' }] } }] }, logStatus: 'throw' });
  res = mockRes();
  await aarna({ method: 'POST', headers: { authorization: 'Bearer t' }, body: { message: 'hi' }, socket: {} }, res);
  assert.equal(res.statusCode, 200);
  assert.equal(res.body.text, 'Hi');
});
