"""Export EfficientViT-Seg B1 (ADE20K) to ONNX. Usage: python export.py CODE_DIR CKPT OUT W H"""
import sys, types
code, ckpt, out, w, h = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4]), int(sys.argv[5])
sys.path.insert(0, code)
# The Triton RMSNorm kernel module (GPU only) is imported but unused by this model; stub just that module.
stub = types.ModuleType("efficientvit.models.nn.triton_rms_norm")
stub.TritonRMSNorm2dFunc = None
sys.modules["efficientvit.models.nn.triton_rms_norm"] = stub
import torch
from efficientvit.models.efficientvit.seg import efficientvit_seg_b1
model = efficientvit_seg_b1("ade20k")
sd = torch.load(ckpt, map_location="cpu", weights_only=True)
sd = sd.get("state_dict", sd)
print(model.load_state_dict(sd, strict=True))
model.eval()
x = torch.randn(1, 3, h, w)
with torch.no_grad():
    print("out", model(x).shape)
torch.onnx.export(model, x, out, input_names=["image"], output_names=["logits"], opset_version=17, dynamo=False)
print("saved", out)
