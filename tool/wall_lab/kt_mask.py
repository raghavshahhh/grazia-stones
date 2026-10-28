"""Exact numpy port of the phone's wall mask (WallSegmenter.labGrid + nonWallSeeds + WallGeodesic.segment), so
the mask can be tuned on dumped frames (debug.grazia.dump) and the result checked before it goes into Kotlin.

  D=<segdump dir> python kt_mask.py f11 <seed_x> <seed_y> [out.png]      (seed in GW x GH grid pixels)
"""
import json, os, sys
import numpy as np, cv2, onnxruntime as ort

GW, GH, IN_W, IN_H = 270, 600, 160, 352
OUT_W, OUT_H = IN_W // 8, IN_H // 8
HERE = os.path.dirname(os.path.abspath(__file__))
D = os.environ.get('D', 'segdump')
P = dict(EPS=0.002, LAMBDA_CHROMA=0.08, TOL_CHROMA=6.0, MU_LIGHT=0.05, TOL_LIGHT=9.0, T=3.0, ITERS=3, BORDER=2,
         BG_CHROMA=10.0, BG_LIGHT=30.0)
# ADE20K outdoor classes the model hallucinates on plain/close-up/overexposed indoor walls (sky, tree, road, grass,
# earth, mountain, water, sea, field, sand, river, hill): never a background seed indoors.
OUTDOOR = [2, 4, 6, 9, 13, 16, 21, 26, 29, 46, 60, 68]


def load(fid):
    j = json.load(open(f'{D}/{fid}.json'))
    w, h, yr, uvr, uvp = j['w'], j['h'], j['yRow'], j['uvRow'], j['uvPix']
    y = np.frombuffer(open(f'{D}/{fid}.y', 'rb').read(), np.uint8)
    u = np.frombuffer(open(f'{D}/{fid}.u', 'rb').read(), np.uint8)
    v = np.frombuffer(open(f'{D}/{fid}.v', 'rb').read(), np.uint8)
    c = np.array(j['viewCornersToImage'], np.float32).reshape(4, 2)
    return (y, u, v, w, h, yr, uvr, uvp), c


