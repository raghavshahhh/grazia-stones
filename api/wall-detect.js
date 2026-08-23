// Server-side proxy for NVIDIA NIM wall/surface detection.
// Keeps NVIDIA_NIM_API_KEY out of the client bundle — ar_camera.js calls
// this endpoint instead of NIM directly (grazia-stones is a static SPA;
// anything shipped to build/web is world-readable).

const NIM_URL = 'https://integrate.api.nvidia.com/v1/chat/completions';
// Using Llama 3.2 Vision for semantic understanding + geometry.
// SAM (Segment Anything Model) for pixel-level segmentation.
// This endpoint provides both semantic understanding AND true segmentation masks.
const NIM_MODEL_VLM = 'meta/llama-3.2-11b-vision-instruct';
const NIM_MODEL_SAM = 'nvidia/segformer-b5-finetuned-ade-512-512'; // SAM via NIM
const MAX_IMAGE_LENGTH = 500_000; // Increased for higher-res input (640px ~80KB base64)
const ALLOWED_ORIGINS = ['https://grazia-stones.vercel.app', 'http://localhost:3000', 'http://localhost:8080', 'https://grazia-stones-git-main-raghavshah.vercel.app'];

// Rate limiting
const RATE_LIMIT_WINDOW_MS = 60_000;
const RATE_LIMIT_MAX = 30;
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

// Enhanced prompt for more precise geometric detection with pixel-level segmentation
const PROMPT_VLM = `You are a precise computer-vision assistant for an AR room visualizer.
Analyze this indoor room photo and detect wall surfaces and obstacles with high geometric precision.

TASK:
1. Identify ALL flat, vertical wall surfaces suitable for texture projection.
2. Identify obstacles ON those walls that must be excluded from texturing.

OUTPUT FORMAT — JSON ONLY, no prose, no markdown:
{
  "wallDetected": true|false,
  "confidence": 0.0-1.0,
  "walls": [
    {
      "id": "wall_1",
      "confidence": 0.0-1.0,
      "polygon": [[x1,y1], [x2,y2], [x3,y3], [x4,y4]],
      "boundingBox": {"x": 0.0-1.0, "y": 0.0-1.0, "width": 0.0-1.0, "height": 0.0-1.0},
      "surfaceType": "flat|angled|partial",
      "visibleEdges": ["top","bottom","left","right"]
    }
  ],
  "objects": [
    {
      "type": "painting|window|door|furniture|frame|mirror|tv|shelf|outlet|switch|other",
      "confidence": 0.0-1.0,
      "polygon": [[x1,y1], [x2,y2], [x3,y3], [x4,y4]],
      "onWallId": "wall_1"
    }
  ]
}

RULES:
- polygon points: normalized 0.0-1.0 (relative to image width/height)
- polygon order: top-left, top-right, bottom-right, bottom-left (clockwise from top-left)
- boundingBox: minimal axis-aligned box containing the polygon (normalized)
- walls: ONLY flat vertical wall surfaces, NOT floor, ceiling, or angled surfaces > 30° from vertical
- objects: ANY item ON the wall that should NOT be textured over (paintings, frames, mirrors, windows, doors, TVs, shelves, outlets, switches, furniture against wall)
- If multiple wall segments visible (corners, angles), return each as separate wall entry
- If no suitable wall: {"wallDetected": false, "confidence": 0, "walls": [], "objects": []}
- Be precise: polygon corners MUST align with visible wall edges and object boundaries
- Estimate surfaceType: "flat" for full rectangular walls, "partial" for walls partially visible, "angled" for perspective walls
- visibleEdges: which edges of the wall are fully visible in frame`;

// SAM prompt for pixel-level segmentation mask
const PROMPT_SAM = `You are a pixel-level segmentation model. Analyze this indoor room photo and output a segmentation mask for walls and objects.

OUTPUT FORMAT — JSON ONLY:
{
  "wallMask": [[x1,y1], [x2,y2], ...], // polygon points of the main wall area (normalized 0-1)
  "objectMasks": [
    {
      "type": "painting|window|door|furniture|frame|mirror|tv|shelf|outlet|switch|other",
      "confidence": 0.0-1.0,
      "polygon": [[x1,y1], [x2,y2], ...], // precise polygon for each object
      "maskData": "base64_encoded_rle_or_rgba" // optional: run-length encoded mask for exact pixels
    }
  ],
  "confidence": 0.0-1.0
}`;

