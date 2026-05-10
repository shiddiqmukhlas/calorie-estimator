import joblib
import os
import pandas as pd

# Path model
model_path = os.path.join(os.path.dirname(__file__), 'rf_model_v2.pkl')

# Pastikan model tersedia
if not os.path.exists(model_path):
    raise FileNotFoundError(f"Model tidak ditemukan di path: {model_path}")

# Load model
model = joblib.load(model_path)

def predict_calories(features):
    area = features.get('area')
    width = features.get('width')
    height = features.get('height')
    depth_mean = features.get('depth_mean')
    depth_median = features.get('depth_median')
    class_id = features.get('class_id')

    if None in [area, width, height, depth_mean, depth_median, class_id]:
        raise ValueError("Semua fitur (area, width, height, depth_mean, depth_median, class_id) harus disediakan.")

    area_times_depth = area * depth_mean
    area_div_depth_median = area / depth_median if depth_median != 0 else 0

    sample_dict = {
        'area': area,
        'width': width,
        'height': height,
        'depth_mean': depth_mean,
        'depth_median': depth_median,
        'area * depth_mean': area_times_depth,
        'area / depth_median': area_div_depth_median,
        'class_id': class_id
    }
    sample_df = pd.DataFrame([sample_dict])

    predicted_weight = model.predict(sample_df)[0]
    print("Estimated Weight:", predicted_weight)
    return predicted_weight

