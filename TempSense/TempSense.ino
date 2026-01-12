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
#include "NeckCoolerML.h"

// WiFi & MQTT Credentials
#define WIFI_SSID "MT20_MIFI_GEN-66"
#define WIFI_PASSWORD "9g8P604?"
#define MQTT_HOST "broker.hivemq.com"
#define MQTT_PORT 1883

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
const char* TOPIC_ML_STATUS = "neckcooler/ml/status";

// TinyML Model
TinyML::NeckCoolerML mlModel;

// Global Variables
float temperature = 0.0;
float humidity = 0.0;
int heartRate = 0;
int spo2 = 0;
int fanSpeed = 0;
bool autoMode = true;
unsigned long lastSensorUpdate = 0;
const long sensorInterval = 500;  // OPTIMIZED: Reduced to 500ms for faster sensor updates
unsigned long lastDisplayUpdate = 0;
const long displayInterval = 250;  // OPTIMIZED: Update display every 250ms
bool max30102Connected = false;

// Heart rate detection
const byte RATE_SIZE = 4;
byte rates[RATE_SIZE];
byte rateSpot = 0;
long lastBeat = 0;
float beatsPerMinute = 0;
int beatAvg = 0;

// Fast sampling for heart rate
unsigned long lastHeartRateSample = 0;
const long heartRateSampleInterval = 20;

// SpO2 calculation variables
#define SPO2_BUFFER_SIZE 50
uint32_t irBuffer[SPO2_BUFFER_SIZE];
uint32_t redBuffer[SPO2_BUFFER_SIZE];
int bufferIndex = 0;
bool bufferFilled = false;
unsigned long lastSpO2Calc = 0;

// Buffer for MQTT messages
char msgBuffer[50];

// OPTIMIZED: Fan control immediate response
int targetFanSpeed = 0;
unsigned long lastFanUpdate = 0;
const long fanUpdateInterval = 50;  // Update fan every 50ms for smooth transitions

// TempSense Logo (32x32 bitmap)
const unsigned char tempSenseLogo [] PROGMEM = {
  0x00, 0x00, 0x00, 0x00, 0x00, 0x7f, 0xfe, 0x00, 0x01, 0xff, 0xff, 0x80, 0x03, 0xe0, 0x07, 0xc0, 
  0x07, 0x80, 0x01, 0xe0, 0x0f, 0x00, 0x00, 0xf0, 0x0e, 0x07, 0xe0, 0x70, 0x1c, 0x0f, 0xf0, 0x38, 
  0x1c, 0x1c, 0x38, 0x38, 0x38, 0x18, 0x1c, 0x1c, 0x38, 0x18, 0x1c, 0x1c, 0x38, 0x18, 0x1c, 0x1c, 
  0x38, 0x1c, 0x38, 0x1c, 0x38, 0x1c, 0x38, 0x1c, 0x38, 0x1c, 0x38, 0x1c, 0x38, 0x1c, 0x38, 0x1c, 
  0x1c, 0x0e, 0x70, 0x38, 0x1c, 0x0f, 0xe0, 0x38, 0x0e, 0x07, 0xc0, 0x70, 0x0f, 0x00, 0x00, 0xf0, 
  0x07, 0x80, 0x01, 0xe0, 0x03, 0xe0, 0x07, 0xc0, 0x01, 0xff, 0xff, 0x80, 0x00, 0x7f, 0xfe, 0x00, 
  0x00, 0x00, 0x00, 0x00
};

// ====================
// DISPLAY LOGO
// ====================
void showLogo() {
  display.clearDisplay();
  int logoX = (128 - 32) / 2;
  int logoY = 8;
  display.drawBitmap(logoX, logoY, tempSenseLogo, 32, 32, SSD1306_WHITE);
  display.setTextSize(2);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(10, 45);
  display.println("TempSense");
  display.display();
  delay(2000);
  
  for (int i = 0; i < 3; i++) {
    display.clearDisplay();
    display.drawBitmap(logoX, logoY, tempSenseLogo, 32, 32, SSD1306_WHITE);
    display.setTextSize(1);
    display.setCursor(30, 50);
    display.print("Loading");
    for (int j = 0; j <= i; j++) {
      display.print(".");
    }
    display.display();
    delay(500);
  }
}