async function _callNIM(model, prompt, imageDataUrl) {
  const apiKey = process.env.NVIDIA_NIM_API_KEY;
  if (!apiKey) throw new Error('NVIDIA_NIM_API_KEY not configured');
  
  const nimRes = await fetch(NIM_URL, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
      Accept: 'application/json',
    },
    body: JSON.stringify({
      model: model,
      messages: [{
        role: 'user',
        content: [
          { type: 'text', text: prompt },
          { type: 'image_url', image_url: { url: imageDataUrl } },
        ],
      }],
      max_tokens: 2000,
      temperature: 0.0,
    }),
  });
  
  if (!nimRes.ok) {
    const errText = await nimRes.text();
    throw new Error(`NIM ${model} failed: ${nimRes.status} ${errText}`);
  }
  
  const data = await nimRes.json();
  const content = data?.choices?.[0]?.message?.content ?? '';
  const jsonMatch = content.match(/\{[\s\S]*\}/);
  if (!jsonMatch) throw new Error('No JSON in NIM response');
  return JSON.parse(jsonMatch[0]);
}

module.exports = async (req, res) => {
  const rawOrigin = req.headers.origin || req.headers.referer || '';
  // Exact-match the request's actual origin (scheme+host+port) against the
  // allowlist — a startsWith() prefix check would let
  // "https://grazia-stones.vercel.app.evil.com" impersonate an allowed origin.
  let originValue = '';
  try {
    originValue = new URL(rawOrigin).origin;
  } catch {
    originValue = '';
  }
  const originAllowed = ALLOWED_ORIGINS.includes(originValue);

  // CORS: only echo back the origin if it's actually on the allowlist —
  // never reflect an arbitrary Origin header.
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

  const { image, useSegmentation } = req.body || {};
  if (!image || typeof image !== 'string' || !image.startsWith('data:image/')) {
    res.status(400).json({ error: 'image must be a data:image/... base64 URL' });
    return;
  }
  if (image.length > MAX_IMAGE_LENGTH) {
    res.status(413).json({ error: 'Image too large' });
    return;
  }

  try {
    // Step 1: Get VLM understanding (walls + objects with polygons)
    const vlmResult = await _callNIM(NIM_MODEL_VLM, PROMPT_VLM, image);
    
    // Step 2: Get SAM pixel-level segmentation (if requested)
    let samResult = null;
    if (useSegmentation === true) {
      try {
        samResult = await _callNIM(NIM_MODEL_SAM, PROMPT_SAM, image);
      } catch (samErr) {
        console.warn('[wall-detect] SAM segmentation failed, using VLM only:', samErr.message);
      }
    }

    // Step 3: Merge results - SAM masks take precedence for precision
    const merged = _mergeResults(vlmResult, samResult);
    
    // Validate response structure
    if (!merged.wallDetected && (!merged.walls || merged.walls.length === 0)) {
      res.status(200).json({ wallDetected: false, confidence: 0, walls: [], objects: [] });
      return;
    }
    // Ensure required fields exist
    if (!merged.walls) merged.walls = [];
    if (!merged.objects) merged.objects = [];
    if (typeof merged.confidence !== 'number') merged.confidence = 0.5;
    if (typeof merged.wallDetected !== 'boolean') merged.wallDetected = merged.walls.length > 0;

    // Validate each wall has proper polygon
    merged.walls = merged.walls.filter(w => 
      w.polygon && Array.isArray(w.polygon) && w.polygon.length >= 4 &&
      w.polygon.every(p => Array.isArray(p) && p.length === 2 &&
        typeof p[0] === 'number' && typeof p[1] === 'number' &&
        p[0] >= 0 && p[0] <= 1 && p[1] >= 0 && p[1] <= 1)
    );

    // Validate each object
    merged.objects = merged.objects.filter(o =>
      o.polygon && Array.isArray(o.polygon) && o.polygon.length >= 4 &&
      o.polygon.every(p => Array.isArray(p) && p.length === 2 &&
        typeof p[0] === 'number' && typeof p[1] === 'number' &&
        p[0] >= 0 && p[0] <= 1 && p[1] >= 0 && p[1] <= 1)
    );

    // Assign objects to nearest wall if onWallId missing
    merged.objects.forEach(obj => {
      if (!obj.onWallId && merged.walls.length > 0) {
        let bestWall = merged.walls[0];
        let bestDist = Infinity;
        const objCenter = _polygonCenter(obj.polygon);
        merged.walls.forEach(wall => {
          const wallCenter = _polygonCenter(wall.polygon);
          const dist = Math.hypot(objCenter.x - wallCenter.x, objCenter.y - wallCenter.y);
          if (dist < bestDist) {
            bestDist = dist;
            bestWall = wall;
          }
        });
        obj.onWallId = bestWall.id;
      }
    });

    res.status(200).json(merged);
  } catch (err) {
    console.error('[wall-detect] proxy error', err);
    res.status(502).json({ error: 'Detection service unavailable' });
  }
};

