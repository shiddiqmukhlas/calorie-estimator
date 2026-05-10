from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
from app.ml_models.yolov8_model import yolov8_detect
from app.ml_models.midas_model import midas_depth  # Impor fungsi midas_depth
from app.ml_models.random_forest import predict_calories
import os
import numpy as np
import base64
import cv2
import time
import logging

logging.basicConfig(level=logging.INFO)

app = FastAPI()


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Sebaiknya spesifikkan domain untuk keamanan, seperti ["http://192.168.1.100"]
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mapping class_id ke nama makanan
id_to_label = {
    0: "nasi_putih",
    1: "dada_ayam_fillet",
    2: "indomie_goreng",
    3: "sambel_goreng_kentang",
    4: "tumis_kangkung",
    5: "tumis_tempe"
    # tambahkan class lainnya sesuai label YOLO kamu
}

# Kalori per gram dari masing-masing makanan
kalori_per_gram = {
    "nasi_putih": 1.8,
    "dada_ayam_fillet": 1.9,
    "indomie_goreng": 2.75,
    "sambel_goreng_kentang": 1.02,
    "tumis_kangkung": 0.98,
    "tumis_tempe": 1.95,
    "unknown": 1.0  # default jika label tidak ditemukan
}

# Endpoint untuk estimasi kalori
@app.post("/calorie_estimation")
async def calorie_estimation(file: UploadFile = File(...)):  # Sesuaikan nama parameter menjadi "file"
    temp_dir = "temp"
    if not os.path.exists(temp_dir):
        os.makedirs(temp_dir)
    print("Received image for detection and depth estimation")
    
    # Simpan gambar sementara
    start_read = time.time()
    file_path = f"{temp_dir}/{file.filename}"
    contents = await file.read()
    with open(file_path, "wb") as buffer:
        buffer.write(contents)
    end_read = time.time()
    logging.info(f"Time to read and save uploaded file: {end_read - start_read:.3f} seconds")

    try:
        # Jalankan YOLOv8 untuk deteksi
        start_yolo = time.time()
        detection_result = yolov8_detect(file_path)
        end_yolo = time.time()
        logging.info(f"YOLOv8 detection completed in {end_yolo - start_yolo:.3f} seconds")

        # Proses depth untuk setiap deteksi
        start_depth = time.time()
        depth_results = []
        features = []  # Untuk menyimpan fitur yang diperlukan untuk prediksi kalori
        for detection in detection_result.get("detections", []):  # Pastikan "detections" ada
            class_id = detection.get("class_id")
            detection["class_label"] = id_to_label.get(class_id, "unknown")

            mask_base64 = detection.get("mask_base64")
            width = detection.get("bounding_box", {}).get("width", 0)
            height = detection.get("bounding_box", {}).get("height", 0)
            area = detection.get("area", 0)

            # Jika mask tersedia, lakukan depth estimation
            if mask_base64:
                # Decode base64 jadi bytes
                mask_bytes = base64.b64decode(mask_base64)
                # Baca sebagai gambar grayscale
                mask_np = cv2.imdecode(np.frombuffer(mask_bytes, np.uint8), cv2.IMREAD_GRAYSCALE)
                # Pastikan mask biner (0 atau 1)
                mask_np = (mask_np > 127).astype(np.uint8)
                depth_result = midas_depth(file_path, mask_np)
                print(f"Objek class {class_id} — depth_mean: {depth_result['depth_mean']:.2f}, depth_median: {depth_result['depth_median']:.2f}")
                depth_results.append({
                    "class_id": class_id,
                    "depth_mean": depth_result["depth_mean"],
                    "depth_median": depth_result["depth_median"]
                })


                # Ambil fitur yang diperlukan untuk prediksi kalori
                depth_mean = depth_result["depth_mean"]
                depth_median = depth_result["depth_median"]
                
                features.append({
                    "area": area,
                    "width": width,
                    "height": height,
                    "depth_mean": depth_mean,
                    "depth_median": depth_median,
                    "class_id": class_id
                })
            else:
                depth_results.append({
                    "class_id": class_id,
                    "depth_mean": 0.0,
                    "depth_median": 0.0
                })

        end_depth = time.time()
        logging.info(f"Depth estimation completed in {end_depth - start_depth:.3f} seconds")

        # Prediksi kalori untuk setiap deteksi
        estimated_weights = []
        for feature in features:
            predicted_weight = predict_calories(feature)
            estimated_weights.append(predicted_weight)

        # Masukkan nilai kalori ke masing-masing deteksi
        for i, detection in enumerate(detection_result["detections"]):
            if i < len(estimated_weights):
                label = detection.get("class_label", "unknown")
                per_gram = kalori_per_gram.get(label, 1.0)
                weight = estimated_weights[i]
                calories = weight * per_gram

                detection["weight"] = round(weight, 2)
                detection["calories"] = round(calories, 2)


        # Kembalikan hasil
        final_result = {
            "detections": detection_result["detections"]
        }

        # **Tidak menghapus `mask_base64`** untuk memastikan data mask tetap ada
        print("Depth estimation and calorie prediction completed successfully")
        return JSONResponse(content=final_result)

    except Exception as e:
        print(f"Error during detection, depth estimation, and calorie prediction: {e}")
        return JSONResponse(status_code=500, content={"message": f"Error: {str(e)}"})


if __name__ == "__main__":
    uvicorn.run(app, host="192.168.1.4", port=9000)
