// Server-side proxy for Gemini image generation/editing — AI Studio's
// generation step. Keeps GEMINI_API_KEY out of the client bundle, same
// pattern as api/wall-detect.js (which handles room *analysis* only).

const { verifyRequestAuth } = require('./_supabaseAuth');

const GEMINI_URL =
  'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent';
const MAX_IMAGE_LENGTH = 500_000;
const ALLOWED_ORIGINS = [
  'https://grazia-stones.vercel.app',
  'http://localhost:3000',
  'http://localhost:8080',
  'https://grazia-stones-git-main-raghavshah.vercel.app',
];

// Authenticated callers get the full limit; guests (intentional current
// product behaviour — see _supabaseAuth.js) get a tighter one. Generation
// is the heaviest/most expensive call in this app, so the guest cap here is
// the strictest of the two AI endpoints.
const RATE_LIMIT_WINDOW_MS = 60_000;
const RATE_LIMIT_MAX_AUTH = 15; // generation is heavier than analysis — tighter cap
const RATE_LIMIT_MAX_GUEST = 4;
const _rateLimitHits = new Map();

function _isRateLimited(key, max) {
  const now = Date.now();
  const hit = _rateLimitHits.get(key);
  if (!hit || now - hit.windowStart > RATE_LIMIT_WINDOW_MS) {
    _rateLimitHits.set(key, { windowStart: now, count: 1 });
    return false;
  }
  hit.count++;
  return hit.count > max;
}

// 4 variant angles and colorway recommendations
const VARIANT_PROMPTS = [
  'Palette 1 (Classic Original): Natural daylight illumination, true-to-life architectural perspective preserving original natural stone veining.',
  'Palette 2 (Warm Champagne Gold): Warm golden hour ambient lighting with soft amber and honey undertones accentuating the stone.',
  'Palette 3 (Noir Charcoal Dramatic): Moody, deep slate noir architectural accent lighting with high-contrast luxury drama.',
  'Palette 4 (Cool Bianco Mist): Ultra-crisp modern showroom illumination with pure silver-white clean marble aesthetics.',
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

// Used when the user supplies an actual photo of the material/design instead
// of picking a catalog stone by name — the two images are sent to Gemini
// together so the *real* uploaded texture is what gets applied, not a text
// guess at what "marble" or "granite" might look like.
function _buildCompositePrompt() {
  return `You are editing a photo of a real room for an architectural visualization product.

You are given two images:
1. The FIRST image is a real photo of a room, showing a wall to be re-clad.
2. The SECOND image is a close-up photo of a real stone/tile/material sample.

TASK: Apply the exact material shown in the SECOND image onto the main wall of the room in the FIRST image, as if that wall were physically re-clad with that material.

RULES:
- Use the actual pattern, color, veining, and texture visible in the second image — do not substitute a generic or different-looking material.
- Preserve the room's architecture, perspective, camera angle, furniture, windows, doors, and all other objects from the first image exactly as they are — change ONLY the wall surface.
- Match the room's existing lighting and shadow direction so the applied material looks physically present, not pasted on.
- Tile/fit the material naturally across the wall's visible area (respecting joints/grain direction if visible in the sample).
- Output a single photorealistic result — not a collage, not a flat texture overlay, not a side-by-side of the two inputs.`;
}

module.exports = async (req, res) => {
  const rawOrigin = req.headers.origin || req.headers.referer || '';
  let originValue = '';
  try {
    originValue = new URL(rawOrigin).origin;
  } catch {
    originValue = '';
  }
  const isVercel = originValue.endsWith('.vercel.app');
  const isLocal = originValue.startsWith('http://localhost:') || originValue.startsWith('http://127.0.0.1:');
  const originAllowed = !originValue || isVercel || isLocal || ALLOWED_ORIGINS.includes(originValue);

  if (originAllowed) {
    res.setHeader('Access-Control-Allow-Origin', originValue || '*');
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

  const auth = await verifyRequestAuth(req);
  if (auth.invalid) {
    res.status(401).json({ error: 'Invalid or expired session' });
    return;
  }

  const ip = req.headers['x-forwarded-for']?.split(',')[0]?.trim() || req.socket?.remoteAddress || 'unknown';
  const rateLimitKey = auth.authenticated ? `user:${auth.userId}` : `guest:${ip}`;
  const rateLimitMax = auth.authenticated ? RATE_LIMIT_MAX_AUTH : RATE_LIMIT_MAX_GUEST;
  if (_isRateLimited(rateLimitKey, rateLimitMax)) {
    res.status(429).json({ error: 'Too many requests' });
    return;
  }

  const apiKey = (process.env.GEMINI_API_KEY || '').trim();
  if (!apiKey) {
    res.status(503).json({ error: 'GEMINI_API_KEY not configured' });
    return;
  }

  const { image, designImage, stoneName, color, finish, variantIndex } = req.body || {};
  if (!image || typeof image !== 'string' || !image.startsWith('data:image/')) {
    res.status(400).json({ error: 'image must be a data:image/... base64 URL' });
    return;
  }
  if (image.length > MAX_IMAGE_LENGTH) {
    res.status(413).json({ error: 'Image too large' });
    return;
  }
  // Either a catalog stone name (existing flow) or an actual photo of the
  // material (designImage — the simple "upload your own design" flow) is
  // required. Without one of the two, Gemini has nothing to apply.
  const hasDesignImage = typeof designImage === 'string' && designImage.startsWith('data:image/');
  if (!hasDesignImage && (!stoneName || typeof stoneName !== 'string')) {
    res.status(400).json({ error: 'Either stoneName or designImage is required' });
    return;
  }
  if (hasDesignImage && designImage.length > MAX_IMAGE_LENGTH) {
    res.status(413).json({ error: 'designImage too large' });
    return;
  }
  const variant = Number.isInteger(variantIndex) ? variantIndex : 0;

  const [, mimeType, base64Data] = image.match(/^data:(image\/[a-zA-Z+]+);base64,(.+)$/) || [];
  if (!base64Data) {
    res.status(400).json({ error: 'Malformed image data URL' });
    return;
  }

  let designMimeType, designBase64Data;
  if (hasDesignImage) {
    [, designMimeType, designBase64Data] = designImage.match(/^data:(image\/[a-zA-Z+]+);base64,(.+)$/) || [];
    if (!designBase64Data) {
      res.status(400).json({ error: 'Malformed designImage data URL' });
      return;
    }
  }

  try {
    const prompt = hasDesignImage
      ? _buildCompositePrompt()
      : _buildPrompt({ stoneName, color, finish, variantIndex: variant });

    const requestParts = hasDesignImage
      ? [
          { text: prompt },
          { inline_data: { mime_type: mimeType, data: base64Data } },
          { inline_data: { mime_type: designMimeType, data: designBase64Data } },
        ]
      : [
          { text: prompt },
          { inline_data: { mime_type: mimeType, data: base64Data } },
        ];

    const geminiRes = await fetch(`${GEMINI_URL}?key=${apiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts: requestParts }],
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
