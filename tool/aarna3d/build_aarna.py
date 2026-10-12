#!/usr/bin/env python3
"""Generates assets/3d/aarna.glb: the Aarna marble robot as real 3D geometry with a joint hierarchy
(Body > Chest / Head / Shoulder > Elbow > Wrist > fingers, Eyes) and three clips: Idle, Wave, Blink.
No Blender needed: geometry, PBR materials and glTF animation are written directly.
Run: python3 tool/aarna3d/build_aarna.py  (needs numpy + Pillow)."""
import json, math, os, struct
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)


# ---------------------------------------------------------------- primitives
class Mesh:
    def __init__(s, p, n, uv, i):
        s.p, s.n, s.uv, s.i = (np.asarray(a, d) for a, d in ((p, np.float32), (n, np.float32), (uv, np.float32), (i, np.uint32)))


def _uv(p, n, off):
    ax = np.argmax(np.abs(n), axis=1)
    u = np.where(ax == 0, p[:, 2], p[:, 0])
    v = np.where(ax == 1, p[:, 2], p[:, 1])
    return np.stack([off[0] + u * 1.5, off[1] + v * 1.5], 1)


def _grid_idx(rows, cols, base=0):
    idx = []
    for r in range(rows):
        for c in range(cols):
            a = base + r * (cols + 1) + c
            b, d = a + 1, a + cols + 1
            idx += [a, b, d, b, d + 1, d] if False else [a, d, b, b, d, d + 1]
    return idx


def _orient(p, n, idx):
    """Flip triangles whose winding disagrees with the vertex normals."""
    t = np.asarray(idx, np.int64).reshape(-1, 3)
    fn = np.cross(p[t[:, 1]] - p[t[:, 0]], p[t[:, 2]] - p[t[:, 0]])
    vn = n[t[:, 0]] + n[t[:, 1]] + n[t[:, 2]]
    flip = (fn * vn).sum(1) < 0
    t[flip] = t[flip][:, [0, 2, 1]]
    return t.ravel()


def rounded_box(sx, sy, sz, r, n=10):
    half = np.array([sx, sy, sz]) / 2
    h = half - r
    t = np.linspace(-1, 1, n + 1)
    U, V = np.meshgrid(t, t)
    P, I, base = [], [], 0
    for axis in range(3):
        a1, a2 = [k for k in range(3) if k != axis]
        for sign in (-1, 1):
            q = np.zeros((U.size, 3))
            q[:, axis], q[:, a1], q[:, a2] = sign, U.ravel(), V.ravel()
            P.append(q * half)
            I += _grid_idx(n, n, base)
            base += U.size
    P = np.concatenate(P)
    inner = np.clip(P, -h, h)
    d = P - inner
    nr = d / np.linalg.norm(d, axis=1, keepdims=True)
    pos = inner + nr * r
    return Mesh(pos, nr, _uv(pos, nr, rng.uniform(0.45, 0.55, 2)), _orient(pos, nr, I))


def sphere(nu=28, nv=18):
    P, I = [], []
    for j in range(nv + 1):
        th = math.pi * j / nv
        for i in range(nu + 1):
            ph = 2 * math.pi * i / nu
            P.append([math.sin(th) * math.cos(ph), math.cos(th), math.sin(th) * math.sin(ph)])
    P = np.array(P)
    I = _grid_idx(nv, nu)
    return Mesh(P, P, _uv(P, P, rng.uniform(0.45, 0.55, 2)), _orient(P, P, I))


def cylinder(r, h, seg=36):
    P, N, I = [], [], []
    for y, ny in ((h / 2, 0), (-h / 2, 0)):
        for i in range(seg + 1):
            a = 2 * math.pi * i / seg
            P.append([r * math.cos(a), y, r * math.sin(a)]); N.append([math.cos(a), 0, math.sin(a)])
    I += _grid_idx(1, seg)
    for y, ny in ((h / 2, 1), (-h / 2, -1)):
        c = len(P)
        P.append([0, y, 0]); N.append([0, ny, 0])
        for i in range(seg + 1):
            a = 2 * math.pi * i / seg
            P.append([r * math.cos(a), y, r * math.sin(a)]); N.append([0, ny, 0])
        I += [v for i in range(seg) for v in (c, c + 1 + i, c + 2 + i)]
    P, N = np.array(P), np.array(N)
    return Mesh(P, N, _uv(P, N, rng.uniform(0.45, 0.55, 2)), _orient(P, N, I))


