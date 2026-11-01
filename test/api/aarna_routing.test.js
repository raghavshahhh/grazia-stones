// Run: node --test test/api/aarna_routing.test.js
// Aarna intent routing with Gemini mocked: design cards only when the model picks designs,
// plain answers stay plain, search grounding is requested and cited, usage is still logged.
const test = require('node:test');
const assert = require('node:assert');

process.env.GEMINI_API_KEY = 'test-key';
process.env.SUPABASE_URL = 'https://example.supabase.co';
process.env.SUPABASE_ANON_KEY = 'anon';
process.env.SUPABASE_SERVICE_ROLE_KEY = 'service';

const handler = require('../../api/aarna.js');
const { parseReply, resetCatalogue } = handler._test;

const STONES = [
  { id: 'u-pietra', name: 'Pietra', colors: ['Steel Grey'], tags: ['Living Rooms'], description: 'Twisted ribbon', collections: { name: 'Premium Surface Collection' } },
  { id: 'u-grande', name: 'Grande Ledge Series', colors: null, tags: ['ATY 10'], description: 'Rugged ledge', collections: { name: 'Grande Ledge Series' } },
];

function call(message, geminiReply, { geminiStatus = 200, grounding } = {}) {
  resetCatalogue();
  const calls = [];
  global.fetch = async (url, opts) => {
    calls.push({ url, body: opts && opts.body });
    if (url.includes('/rest/v1/stones')) return { ok: true, json: async () => STONES };
    if (url.includes('/rest/v1/ai_usage_events')) return { ok: true, status: 201 };
    if (url.includes('generativelanguage')) {
      if (geminiStatus !== 200) return { ok: false, status: geminiStatus, json: async () => ({}) };
      return {
        ok: true,
        status: 200,
        json: async () => ({
          candidates: [{ content: { parts: [{ text: geminiReply }] }, groundingMetadata: grounding }],
          usageMetadata: { promptTokenCount: 10, candidatesTokenCount: 5, totalTokenCount: 15 },
        }),
      };
    }
    throw new Error('unexpected ' + url);
  };
  const res = { code: null, body: null, setHeader() {}, status(c) { this.code = c; return this; }, json(b) { this.body = b; return this; }, end() {} };
  const req = { method: 'POST', headers: {}, body: { message, history: [] }, socket: {} };
  return handler(req, res).then(() => ({ res, calls }));
}

test('plain question: no design cards, tag-free text, search tool offered, catalogue in prompt, usage logged', async () => {
  const { res, calls } = await call('How do I install cultured stone?', 'Prepare the wall, then fix each piece with adhesive.');
  assert.equal(res.code, 200);
  assert.deepEqual(res.body.designs, []);
  assert.equal(res.body.text, 'Prepare the wall, then fix each piece with adhesive.');
  const gem = JSON.parse(calls.find((c) => c.url.includes('generativelanguage')).body);
  assert.deepEqual(gem.tools, [{ google_search: {} }]);
  assert.match(gem.system_instruction.parts[0].text, /D1 \| Pietra \| Premium Surface Collection \| colours: Steel Grey/);
  assert.ok(calls.some((c) => c.url.includes('/rest/v1/ai_usage_events')));
});

test('design request: only the picked, existing designs come back, in order, tag stripped', async () => {
  const { res } = await call('Show me grey stones for a living room', '**Pietra** in Steel Grey suits it. Cards below.\n[[DESIGNS: D1, D9, D1]]');
  assert.equal(res.code, 200);
  assert.deepEqual(res.body.designs, [{ id: 'u-pietra', name: 'Pietra', collection: 'Premium Surface Collection' }]);
  assert.ok(!res.body.text.includes('[['));
  assert.ok(!res.body.text.includes('D1'));
});

test('grounded answer cites its web sources', async () => {
  const grounding = { groundingChunks: [{ web: { uri: 'https://x/1', title: 'archdaily.com' } }, { web: { uri: 'https://x/2', title: 'archdaily.com' } }, { web: { uri: 'https://x/3', title: 'dezeen.com' } }] };
  const { res } = await call('Latest wall cladding trend 2026?', 'Textured 3D walls are big.', { grounding });
  assert.deepEqual(res.body.sources.map((s) => s.title), ['archdaily.com', 'dezeen.com']);
  assert.match(res.body.text, /Sources: archdaily\.com, dezeen\.com$/);
  assert.deepEqual(res.body.designs, []);
});

test('a model that rejects the search tool is retried once without it', async () => {
  resetCatalogue();
  const bodies = [];
  global.fetch = async (url, opts) => {
    if (url.includes('/rest/v1/stones')) return { ok: true, json: async () => STONES };
    if (url.includes('/rest/v1/ai_usage_events')) return { ok: true, status: 201 };
    const b = JSON.parse(opts.body);
    bodies.push(b);
    if (b.tools) return { ok: false, status: 400, json: async () => ({}) };
    return { ok: true, status: 200, json: async () => ({ candidates: [{ content: { parts: [{ text: 'Hello!' }] } }] }) };
  };
  const res = { code: null, body: null, setHeader() {}, status(c) { this.code = c; return this; }, json(b) { this.body = b; return this; }, end() {} };
  await handler({ method: 'POST', headers: {}, body: { message: 'hi' }, socket: {} }, res);
  assert.equal(res.code, 200);
  assert.equal(bodies.length, 2);
  assert.ok(bodies[0].tools && !bodies[1].tools);
});

test('upstream 429 stays 429', async () => {
  const { res } = await call('hi', '', { geminiStatus: 429 });
  assert.equal(res.code, 429);
});

test('parseReply ignores unknown keys and caps at 6', () => {
  const many = Array.from({ length: 10 }, (_, i) => ({ id: `s${i}`, name: `S${i}` }));
  const { designs, text } = parseReply('Hi\n[[DESIGNS: D1,D2,D3,D4,D5,D6,D7,D99]]', many);
  assert.equal(designs.length, 6);
  assert.equal(text, 'Hi');
});
