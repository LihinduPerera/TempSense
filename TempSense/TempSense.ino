// ====================
// INCLUDES & DEFINES
// ====================
#include <Arduino.h>
#include <WiFi.h>
#include <PubSubClient.h>
#include "DHT.h"
#include <MAX30105.h>
#include <heartRate.h>
#include <Adafruit_SSD1306.h>
#include <Wire.h>
#include "NeckCoolerSimpleML.h"  // Our TinyML model header

// WiFi & MQTT Credentials
#define WIFI_SSID "YOUR_WIFI_SSID"
#define WIFI_PASSWORD "YOUR_WIFI_PASSWORD"
#define MQTT_HOST "broker.hivemq.com"
#define MQTT_PORT 1883
#define MQTT_USER ""
#define MQTT_PASSWORD ""

// Pin Definitions
#define DHTPIN 4
#define MOSFET_PIN 25
#define I2C_SDA 21
#define I2C_SCL 22

// Sensor & Display Objects
#define DHTTYPE DHT22
DHT dht(DHTPIN, DHTTYPE);
MAX30105 particleSensor;
Adafruit_SSD1306 display(128, 64, &Wire, -1);

// MQTT Client
WiFiClient espClient;
PubSubClient mqttClient(espClient);

// MQTT Topics
const char* TOPIC_TEMP = "neckcooler/sensors/temperature";
const char* TOPIC_HUMID = "neckcooler/sensors/humidity";
const char* TOPIC_HEARTRATE = "neckcooler/sensors/heartrate";
const char* TOPIC_SPO2 = "neckcooler/sensors/spo2";
const char* TOPIC_FAN_SPEED = "neckcooler/sensors/fan_speed";
const char* TOPIC_CONTROL = "neckcooler/control/fan_speed";
const char* TOPIC_ML_STATUS = "neckcooler/ml/status";  // For ML diagnostics

// TinyML Model
TinyML::NeckCoolerSimpleML mlModel;

// Global Variables
float temperature = 0.0;
float humidity = 0.0;
int heartRate = 0;
int spo2 = 0;
int fanSpeed = 0;
bool autoMode = true;
unsigned long lastSensorUpdate = 0;
const long sensorInterval = 2000;
long lastBeat = 0;

// Smoothing filters
const int SMOOTHING_WINDOW = 5;
float tempHistory[SMOOTHING_WINDOW] = {0};
float humHistory[SMOOTHING_WINDOW] = {0};
int hrHistory[SMOOTHING_WINDOW] = {0};
int spo2History[SMOOTHING_WINDOW] = {0};
int historyIndex = 0;

// ML Performance tracking
float mlConfidence = 1.0;
int predictionCount = 0;
int lastPredictedSpeed = 0;

// ====================
// SMOOTHING FUNCTIONS
// ====================
float smoothValue(float newValue, float history[], int& idx) {
    history[idx % SMOOTHING_WINDOW] = newValue;
    idx++;
    
    float sum = 0;
    int count = 0;
    for (int i = 0; i < SMOOTHING_WINDOW; i++) {
        if (history[i] != 0) {
            sum += history[i];
            count++;
        }
    }
    
    return count > 0 ? sum / count : newValue;
}

int smoothValue(int newValue, int history[], int& idx) {
    history[idx % SMOOTHING_WINDOW] = newValue;
    idx++;
    
    int sum = 0;
    int count = 0;
    for (int i = 0; i < SMOOTHING_WINDOW; i++) {
        if (history[i] != 0) {
            sum += history[i];
            count++;
        }
    }
    
    return count > 0 ? sum / count : newValue;
}

