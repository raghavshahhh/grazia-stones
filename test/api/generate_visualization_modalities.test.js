// Run: node --test test/api/generate_visualization_modalities.test.js
// Gemini is asked for the image only; a model that rejects that (400) is retried once with TEXT + IMAGE.
const test = require('node:test');
const assert = require('node:assert');

process.env.GEMINI_API_KEY = 'test-key';
process.env.SUPABASE_URL = 'https://example.supabase.co';
process.env.SUPABASE_ANON_KEY = 'anon';
process.env.SUPABASE_SERVICE_ROLE_KEY = 'service';

const handler = require('../../api/generate-visualization.js');
const PNG = 'data:image/png;base64,iVBORw0KGgo=';
const rpc = { ok: true, reason: null, plan: 'free', source: null, period_end: null, trial_ends_at: null, monthly_limit: 3, monthly_used: 1, daily_limit: 3, daily_used: 1, resets_at: null };
const imageReply = { ok: true, status: 200, json: async () => ({ candidates: [{ content: { parts: [{ inlineData: { mimeType: 'image/png', data: 'AAAA' } }] } }] }) };

function run(geminiReplies) {
  const gemini = [];
  global.fetch = async (url, opts) => {
    if (url.endsWith('/auth/v1/user')) return { ok: true, json: async () => ({ id: 'u1' }) };
    if (url.includes('/rpc/consume_ai_render')) return { ok: true, text: async () => JSON.stringify([rpc]) };
    if (url.includes('/rpc/refund_ai_render')) return { ok: true, text: async () => '' };
    if (url.includes('/rest/v1/ai_usage_events')) return { ok: true, status: 201 };
    if (url.includes('generativelanguage')) {
      gemini.push({ url, modalities: JSON.parse(opts.body).generationConfig.responseModalities });
      return geminiReplies.shift();
    }
    throw new Error('unexpected ' + url);
  };
  const res = { code: null, body: null, setHeader() {}, status(c) { this.code = c; return this; }, json(b) { this.body = b; return this; }, end() {} };
  const req = { method: 'POST', headers: { authorization: 'Bearer t' }, body: { image: PNG, designImage: PNG }, socket: {} };
  return handler(req, res).then(() => ({ res, gemini }));
}

test('asks for the image only and returns it', async () => {
  const { res, gemini } = await run([imageReply]);
  assert.equal(res.code, 200);
  assert.equal(res.body.resultImage, 'data:image/png;base64,AAAA');
  assert.deepEqual(gemini.map((g) => g.modalities), [['IMAGE']]);
});

test('a 400 on image-only retries the same model with TEXT + IMAGE', async () => {
  const bad = { ok: false, status: 400, text: async () => 'bad modality' };
  const { res, gemini } = await run([bad, imageReply]);
  assert.equal(res.code, 200);
  assert.deepEqual(gemini.map((g) => g.modalities), [['IMAGE'], ['TEXT', 'IMAGE']]);
  assert.equal(gemini[0].url, gemini[1].url);
});
