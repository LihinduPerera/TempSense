
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
