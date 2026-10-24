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


def tube(path, radii, ring=14, closed=False):
    path = np.asarray(path, float)
    P, N, I = [], [], []
    L = len(path) - 1
    for k, c in enumerate(path):
        T = (path[(k + 1) % L] - path[(k - 1) % L]) if closed else path[min(k + 1, len(path) - 1)] - path[max(k - 1, 0)]
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


def rrect_path(w, h, r, n=10):
    pts = []
    for cx, cy, a0 in ((w / 2 - r, h / 2 - r, 0), (-w / 2 + r, h / 2 - r, 90), (-w / 2 + r, -h / 2 + r, 180), (w / 2 - r, -h / 2 + r, 270)):
        for k in range(n + 1):
            a = math.radians(a0 + 90 * k / n)
            pts.append([cx + r * math.cos(a), cy + r * math.sin(a), 0])
    pts.append(pts[0])
    return pts


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
    f = sum(noise(size, 4 * 2 ** o, 11 + o) * 0.55 ** o for o in range(6))
    f = (f - f.min()) / (f.max() - f.min())
    g = sum(noise(size, 3 * 2 ** o, 31 + o) * 0.5 ** o for o in range(5))
    g = (g - g.min()) / (g.max() - g.min())
    grey = np.exp(-((f - 0.5) ** 2) / (2 * 0.0045 ** 2)) * 0.80 + np.exp(-((f - 0.31) ** 2) / (2 * 0.0035 ** 2)) * 0.50
    gold = np.exp(-((g - 0.42) ** 2) / (2 * 0.005 ** 2)) * 0.45
    base = np.array([241, 231, 214], np.float32)
    mott = (noise(size, 18, 5)[..., None] - 0.5) * 9 + (noise(size, 64, 9)[..., None] - 0.5) * 4
    col = base + mott
    col = col * (1 - grey[..., None]) + np.array([146, 132, 120], np.float32) * grey[..., None]
    col = col * (1 - gold[..., None]) + np.array([206, 172, 118], np.float32) * gold[..., None]
    seam = np.zeros((size, size), np.float32)
    k = size // 4
    for r in range(4):  # running-bond stone blocks: horizontal joints + staggered verticals
        seam[r * k : r * k + 2, :] = 1
        x0 = k // 2 if r % 2 else 0
        for c in range(0, size, k):
            xx = (c + x0) % size
            seam[r * k : (r + 1) * k, xx : xx + 2] = 1
    seam = np.asarray(Image.fromarray((seam * 255).astype(np.uint8)).filter(__import__("PIL.ImageFilter", fromlist=["x"]).GaussianBlur(1.0)), np.float32)[..., None] / 255
    col = col * (1 - 0.40 * seam) + np.array([168, 140, 110], np.float32) * 0.40 * seam
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
CC = "KHR_materials_clearcoat"
MATS = {
    "marble": dict(pbrMetallicRoughness=dict(baseColorTexture=dict(index=0), metallicFactor=0.0, roughnessFactor=0.34),
                   extensions={CC: dict(clearcoatFactor=0.55, clearcoatRoughnessFactor=0.10)}),
    "rose": dict(pbrMetallicRoughness=dict(baseColorFactor=[0.88, 0.58, 0.47, 1], metallicFactor=1.0, roughnessFactor=0.20)),
    "glass": dict(pbrMetallicRoughness=dict(baseColorFactor=[0.006, 0.005, 0.006, 1], metallicFactor=0.0, roughnessFactor=0.06),
                  extensions={CC: dict(clearcoatFactor=1.0, clearcoatRoughnessFactor=0.02)}),
    "glow": dict(pbrMetallicRoughness=dict(baseColorFactor=[1, 0.52, 0.14, 1], metallicFactor=0, roughnessFactor=0.5),
                 emissiveFactor=[1.0, 0.46, 0.10], extensions={"KHR_materials_emissive_strength": dict(emissiveStrength=1.15)}),
    "bow": dict(pbrMetallicRoughness=dict(baseColorFactor=[0.86, 0.60, 0.55, 1], metallicFactor=0.25, roughnessFactor=0.30),
                extensions={CC: dict(clearcoatFactor=0.8, clearcoatRoughnessFactor=0.12)}),
}
MAT_ORDER = list(MATS)


