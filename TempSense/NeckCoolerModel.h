#pragma once
#include <cstdarg>
namespace Eloquent {
    namespace ML {
        namespace Port {
            class LinearRegression {
                public:
                    /**
                    * Predict class for features vector
                    */
                    float predict(float *x) {
                        return dot(x, 2.539762321627, 0.084285283854, 0.064915820584, -0.247257077925) + -33.26452153060799;
                    }

                protected:
                    /**
                    * Compute dot product
                    */
                    float dot(float *x, ...) {
                        va_list w;
                        va_start(w, 4);
                        float dot = 0.0;

                        for (uint16_t i = 0; i < 4; i++) {
                            const float wi = va_arg(w, double);
                            dot += x[i] * wi;
                        }

                        return dot;
                    }
                };
            }
        }
    }