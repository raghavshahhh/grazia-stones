import json, numpy as np, cv2, os
D = os.environ.get('D', 'segdump')  # adb pull /sdcard/Android/data/com.graziastones.grazia_stones/files/segdump

def load(fid):
    j = json.load(open(f'{D}/{fid}.json'))
    w, h, yr, uvr, uvp = j['w'], j['h'], j['yRow'], j['uvRow'], j['uvPix']
    y = np.frombuffer(open(f'{D}/{fid}.y','rb').read(), np.uint8)
    u = np.frombuffer(open(f'{D}/{fid}.u','rb').read(), np.uint8)
    v = np.frombuffer(open(f'{D}/{fid}.v','rb').read(), np.uint8)
    Y = np.zeros((h, w), np.uint8)
    for r in range(h): Y[r] = y[r*yr:r*yr+w]
    U = np.full((h//2, w//2), 128, np.uint8); V = U.copy()
    for r in range(h//2):
        row_u = u[r*uvr: r*uvr + (w//2-1)*uvp + 1]; row_v = v[r*uvr: r*uvr + (w//2-1)*uvp + 1]
        U[r, :len(row_u[::uvp])] = row_u[::uvp]; V[r, :len(row_v[::uvp])] = row_v[::uvp]
    U = cv2.resize(U, (w, h), interpolation=cv2.INTER_LINEAR).astype(np.float32) - 128
    V = cv2.resize(V, (w, h), interpolation=cv2.INTER_LINEAR).astype(np.float32) - 128
    Yf = Y.astype(np.float32)
    rgb = np.stack([Yf + 1.402*V, Yf - 0.344136*U - 0.714136*V, Yf + 1.772*U], -1).clip(0,255).astype(np.uint8)
    # view-normalized corners -> image px: (0,0),(1,0),(0,1),(1,1)
    c = np.array(j['viewCornersToImage'], np.float32).reshape(4,2)
    return rgb, c, j

def to_view(img, c, vw, vh):
    """Warp image into view orientation (portrait) of size vw x vh."""
    src = np.float32([c[0], c[1], c[2]])          # view (0,0),(1,0),(0,1)
    dst = np.float32([[0,0],[vw,0],[0,vh]])
    M = cv2.getAffineTransform(src, dst)
    return cv2.warpAffine(img, M, (vw, vh), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)
