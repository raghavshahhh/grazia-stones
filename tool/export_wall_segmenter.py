"""Export EfficientViT-Seg B1 (ADE20K) to ONNX for the Live AR wall segmenter.

Usage:
    python tool/export_wall_segmenter.py CODE_DIR CKPT OUT W H
    e.g. python tool/export_wall_segmenter.py ../efficientvit efficientvit_seg_b1_ade20k.pt \
             android/app/src/main/assets/models/wall_seg_160x352.onnx 160 352

CODE_DIR: a checkout of https://github.com/mit-han-lab/efficientvit
CKPT:     efficientvit_seg_b1_ade20k.pt (Hugging Face: han-cai/efficientvit-seg)
W x H:    portrait input size, multiples of 32. WallSegmenter.kt must use the same IN_W / IN_H.
          160x352 is what ships: ~3x faster on a phone CPU than the first 288x640 export.

Needs: torch, onnx, timm, omegaconf, einops (pip). The repo's __init__ also imports SAM / DC-AE / training
code that the segmentation model never uses; those imports are stubbed below instead of installed.

After export, the two cubic `Resize` ops in the head are rewritten to `linear`: ONNX Runtime's XNNPACK
provider rejects cubic resize on 4-D NHWC input, which silently dropped the session to the slow default CPU
path on Android (argmax agreement after the change: ~99%).
"""
import importlib.abc
import importlib.machinery
import sys
import types

code, ckpt, out, w, h = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4]), int(sys.argv[5])
sys.path.insert(0, code)

STUB_ROOTS = (
    "segment_anything", "onnxsim", "wandb", "torchpack", "matplotlib",
    "efficientvit.models.nn.triton_rms_norm", "diffusers", "transformers",
)


class _Dummy:
    def __init__(self, *a, **k):
        pass

    def __getattr__(self, n):
        return _Dummy

    def __call__(self, *a, **k):
        return _Dummy()


class _StubLoader(importlib.abc.Loader):
    def create_module(self, spec):
        m = types.ModuleType(spec.name)
        m.__path__ = []
        m.__all__ = []
        m.__getattr__ = lambda n: _Dummy
        return m

    def exec_module(self, m):
        pass


class _StubFinder(importlib.abc.MetaPathFinder):
    def find_spec(self, name, path=None, target=None):
        if any(name == r or name.startswith(r + ".") for r in STUB_ROOTS):
            return importlib.machinery.ModuleSpec(name, _StubLoader(), is_package=True)


sys.meta_path.insert(0, _StubFinder())

import onnx  # noqa: E402
import torch  # noqa: E402
from efficientvit.models.efficientvit.seg import efficientvit_seg_b1  # noqa: E402

model = efficientvit_seg_b1("ade20k")
sd = torch.load(ckpt, map_location="cpu", weights_only=True)
sd = sd.get("state_dict", sd)
print(model.load_state_dict(sd, strict=True))
model.eval()
x = torch.randn(1, 3, h, w)
with torch.no_grad():
    print("out", model(x).shape)  # (1, 150, H/8, W/8)
torch.onnx.export(model, x, out, input_names=["image"], output_names=["logits"], opset_version=17, dynamo=False)

m = onnx.load(out)
patched = 0
for node in m.graph.node:
    if node.op_type != "Resize":
        continue
    for a in node.attribute:
        if a.name == "mode" and a.s == b"cubic":
            a.s = b"linear"
            patched += 1
    keep = [a for a in node.attribute if a.name != "cubic_coeff_a"]
    del node.attribute[:]
    node.attribute.extend(keep)
onnx.checker.check_model(m)
onnx.save(m, out)
print(f"saved {out} ({patched} cubic Resize ops rewritten to linear)")
