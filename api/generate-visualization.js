// Server-side proxy for Gemini image generation/editing — AI Studio's
// generation step. Keeps GEMINI_API_KEY out of the client bundle, same
// pattern as api/wall-detect.js (which handles room *analysis* only).

const GEMINI_URL =
  'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent';
const MAX_IMAGE_LENGTH = 500_000;
const ALLOWED_ORIGINS = [
  'https://grazia-stones.vercel.app',
  'http://localhost:3000',
  'http://localhost:8080',
  'https://grazia-stones-git-main-raghavshah.vercel.app',
];

const RATE_LIMIT_WINDOW_MS = 60_000;
const RATE_LIMIT_MAX = 15; // generation is heavier than analysis — tighter cap
const _rateLimitHits = new Map();

function _isRateLimited(ip) {
  const now = Date.now();
  const hit = _rateLimitHits.get(ip);
  if (!hit || now - hit.windowStart > RATE_LIMIT_WINDOW_MS) {
    _rateLimitHits.set(ip, { windowStart: now, count: 1 });
    return false;
  }
  hit.count++;
  return hit.count > RATE_LIMIT_MAX;
}

// 4 variant angles so repeated calls for the same product don't return the
// same image — see PHASE 6 (four distinct concepts) in the product brief.
const VARIANT_PROMPTS = [
  'Render it in natural daytime lighting, straight-on perspective.',
  'Render it in warm evening ambient lighting, slightly angled perspective.',
  'Render it with dramatic accent lighting highlighting the stone texture.',
  'Render it in bright, even studio-style lighting for a clean showroom look.',
];

function _buildPrompt({ stoneName, color, finish, variantIndex }) {
  const variant = VARIANT_PROMPTS[variantIndex % VARIANT_PROMPTS.length];
  return `You are editing a photo of a real room for an architectural visualization product.
Apply "${stoneName}" natural stone cladding${color ? ` in ${color}` : ''}${finish ? `, ${finish} finish` : ''} to the main wall in this photo.

RULES:
- Preserve the room's architecture, perspective, and camera angle exactly.
- Preserve all foreground objects, furniture, windows, doors, and existing decor — do not remove or move them.
- Apply the stone material ONLY to the intended wall surface.
- Keep lighting and shadows physically plausible for the room.
- ${variant}
- Output a photorealistic result, not a flat texture overlay.`;
}

module.exports = async (req, res) => {
  const rawOrigin = req.headers.origin || req.headers.referer || '';
  let originValue = '';
  try {
    originValue = new URL(rawOrigin).origin;
  } catch {
    originValue = '';
  }
  const originAllowed = ALLOWED_ORIGINS.includes(originValue);

  if (originAllowed) {
    res.setHeader('Access-Control-Allow-Origin', originValue);
    res.setHeader('Vary', 'Origin');
  }
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(204).end();
    return;
  }
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }
  if (!originAllowed) {
    res.status(403).json({ error: 'Forbidden' });
    return;
  }

  const ip = req.headers['x-forwarded-for']?.split(',')[0]?.trim() || req.socket?.remoteAddress || 'unknown';
  if (_isRateLimited(ip)) {
    res.status(429).json({ error: 'Too many requests' });
    return;
  }

  const apiKey = (process.env.GEMINI_API_KEY || '').trim();
  if (!apiKey) {
    res.status(503).json({ error: 'GEMINI_API_KEY not configured' });
    return;
  }

  const { image, stoneName, color, finish, variantIndex } = req.body || {};
  if (!image || typeof image !== 'string' || !image.startsWith('data:image/')) {
    res.status(400).json({ error: 'image must be a data:image/... base64 URL' });
    return;
  }
  if (image.length > MAX_IMAGE_LENGTH) {
    res.status(413).json({ error: 'Image too large' });
    return;
  }
  if (!stoneName || typeof stoneName !== 'string') {
    res.status(400).json({ error: 'stoneName is required' });
    return;
  }
  const variant = Number.isInteger(variantIndex) ? variantIndex : 0;

  const [, mimeType, base64Data] = image.match(/^data:(image\/[a-zA-Z+]+);base64,(.+)$/) || [];
  if (!base64Data) {
    res.status(400).json({ error: 'Malformed image data URL' });
    return;
  }

  try {
    const prompt = _buildPrompt({ stoneName, color, finish, variantIndex: variant });

    const geminiRes = await fetch(`${GEMINI_URL}?key=${apiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [
          {
            parts: [
              { text: prompt },
              { inline_data: { mime_type: mimeType, data: base64Data } },
            ],
          },
        ],
      }),
    });

    if (!geminiRes.ok) {
      const errText = await geminiRes.text().catch(() => '');
      res.status(502).json({ error: `Gemini request failed: ${geminiRes.status} ${errText.slice(0, 200)}` });
      return;
    }

    const result = await geminiRes.json();
    const parts = result?.candidates?.[0]?.content?.parts || [];
    const imagePart = parts.find((p) => p.inline_data || p.inlineData);
    const inline = imagePart?.inline_data || imagePart?.inlineData;

    if (!inline?.data) {
      res.status(502).json({ error: 'Gemini did not return an image' });
      return;
    }

    res.status(200).json({
      resultImage: `data:${inline.mime_type || inline.mimeType || 'image/png'};base64,${inline.data}`,
      variantIndex: variant,
    });
  } catch (err) {
    res.status(500).json({ error: `Generation failed: ${err.message}` });
  }
};