// ====================
// WiFi CONNECTION
// ====================
void connectToWiFi() {
  Serial.print("Connecting to WiFi");
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  
  display.clearDisplay();
  display.setTextSize(1);
  display.setCursor(0, 0);
  display.println("Connecting WiFi...");
  display.display();
  
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
    display.println("WiFi: Connected");
    display.display();
    delay(1000);
  } else {
    Serial.println("\nWiFi connection failed!");
    display.println("WiFi: Failed");
    display.display();
    delay(1000);
  }
}

// ====================
// MQTT CALLBACK - OPTIMIZED FOR INSTANT RESPONSE
// ====================
void mqttCallback(char* topic, byte* payload, unsigned int length) {
  char message[length + 1];
  for (unsigned int i = 0; i < length; i++) {
    message[i] = (char)payload[i];
  }
  message[length] = '\0';
  
  Serial.print("MQTT [");
  Serial.print(topic);
  Serial.print("]: ");
  Serial.println(message);
  
  if (strcmp(topic, TOPIC_CONTROL) == 0) {
    if (strcmp(message, "AUTO") == 0) {
      autoMode = true;
      Serial.println("Switched to AUTO mode");
      // OPTIMIZED: Immediate feedback
      publishFanSpeed();
    } else if (strcmp(message, "MANUAL") == 0) {
      autoMode = false;
      Serial.println("Switched to MANUAL mode");
      // OPTIMIZED: Immediate feedback
      publishFanSpeed();
    } else {
      int newSpeed = atoi(message);
      if (newSpeed >= 0 && newSpeed <= 100) {
        targetFanSpeed = newSpeed;
        fanSpeed = newSpeed;
        autoMode = false;
        
        // OPTIMIZED: Apply fan speed IMMEDIATELY
        int pwmValue = map(fanSpeed, 0, 100, 0, 255);
        analogWrite(MOSFET_PIN, pwmValue);
        
        Serial.printf("⚡ INSTANT: Manual speed set to: %d%%\n", fanSpeed);
        
        // OPTIMIZED: Send immediate confirmation back to app
        publishFanSpeed();
      }
    }
  }
}

// ====================
// MQTT CONNECTION
// ====================
void connectToMqtt() {
  int retries = 0;
  while (!mqttClient.connected() && retries < 3) {
    Serial.print("Connecting to MQTT...");
    
    String clientId = "NeckCooler-";
    clientId += String(random(0xffff), HEX);
    
    if (mqttClient.connect(clientId.c_str())) {
      Serial.println("Connected!");
      mqttClient.subscribe(TOPIC_CONTROL);
      mqttClient.publish("neckcooler/status", "connected");
      return;
    } else {
      Serial.print("Failed, rc=");
      Serial.println(mqttClient.state());
      retries++;
      delay(2000);
    }
  }
}

// OPTIMIZED: Separate function for immediate fan speed feedback
void publishFanSpeed() {
  if (mqttClient.connected()) {
    snprintf(msgBuffer, sizeof(msgBuffer), "%d", fanSpeed);
    mqttClient.publish(TOPIC_FAN_SPEED, msgBuffer, false);  // No retain for instant updates
  }
}

// ====================
// PUBLISH SENSOR DATA
// ====================
void publishSensorData() {
  if (!mqttClient.connected()) {
    return;
  }
  
  snprintf(msgBuffer, sizeof(msgBuffer), "%.1f", temperature);
  mqttClient.publish(TOPIC_TEMP, msgBuffer);
  
  snprintf(msgBuffer, sizeof(msgBuffer), "%.1f", humidity);
  mqttClient.publish(TOPIC_HUMID, msgBuffer);
  
  snprintf(msgBuffer, sizeof(msgBuffer), "%d", heartRate);
  mqttClient.publish(TOPIC_HEARTRATE, msgBuffer);
  
  snprintf(msgBuffer, sizeof(msgBuffer), "%d", spo2);
  mqttClient.publish(TOPIC_SPO2, msgBuffer);
  
  publishFanSpeed();
  
  float confidence = max30102Connected ? 0.85 : 0.50;
  snprintf(msgBuffer, sizeof(msgBuffer), "%.2f", confidence);
  mqttClient.publish(TOPIC_ML_STATUS, msgBuffer);
}

// ====================
// SENSOR READING
// ====================
void readDHT22() {
  float t = dht.readTemperature();
  float h = dht.readHumidity();
  
  if (!isnan(t) && t > -40 && t < 80) {
    temperature = t;
  }
  if (!isnan(h) && h > 0 && h < 100) {
    humidity = h;
  }
}

