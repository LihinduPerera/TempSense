
#ifndef NECKCOOLER_ML_H
#define NECKCOOLER_ML_H

namespace TinyML {

class NeckCoolerML {
public:
    float predict(float temperature, float humidity, float heart_rate, float spo2) const {
        float x[4];

        // Min-max scaling to [-1, 1]
        x[0] = (temperature - 20.0f) / (40.0f - 20.0f) * 2.0f - 1.0f;
        x[1] = (humidity - 30.0f) / (80.0f - 30.0f) * 2.0f - 1.0f;
        x[2] = (heart_rate - 60.0f) / (120.0f - 60.0f) * 2.0f - 1.0f;
        x[3] = (spo2 - 94.0f) / (100.0f - 94.0f) * 2.0f - 1.0f;

        float y = 57.130457f;
        float coef[4] = {74.401611f, 1.042139f, 3.152689f, 0.207605f};

        for (int i = 0; i < 4; i++) {
            y += coef[i] * x[i];
        }

        if (y < 0) y = 0;
        if (y > 100) y = 100;
        return y;
    }
};

} // namespace TinyML

#endif
