// ====================
// INCLUDES & DEFINES
// ====================
#include <WiFi.h>
#include <AsyncMQTT_ESP32.h> // Or AsyncMqttClient
#include "DHT.h"
#include <MAX30105.h>
#include <heartRate.h>
#include <spo2_algorithm.h>
#include <Adafruit_SSD1306.h>
#include <Wire.h>
#include "NeckCoolerModel.h" // Your TinyML model header

// WiFi & MQTT Credentials
#define WIFI_SSID "YOUR_WIFI_SSID"
#define WIFI_PASSWORD "YOUR_WIFI_PASSWORD"
#define MQTT_HOST "broker.hivemq.com" // or your broker IP
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
AsyncMqttClient mqttClient;
TimerHandle_t mqttReconnectTimer;
TimerHandle_t wifiReconnectTimer;

// MQTT Topics
#define TOPIC_TEMP "neckcooler/sensors/temperature"
#define TOPIC_HUMID "neckcooler/sensors/humidity"
#define TOPIC_HEARTRATE "neckcooler/sensors/heartrate"
#define TOPIC_SPO2 "neckcooler/sensors/spo2"
#define TOPIC_FAN_SPEED "neckcooler/sensors/fan_speed"
#define TOPIC_CONTROL "neckcooler/control/fan_speed"

// TinyML Model
Eloquent::ML::Port::LinearRegression mlModel; // Replace with your model class

// Global Variables
float temperature, humidity;
int heartRate, spo2;
int fanSpeed = 0; // 0-100%
bool autoMode = true;
unsigned long lastSensorUpdate = 0;
const long sensorInterval = 2000; // Publish every 2 seconds

// ====================
// PWM SETUP
// ====================
void setupPWM() {
  ledcSetup(0, 25000, 8); // Channel 0, 25 kHz, 8-bit resolution
  ledcAttachPin(MOSFET_PIN, 0);
  ledcWrite(0, 0); // Start with motor off
}

// ====================
// SENSOR READING FUNCTIONS
// ====================
void readDHT22() {
  temperature = dht.readTemperature();
  humidity = dht.readHumidity();
  if (isnan(temperature) || isnan(humidity)) {
    Serial.println("Failed to read from DHT sensor!");
    temperature = 0.0;
    humidity = 0.0;
  }
}

void readMAX30102() {
  // Heart rate calculation (simplified from SparkFun examples)
  long irValue = particleSensor.getIR();
  if (checkForBeat(irValue) == true) {
    long delta = millis() - lastBeat;
    lastBeat = millis();
    heartRate = 60 / (delta / 1000.0);
    if (heartRate < 50 || heartRate > 220) heartRate = 0;
  }

  // SpO2 calculation (simplified)
  uint32_t ir, red;
  particleSensor.check();
  if (particleSensor.available()) {
    ir = particleSensor.getFIFOIR();
    red = particleSensor.getFIFORed();
    // ... Implement SpO2 algorithm from SparkFun example
    spo2 = 95; // Placeholder
    particleSensor.nextSample();
  }
}

// ====================
// TINYML INFERENCE
// ====================
int predictFanSpeed() {
  // Prepare input features: temp, humidity, heart rate, SpO2
  float input[] = {temperature, humidity, (float)heartRate, (float)spo2};
  // Run inference (output is 0-100)
  float prediction = mlModel.predict(input);
  return constrain((int)prediction, 0, 100);
}

// ====================
// MQTT FUNCTIONS
// ====================
void connectToWifi() {
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
}

void connectToMqtt() {
  mqttClient.connect();
}

void WiFiEvent(WiFiEvent_t event) {
  switch (event) {
    case SYSTEM_EVENT_STA_GOT_IP:
      connectToMqtt();
      break;
    case SYSTEM_EVENT_STA_DISCONNECTED:
      xTimerStop(mqttReconnectTimer, 0);
      xTimerStart(wifiReconnectTimer, 0);
      break;
  }
}

