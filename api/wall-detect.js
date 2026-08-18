// Server-side proxy for NVIDIA NIM wall/surface detection.
// Keeps NVIDIA_NIM_API_KEY out of the client bundle — ar_camera.js calls
// this endpoint instead of NIM directly (grazia-stones is a static SPA;
// anything shipped to build/web is world-readable).

const NIM_URL = 'https://integrate.api.nvidia.com/v1/chat/completions';
const NIM_MODEL = 'meta/llama-3.2-11b-vision-instruct';

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

  const apiKey = process.env.NVIDIA_NIM_API_KEY;
  if (!apiKey) {
    res.status(500).json({ error: 'NVIDIA_NIM_API_KEY not configured' });
    return;
  }

  const { image } = req.body || {};
  if (!image || typeof image !== 'string' || !image.startsWith('data:image/')) {
    res.status(400).json({ error: 'image must be a data:image/... base64 URL' });
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
      const detail = await nimRes.text();
      res.status(502).json({ error: 'NIM request failed', detail });
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
    res.status(502).json({ error: 'NIM proxy error', detail: String(err) });
  }
};