def node(name, mesh=None, mat=None, t=(0, 0, 0), r=(0, 0, 0, 1), s=(1, 1, 1), kids=()):
    return dict(name=name, mesh=mesh, mat=mat, t=list(t), r=list(r), s=list(s), kids=list(kids))


def arm(side):
    sx = 1 if side == "R" else -1  # R = +x (viewer's right, the waving arm)
    fingers = [node(f"Finger{side}{i}", sphere(), "marble", t=(sx * (-0.027 + i * 0.018), -0.104, 0.002), s=(0.0175, 0.032, 0.0175))
               for i in range(4)]
    thumb = node(f"Thumb{side}", sphere(), "marble", t=(sx * 0.046, -0.060, 0.010), r=qe(z=-sx * 0.55), s=(0.017, 0.030, 0.017))
    palm = node(f"Palm{side}", rounded_box(0.086, 0.078, 0.048, 0.022), "marble", t=(0, -0.050, 0))
    ring = node(f"WristRing{side}", torus(0.035, 0.011), "rose", t=(0, -0.004, 0))
    wrist = node(f"Wrist{side}", kids=[ring, palm, thumb] + fingers, t=(0, -0.096, 0))
    fore = node(f"Forearm{side}", rounded_box(0.064, 0.090, 0.064, 0.026), "marble", t=(0, -0.050, 0))
    elbow_j = node(f"ElbowJoint{side}", sphere(), "rose", s=(0.040, 0.040, 0.040))
    elbow = node(f"Elbow{side}", kids=[elbow_j, fore, wrist], t=(0, -0.108, 0), r=qe(z=sx * 0.06))
    upper = node(f"UpperArm{side}", rounded_box(0.070, 0.096, 0.070, 0.028), "marble", t=(0, -0.056, 0))
    sh_j = node(f"ShoulderJoint{side}", sphere(), "rose", s=(0.052, 0.052, 0.052))
    return node(f"Shoulder{side}", kids=[sh_j, upper, elbow], t=(sx * 0.178, 0.205, 0), r=qe(z=sx * 0.12))


def crescent(up, R, alpha, rad, n=30):
    ph = np.linspace(-alpha, alpha, n)
    y = (R * np.cos(ph)) * (1 if up else -1)
    y -= y.mean()
    path = np.stack([R * np.sin(ph), y, np.zeros(n)], 1)
    t = np.linspace(0, 1, n)
    return tube(path, rad * np.sin(np.pi * t) ** 0.22 + 1e-5, ring=12)


