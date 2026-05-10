import os
import numpy as np
from ultralytics import YOLO
import cv2
import torch
import base64

# Path ke model
model_path = os.path.join(os.path.dirname(__file__), 'yolov8m-seg.pt')
if not os.path.exists(model_path):
    raise FileNotFoundError(f"Model tidak ditemukan di path: {model_path}")

model = YOLO(model_path)

def yolov8_detect(image_path):
    # Load gambar asli
    img = cv2.imread(image_path)
    img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    original_height, original_width = img.shape[:2]

    # Resize ke 640x640 tanpa padding karena sudah square
    resized_img = cv2.resize(img, (640, 640), interpolation=cv2.INTER_LINEAR)

    # Simpan sementara untuk inferensi
    resized_path = "temp/resized_image.jpg"
    cv2.imwrite(resized_path, cv2.cvtColor(resized_img, cv2.COLOR_RGB2BGR))

    # YOLOv8 inference
    results = model(resized_path, conf=0.5)[0]

    detections = []
    for i, (mask, box, cls) in enumerate(zip(results.masks.data, results.boxes.xywh, results.boxes.cls)):
        try:
            # Konversi mask ke numpy
            mask_np = mask.cpu().numpy().astype(np.uint8) if isinstance(mask, torch.Tensor) else mask.astype(np.uint8)

            # Hitung luas area mask
            area = int(np.sum(mask_np > 0))

            # Ambil bounding box
            bbox = box.cpu().numpy()
            x_center, y_center, width, height = map(float, bbox)
            class_id = int(cls.cpu().item())

            # Kompres mask ke PNG (0/1 jadi 0/255 biar kelihatan di gambar)
            _, mask_png = cv2.imencode(".png", mask_np * 255)

            # Encode ke base64
            mask_base64 = base64.b64encode(mask_png).decode("utf-8")

            detections.append({
                "class_id": class_id,
                "bounding_box": {
                    "x_center": x_center,
                    "y_center": y_center,
                    "width": width,
                    "height": height
                },
                "area": area,
                "mask_base64": mask_base64 
            })

        except Exception as e:
            print(f"Error processing detection {i}: {e}")
            continue

    # Logging
    print(f"\n[YOLO DETEKSI]")
    print(f"Jumlah objek terdeteksi: {len(detections)}")
    for idx, d in enumerate(detections):
        bb = d['bounding_box']
        print(f"Objek {idx+1}: Class={d['class_id']}, Area={d['area']}, Box={bb}")

    return {
        "detections": detections,
        "original_size": {
            "width": original_width,
            "height": original_height
        }
    }
