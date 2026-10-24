import numpy as np, cv2
def seam_h(t, B):
    """Make t seamless horizontally: overlap the right band onto the left band and cut along the min-error path."""
    h, w = t.shape[:2]; tf = t.astype(np.float32)
    err = ((tf[:, :B] - tf[:, w-B:])**2).sum(-1)          # h x B
    cum = err.copy(); back = np.zeros((h, B), np.int32)
    for y in range(1, h):
        for c in range(B):
            lo, hi = max(0, c-1), min(B, c+2)
            k = lo + int(np.argmin(cum[y-1, lo:hi])); cum[y, c] += cum[y-1, k]; back[y, c] = k
    cut = np.zeros(h, np.int32); cut[-1] = int(np.argmin(cum[-1]))
    for y in range(h-1, 0, -1): cut[y-1] = back[y, cut[y]]
    out = t[:, :w-B].copy()
    for y in range(h):
        c = cut[y]; out[y, :c] = t[y, w-B:w-B+c]
    return out
def seamless(t, frac=0.12):
    h, w = t.shape[:2]
    t = seam_h(t, max(4, int(w*frac)))
    t = seam_h(t.transpose(1,0,2), max(4, int(h*frac))).transpose(1,0,2)
    return np.ascontiguousarray(t)
