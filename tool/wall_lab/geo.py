import numpy as np, cv2, heapq
def lab_image(view_rgb):
    sm = cv2.bilateralFilter(view_rgb, 7, 25, 5)
    return cv2.cvtColor(sm, cv2.COLOR_RGB2LAB).astype(np.float32) * np.array([100/255., 1, 1], np.float32)
def edge_cost(lab):
    # colour gradient magnitude (Delta-E per pixel), from Sobel on each Lab channel
    g = np.zeros(lab.shape[:2], np.float32)
    for k in range(3):
        gx = cv2.Sobel(lab[...,k], cv2.CV_32F, 1, 0, ksize=3); gy = cv2.Sobel(lab[...,k], cv2.CV_32F, 0, 1, ksize=3)
        g += gx*gx + gy*gy
    return np.sqrt(g) / 8.0
def geodesic(cost, seeds, eps=0.15):
    """Dijkstra: distance = sum over the path of (eps + cost^2) -> strong edges dominate, flat shading is cheap."""
    h, w = cost.shape; step = eps + cost**2
    d = np.full(h*w, np.inf, np.float32); pq = []
    for (y, x) in seeds: d[y*w+x] = 0; heapq.heappush(pq, (0.0, y*w+x))
    sf = step.ravel()
    while pq:
        dk, k = heapq.heappop(pq)
        if dk > d[k]: continue
        y, x = divmod(k, w)
        for ny, nx in ((y-1,x),(y+1,x),(y,x-1),(y,x+1)):
            if 0 <= ny < h and 0 <= nx < w:
                n = ny*w+nx; nd = dk + 0.5*(sf[k]+sf[n])
                if nd < d[n]: d[n] = nd; heapq.heappush(pq, (nd, n))
    return d.reshape(h, w)

def geodesic_multi(step, fg, bg):
    """Two-label geodesic Voronoi: returns (dFG, dBG) with per-pixel step costs (already >=0)."""
    def run(seeds):
        h, w = step.shape; d = np.full(h*w, np.inf, np.float32); pq=[]; sf = step.ravel()
        for k in seeds: d[k] = 0; pq.append((0.0, int(k)))
        heapq.heapify(pq)
        while pq:
            dk, k = heapq.heappop(pq)
            if dk > d[k]: continue
            y, x = divmod(k, w)
            for n in ((k-w) if y>0 else -1, (k+w) if y<h-1 else -1, (k-1) if x>0 else -1, (k+1) if x<w-1 else -1):
                if n < 0: continue
                nd = dk + 0.5*(sf[k]+sf[n])
                if nd < d[n]: d[n] = nd; heapq.heappush(pq, (nd, n))
        return d.reshape(h, w)
    return run(fg), run(bg)

def wall_cost(lab, cost, sy, sx, floor_k=1.0, lam=0.08, tolC=6.0, mu=0.02, tolL=22.0, eps=0.002):
    patch = lab[sy-20:sy+20, sx-20:sx+20].reshape(-1,3)
    ref = np.median(patch, 0)
    floor = np.percentile(cost[sy-25:sy+25, sx-25:sx+25], 95) * floor_k
    dC = np.sqrt((lab[...,1]-ref[1])**2 + (lab[...,2]-ref[2])**2)
    dL = np.abs(lab[...,0]-ref[0])
    step = eps + np.maximum(cost-floor,0)**2 + lam*np.maximum(dC-tolC,0)**2 + mu*np.maximum(dL-tolL,0)**2
    return step.astype(np.float32), ref

def segment_wall(v, p_model, sy, sx, tolLrel=9.0, mu=0.05, dil=3, T=3.0, med=31, B=2):
    H, W = v.shape[:2]
    lab = lab_image(v); cost = cv2.dilate(edge_cost(lab), np.ones((dil,dil),np.uint8))
    fg = [ (sy+dy)*W + sx+dx for dy in range(-6,7,3) for dx in range(-6,7,3)]
    top = p_model.argmax(0); conf = p_model.max(0)
    nw = cv2.erode(cv2.resize(((top!=0)&(top!=1)&(conf>0.5)).astype(np.uint8),(W,H),interpolation=cv2.INTER_NEAREST), np.ones((9,9),np.uint8))
    bg = np.flatnonzero(nw)
    # pass 1: edges + chroma only
    step1, ref = wall_cost(lab, cost, sy, sx, mu=0.0)
    dF, dB = geodesic_multi(step1, fg, bg)
    m1 = (dF < T) & (dF < dB)
    # illumination field of THE wall: median of L over pass-1 wall pixels (outside filled with wall median)
    L = lab[...,0]; fill = np.where(m1, L, np.median(L[m1]))
    small = cv2.resize(np.clip(fill*2.55,0,255).astype(np.uint8), (W//4, H//4), interpolation=cv2.INTER_AREA)
    illum = cv2.resize(cv2.medianBlur(small, med), (W, H), interpolation=cv2.INTER_LINEAR).astype(np.float32)/2.55
    dLrel = np.abs(L - illum)
    step2 = step1 + mu*np.maximum(dLrel - tolLrel, 0)**2
    # No travelling along the screen edge: objects cut by the border (a board, a door) were entered from there.
    step2[:B, :] = step2[-B:, :] = 1e3; step2[:, :B] = step2[:, -B:] = 1e3
    dF, dB = geodesic_multi(step2, fg, bg)
    m = ((dF < T) & (dF < dB))
    m[:B, :] = m[B:B+1, :]; m[-B:, :] = m[-B-1:-B, :]; m[:, :B] = m[:, B:B+1]; m[:, -B:] = m[:, -B-1:-B]
    return m, illum

def geodesic_raster(step, seeds, iters=3):
    """GeoS-style raster scans (4-neighbour). Same metric as Dijkstra above, O(N) per sweep."""
    h, w = step.shape; d = np.full((h, w), np.inf, np.float32); s = step
    for k in seeds: d.flat[k] = 0
    for _ in range(iters):
        for y in range(h):                       # forward
            row = d[y]
            if y > 0: np.minimum(row, d[y-1] + 0.5*(s[y]+s[y-1]), out=row)
            for x in range(1, w):
                c = row[x-1] + 0.5*(s[y,x]+s[y,x-1])
                if c < row[x]: row[x] = c
        for y in range(h-1, -1, -1):             # backward
            row = d[y]
            if y < h-1: np.minimum(row, d[y+1] + 0.5*(s[y]+s[y+1]), out=row)
            for x in range(w-2, -1, -1):
                c = row[x+1] + 0.5*(s[y,x]+s[y,x+1])
                if c < row[x]: row[x] = c
    return d
