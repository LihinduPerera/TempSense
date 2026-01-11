// ====================
// INCLUDES & DEFINES
// ====================
#include <Arduino.h>
#include <WiFi.h>
#include <PubSubClient.h>       // switched to PubSubClient for simplicity
#include "DHT.h"
#include <MAX30105.h>
#include <heartRate.h>          // SparkFun heart-rate helper (checkForBeat uses lastBeat)
#include <Adafruit_SSD1306.h>
#include <Wire.h>
// #include "NeckCoolerModel.h" // <-- If you have a TinyML header, re-enable and adapt predictFanSpeed()

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

// MQTT Client (PubSubClient)
WiFiClient espClient;
PubSubClient mqttClient(espClient);

// MQTT Topics
const char* TOPIC_TEMP = "neckcooler/sensors/temperature";
const char* TOPIC_HUMID = "neckcooler/sensors/humidity";
const char* TOPIC_HEARTRATE = "neckcooler/sensors/heartrate";
const char* TOPIC_SPO2 = "neckcooler/sensors/spo2";
const char* TOPIC_FAN_SPEED = "neckcooler/sensors/fan_speed";
const char* TOPIC_CONTROL = "neckcooler/control/fan_speed";

// Global Variables
float temperature = 0.0;
float humidity = 0.0;
int heartRate = 0;
int spo2 = 0;
int fanSpeed = 0; // 0-100%
bool autoMode = true;
unsigned long lastSensorUpdate = 0;
const long sensorInterval = 2000; // Publish every 2 seconds

// MAX30102 beat helper
long lastBeat = 0; // required by heartRate helper (keeps previous beat time)

// ====================
// PWM SETUP - FIXED FOR NEW ESP32 CORE
// ====================
void setupPWM() {
  // ESP32 LEDC PWM: Using new API for ESP32 Arduino Core 3.x+
  // ledcAttach(pin, freq, resolution) returns the channel number
  const int freq = 25000;      // 25 kHz
  const int resolution = 8;    // 8-bit resolution (0-255)
  
  // Attach PWM to the pin - this replaces ledcSetup + ledcAttachPin
  ledcAttach(MOSFET_PIN, freq, resolution);
  
  // Set initial duty cycle to 0 (motor off)
  ledcWrite(MOSFET_PIN, 0);
}

// ====================
// SENSOR READING FUNCTIONS
// ====================
void readDHT22() {
  float t = dht.readTemperature();
  float h = dht.readHumidity();
  if (isnan(t) || isnan(h)) {
    Serial.println("Failed to read from DHT sensor!");
    // keep previous good values rather than forcing 0.0; adjust as desired
  } else {
    temperature = t;
    humidity = h;
  }
}

void readMAX30102() {
  // Basic heart-rate detection (from SparkFun examples)
  long irValue = particleSensor.getIR();

  if (irValue > 50000) { // signal present threshold; adjust to your sensor & finger placement
    if (checkForBeat(irValue)) {
      long delta = millis() - lastBeat;
      lastBeat = millis();
      if (delta > 0) {
        int bpm = (int)(60.0 / (delta / 1000.0));
        if (bpm >= 40 && bpm <= 220) heartRate = bpm;
        else heartRate = 0;
      }
    }
  } else {
    // no finger / weak signal
    // heartRate = 0; // optionally set to 0
  }

  // SpO2 placeholder: implementing a robust SpO2 algorithm requires the full SPO2 code.
  // If you have a tested spo2_algorithm implementation, plug it in here.
  if (particleSensor.available()) {
    // Consume sample (prevent FIFO overflow)
    uint32_t ir = particleSensor.getFIFOIR();
    uint32_t red = particleSensor.getFIFORed();
    (void)ir;
    (void)red;
    particleSensor.nextSample();
    // spo2 = <call your SPO2 calc here>; 
    // For now, leave as last known or a placeholder value:
    if (spo2 == 0) spo2 = 95;
  }
}

// ====================
// SIMPLE FAN SPEED MODEL
// ====================
// This is a simple fallback heuristic so code compiles without TinyML.
// Replace the body by calling your TinyML model's predict function if available.
int predictFanSpeed() {
  // Basic logic:
  // - Base speed from temperature (below 28°C -> low, above 40°C -> max)
  // - Add small adjustments from heart rate and humidity
  float t = temperature;
  int speed = 0;

  if (t <= 28.0) speed = 10;
  else if (t >= 40.0) speed = 100;
  else {
    // linear mapping between 28..40 to 10..100
    speed = (int)map((int)(t * 10), (int)(28.0 * 10), (int)(40.0 * 10), 10, 100);
  }

  // nudge by heart rate (if elevated > 100)
  if (heartRate > 100) speed += (heartRate - 100) / 2;
  // nudge by humidity (very high humidity reduces cooling efficiency -> raise fan)
  if (humidity > 70.0) speed += (int)((humidity - 70.0) / 2);

  speed = constrain(speed, 0, 100);
  return speed;
}