def sample_rgb(raw, c, gw, gh):
    """Nearest-pixel YUV->RGB of the view grid (transformCoordinates2d is affine for this camera)."""
    y, u, v, w, h, yr, uvr, uvp = raw
    gx = (np.arange(gw) + 0.5) / gw; gy = (np.arange(gh) + 0.5) / gh
    X, Y = np.meshgrid(gx, gy)
    ix = c[0, 0] + (c[1, 0] - c[0, 0]) * X + (c[2, 0] - c[0, 0]) * Y
    iy = c[0, 1] + (c[1, 1] - c[0, 1]) * X + (c[2, 1] - c[0, 1]) * Y
    px = np.clip(ix.astype(int), 0, w - 1); py = np.clip(iy.astype(int), 0, h - 1)
    yy = y[py * yr + px].astype(np.float32)
    uvi = (py // 2) * uvr + (px // 2) * uvp
    uu = np.where(uvi < len(u), u[np.minimum(uvi, len(u) - 1)], 128).astype(np.float32) - 128
    vv = np.where(uvi < len(v), v[np.minimum(uvi, len(v) - 1)], 128).astype(np.float32) - 128
    return np.stack([yy + 1.402 * vv, yy - 0.344136 * uu - 0.714136 * vv, yy + 1.772 * uu], -1).clip(0, 255)


def lab_grid(rgb):
    k5 = np.array([0.0663, 0.2483, 0.3707, 0.2483, 0.0663], np.float32)
    sm = cv2.sepFilter2D(rgb.astype(np.float32), -1, k5, k5, borderType=cv2.BORDER_REPLICATE)
    v = np.clip(sm.astype(int), 0, 255) / 255.0
    lin = np.where(v <= 0.04045, v / 12.92, ((v + 0.055) / 1.055) ** 2.4)
    X = (0.412453 * lin[..., 0] + 0.357580 * lin[..., 1] + 0.180423 * lin[..., 2]) / 0.950456
    Yl = 0.212671 * lin[..., 0] + 0.715160 * lin[..., 1] + 0.072169 * lin[..., 2]
    Z = (0.019334 * lin[..., 0] + 0.119193 * lin[..., 1] + 0.950227 * lin[..., 2]) / 1.088754
    f = lambda t: np.where(t > 0.008856, np.cbrt(t), 7.787 * t + 16 / 116)
    L = np.where(Yl > 0.008856, 116 * np.cbrt(Yl) - 16, 903.3 * Yl)
    return [L.astype(np.float32).ravel(), (500 * (f(X) - f(Yl)) + 128).astype(np.float32).ravel(),
            (200 * (f(Yl) - f(Z)) + 128).astype(np.float32).ravel()]


_sess = None
def model(rgb_in):
    global _sess
    if _sess is None:
        _sess = ort.InferenceSession(os.path.join(HERE, '../../android/app/src/main/assets/models/wall_seg_160x352.onnx'),
                                     providers=['CPUExecutionProvider'])
    MEAN = np.array([0.485, 0.456, 0.406], np.float32); STD = np.array([0.229, 0.224, 0.225], np.float32)
    x = ((rgb_in / 255.0 - MEAN) / STD).astype(np.float32).transpose(2, 0, 1)[None]
    logits = _sess.run(None, {'image': x})[0][0]
    arg = logits.argmax(0); mx = logits.max(0); s = np.exp(logits - mx).sum(0)
    non_wall = (arg != 0) & (arg != 1) & (1.0 / s > 0.5) & ~np.isin(arg, OUTDOOR)
    return non_wall, arg


def non_wall_seeds(cells):
    k = np.arange(GW * GH); x = k % GW; y = k // GW
    up = cells.ravel()[(y * OUT_H // GH) * OUT_W + x * OUT_W // GW].reshape(GH, GW)
    r = 4
    er = cv2.erode(up.astype(np.uint8), np.ones((2 * r + 1, 2 * r + 1), np.uint8), borderType=cv2.BORDER_CONSTANT, borderValue=0)
    return er.astype(bool).ravel()


def edge_cost(lab, w, h):
    out = np.zeros(w * h, np.float32)
    for ch in lab:
        a = ch.reshape(h, w)
        p = np.pad(a, 1, mode='reflect')
        gx = (p[:-2, 2:] + 2 * p[1:-1, 2:] + p[2:, 2:]) - (p[:-2, :-2] + 2 * p[1:-1, :-2] + p[2:, :-2])
        gy = (p[2:, :-2] + 2 * p[2:, 1:-1] + p[2:, 2:]) - (p[:-2, :-2] + 2 * p[:-2, 1:-1] + p[:-2, 2:])
        out += (gx * gx + gy * gy).ravel()
    return np.sqrt(out) / 8


def geodesic(s, w, h, seeds, iters):
    # Dijkstra (the raster sweeps approximate it; equal on the test frames per WallGeodesic's comment).
    import heapq
    d = np.full(w * h, np.inf, np.float32)
    pq = []
    for k in seeds: d[k] = 0; pq.append((0.0, int(k)))
    heapq.heapify(pq)
    while pq:
        dk, k = heapq.heappop(pq)
        if dk > d[k]: continue
        y, x = divmod(k, w)
        for n in ((k - w) if y > 0 else -1, (k + w) if y < h - 1 else -1, (k - 1) if x > 0 else -1, (k + 1) if x < w - 1 else -1):
            if n < 0: continue
            nd = dk + 0.5 * (s[k] + s[n])
            if nd < d[n]: d[n] = nd; heapq.heappush(pq, (nd, n))
    return d


def illumination(L, m, w, h):
    fill = L[m].mean() if m.any() else 50
    img = np.where(m, L, fill).reshape(h, w)
    small = np.clip(cv2.resize(img, (w // 4, h // 4), interpolation=cv2.INTER_AREA), 0, 100).astype(np.uint8)
    med = cv2.medianBlur(small, 31) if min(small.shape) > 31 else small
    return cv2.resize(med.astype(np.float32), (w, h), interpolation=cv2.INTER_LINEAR).ravel()


def segment(lab, w, h, sx, sy, non_wall, p=P):
    L, la, lb = lab
    cost = cv2.dilate(edge_cost(lab, w, h).reshape(h, w), np.ones((3, 3), np.uint8)).ravel()
    def patch(a, r):
        return a.reshape(h, w)[max(0, sy - r):sy + r, max(0, sx - r):sx + r].ravel()
    refA = np.median(patch(la, 20)); refB = np.median(patch(lb, 20))
    floor = np.quantile(patch(cost, 25), 0.95)
    e = np.maximum(cost - floor, 0)
    dc = np.sqrt((la - refA) ** 2 + (lb - refB) ** 2)
    step = p['EPS'] + e * e + p['LAMBDA_CHROMA'] * np.maximum(dc - p['TOL_CHROMA'], 0) ** 2
    fg = [min(max(sy + (i // 5 - 2) * 3, 0), h - 1) * w + min(max(sx + (i % 5 - 2) * 3, 0), w - 1) for i in range(25)]
    if p['BG_CHROMA'] is not None:
        # A background seed must LOOK different from the wall; the model also calls plain plaster "door"/"person".
        refL = np.median(patch(L, 20))
        far = (dc > p['BG_CHROMA']) | (np.abs(L - refL) > p['BG_LIGHT'])
        non_wall = non_wall & far
    bg = np.flatnonzero(non_wall)
    dB = geodesic(step, w, h, bg, p['ITERS'])
    first = geodesic(step, w, h, fg, p['ITERS'])
    m1 = (first < p['T']) & (first < dB)
    illum = illumination(L, m1, w, h)
    step = step + p['MU_LIGHT'] * np.maximum(np.abs(L - illum) - p['TOL_LIGHT'], 0) ** 2
    b = p['BORDER']
    s2 = step.reshape(h, w).copy(); s2[:b] = s2[-b:] = 1e3; s2[:, :b] = s2[:, -b:] = 1e3
    dF = geodesic(s2.ravel(), w, h, fg, p['ITERS'])
    return ((dF < p['T']) & (dF < dB)).reshape(h, w), dF.reshape(h, w), dB.reshape(h, w)


def run(fid, sx, sy, p=P):
    raw, c = load(fid)
    rgb = sample_rgb(raw, c, GW, GH)
    non_wall, arg = model(sample_rgb(raw, c, IN_W, IN_H))
    m, dF, dB = segment(lab_grid(rgb), GW, GH, sx, sy, non_wall_seeds(non_wall), p)
    return rgb, m, arg, non_wall


def overlay(rgb, m, sx, sy, arg=None):
    out = rgb.copy()
    out[m] = out[m] * 0.45 + np.array([0, 255, 0]) * 0.55
    cv2.circle(out, (sx, sy), 5, (255, 0, 0), -1)
    return cv2.cvtColor(out.astype(np.uint8), cv2.COLOR_RGB2BGR)


if __name__ == '__main__':
    fid, sx, sy = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
    rgb, m, arg, nw = run(fid, sx, sy)
    print(f'{fid}: wall {m.mean() * 100:.1f}% of view, model wall/building cells {(np.isin(arg, [0, 1])).mean() * 100:.0f}%')
    cv2.imwrite(sys.argv[4] if len(sys.argv) > 4 else f'{fid}_mask.png', overlay(rgb, m, sx, sy))