void onMqttConnect(bool sessionPresent) {
  Serial.println("Connected to MQTT.");
  // Subscribe to control topic
  mqttClient.subscribe(TOPIC_CONTROL, 0);
}

void onMqttMessage(char* topic, char* payload, AsyncMqttClientMessageProperties properties, size_t len, size_t index, size_t total) {
  // Handle incoming speed commands
  String message;
  for (size_t i = 0; i < len; i++) {
    message += (char)payload[i];
  }
  
  if (String(topic) == TOPIC_CONTROL) {
    int newSpeed = message.toInt();
    if (newSpeed >= 0 && newSpeed <= 100) {
      fanSpeed = newSpeed;
      autoMode = false; // Switch to manual mode
      Serial.printf("Manual speed set to: %d%%\n", fanSpeed);
    }
  }
}

void publishSensorData() {
  char buffer[10];
  
  dtostrf(temperature, 4, 2, buffer);
  mqttClient.publish(TOPIC_TEMP, 0, false, buffer);
  
  dtostrf(humidity, 4, 2, buffer);
  mqttClient.publish(TOPIC_HUMID, 0, false, buffer);
  
  sprintf(buffer, "%d", heartRate);
  mqttClient.publish(TOPIC_HEARTRATE, 0, false, buffer);
  
  sprintf(buffer, "%d", spo2);
  mqttClient.publish(TOPIC_SPO2, 0, false, buffer);
  
  sprintf(buffer, "%d", fanSpeed);
  mqttClient.publish(TOPIC_FAN_SPEED, 0, false, buffer);
}

// ====================
// OLED DISPLAY
// ====================
void updateDisplay() {
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 0);
  
  display.printf("Temp: %.1fC\n", temperature);
  display.printf("Hum: %.1f%%\n", humidity);
  display.printf("HR: %d BPM\n", heartRate);
  display.printf("SpO2: %d%%\n", spo2);
  display.printf("Fan: %d%%\n", fanSpeed);
  display.printf("%s\n", autoMode ? "AUTO" : "MANUAL");
  
  display.display();
}

// ====================
// ARDUINO STANDARD FUNCTIONS
// ====================
void setup() {
  Serial.begin(115200);
  
  // Initialize I2C
  Wire.begin(I2C_SDA, I2C_SCL);
  
  // Initialize sensors
  dht.begin();
  if (!particleSensor.begin(Wire, I2C_SPEED_FAST)) {
    Serial.println("MAX30102 not found!");
  }
  particleSensor.setup();
  
  // Initialize OLED
  if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println("OLED not found!");
  }
  display.clearDisplay();
  
  // Setup PWM
  setupPWM();
  
  // Setup MQTT
  mqttReconnectTimer = xTimerCreate("mqttTimer", pdMS_TO_TICKS(2000), pdFALSE, (void*)0, reinterpret_cast<TimerCallbackFunction_t>(connectToMqtt));
  wifiReconnectTimer = xTimerCreate("wifiTimer", pdMS_TO_TICKS(5000), pdFALSE, (void*)0, reinterpret_cast<TimerCallbackFunction_t>(connectToWifi));
  
  WiFi.onEvent(WiFiEvent);
  mqttClient.onConnect(onMqttConnect);
  mqttClient.onMessage(onMqttMessage);
  mqttClient.setServer(MQTT_HOST, MQTT_PORT);
  mqttClient.setCredentials(MQTT_USER, MQTT_PASSWORD);
  
  connectToWifi();
}

void loop() {
  unsigned long currentMillis = millis();
  
  // Read sensors periodically
  if (currentMillis - lastSensorUpdate >= sensorInterval) {
    readDHT22();
    readMAX30102();
    
    // Auto mode: use TinyML to predict speed
    if (autoMode) {
      fanSpeed = predictFanSpeed();
    }
    
    // Apply PWM
    int pwmValue = map(fanSpeed, 0, 100, 0, 255);
    ledcWrite(0, pwmValue);
    
    // Publish data
    publishSensorData();
    
    // Update display
    updateDisplay();
    
    lastSensorUpdate = currentMillis;
  }
}