void calculateSpO2() {
  if (!bufferFilled) return;
  
  uint32_t irMax = 0, irMin = 0xFFFFFFFF;
  uint32_t redMax = 0, redMin = 0xFFFFFFFF;
  
  for (int i = 0; i < SPO2_BUFFER_SIZE; i++) {
    if (irBuffer[i] > irMax) irMax = irBuffer[i];
    if (irBuffer[i] < irMin) irMin = irBuffer[i];
    if (redBuffer[i] > redMax) redMax = redBuffer[i];
    if (redBuffer[i] < redMin) redMin = redBuffer[i];
  }
  
  float irAC = irMax - irMin;
  float irDC = (irMax + irMin) / 2.0;
  float redAC = redMax - redMin;
  float redDC = (redMax + redMin) / 2.0;
  
  if (irAC < 100 || irDC < 100 || redDC < 100) {
    return;
  }
  
  float R = (redAC / redDC) / (irAC / irDC);
  
  if (R >= 0.4 && R <= 2.0) {
    float calculatedSpO2 = 110.0 - 25.0 * R;
    spo2 = constrain((int)calculatedSpO2, 85, 100);
  }
}

void sampleHeartRate() {
  if (!max30102Connected) {
    return;
  }
  
  long irValue = particleSensor.getIR();
  long redValue = particleSensor.getRed();
  
  if (irValue < 10000) {
    heartRate = 0;
    beatsPerMinute = 0;
    for (byte x = 0; x < RATE_SIZE; x++) {
      rates[x] = 0;
    }
    rateSpot = 0;
    return;
  }
  
  irBuffer[bufferIndex] = irValue;
  redBuffer[bufferIndex] = redValue;
  bufferIndex++;
  
  if (bufferIndex >= SPO2_BUFFER_SIZE) {
    bufferIndex = 0;
    bufferFilled = true;
  }
  
  if (checkForBeat(irValue) == true) {
    long delta = millis() - lastBeat;
    lastBeat = millis();
    
    beatsPerMinute = 60.0 / (delta / 1000.0);
    
    if (beatsPerMinute > 30 && beatsPerMinute < 220) {
      rates[rateSpot++] = (byte)beatsPerMinute;
      rateSpot %= RATE_SIZE;
      
      int sum = 0;
      int validCount = 0;
      for (byte x = 0; x < RATE_SIZE; x++) {
        if (rates[x] > 0) {
          sum += rates[x];
          validCount++;
        }
      }
      
      if (validCount > 0) {
        beatAvg = sum / validCount;
        heartRate = beatAvg;
      }
    }
  }
}

void readMAX30102() {
  if (!max30102Connected) {
    heartRate = 0;
    spo2 = 0;
    return;
  }
  
  long irValue = particleSensor.getIR();
  
  if (irValue < 10000) {
    return;
  }
  
  if (bufferFilled && (millis() - lastSpO2Calc > 1000)) {
    calculateSpO2();
    lastSpO2Calc = millis();
  }
}

// ====================
// FAN CONTROL - OPTIMIZED
// ====================
void controlFan() {
  if (autoMode) {
    targetFanSpeed = mlModel.predict(temperature, humidity, heartRate, spo2);
  }
  
  targetFanSpeed = constrain(targetFanSpeed, 0, 100);
  fanSpeed = targetFanSpeed;
  
  // OPTIMIZED: Apply PWM immediately
  int pwmValue = map(fanSpeed, 0, 100, 0, 255);
  analogWrite(MOSFET_PIN, pwmValue);
}

// ====================
// OLED DISPLAY - OPTIMIZED
// ====================
void updateDisplay() {
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  
  display.setCursor(0, 0);
  display.print("TempSense Cooler");
  display.drawLine(0, 9, 128, 9, SSD1306_WHITE);
  
  display.setCursor(0, 12);
  display.print("WiFi:");
  display.setCursor(40, 12);
  display.print(WiFi.status() == WL_CONNECTED ? "OK" : "X");
  
  display.setCursor(70, 12);
  display.print("MQTT:");
  display.setCursor(105, 12);
  display.print(mqttClient.connected() ? "OK" : "X");
  
  display.setCursor(0, 24);
  display.printf("Temp: %.1f C", temperature);
  
  display.setCursor(0, 34);
  display.printf("Humid: %.0f %%", humidity);
  
  display.setCursor(0, 44);
  if (max30102Connected && heartRate > 0) {
    display.printf("HR: %d bpm", heartRate);
  } else {
    display.print("HR: --- bpm");
  }
  
  display.setCursor(0, 54);
  if (max30102Connected && spo2 > 0) {
    display.printf("SpO2: %d%%  ", spo2);
  } else {
    display.print("SpO2: ---%  ");
  }
  
  display.setCursor(85, 54);
  display.printf("F:%d%%", fanSpeed);
  
  display.setCursor(85, 44);
  display.print(autoMode ? "AUTO" : "MAN ");
  
  display.display();
}