def torus(R, r, nu=48, nv=16):
    P, N, I = [], [], []
    for i in range(nu + 1):
        a = 2 * math.pi * i / nu
        for j in range(nv + 1):
            b = 2 * math.pi * j / nv
            c = np.array([R * math.cos(a), 0, R * math.sin(a)])
            nr = np.array([math.cos(b) * math.cos(a), math.sin(b), math.cos(b) * math.sin(a)])
            P.append(c + r * nr); N.append(nr)
    I = _grid_idx(nu, nv)
    P, N = np.array(P), np.array(N)
    return Mesh(P, N, _uv(P, N, (0.5, 0.5)), _orient(P, N, I))


def tube(path, radii, ring=14):
    path = np.asarray(path, float)
    P, N, I = [], [], []
    for k, c in enumerate(path):
        T = path[min(k + 1, len(path) - 1)] - path[max(k - 1, 0)]
        T /= np.linalg.norm(T)
        B = np.array([0, 0, 1.0])
        Nn = np.cross(B, T)
        for j in range(ring + 1):
            a = 2 * math.pi * j / ring
            d = math.cos(a) * Nn + math.sin(a) * B
            P.append(c + radii[k] * d); N.append(d)
    I = _grid_idx(len(path) - 1, ring)
    P, N = np.array(P), np.array(N)
    return Mesh(P, N, _uv(P, N, (0.5, 0.5)), _orient(P, N, I))


def star_prism(R, r, depth, pts=4):
    poly = []
    for k in range(pts * 2):
        a = math.pi * k / pts + math.pi / 2
        rr = R if k % 2 == 0 else r
        poly.append([rr * math.cos(a), rr * math.sin(a)])
    P, N, I = [], [], []
    for z, nz in ((depth / 2, 1), (-depth / 2, -1)):
        c = len(P)
        P.append([0, 0, z]); N.append([0, 0, nz])
        for x, y in poly:
            P.append([x, y, z]); N.append([0, 0, nz])
        I += [v for k in range(len(poly)) for v in (c, c + 1 + k, c + 1 + (k + 1) % len(poly))]
    for k in range(len(poly)):
        a, b = poly[k], poly[(k + 1) % len(poly)]
        e = np.array([b[0] - a[0], b[1] - a[1]]); nn = np.array([e[1], -e[0], 0.0]); nn /= np.linalg.norm(nn)
        c = len(P)
        for x, y in (a, b):
            for z in (depth / 2, -depth / 2):
                P.append([x, y, z]); N.append(nn)
        I += [c, c + 1, c + 2, c + 1, c + 3, c + 2]
    P, N = np.array(P), np.array(N)
    return Mesh(P, N, _uv(P, N, (0.5, 0.5)), _orient(P, N, I))


# ---------------------------------------------------------------- textures
def noise(size, cells, seed):
    g = np.random.default_rng(seed).random((cells, cells)).astype(np.float32)
    return np.asarray(Image.fromarray((g * 255).astype(np.uint8)).resize((size, size), Image.BICUBIC), np.float32) / 255