// ====================
// TINYML INFERENCE FUNCTION
// ====================
int predictOptimalFanSpeed() {
    // Get smoothed values
    float smoothedTemp = smoothValue(temperature, tempHistory, historyIndex);
    float smoothedHum = smoothValue(humidity, humHistory, historyIndex);
    int smoothedHR = smoothValue(heartRate, hrHistory, historyIndex);
    int smoothedSpO2 = smoothValue(spo2, spo2History, historyIndex);
    
    // Run TinyML inference
    int predictedSpeed = mlModel.predict(smoothedTemp, smoothedHum, smoothedHR, smoothedSpO2);
    
    // Calculate confidence based on sensor quality
    float confidence = 1.0;
    
    // Lower confidence if sensors are reading unrealistic values
    if (smoothedTemp < 20 || smoothedTemp > 40) confidence *= 0.5;
    if (smoothedHum < 30 || smoothedHum > 80) confidence *= 0.5;
    if (smoothedHR < 40 || smoothedHR > 120) confidence *= 0.3;
    if (smoothedSpO2 < 90 || smoothedSpO2 > 100) confidence *= 0.3;
    
    // Gradually change speed if confidence is low
    if (confidence < 0.7 && predictionCount > 0) {
        // Smooth transition (max 10% change per cycle)
        int delta = predictedSpeed - lastPredictedSpeed;
        if (abs(delta) > 10) {
            predictedSpeed = lastPredictedSpeed + (delta > 0 ? 10 : -10);
        }
    }
    
    lastPredictedSpeed = predictedSpeed;
    mlConfidence = confidence;
    predictionCount++;
    
    return predictedSpeed;
}

// ====================
// IMPROVED SENSOR READING
// ====================
void readDHT22() {
    float t = dht.readTemperature();
    float h = dht.readHumidity();
    
    if (!isnan(t) && !isnan(h)) {
        temperature = t;
        humidity = h;
    } else {
        // Use last valid readings if sensor fails
        Serial.println("DHT22 read failed, using cached values");
    }
}

void readMAX30102() {
    static uint32_t samplesCollected = 0;
    static uint32_t irBuffer[100];
    static uint32_t redBuffer[100];
    static uint32_t bufferIndex = 0;
    
    // Check for new data
    particleSensor.check();
    
    while (particleSensor.available()) {
        // Read the IR and Red values
        irBuffer[bufferIndex] = particleSensor.getFIFOIR();
        redBuffer[bufferIndex] = particleSensor.getFIFORed();
        
        // Heart rate detection
        if (checkForBeat(irBuffer[bufferIndex])) {
            long delta = millis() - lastBeat;
            lastBeat = millis();
            
            if (delta > 0) {
                int bpm = 60000 / delta;  // Convert to BPM
                if (bpm >= 40 && bpm <= 220) {
                    heartRate = bpm;
                }
            }
        }
        
        bufferIndex++;
        samplesCollected++;
        particleSensor.nextSample();
        
        // Process batch for SpO2
        if (bufferIndex >= 100) {
            // Calculate SpO2 (simplified algorithm)
            // In production, implement proper SPO2 algorithm from SparkFun
            float irAvg = 0, redAvg = 0;
            for (int i = 0; i < 100; i++) {
                irAvg += irBuffer[i];
                redAvg += redBuffer[i];
            }
            irAvg /= 100;
            redAvg /= 100;
            
            // Simplified SpO2 calculation (calibrate for your hardware!)
            float ratio = (redAvg / irAvg);
            spo2 = 110 - (ratio * 25);  // Calibration formula
            
            if (spo2 < 90) spo2 = 90;
            if (spo2 > 100) spo2 = 100;
            
            bufferIndex = 0;
        }
        
        // Limit processing time
        if (samplesCollected > 300) {
            break;
        }
    }
}

// ====================
// MQTT FUNCTIONS
// ====================
void mqttCallback(char* topic, byte* payload, unsigned int length) {
    String message;
    for (unsigned int i = 0; i < length; i++) {
        message += (char)payload[i];
    }
    
    Serial.print("MQTT [");
    Serial.print(topic);
    Serial.print("]: ");
    Serial.println(message);
    
    if (String(topic) == TOPIC_CONTROL) {
        if (message == "AUTO") {
            autoMode = true;
            Serial.println("Switched to AUTO mode (TinyML control)");
        } else if (message == "MANUAL") {
            autoMode = false;
            Serial.println("Switched to MANUAL mode");
        } else {
            int newSpeed = message.toInt();
            if (newSpeed >= 0 && newSpeed <= 100) {
                fanSpeed = newSpeed;
                autoMode = false;
                Serial.printf("Manual speed: %d%%\n", fanSpeed);
            }
        }
    }
}

