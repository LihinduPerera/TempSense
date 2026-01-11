import numpy as np
import pandas as pd
from sklearn.linear_model import LinearRegression
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_absolute_error
from micromlgen import port

# Generate synthetic training data
np.random.seed(42)
n_samples = 1000

# Feature ranges (simulating real-world conditions)
temperature = np.random.uniform(20, 40, n_samples)  # °C
humidity = np.random.uniform(30, 80, n_samples)     # %
heart_rate = np.random.randint(60, 100, n_samples)  # BPM
spo2 = np.random.randint(90, 100, n_samples)        # %

# Synthetic target: fan speed (0-100%)
# This formula simulates a sensible cooling policy
fan_speed = (
    0.5 * (temperature - 20) * 5 +          # Temp contribution
    0.2 * (humidity - 30) * 0.5 +           # Humidity contribution
    0.2 * (heart_rate - 60) * 0.2 +         # Heart rate contribution
    0.1 * (100 - spo2) * 2 +                # SpO2 contribution
    np.random.normal(0, 5, n_samples)       # Noise
)
fan_speed = np.clip(fan_speed, 0, 100)

# Create DataFrame
X = np.column_stack([temperature, humidity, heart_rate, spo2])
y = fan_speed

# Split data
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

# Train model
model = LinearRegression()
model.fit(X_train, y_train)

# Evaluate
y_pred = model.predict(X_test)
mae = mean_absolute_error(y_test, y_pred)
print(f"Model MAE: {mae:.2f}%")
print(f"Model coefficients: {model.coef_}")
print(f"Model intercept: {model.intercept_}")

# Convert to C code
c_code = port(model, classname='NeckCoolerModel', namespace='Eloquent::ML::Port')
print("\nGenerated C code length:", len(c_code))

# Save as header file
with open('NeckCoolerModel.h', 'w') as f:
    f.write(c_code)
print("Header file saved as 'NeckCoolerModel.h'")