// ====================
// SETUP
// ====================
void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("\n=== TempSense AI Neck Cooler ===");
  
  Wire.begin(I2C_SDA, I2C_SCL);
  Wire.setClock(400000);
  Serial.println("I2C initialized at 400kHz");
  
  if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println("OLED initialization failed!");
  } else {
    Serial.println("OLED initialized");
    showLogo();
  }
  
  dht.begin();
  Serial.println("DHT22 initialized");
  
  display.clearDisplay();
  display.setTextSize(1);
  display.setCursor(0, 0);
  display.println("Initializing...");
  display.display();
  
  Serial.println("Initializing MAX30102...");
  if (particleSensor.begin(Wire, I2C_SPEED_FAST)) {
    Serial.println("MAX30102 found!");
    
    byte ledBrightness = 0x7F;
    byte sampleAverage = 2;
    byte ledMode = 2;
    byte sampleRate = 200;
    int pulseWidth = 411;
    int adcRange = 16384;
    
    particleSensor.setup(ledBrightness, sampleAverage, ledMode, sampleRate, pulseWidth, adcRange);
    particleSensor.setPulseAmplitudeRed(0x0A);
    particleSensor.setPulseAmplitudeIR(0x7F);
    particleSensor.setPulseAmplitudeGreen(0);
    
    max30102Connected = true;
    Serial.println("✓ MAX30102 configured");
    
    display.println("MAX30102: OK");
    display.display();
  } else {
    Serial.println("MAX30102 not found!");
    max30102Connected = false;
    display.println("MAX30102: FAILED");
    display.display();
  }
  
  delay(1000);
  
  pinMode(MOSFET_PIN, OUTPUT);
  analogWrite(MOSFET_PIN, 0);
  Serial.println("Fan controller initialized");
  
  connectToWiFi();
  
  // OPTIMIZED: Configure MQTT for low latency
  mqttClient.setServer(MQTT_HOST, MQTT_PORT);
  mqttClient.setCallback(mqttCallback);
  mqttClient.setKeepAlive(15);  // Reduced for faster reconnection
  mqttClient.setBufferSize(256);  // Smaller buffer for faster processing
  
  connectToMqtt();
  
  for (byte x = 0; x < RATE_SIZE; x++) {
    rates[x] = 0;
  }
  
  bufferIndex = 0;
  bufferFilled = false;
  
  Serial.println("\n✓✓✓ Setup complete! ✓✓✓");
  Serial.println("========================\n");
  
  display.clearDisplay();
  display.setTextSize(1);
  display.setCursor(0, 0);
  display.println("System Ready!");
  display.display();
  delay(2000);
}

// ====================
// MAIN LOOP - OPTIMIZED FOR RESPONSIVENESS
// ====================
void loop() {
  // PRIORITY 1: MQTT processing for instant commands
  if (!mqttClient.connected()) {
    connectToMqtt();
  }
  mqttClient.loop();  // Process immediately
  
  // PRIORITY 2: Fast heart rate sampling (every 20ms)
  if (millis() - lastHeartRateSample >= heartRateSampleInterval) {
    sampleHeartRate();
    lastHeartRateSample = millis();
  }
  
  // PRIORITY 3: Regular sensor updates (every 500ms - FASTER)
  if (millis() - lastSensorUpdate >= sensorInterval) {
    readDHT22();
    readMAX30102();
    controlFan();
    publishSensorData();
    
    Serial.printf("📊 T:%.1f°C | H:%.1f%% | HR:%d | SpO2:%d%% | Fan:%d%% | %s\n",
                  temperature, humidity, heartRate, spo2, fanSpeed, 
                  autoMode ? "AUTO" : "MANUAL");
    
    lastSensorUpdate = millis();
  }
  
  // PRIORITY 4: Display updates (every 250ms - FASTER)
  if (millis() - lastDisplayUpdate >= displayInterval) {
    updateDisplay();
    lastDisplayUpdate = millis();
  }
  
  // PRIORITY 5: WiFi maintenance
  if (WiFi.status() != WL_CONNECTED) {
    connectToWiFi();
  }
  
  delay(5);  // Minimal delay for stability
}