// ====================
// MQTT FUNCTIONS
// ====================
void mqttCallback(char* topic, byte* payload, unsigned int length) {
  // Convert payload to String
  String message;
  for (unsigned int i = 0; i < length; i++) message += (char)payload[i];

  Serial.print("MQTT msg [");
  Serial.print(topic);
  Serial.print("] ");
  Serial.println(message);

  if (String(topic) == TOPIC_CONTROL) {
    int newSpeed = message.toInt();
    if (newSpeed >= 0 && newSpeed <= 100) {
      fanSpeed = newSpeed;
      autoMode = false; // switch to manual
      Serial.printf("Manual speed set to: %d%%\n", fanSpeed);
    }
  }
}

void connectToMqtt() {
  while (!mqttClient.connected()) {
    Serial.print("Connecting to MQTT...");
    // client ID must be unique
    String clientId = "ESP32-NeckCooler-";
    clientId += String((uint32_t)ESP.getEfuseMac(), HEX);
    if (mqttClient.connect(clientId.c_str(), MQTT_USER, MQTT_PASSWORD)) {
      Serial.println("connected");
      mqttClient.subscribe(TOPIC_CONTROL);
    } else {
      Serial.print("failed, rc=");
      Serial.print(mqttClient.state());
      Serial.println("; retrying in 3s");
      delay(3000);
    }
  }
}

void publishSensorData() {
  char buffer[16];

  // Temperature
  snprintf(buffer, sizeof(buffer), "%.2f", temperature);
  mqttClient.publish(TOPIC_TEMP, buffer);

  // Humidity
  snprintf(buffer, sizeof(buffer), "%.2f", humidity);
  mqttClient.publish(TOPIC_HUMID, buffer);

  // Heart rate
  snprintf(buffer, sizeof(buffer), "%d", heartRate);
  mqttClient.publish(TOPIC_HEARTRATE, buffer);

  // SpO2
  snprintf(buffer, sizeof(buffer), "%d", spo2);
  mqttClient.publish(TOPIC_SPO2, buffer);

  // Fan speed
  snprintf(buffer, sizeof(buffer), "%d", fanSpeed);
  mqttClient.publish(TOPIC_FAN_SPEED, buffer);
}

// ====================
// OLED DISPLAY
// ====================
void updateDisplay() {
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 0);

  // Using prints to avoid relying on printf compatibility
  display.print("Temp: ");
  display.print(temperature, 1);
  display.println(" C");

  display.print("Hum: ");
  display.print(humidity, 1);
  display.println(" %");

  display.print("HR: ");
  display.print(heartRate);
  display.println(" BPM");

  display.print("SpO2: ");
  display.print(spo2);
  display.println(" %");

  display.print("Fan: ");
  display.print(fanSpeed);
  display.println(" %");

  display.println(autoMode ? "AUTO" : "MANUAL");

  display.display();
}

// ====================
// SETUP
// ====================
void setup() {
  Serial.begin(115200);
  delay(50);

  // I2C
  Wire.begin(I2C_SDA, I2C_SCL);

  // DHT
  dht.begin();

  // MAX30102
  if (!particleSensor.begin(Wire)) {
    Serial.println("MAX30102 not found!");
  } else {
    Serial.println("MAX30102 found.");
    particleSensor.setup(); // default setup; tune as needed
    particleSensor.setPulseAmplitudeRed(0x0A); // lower LED amplitude to start
    particleSensor.setPulseAmplitudeIR(0x0A);
  }

  // OLED
  if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println("OLED not found!");
  } else {
    display.clearDisplay();
    display.display();
  }

  // PWM
  setupPWM();

  // WiFi
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting to WiFi");
  int wifi_wait = 0;
  while (WiFi.status() != WL_CONNECTED && wifi_wait < 20) {
    delay(500);
    Serial.print(".");
    wifi_wait++;
  }
  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    Serial.print("Connected, IP: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("WiFi connect failed (continuing; will retry in loop).");
  }

  // MQTT
  mqttClient.setServer(MQTT_HOST, MQTT_PORT);
  mqttClient.setCallback(mqttCallback);

  // Try connect immediately if WiFi already connected
  if (WiFi.status() == WL_CONNECTED) {
    connectToMqtt();
  }
}

// ====================
// LOOP
// ====================
void loop() {
  unsigned long currentMillis = millis();

  // Ensure MQTT client connected if WiFi connected
  if (WiFi.status() == WL_CONNECTED) {
    if (!mqttClient.connected()) {
      connectToMqtt();
    }
    mqttClient.loop();
  } else {
    // Try to reconnect WiFi if disconnected
    static unsigned long lastWifiAttempt = 0;
    if (millis() - lastWifiAttempt > 5000) {
      Serial.println("Attempting WiFi reconnect...");
      WiFi.disconnect();
      WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
      lastWifiAttempt = millis();
    }
  }

  // Read sensors periodically
  if (currentMillis - lastSensorUpdate >= sensorInterval) {
    readDHT22();
    readMAX30102();

    // Auto mode: use (TinyML or fallback) to predict speed
    if (autoMode) {
      fanSpeed = predictFanSpeed();
    }

    // Apply PWM (map 0-100 to 0-255 for 8-bit)
    int pwmValue = map(fanSpeed, 0, 100, 0, 255);
    ledcWrite(MOSFET_PIN, pwmValue);  // Updated to use pin directly

    // Publish data
    if (WiFi.status() == WL_CONNECTED && mqttClient.connected()) {
      publishSensorData();
    }

    // Update display
    updateDisplay();

    lastSensorUpdate = currentMillis;
  }
}