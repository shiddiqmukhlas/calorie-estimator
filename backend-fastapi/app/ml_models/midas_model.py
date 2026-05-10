import torch
import os
import numpy as np
from PIL import Image
import cv2

# Memuat MiDaS model
MODEL_PATH = "midas_model.pth"
if not os.path.exists(MODEL_PATH):
    print("Downloading MiDaS model...")
    midas = torch.hub.load("intel-isl/MiDaS", "DPT_Hybrid")
    torch.save(midas.state_dict(), MODEL_PATH)  # Simpan model secara lokal
else:
    print("Loading MiDaS model from local storage...")
    midas = torch.hub.load("intel-isl/MiDaS", "DPT_Hybrid")
    midas.load_state_dict(torch.load(MODEL_PATH))

# Transformasi model MiDaS
midas_transforms = torch.hub.load("intel-isl/MiDaS", "transforms").dpt_transform
device = "cuda" if torch.cuda.is_available() else "cpu"
midas.to(device).eval()

def midas_depth(image_path, mask_np):

    # Buka gambar dan konversi ke RGB
    image = Image.open(image_path).convert("RGB")
    
    # Konversi gambar ke format NumPy dan kemudian ke tensor
    image_np = np.array(image)
    input_batch = midas_transforms(image_np).to(device)
    
    with torch.no_grad():
        prediction = midas(input_batch)
    
    # Resize depth map ke dimensi asli gambar
    depth_map = prediction.squeeze().cpu().numpy()
    depth_map_resized = cv2.resize(depth_map, (mask_np.shape[1], mask_np.shape[0]))

    # Crop depth map menggunakan mask
    masked_depth = depth_map_resized * (mask_np > 0)  # Hanya bagian di dalam mask
    depth_values = masked_depth[masked_depth > 0]  # Ambil hanya nilai non-zero

    # Hitung mean dan median dari nilai kedalaman yang dipilih
    if len(depth_values) > 0:  # Pastikan ada nilai valid
        depth_mean = round(float(np.mean(depth_values)), 2)  # Konversi ke float Python
        depth_median = round(float(np.median(depth_values)), 2)  # Konversi ke float Python
    else:
        depth_mean = 0.0
        depth_median = 0.0


    # Kembalikan hasil sebagai JSON-friendly format
    return {
        "depth_map": depth_map_resized.tolist(),  # Convert numpy array ke list untuk JSON
        "depth_mean": float(depth_mean),
        "depth_median": float(depth_median)
    }