void connectToMqtt() {
    while (!mqttClient.connected()) {
        Serial.print("Connecting to MQTT...");
        
        String clientId = "NeckCooler-";
        clientId += String((uint32_t)ESP.getEfuseMac(), HEX);
        
        if (mqttClient.connect(clientId.c_str(), MQTT_USER, MQTT_PASSWORD)) {
            Serial.println("Connected!");
            
            // Subscribe to topics
            mqttClient.subscribe(TOPIC_CONTROL);
            Serial.println("Subscribed to control topic");
            
            // Publish connection status
            mqttClient.publish("neckcooler/status", "connected");
        } else {
            Serial.print("Failed, rc=");
            Serial.print(mqttClient.state());
            Serial.println(" retrying in 5s...");
            delay(5000);
        }
    }
}

void publishSensorData() {
    char buffer[20];
    
    // Publish all sensor data
    dtostrf(temperature, 4, 2, buffer);
    mqttClient.publish(TOPIC_TEMP, buffer);
    
    dtostrf(humidity, 4, 2, buffer);
    mqttClient.publish(TOPIC_HUMID, buffer);
    
    snprintf(buffer, sizeof(buffer), "%d", heartRate);
    mqttClient.publish(TOPIC_HEARTRATE, buffer);
    
    snprintf(buffer, sizeof(buffer), "%d", spo2);
    mqttClient.publish(TOPIC_SPO2, buffer);
    
    snprintf(buffer, sizeof(buffer), "%d", fanSpeed);
    mqttClient.publish(TOPIC_FAN_SPEED, buffer);
    
    // Publish ML status
    snprintf(buffer, sizeof(buffer), "%.2f", mlConfidence);
    mqttClient.publish(TOPIC_ML_STATUS, buffer);
}

// ====================
// OLED DISPLAY WITH ML INFO
// ====================
void updateDisplay() {
    display.clearDisplay();
    display.setTextSize(1);
    display.setTextColor(SSD1306_WHITE);
    
    // Header
    display.setCursor(0, 0);
    display.print("Neck Cooler v1.0");
    
    // Sensor Data
    display.setCursor(0, 10);
    display.printf("T:%.1fC H:%.0f%%", temperature, humidity);
    
    display.setCursor(0, 20);
    display.printf("HR:%d SpO2:%d%%", heartRate, spo2);
    
    // Control Info
    display.setCursor(0, 30);
    display.printf("Fan:%3d%%", fanSpeed);
    
    display.setCursor(0, 40);
    if (autoMode) {
        display.print("MODE: TinyML AUTO");
    } else {
        display.print("MODE: MANUAL    ");
    }
    
    // ML Confidence
    display.setCursor(0, 50);
    display.printf("ML Conf: %.0f%%", mlConfidence * 100);
    
    display.display();
}

