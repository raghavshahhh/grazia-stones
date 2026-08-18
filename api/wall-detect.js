// Server-side proxy for NVIDIA NIM wall/surface detection.
// Keeps NVIDIA_NIM_API_KEY out of the client bundle — ar_camera.js calls
// this endpoint instead of NIM directly (grazia-stones is a static SPA;
// anything shipped to build/web is world-readable).

const NIM_URL = 'https://integrate.api.nvidia.com/v1/chat/completions';
const NIM_MODEL = 'meta/llama-3.2-11b-vision-instruct';
const MAX_IMAGE_LENGTH = 200_000; // client sends a 320px jpeg (~20-40KB base64); leaves headroom
const ALLOWED_ORIGINS = ['https://grazia-stones.vercel.app'];

// ponytail: per-instance in-memory counter, not a real distributed rate
// limiter — resets on cold start and doesn't share state across instances.
// Stops casual/scripted abuse cheaply; move to Upstash/Vercel KV if this
// endpoint ever needs to survive a real attack.
const RATE_LIMIT_WINDOW_MS = 60_000;
const RATE_LIMIT_MAX = 20;
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

const PROMPT = `You are a computer-vision assistant for an AR room-visualizer.
Look at this photo of an indoor room and find the single largest flat, unobstructed
wall surface suitable for projecting a texture onto (ignore furniture, doors, windows,
people, floor, ceiling).
Respond with ONLY a JSON object, no prose, no markdown fences:
- If a suitable wall is visible: {"found": true, "x": 0.0-1.0, "y": 0.0-1.0, "width": 0.0-1.0, "height": 0.0-1.0}
  (x,y = top-left corner of the wall region, normalized to image width/height)
- If no suitable wall is visible: {"found": false}`;

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  const origin = req.headers.origin || req.headers.referer || '';
  if (!ALLOWED_ORIGINS.some((allowed) => origin.startsWith(allowed))) {
    res.status(403).json({ error: 'Forbidden' });
    return;
  }

  const ip = req.headers['x-forwarded-for']?.split(',')[0]?.trim() || req.socket?.remoteAddress || 'unknown';
  if (_isRateLimited(ip)) {
    res.status(429).json({ error: 'Too many requests' });
    return;
  }

  const apiKey = process.env.NVIDIA_NIM_API_KEY;
  if (!apiKey) {
    console.error('[wall-detect] NVIDIA_NIM_API_KEY not configured');
    res.status(500).json({ error: 'Service not configured' });
    return;
  }

  const { image } = req.body || {};
  if (!image || typeof image !== 'string' || !image.startsWith('data:image/')) {
    res.status(400).json({ error: 'image must be a data:image/... base64 URL' });
    return;
  }
  if (image.length > MAX_IMAGE_LENGTH) {
    res.status(413).json({ error: 'Image too large' });
    return;
  }

  try {
    const nimRes = await fetch(NIM_URL, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: JSON.stringify({
        model: NIM_MODEL,
        messages: [
          {
            role: 'user',
            content: [
              { type: 'text', text: PROMPT },
              { type: 'image_url', image_url: { url: image } },
            ],
          },
        ],
        max_tokens: 200,
        temperature: 0.0,
      }),
    });

    if (!nimRes.ok) {
      console.error('[wall-detect] NIM request failed', nimRes.status, await nimRes.text());
      res.status(502).json({ error: 'Detection service unavailable' });
      return;
    }

    const data = await nimRes.json();
    const content = data?.choices?.[0]?.message?.content ?? '';
    const jsonMatch = content.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      res.status(200).json({ found: false });
      return;
    }

    const parsed = JSON.parse(jsonMatch[0]);
    res.status(200).json(parsed);
  } catch (err) {
    console.error('[wall-detect] proxy error', err);
    res.status(502).json({ error: 'Detection service unavailable' });
  }
};
