# 🍱 Calorie Estimator

A computer vision system that estimates the **calorie content of Indonesian food** from a single photo. The app combines **YOLOv8 instance segmentation**, **MiDaS monocular depth estimation**, and a **Random Forest** regression model to predict food weight and calories — all accessible from a native **iOS app**.

---

## 🛠️ Tech Stack

**iOS Client**

![Swift](https://img.shields.io/badge/Swift-F05138?style=for-the-badge&logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-0066CC?style=for-the-badge&logo=swift&logoColor=white)
![Xcode](https://img.shields.io/badge/Xcode-147EFB?style=for-the-badge&logo=xcode&logoColor=white)

**Backend**

![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)
![FastAPI](https://img.shields.io/badge/FastAPI-009688?style=for-the-badge&logo=fastapi&logoColor=white)
![Uvicorn](https://img.shields.io/badge/Uvicorn-4B0082?style=for-the-badge&logo=gunicorn&logoColor=white)

**Computer Vision & ML**

![YOLOv8](https://img.shields.io/badge/YOLOv8-00FFFF?style=for-the-badge&logo=yolo&logoColor=black)
![OpenCV](https://img.shields.io/badge/OpenCV-5C3EE8?style=for-the-badge&logo=opencv&logoColor=white)
![scikit-learn](https://img.shields.io/badge/scikit--learn-F7931E?style=for-the-badge&logo=scikit-learn&logoColor=white)

**Deep Learning**

![PyTorch](https://img.shields.io/badge/PyTorch-EE4C2C?style=for-the-badge&logo=pytorch&logoColor=white)
![NumPy](https://img.shields.io/badge/NumPy-013243?style=for-the-badge&logo=numpy&logoColor=white)
![Jupyter](https://img.shields.io/badge/Jupyter-F37626?style=for-the-badge&logo=jupyter&logoColor=white)

---

## 📸 Demo

| Photo Input | Detection & Overlay |
|:-----------:|:-------------------:|
| ![Demo food photo](demo%20images/f159930360.png) | Detection bounding boxes + calorie labels rendered directly on image |

---

## 🧠 How It Works

```
User Photo (iOS)
      │
      ▼
FastAPI Backend
      │
      ├── YOLOv8m-seg  ──► Instance segmentation (food class + mask + bbox)
      │
      ├── MiDaS         ──► Monocular depth estimation per food region
      │
      └── Random Forest ──► Predicts food weight (g) from area + depth features
                                │
                                ▼
                     Calories = weight × kcal/gram
                                │
                                ▼
                     JSON Response → iOS Overlay UI
```

---

## 🗂️ Project Structure

```
CalorieEstimator/
├── backend-fastapi/           # Python backend
│   ├── app/
│   │   ├── main.py            # FastAPI app & /calorie_estimation endpoint
│   │   ├── lookup_table.py    # Calorie-per-gram reference table
│   │   ├── ml_models/
│   │   │   ├── yolov8_model.py       # YOLOv8 segmentation inference
│   │   │   ├── midas_model.py        # MiDaS depth estimation
│   │   │   ├── random_forest.py      # Weight prediction
│   │   │   ├── yolov8m-seg.pt        # Trained YOLOv8 model
│   │   │   └── rf_model_v2.pkl       # Trained Random Forest model
│   │   └── utils/
│   ├── midas_model.pth        # MiDaS pretrained weights
│   └── requirements.txt
│
├── ios-app/                   # Swift / SwiftUI iOS client
│   └── CalorieEstimator/
│       ├── Config.swift               # ⚙️ Backend URL config (edit this)
│       ├── ContentView.swift          # Main UI + API call logic
│       ├── DetectionOverlay.swift     # Draws bounding boxes + calorie labels
│       ├── CameraViewController.swift # Live camera capture
│       ├── ImagePicker.swift          # Photo library picker
│       ├── ScanningLoadingView.swift  # Scanning animation overlay
│       └── DetectionData.swift        # JSON response model
│
├── ml-training/
│   └── Estimasi_Kalori.ipynb  # Model training notebook (YOLOv8 + RF)
│
└── demo images/               # Sample input images
```

---

## 🍛 Supported Food Classes

| ID | Label | kcal/gram |
|----|-------|-----------|
| 0 | Nasi Putih | 1.80 |
| 1 | Dada Ayam Fillet | 1.90 |
| 2 | Indomie Goreng | 2.75 |
| 3 | Sambel Goreng Kentang | 1.02 |
| 4 | Tumis Kangkung | 0.98 |
| 5 | Tumis Tempe | 1.95 |

---

## ⚙️ Backend Setup

### Prerequisites
- Python 3.10+
- CUDA-capable GPU (recommended for inference speed)

### Install dependencies

```bash
cd backend-fastapi
pip install -r requirements.txt
```

### Run the server

```bash
cd backend-fastapi
uvicorn app.main:app --host 0.0.0.0 --port 9000 --reload
```

> For remote access from iOS, expose the server using [ngrok](https://ngrok.com/):
> ```bash
> ngrok http 9000
> ```
> Then paste the generated HTTPS URL into `ContentView.swift`.

### API Endpoint

```
POST /calorie_estimation
Content-Type: multipart/form-data

Body: file=<image.jpg>
```

**Response:**
```json
{
  "detections": [
    {
      "class_id": 0,
      "class_label": "nasi_putih",
      "bounding_box": { "x_center": 320, "y_center": 240, "width": 180, "height": 160 },
      "area": 22450,
      "depth_mean": 0.63,
      "depth_median": 0.61,
      "weight": 185.4,
      "calories": 333.7,
      "mask_base64": "<base64_string>"
    }
  ]
}
```

---

## 📱 iOS App Setup

1. Open `ios-app/CalorieEstimator.xcodeproj` in **Xcode 15+**
2. Open **`Config.swift`** and set your backend URL:
   ```swift
   enum Config {
       static let baseURL = "https://your-ngrok-url.ngrok-free.app"
   }
   ```
   > This is the **only file** you need to edit when the server URL changes.
3. Run on a **physical iPhone** (camera + network required)

---

## 🤖 ML Pipeline

### 1. YOLOv8 Instance Segmentation
- Model: `yolov8m-seg.pt` (fine-tuned on custom Indonesian food dataset)
- Input: 640×640 image
- Output: class ID, bounding box, segmentation mask, confidence score

### 2. MiDaS Depth Estimation
- Model: `midas_model.pth`
- Estimates relative depth for each food region using the segmentation mask
- Outputs `depth_mean` and `depth_median` per detected object

### 3. Random Forest Weight Prediction
- Model: `rf_model_v2.pkl`
- Features: `area`, `width`, `height`, `depth_mean`, `depth_median`, `class_id`
- Predicts estimated food weight in grams

### 4. Calorie Calculation
```
calories = predicted_weight (g) × kcal_per_gram[food_label]
```

---

## 📦 Key Dependencies

| Package | Purpose |
|---------|---------|
| `fastapi` | REST API framework |
| `ultralytics` | YOLOv8 inference |
| `timm` / `torch` | MiDaS depth model |
| `scikit-learn` | Random Forest model |
| `opencv-python` | Image processing |
| `uvicorn` | ASGI server |

---

## 📓 Training

The training notebook is in `ml-training/Estimasi_Kalori.ipynb`. It covers:
- Dataset preparation and annotation
- YOLOv8 fine-tuning
- Feature engineering from depth + segmentation data
- Random Forest training and evaluation

---

## 📄 Author

M. Shiddiq Mukhlas
LinkedIn: https://www.linkedin.com/in/shiddiqmukhlas/