// ====================
// SETUP
// ====================
void setup() {
    Serial.begin(115200);
    delay(100);
    
    Serial.println("\n=== AI Neck Cooler System ===");
    Serial.println("Initializing...");
    
    // Initialize I2C
    Wire.begin(I2C_SDA, I2C_SCL);
    
    // Initialize DHT22
    dht.begin();
    Serial.println("DHT22 initialized");
    
    // Initialize MAX30102
    if (particleSensor.begin(Wire, I2C_SPEED_FAST)) {
        Serial.println("MAX30102 found");
        
        // Configure sensor
        byte ledBrightness = 0x1F; // Options: 0=Off to 255=50mA
        byte sampleAverage = 4;    // Options: 1, 2, 4, 8, 16, 32
        byte ledMode = 2;          // Options: 1 = Red only, 2 = Red + IR
        int sampleRate = 100;      // Options: 50, 100, 200, 400, 800, 1000
        int pulseWidth = 411;      // Options: 69, 118, 215, 411
        int adcRange = 4096;       // Options: 2048, 4096, 8192, 16384
        
        particleSensor.setup(ledBrightness, sampleAverage, ledMode, sampleRate, pulseWidth, adcRange);
        particleSensor.setPulseAmplitudeRed(0x0A);
        particleSensor.setPulseAmplitudeIR(0x0A);
    } else {
        Serial.println("MAX30102 not found!");
    }
    
    // Initialize OLED
    if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
        Serial.println("OLED not found!");
    } else {
        display.clearDisplay();
        display.setTextSize(1);
        display.setTextColor(SSD1306_WHITE);
        display.setCursor(0, 0);
        display.println("AI Neck Cooler");
        display.println("Initializing...");
        display.display();
        delay(2000);
    }
    
    // Setup PWM
    const int freq = 25000;
    const int resolution = 8;
    ledcAttach(MOSFET_PIN, freq, resolution);
    ledcWrite(MOSFET_PIN, 0);
    
    // Connect to WiFi
    WiFi.mode(WIFI_STA);
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    
    Serial.print("Connecting to WiFi");
    int attempts = 0;
    while (WiFi.status() != WL_CONNECTED && attempts < 20) {
        delay(500);
        Serial.print(".");
        attempts++;
    }
    
    if (WiFi.status() == WL_CONNECTED) {
        Serial.println("\nWiFi connected!");
        Serial.print("IP: ");
        Serial.println(WiFi.localIP());
    }
    
    // Setup MQTT
    mqttClient.setServer(MQTT_HOST, MQTT_PORT);
    mqttClient.setCallback(mqttCallback);
    mqttClient.setBufferSize(512);
    
    // Initialize TinyML
    Serial.println("TinyML model initialized");
    
    // Show startup complete
    display.clearDisplay();
    display.setCursor(0, 0);
    display.println("System Ready");
    display.print("IP: ");
    if (WiFi.status() == WL_CONNECTED) {
        display.println(WiFi.localIP());
    } else {
        display.println("No WiFi");
    }
    display.display();
    
    delay(1000);
}

// ====================
// MAIN LOOP
// ====================
void loop() {
    unsigned long currentMillis = millis();
    
    // Maintain MQTT connection
    if (WiFi.status() == WL_CONNECTED) {
        if (!mqttClient.connected()) {
            connectToMqtt();
        }
        mqttClient.loop();
    } else {
        // Attempt WiFi reconnect every 30 seconds
        static unsigned long lastWifiReconnect = 0;
        if (currentMillis - lastWifiReconnect > 30000) {
            WiFi.reconnect();
            lastWifiReconnect = currentMillis;
        }
    }
    
    // Main sensor/control cycle
    if (currentMillis - lastSensorUpdate >= sensorInterval) {
        // Read sensors
        readDHT22();
        readMAX30102();
        
        // Auto mode: Use TinyML for intelligent control
        if (autoMode) {
            fanSpeed = predictOptimalFanSpeed();
            Serial.printf("TinyML prediction: %d%% (Confidence: %.2f)\n", 
                         fanSpeed, mlConfidence);
        }
        
        // Apply fan speed via PWM
        int pwmValue = map(fanSpeed, 0, 100, 0, 255);
        ledcWrite(MOSFET_PIN, pwmValue);
        
        // Publish data if connected
        if (mqttClient.connected()) {
            publishSensorData();
        }
        
        // Update display
        updateDisplay();
        
        // Debug output
        Serial.printf("T:%.1fC H:%.1f%% HR:%d SpO2:%d Fan:%d%%\n",
                     temperature, humidity, heartRate, spo2, fanSpeed);
        
        lastSensorUpdate = currentMillis;
    }
    
    // Small delay to prevent watchdog issues
    delay(10);
}