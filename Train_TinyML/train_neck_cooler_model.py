import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import MinMaxScaler
from sklearn.metrics import mean_absolute_error
from sklearn.linear_model import LinearRegression
from sklearn.tree import DecisionTreeRegressor
import joblib
from micromlgen import port
import warnings

warnings.filterwarnings("ignore")

# ====================
# 1. GENERATE REALISTIC TRAINING DATA
# ====================
def generate_training_data(n_samples=2000):
    np.random.seed(42)

    temp = np.clip(np.random.normal(28, 5, n_samples), 20, 40)
    humidity = np.clip(np.random.normal(50, 15, n_samples), 30, 80)

    hr_base = np.random.normal(70, 10, n_samples)
    heart_rate = np.clip(
        hr_base
        + (temp - 28) * 1.5
        + (humidity - 50) * 0.3
        + np.random.normal(0, 3, n_samples),
        60,
        120,
    )

    spo2 = np.clip(
        np.random.normal(98, 1, n_samples)
        - (temp - 28) * 0.1
        - (heart_rate - 70) * 0.02
        + np.random.normal(0, 0.5, n_samples),
        94,
        100,
    )

    fan_speed = np.zeros(n_samples)

    for i in range(n_samples):
        t, h, hr, s = temp[i], humidity[i], heart_rate[i], spo2[i]

        if t <= 26:
            speed = 0
        elif t <= 28:
            speed = 20
        elif t <= 32:
            speed = 30 + (t - 28) * 15
        elif t <= 36:
            speed = 90 + (t - 32) * 2.5
        else:
            speed = 100

        if h > 70:
            speed += (h - 70) * 0.5
        if hr > 85:
            speed += (hr - 85) * 0.7
        if s < 96:
            speed += (96 - s) * 2

        speed += np.random.normal(0, 3)
        fan_speed[i] = np.clip(speed, 0, 100)

    return pd.DataFrame(
        {
            "temperature": temp,
            "humidity": humidity,
            "heart_rate": heart_rate,
            "spo2": spo2,
            "fan_speed": fan_speed,
        }
    )

# ====================
# 2. DATA PREPARATION
# ====================
print("Generating data...")
data = generate_training_data(2000)

X = data[["temperature", "humidity", "heart_rate", "spo2"]].values
y = data["fan_speed"].values

X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42
)

scaler = MinMaxScaler(feature_range=(-1, 1))
X_train_scaled = scaler.fit_transform(X_train)
X_test_scaled = scaler.transform(X_test)

joblib.dump(
    {
        "min_": scaler.min_,
        "scale_": scaler.scale_,
        "data_min_": scaler.data_min_,
        "data_max_": scaler.data_max_,
    },
    "scaler_params.joblib",
)

# ====================
# 3. MODEL TRAINING
# ====================
print("\nTraining Linear Regression...")
lr = LinearRegression()
lr.fit(X_train_scaled, y_train)

y_pred = lr.predict(X_test_scaled)
print(f"MAE: {mean_absolute_error(y_test, y_pred):.2f}%")

# Optional Decision Tree
dt = DecisionTreeRegressor(max_depth=4, random_state=42)
dt.fit(X_train_scaled, y_train)

# ====================
# 4. EXPORT MODEL (FIXED)
# ====================
print("\nExporting TinyML header...")

coef_str = ", ".join([f"{c:.6f}f" for c in lr.coef_])
intercept = lr.intercept_

header_content = f"""
#ifndef NECKCOOLER_ML_H
#define NECKCOOLER_ML_H

namespace TinyML {{

class NeckCoolerML {{
public:
    float predict(float temperature, float humidity, float heart_rate, float spo2) const {{
        float x[4];

        // Min-max scaling to [-1, 1]
        x[0] = (temperature - 20.0f) / (40.0f - 20.0f) * 2.0f - 1.0f;
        x[1] = (humidity - 30.0f) / (80.0f - 30.0f) * 2.0f - 1.0f;
        x[2] = (heart_rate - 60.0f) / (120.0f - 60.0f) * 2.0f - 1.0f;
        x[3] = (spo2 - 94.0f) / (100.0f - 94.0f) * 2.0f - 1.0f;

        float y = {intercept:.6f}f;
        float coef[4] = {{{coef_str}}};

        for (int i = 0; i < 4; i++) {{
            y += coef[i] * x[i];
        }}

        if (y < 0) y = 0;
        if (y > 100) y = 100;
        return y;
    }}
}};

}} // namespace TinyML

#endif
"""

with open("NeckCoolerML.h", "w") as f:
    f.write(header_content)

print("Saved NeckCoolerML.h")

# ====================
# 5. SIMPLE RULE MODEL
# ====================
simple_header = """
#ifndef NECKCOOLER_SIMPLE_ML_H
#define NECKCOOLER_SIMPLE_ML_H

namespace TinyML {

class NeckCoolerSimpleML {
public:
    int predict(float t, float h, int hr, int s) const {
        float speed = 0;

        if (t <= 26) speed = 0;
        else if (t <= 28) speed = 20;
        else if (t <= 32) speed = 30 + (t - 28) * 15;
        else if (t <= 36) speed = 90 + (t - 32) * 2.5;
        else speed = 100;

        if (h > 70) speed += (h - 70) * 0.5;
        if (hr > 85) speed += (hr - 85) * 0.7;
        if (s < 96) speed += (96 - s) * 2;

        if (speed < 0) speed = 0;
        if (speed > 100) speed = 100;

        return (int)speed;
    }
};

}

#endif
"""

with open("NeckCoolerSimpleML.h", "w") as f:
    f.write(simple_header)

print("Saved NeckCoolerSimpleML.h")
print("\n✅ TRAINING COMPLETE")
