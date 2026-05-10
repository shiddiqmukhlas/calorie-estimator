# Definisikan class ID untuk setiap objek
CLASS_ID_NASI_PUTIH = 0
CLASS_ID_TELUR_CEPLOK = 1
CLASS_ID_TEMPE = 2

def lookup_calories(class_id, per_gram=False):
    calorie_table = {
        CLASS_ID_NASI_PUTIH: {"calories_per_gram": 1.3},  # Nasi
        CLASS_ID_TELUR_CEPLOK: {"calories_total": 250},   # Telur
        CLASS_ID_TEMPE: {"calories_total": 180}          # Tempe
    }
    if per_gram:
        return calorie_table.get(class_id, {}).get("calories_per_gram", 0)
    return calorie_table.get(class_id, {}).get("calories_total", 0)