def marble_texture(path, size=1024):
    f = sum(noise(size, 4 * 2 ** o, 11 + o) * 0.55 ** o for o in range(5))
    f = (f - f.min()) / (f.max() - f.min())
    g = sum(noise(size, 3 * 2 ** o, 31 + o) * 0.5 ** o for o in range(4))
    g = (g - g.min()) / (g.max() - g.min())
    vein = np.exp(-((f - 0.5) ** 2) / (2 * 0.0065 ** 2)) * 0.9 + np.exp(-((g - 0.42) ** 2) / (2 * 0.010 ** 2)) * 0.35
    vein = np.clip(vein, 0, 1)[..., None]
    base = np.array([240, 229, 208], np.float32)
    mott = (noise(size, 24, 5)[..., None] - 0.5) * 18
    col = base + mott
    col = col * (1 - vein) + np.array([196, 150, 98], np.float32) * vein
    seam = np.zeros((size, size), np.float32)
    k = size // 4
    for r in range(4):  # running-bond stone blocks: horizontal joints + staggered verticals
        seam[r * k : r * k + 3, :] = 1
        seam[:, (r * k + (k // 2 if r % 2 else 0)) % size : (r * k + (k // 2 if r % 2 else 0)) % size + 3] = np.maximum(seam[:, (r * k + (k // 2 if r % 2 else 0)) % size : (r * k + (k // 2 if r % 2 else 0)) % size + 3], 0)
    for r in range(4):
        x0 = (k // 2 if r % 2 else 0)
        for c in range(0, size, k):
            xx = (c + x0) % size
            seam[r * k : (r + 1) * k, xx : xx + 3] = 1
    seam = np.asarray(Image.fromarray((seam * 255).astype(np.uint8)).filter(__import__("PIL.ImageFilter", fromlist=["x"]).GaussianBlur(1.2)), np.float32)[..., None] / 255
    col = col * (1 - 0.30 * seam) + np.array([168, 128, 84], np.float32) * 0.30 * seam
    Image.fromarray(np.clip(col, 0, 255).astype(np.uint8)).save(path)


# ---------------------------------------------------------------- quaternions
def qaxis(ax, a):
    s = math.sin(a / 2)
    return [ax[0] * s, ax[1] * s, ax[2] * s, math.cos(a / 2)]


def qmul(a, b):
    ax, ay, az, aw = a; bx, by, bz, bw = b
    return [aw * bx + ax * bw + ay * bz - az * by, aw * by - ax * bz + ay * bw + az * bx,
            aw * bz + ax * by - ay * bx + az * bw, aw * bw - ax * bx - ay * by - az * bz]


def qe(x=0, y=0, z=0):
    return qmul(qmul(qaxis((0, 1, 0), y), qaxis((1, 0, 0), x)), qaxis((0, 0, 1), z))


# ---------------------------------------------------------------- scene
MATS = {
    "marble": dict(pbrMetallicRoughness=dict(baseColorTexture=dict(index=0), metallicFactor=0.0, roughnessFactor=0.30),
                   extensions={"KHR_materials_clearcoat": dict(clearcoatFactor=0.45, clearcoatRoughnessFactor=0.12)}),
    "rose": dict(pbrMetallicRoughness=dict(baseColorFactor=[0.80, 0.48, 0.42, 1], metallicFactor=1.0, roughnessFactor=0.26)),
    "glass": dict(pbrMetallicRoughness=dict(baseColorFactor=[0.008, 0.008, 0.010, 1], metallicFactor=0.1, roughnessFactor=0.05),
                  extensions={"KHR_materials_clearcoat": dict(clearcoatFactor=1.0, clearcoatRoughnessFactor=0.03)}),
    "glow": dict(pbrMetallicRoughness=dict(baseColorFactor=[1, 0.80, 0.50, 1], metallicFactor=0, roughnessFactor=0.5),
                 emissiveFactor=[1.0, 0.66, 0.26], extensions={"KHR_materials_emissive_strength": dict(emissiveStrength=4.2)}),
    "blush": dict(pbrMetallicRoughness=dict(baseColorFactor=[0.98, 0.45, 0.50, 1], metallicFactor=0, roughnessFactor=0.6),
                  emissiveFactor=[0.98, 0.40, 0.46], extensions={"KHR_materials_emissive_strength": dict(emissiveStrength=0.8)}),
    "bow": dict(pbrMetallicRoughness=dict(baseColorFactor=[0.82, 0.50, 0.50, 1], metallicFactor=0.2, roughnessFactor=0.32),
                extensions={"KHR_materials_clearcoat": dict(clearcoatFactor=0.6, clearcoatRoughnessFactor=0.2)}),
    "porcelain": dict(pbrMetallicRoughness=dict(baseColorFactor=[0.97, 0.89, 0.79, 1], metallicFactor=0, roughnessFactor=0.28),
                      extensions={"KHR_materials_clearcoat": dict(clearcoatFactor=0.5, clearcoatRoughnessFactor=0.15)}),
}
MAT_ORDER = list(MATS)


def node(name, mesh=None, mat=None, t=(0, 0, 0), r=(0, 0, 0, 1), s=(1, 1, 1), kids=()):
    return dict(name=name, mesh=mesh, mat=mat, t=list(t), r=list(r), s=list(s), kids=list(kids))


def arm(side):
    sx = 1 if side == "R" else -1  # R = +x (viewer's right, the waving arm)
    fingers = [node(f"Finger{side}{i}", sphere(), "porcelain", t=(sx * (-0.024 + i * 0.016), -0.100, 0), s=(0.0135, 0.034, 0.0135))
               for i in range(4)]
    thumb = node(f"Thumb{side}", sphere(), "porcelain", t=(sx * 0.040, -0.062, 0.004), r=qe(z=-sx * 0.55), s=(0.014, 0.030, 0.014))
    palm = node(f"Palm{side}", rounded_box(0.074, 0.070, 0.036, 0.016), "porcelain", t=(0, -0.045, 0))
    ring = node(f"WristRing{side}", torus(0.032, 0.009), "rose", t=(0, 0, 0))
    wrist = node(f"Wrist{side}", kids=[ring, palm, thumb] + fingers, t=(0, -0.100, 0))
    fore = node(f"Forearm{side}", rounded_box(0.056, 0.092, 0.056, 0.022), "marble", t=(0, -0.052, 0))
    elbow_j = node(f"ElbowJoint{side}", sphere(), "rose", s=(0.036, 0.036, 0.036))
    elbow = node(f"Elbow{side}", kids=[elbow_j, fore, wrist], t=(0, -0.112, 0), r=qe(z=sx * 0.06))
    upper = node(f"UpperArm{side}", rounded_box(0.062, 0.100, 0.062, 0.024), "marble", t=(0, -0.058, 0))
    sh_j = node(f"ShoulderJoint{side}", sphere(), "rose", s=(0.046, 0.046, 0.046))
    return node(f"Shoulder{side}", kids=[sh_j, upper, elbow], t=(sx * 0.158, 0.185, 0), r=qe(z=sx * 0.12))


def crescent(up, R, alpha, rad, n=26):
    ph = np.linspace(-alpha, alpha, n)
    y = (R * np.cos(ph)) * (1 if up else -1)
    y -= y.mean()
    path = np.stack([R * np.sin(ph), y, np.zeros(n)], 1)
    t = np.linspace(0, 1, n)
    return tube(path, rad * np.sin(np.pi * t) ** 0.55 + 1e-5)


def build_scene():
    HC = 0.21  # head centre inside the Head node
    def lashes(sx):
        out = []
        for k, ang in enumerate((0.55, 0.15, -0.25)):
            d = np.array([sx * math.cos(ang), math.sin(ang) + 0.2, 0]); d /= np.linalg.norm(d)
            a = np.array([sx * 0.044, -0.004 - 0.008 * k, 0]); path = np.stack([a + d * f * 0.020 for f in np.linspace(0, 1, 6)])
            out.append(node(f"Lash{k}", tube(path, 0.0034 * np.sin(np.pi * np.linspace(0.05, 0.95, 6)) ** 0.6 + 1e-5, ring=8), "glow"))
        return out
    eyeL = node("EyeL", crescent(True, 0.046, 1.0, 0.0125), "glow", t=(-0.085, HC + 0.036, 0.191), kids=lashes(-1))
    eyeR = node("EyeR", crescent(True, 0.046, 1.0, 0.0125), "glow", t=(0.085, HC + 0.036, 0.191), kids=lashes(1))
    smile = node("Smile", crescent(False, 0.050, 0.9, 0.0095), "glow", t=(0, HC - 0.048, 0.191))
    blushL = node("BlushL", sphere(), "blush", t=(-0.128, HC - 0.020, 0.188), s=(0.028, 0.016, 0.004))
    blushR = node("BlushR", sphere(), "blush", t=(0.128, HC - 0.020, 0.188), s=(0.028, 0.016, 0.004))
    bezel = node("Bezel", rounded_box(0.350, 0.280, 0.030, 0.016), "rose", t=(0, HC, 0.165))
    glass = node("Glass", rounded_box(0.316, 0.246, 0.030, 0.012), "glass", t=(0, HC, 0.172))
    head_box = node("HeadShell", rounded_box(0.460, 0.380, 0.340, 0.075, n=14), "marble", t=(0, HC, 0))

    def cup(sx):
        return [node("CupShell", cylinder(0.088, 0.072), "marble", t=(sx * 0.262, HC - 0.005, 0), r=qaxis((0, 0, 1), math.pi / 2)),
                node("CupRing", torus(0.086, 0.012), "rose", t=(sx * 0.298, HC - 0.005, 0), r=qaxis((0, 0, 1), math.pi / 2)),
                node("CupStar", star_prism(0.046, 0.012, 0.010), "rose", t=(sx * 0.300, HC - 0.005, 0), r=qaxis((0, 1, 0), sx * math.pi / 2))]

    bow = node("Bow", t=(-0.115, HC + 0.215, 0.085), r=qmul(qe(z=0.30), qe(x=-0.45)), kids=[
        node("BowL", sphere(), "bow", t=(-0.056, 0.008, 0), r=qe(z=0.30), s=(0.062, 0.050, 0.034)),
        node("BowR", sphere(), "bow", t=(0.056, 0.008, 0), r=qe(z=-0.30), s=(0.062, 0.050, 0.034)),
        node("BowKnot", sphere(), "bow", s=(0.030, 0.030, 0.034)),
        node("BowTailL", sphere(), "bow", t=(-0.018, -0.030, 0), r=qe(z=0.4), s=(0.018, 0.036, 0.012)),
        node("BowTailR", sphere(), "bow", t=(0.018, -0.030, 0), r=qe(z=-0.4), s=(0.018, 0.036, 0.012))])
    head = node("Head", t=(0, 0.272, 0), kids=[head_box, bezel, glass, eyeL, eyeR, smile, blushL, blushR, bow] + cup(-1) + cup(1))

    a_l = node("A_L", rounded_box(0.014, 0.100, 0.014, 0.006), "rose", t=(-0.022, 0.125, 0.104), r=qe(z=-0.30))
    a_r = node("A_R", rounded_box(0.014, 0.100, 0.014, 0.006), "rose", t=(0.022, 0.125, 0.104), r=qe(z=0.30))
    a_b = node("A_Bar", rounded_box(0.040, 0.012, 0.014, 0.005), "rose", t=(0, 0.108, 0.104))
    spark = node("ChestStar", star_prism(0.026, 0.007, 0.010), "rose", t=(0.062, 0.172, 0.103))
    chest = node("Chest", kids=[node("Torso", rounded_box(0.270, 0.250, 0.205, 0.058), "marble", t=(0, 0.125, 0)), a_l, a_r, a_b, spark], t=(0, 0, 0))
    neck = node("Neck", cylinder(0.036, 0.070), "rose", t=(0, 0.270, 0))
    legs = []
    for sx in (-1, 1):
        legs.append(node(f"Leg{sx}", cylinder(0.034, 0.090), "marble", t=(sx * 0.068, -0.040, 0)))
        legs.append(node(f"Foot{sx}", rounded_box(0.108, 0.058, 0.140, 0.024), "rose", t=(sx * 0.068, -0.100, 0.018)))
    body = node("Body", t=(0, 0.135, 0), kids=[chest, neck, head, arm("L"), arm("R")] + legs)
    return node("Aarna", kids=[body])


# ---------------------------------------------------------------- animation
FPS = 30
sm = lambda x: (lambda c: c * c * (3 - 2 * c))(min(max(x, 0.0), 1.0))


def blink(t, times):
    return max([0.0] + [1 - sm(abs(t - c) / 0.085) for c in times])


def pose(clip, t):
    P = {}
    br = math.sin(2 * math.pi * t / 3.0)
    P["Chest"] = dict(s=[1 + 0.010 * br, 1 + 0.016 * br, 1 + 0.010 * br])
    P["Body"] = dict(t=[0, 0.135 + 0.0015 * br, 0], r=qe(y=0.0, z=0.008 * math.sin(2 * math.pi * t / 6.0)))
    head_r = dict(x=0.035 * math.sin(2 * math.pi * t / 3.0 + 1.0), y=0.10 * math.sin(2 * math.pi * t / 6.0), z=0.015 * math.sin(2 * math.pi * t / 6.0 + 2))
    raise_w = 0.0
    sh = {"L": -0.12 - 0.025 * math.sin(2 * math.pi * t / 3.0), "R": 0.12 + 0.025 * math.sin(2 * math.pi * t / 3.0)}
    el = {"L": -0.06, "R": 0.06}
    wr = {"L": 0.0, "R": 0.0}
    fing = [0.0] * 4
    bt = [1.4, 4.1]
    if clip == "Wave":
        raise_w = sm(t / 0.7) * (1 - sm((t - 3.0) / 0.8))
        osc = sm((t - 0.6) / 0.3) * (1 - sm((t - 2.8) / 0.3))
        ph = 2 * math.pi * 1.7 * (t - 0.6)
        sh["R"] = 0.12 + raise_w * (1.30 - 0.12) + osc * 0.04 * math.sin(ph)
        el["R"] = 0.06 + raise_w * 1.15
        wr["R"] = osc * 0.46 * math.sin(ph)
        fing = [osc * 0.20 * math.sin(ph + i * 0.7) for i in range(4)]
        head_r["z"] += -0.09 * raise_w; head_r["x"] += 0.04 * raise_w * math.sin(2 * math.pi * 1.7 * t)
        P["Body"]["r"] = qe(y=-0.07 * raise_w, z=0.008 * math.sin(2 * math.pi * t / 6.0))
        bt = [1.0, 2.6]
    if clip == "Blink":
        bt = [0.3]
    P["Head"] = dict(r=qe(**head_r))
    fwd = -0.30 * (raise_w if clip == "Wave" else 0.0)
    for side in "LR":
        P[f"Shoulder{side}"] = dict(r=qe(x=fwd if side == "R" else 0.0, z=sh[side]))
        P[f"Elbow{side}"] = dict(r=qe(z=el[side]))
        P[f"Wrist{side}"] = dict(r=qe(z=wr[side]))
    for i in range(4):
        P[f"FingerR{i}"] = dict(r=qe(z=fing[i]))
        P[f"FingerL{i}"] = dict(r=qe())
    b = blink(t, bt)
    for e in ("EyeL", "EyeR"):
        P[e] = dict(s=[1, 1 - 0.94 * b, 1])
    return P


CLIPS = {"Idle": 6.0, "Wave": 3.8, "Blink": 0.6}


# ---------------------------------------------------------------- glTF writer
class Writer:
    def __init__(s):
        s.buf = bytearray(); s.views = []; s.acc = []

    def add(s, arr, ctype, typ, target=None, minmax=False):
        arr = np.ascontiguousarray(arr)
        while len(s.buf) % 4:
            s.buf.append(0)
        s.views.append(dict(buffer=0, byteOffset=len(s.buf), byteLength=arr.nbytes, **({"target": target} if target else {})))
        s.buf += arr.tobytes()
        a = dict(bufferView=len(s.views) - 1, componentType=ctype, count=len(arr), type=typ)
        if minmax:
            a["min"], a["max"] = arr.min(0).tolist(), arr.max(0).tolist()
        s.acc.append(a)
        return len(s.acc) - 1


def write_glb(root, tex_path, out_path):
    W = Writer()
    nodes, meshes, mesh_cache = [], [], {}

    def flat(n):
        idx = len(nodes)
        d = dict(name=n["name"])
        nodes.append(d)
        if n["mesh"] is not None:
            key = id(n["mesh"]), n["mat"]
            if key not in mesh_cache:
                m = n["mesh"]
                prim = dict(attributes=dict(POSITION=W.add(m.p, 5126, "VEC3", 34962, True), NORMAL=W.add(m.n, 5126, "VEC3", 34962),
                                            TEXCOORD_0=W.add(m.uv, 5126, "VEC2", 34962)),
                            indices=W.add(m.i, 5125, "SCALAR", 34963), material=MAT_ORDER.index(n["mat"]))
                meshes.append(dict(name=n["name"], primitives=[prim]))
                mesh_cache[key] = len(meshes) - 1
            d["mesh"] = mesh_cache[key]
        if n["t"] != [0, 0, 0]: d["translation"] = [float(x) for x in n["t"]]
        if n["r"] != [0, 0, 0, 1]: d["rotation"] = [float(x) for x in n["r"]]
        if n["s"] != [1, 1, 1]: d["scale"] = [float(x) for x in n["s"]]
        kids = [flat(k) for k in n["kids"]]
        if kids: d["children"] = kids
        return idx

    flat(root)
    by_name = {d["name"]: i for i, d in enumerate(nodes)}
    anims = []
    for clip, dur in CLIPS.items():
        times = np.arange(0, dur + 1e-6, 1.0 / FPS, dtype=np.float32)
        poses = [pose(clip, float(t)) for t in times]
        tin = W.add(times, 5126, "SCALAR", None, True)
        samplers, channels = [], []
        for name in poses[0]:
            for path in ("t", "r", "s"):
                if path not in poses[0][name]: continue
                vals = np.array([p[name][path] for p in poses], np.float32)
                if path == "r":  # keep quaternions in one hemisphere so LINEAR blends the short way
                    for k in range(1, len(vals)):
                        if np.dot(vals[k], vals[k - 1]) < 0: vals[k] *= -1
                samplers.append(dict(input=tin, output=W.add(vals, 5126, "VEC4" if path == "r" else "VEC3"), interpolation="LINEAR"))
                channels.append(dict(sampler=len(samplers) - 1, target=dict(node=by_name[name], path=dict(t="translation", r="rotation", s="scale")[path])))
        anims.append(dict(name=clip, samplers=samplers, channels=channels))

    img = open(tex_path, "rb").read()
    while len(W.buf) % 4: W.buf.append(0)
    W.views.append(dict(buffer=0, byteOffset=len(W.buf), byteLength=len(img)))
    W.buf += img
    g = dict(asset=dict(version="2.0", generator="grazia aarna builder"), scene=0, scenes=[dict(nodes=[0])], nodes=nodes, meshes=meshes,
             materials=[dict(name=k, **MATS[k]) for k in MAT_ORDER], textures=[dict(source=0, sampler=0)],
             samplers=[dict(magFilter=9729, minFilter=9987, wrapS=10497, wrapT=10497)], images=[dict(bufferView=len(W.views) - 1, mimeType="image/png")],
             accessors=W.acc, bufferViews=W.views, animations=anims, buffers=[dict(byteLength=len(W.buf))],
             extensionsUsed=["KHR_materials_clearcoat", "KHR_materials_emissive_strength"])
    j = json.dumps(g, separators=(",", ":")).encode()
    j += b" " * (-len(j) % 4)
    W.buf += b"\0" * (-len(W.buf) % 4)
    with open(out_path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(j) + 8 + len(W.buf)))
        f.write(struct.pack("<II", len(j), 0x4E4F534A)); f.write(j)
        f.write(struct.pack("<II", len(W.buf), 0x004E4942)); f.write(bytes(W.buf))
    return len(nodes), len(meshes), len(W.acc)


if __name__ == "__main__":
    tex = os.path.join(OUT, "marble.png")
    marble_texture(tex)
    out = os.path.join(OUT, "aarna.glb")
    n, m, a = write_glb(build_scene(), tex, out)
    print(f"nodes={n} meshes={m} accessors={a} size={os.path.getsize(out) / 1024:.0f} KB -> {out}")