def build_scene():
    HC = 0.22   # head centre inside the Head node (head box is 0.44 tall, so its bottom sits on the Head origin)
    FZ = 0.196  # front of the screen glass
    def lashes(sx):
        out = []
        for k, ang in enumerate((-0.15, -0.55)):
            d = np.array([sx * math.cos(ang), math.sin(ang), 0]); d /= np.linalg.norm(d)
            a = np.array([sx * 0.050, -0.016 - 0.006 * k, 0]); path = np.stack([a + d * f * 0.024 for f in np.linspace(0, 1, 6)])
            out.append(node(f"Lash{k}", tube(path, 0.0028 * np.sin(np.pi * np.linspace(0.05, 0.95, 6)) ** 0.6 + 1e-5, ring=8), "glow"))
        return out
    eyeL = node("EyeL", crescent(True, 0.050, 1.12, 0.0125), "glow", t=(-0.092, HC + 0.032, FZ), kids=lashes(-1))
    eyeR = node("EyeR", crescent(True, 0.050, 1.12, 0.0125), "glow", t=(0.092, HC + 0.032, FZ), kids=lashes(1))
    smile = node("Smile", crescent(False, 0.034, 0.95, 0.0105), "glow", t=(0, HC - 0.060, FZ))
    bezel = node("Bezel", tube(rrect_path(0.418, 0.318, 0.062), np.full(4 * 11 + 1, 0.022), ring=16, closed=True), "rose", t=(0, HC, FZ))
    glass = node("Glass", rounded_box(0.404, 0.304, 0.030, 0.012), "glass", t=(0, HC, FZ - 0.016))
    head_box = node("HeadShell", rounded_box(0.540, 0.440, 0.380, 0.095, n=16), "marble", t=(0, HC, 0))

    def cup(sx):
        return [node("CupShell", cylinder(0.102, 0.074, seg=48), "marble", t=(sx * 0.288, HC - 0.010, -0.005), r=qaxis((0, 0, 1), math.pi / 2)),
                node("CupRing", torus(0.098, 0.016), "rose", t=(sx * 0.326, HC - 0.010, -0.005), r=qaxis((0, 0, 1), math.pi / 2)),
                node("CupStar", star_prism(0.052, 0.013, 0.012), "rose", t=(sx * 0.328, HC - 0.010, -0.005), r=qaxis((0, 1, 0), sx * math.pi / 2))]

    bow = node("Bow", t=(-0.165, HC + 0.205, 0.105), r=qmul(qe(z=0.40), qe(x=-0.12)), kids=[
        node("BowL", sphere(), "bow", t=(-0.066, 0.014, 0), r=qe(z=0.42), s=(0.080, 0.050, 0.030)),
        node("BowR", sphere(), "bow", t=(0.066, 0.014, 0), r=qe(z=-0.42), s=(0.080, 0.050, 0.030)),
        node("BowKnot", sphere(), "bow", s=(0.032, 0.030, 0.038)),
        node("BowTailL", sphere(), "bow", t=(-0.026, -0.040, 0.004), r=qe(z=0.45), s=(0.022, 0.044, 0.014)),
        node("BowTailR", sphere(), "bow", t=(0.026, -0.040, 0.004), r=qe(z=-0.45), s=(0.022, 0.044, 0.014))])
    head = node("Head", t=(0, 0.258, 0), kids=[head_box, bezel, glass, eyeL, eyeR, smile, bow] + cup(-1) + cup(1))

    AZ = 0.117
    a_l = node("A_L", rounded_box(0.019, 0.112, 0.016, 0.007), "rose", t=(-0.024, 0.128, AZ), r=qe(z=-0.30))
    a_r = node("A_R", rounded_box(0.019, 0.112, 0.016, 0.007), "rose", t=(0.024, 0.128, AZ), r=qe(z=0.30))
    a_b = node("A_Bar", rounded_box(0.044, 0.014, 0.016, 0.006), "rose", t=(0, 0.110, AZ))
    spark = node("ChestStar", star_prism(0.028, 0.0075, 0.012), "rose", t=(0.070, 0.180, AZ))
    chest = node("Chest", kids=[node("Torso", rounded_box(0.300, 0.270, 0.230, 0.066), "marble", t=(0, 0.135, 0)), a_l, a_r, a_b, spark], t=(0, 0, 0))
    neck = node("Neck", cylinder(0.040, 0.020), "rose", t=(0, 0.262, 0))
    legs = []
    for sx in (-1, 1):
        legs.append(node(f"Leg{sx}", cylinder(0.040, 0.080), "marble", t=(sx * 0.072, -0.030, 0)))
        legs.append(node(f"Foot{sx}", rounded_box(0.118, 0.052, 0.150, 0.024), "marble", t=(sx * 0.072, -0.084, 0.020)))
        legs.append(node(f"Sole{sx}", rounded_box(0.124, 0.022, 0.156, 0.010), "rose", t=(sx * 0.072, -0.112, 0.020)))
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
    body_y, body_s = 0.135 + 0.0015 * br, 1.0
    body_r = dict(y=0.0, z=0.008 * math.sin(2 * math.pi * t / 6.0))
    head_r = dict(x=0.035 * math.sin(2 * math.pi * t / 3.0 + 1.0), y=0.10 * math.sin(2 * math.pi * t / 6.0), z=0.015 * math.sin(2 * math.pi * t / 6.0 + 2))
    sh = {"L": -0.12 - 0.025 * math.sin(2 * math.pi * t / 3.0), "R": 0.12 + 0.025 * math.sin(2 * math.pi * t / 3.0)}
    shx = {"L": 0.0, "R": 0.0}
    el = {"L": (0.0, -0.06), "R": (0.0, 0.06)}  # (x, z)
    wr = {"L": 0.0, "R": 0.0}
    fing = [0.0] * 4
    bt = [1.4, 4.1]
    if clip == "Wave":
        raise_w = sm(t / 0.7) * (1 - sm((t - 3.0) / 0.8))
        osc = sm((t - 0.6) / 0.3) * (1 - sm((t - 2.8) / 0.3))
        ph = 2 * math.pi * 1.7 * (t - 0.6)
        sh["R"] = 0.12 + raise_w * (1.30 - 0.12) + osc * 0.04 * math.sin(ph)
        shx["R"] = -0.30 * raise_w
        el["R"] = (0.0, 0.06 + raise_w * 1.15)
        wr["R"] = osc * 0.46 * math.sin(ph)
        fing = [osc * 0.20 * math.sin(ph + i * 0.7) for i in range(4)]
        head_r["z"] += -0.09 * raise_w; head_r["x"] += 0.04 * raise_w * math.sin(2 * math.pi * 1.7 * t)
        body_r["y"] = -0.07 * raise_w
        bt = [1.0, 2.6]
    if clip == "Think":  # loops: hand rests under the chin, head tilts and looks up, slow sway
        k = 1.0
        sway = math.sin(2 * math.pi * t / 3.0)
        sh["R"] = -0.05 + 0.02 * sway
        shx["R"] = -1.05 - 0.04 * sway
        el["R"] = (-1.75, -0.35)
        wr["R"] = 0.10 * sway
        head_r = dict(x=-0.10 + 0.02 * sway, y=-0.10, z=0.16 + 0.03 * sway)
        body_r["z"] = 0.02 * sway
        bt = [0.9, 2.4]
    if clip == "Hop":  # one happy bounce: squash, jump, land, settle (~1 s)
        air = math.sin(math.pi * min(max((t - 0.18) / 0.42, 0), 1))
        sq = math.exp(-((t - 0.12) / 0.06) ** 2) * 0.10 + math.exp(-((t - 0.66) / 0.06) ** 2) * 0.08
        body_y = 0.135 + 0.075 * air - 0.03 * sq
        body_s = 1 - sq
        up = air
        sh["L"], sh["R"] = -0.12 - 0.85 * up, 0.12 + 0.85 * up
        el["L"], el["R"] = (0.0, -0.06 - 0.5 * up), (0.0, 0.06 + 0.5 * up)
        head_r = dict(x=-0.08 * air + 0.06 * sq * 10 * 0.1, y=0.0, z=0.06 * math.sin(2 * math.pi * t))
        bt = []
    if clip == "Blink":
        bt = [0.3]
    P["Body"] = dict(t=[0, body_y, 0], r=qe(**body_r), s=[1 + 0.5 * (1 - body_s), body_s, 1 + 0.5 * (1 - body_s)])
    P["Head"] = dict(r=qe(**head_r))
    for side in "LR":
        P[f"Shoulder{side}"] = dict(r=qe(x=shx[side], z=sh[side]))
        P[f"Elbow{side}"] = dict(r=qe(x=el[side][0], z=el[side][1]))
        P[f"Wrist{side}"] = dict(r=qe(z=wr[side]))
    for i in range(4):
        P[f"FingerR{i}"] = dict(r=qe(z=fing[i]))
        P[f"FingerL{i}"] = dict(r=qe())
    b = blink(t, bt)
    for e in ("EyeL", "EyeR"):
        P[e] = dict(s=[1, 1 - 0.94 * b, 1])
    return P


CLIPS = {"Idle": 6.0, "Wave": 3.8, "Blink": 0.6, "Think": 3.0, "Hop": 1.0}


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
