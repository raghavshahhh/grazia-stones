import numpy as np, cv2, onnxruntime as ort
from load import *
sess = ort.InferenceSession('../../android/app/src/main/assets/models/wall_seg_160x352.onnx', providers=['CPUExecutionProvider'])
MEAN = np.array([0.485,0.456,0.406],np.float32); STD = np.array([0.229,0.224,0.225],np.float32)
def run(view_rgb, iw=160, ih=352, s=sess):
    x = cv2.resize(view_rgb, (iw, ih), interpolation=cv2.INTER_AREA).astype(np.float32)/255.
    x = ((x-MEAN)/STD).transpose(2,0,1)[None]
    logits = s.run(None, {'image': x})[0][0]   # C,h,w
    e = np.exp(logits - logits.max(0, keepdims=True)); p = e / e.sum(0, keepdims=True)
    return p  # 150 x h x w
def overlay(view, mask, color=(0,255,0)):
    m = cv2.resize(mask.astype(np.float32), (view.shape[1], view.shape[0]), interpolation=cv2.INTER_LINEAR)
    out = view.astype(np.float32).copy(); col = np.array(color, np.float32)
    out = out*(1-0.55*m[...,None]) + col*0.55*m[...,None]
    return out.clip(0,255).astype(np.uint8)