function _mergeResults(vlmResult, samResult) {
  // Start with VLM result as base
  const merged = { ...vlmResult };
  
  if (!samResult) return merged;
  
  // If SAM provides wall mask, use it for higher precision
  if (samResult.wallMask && Array.isArray(samResult.wallMask) && samResult.wallMask.length >= 4) {
    // Find the wall in VLM result with highest confidence and replace its polygon
    if (merged.walls && merged.walls.length > 0) {
      let bestWallIdx = 0;
      let bestConf = 0;
      merged.walls.forEach((w, i) => {
        if (w.confidence > bestConf) {
          bestConf = w.confidence;
          bestWallIdx = i;
        }
      });
      merged.walls[bestWallIdx].polygon = samResult.wallMask;
      merged.walls[bestWallIdx].confidence = Math.max(merged.walls[bestWallIdx].confidence, samResult.confidence || 0.8);
      merged.walls[bestWallIdx].pixelLevel = true;
    } else {
      // Create new wall from SAM mask
      merged.wallDetected = true;
      merged.walls = [{
        id: 'wall_sam_1',
        confidence: samResult.confidence || 0.8,
        polygon: samResult.wallMask,
        boundingBox: _polygonToBoundingBox(samResult.wallMask),
        surfaceType: 'flat',
        visibleEdges: ['top','bottom','left','right'],
        pixelLevel: true
      }];
    }
  }
  
  // Merge SAM object masks (higher precision)
  if (samResult.objectMasks && samResult.objectMasks.length > 0) {
    const samObjects = samResult.objectMasks;
    const existingTypes = new Set(merged.objects.map(o => o.type));
    
    samObjects.forEach(samObj => {
      if (!existingTypes.has(samObj.type)) {
        merged.objects.push({
          type: samObj.type,
          confidence: samObj.confidence || 0.8,
          polygon: samObj.polygon,
          onWallId: merged.walls[0]?.id,
          pixelLevel: true,
          maskData: samObj.maskData
        });
        existingTypes.add(samObj.type);
      }
    });
  }
  
  return merged;
}

function _polygonToBoundingBox(polygon) {
  if (!polygon || polygon.length === 0) return { x: 0, y: 0, width: 0, height: 0 };
  let minX = 1, minY = 1, maxX = 0, maxY = 0;
  polygon.forEach(p => {
    minX = Math.min(minX, p[0]);
    minY = Math.min(minY, p[1]);
    maxX = Math.max(maxX, p[0]);
    maxY = Math.max(maxY, p[1]);
  });
  return { x: minX, y: minY, width: maxX - minX, height: maxY - minY };
}

function _polygonCenter(poly) {
  if (!poly || poly.length === 0) return { x: 0.5, y: 0.5 };
  let sumX = 0, sumY = 0;
  poly.forEach(p => { sumX += p[0]; sumY += p[1]; });
  return { x: sumX / poly.length, y: sumY / poly.length };
}