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
#include "NeckCoolerML.h"  // Our TinyML model header

// WiFi & MQTT Credentials - CHANGE THESE TO YOUR NETWORK
#define WIFI_SSID "MT20_MIFI_GEN-66"
#define WIFI_PASSWORD "00000000"
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
const long sensorInterval = 2000;
bool max30102Connected = false;

// Heart rate detection
const byte RATE_SIZE = 4;
byte rates[RATE_SIZE];
byte rateSpot = 0;
long lastBeat = 0;
float beatsPerMinute;
int beatAvg;

// SpO2 variables
uint32_t irBuffer[100];
uint32_t redBuffer[100];
int32_t bufferLength = 100;
int32_t spo2Value;
int8_t validSPO2;
int32_t heartRateValue;
int8_t validHeartRate;

// Buffer for MQTT messages
char msgBuffer[50];

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
  
  // Draw logo centered
  int logoX = (128 - 32) / 2;
  int logoY = 8;
  display.drawBitmap(logoX, logoY, tempSenseLogo, 32, 32, SSD1306_WHITE);
  
  // Text below logo
  display.setTextSize(2);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(10, 45);
  display.println("TempSense");
  
  display.display();
  delay(2000);
  
  // Loading animation
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
// MQTT CALLBACK
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
    } else if (strcmp(message, "MANUAL") == 0) {
      autoMode = false;
      Serial.println("Switched to MANUAL mode");
    } else {
      int newSpeed = atoi(message);
      if (newSpeed >= 0 && newSpeed <= 100) {
        fanSpeed = newSpeed;
        autoMode = false;
        Serial.printf("Manual speed set to: %d%%\n", fanSpeed);
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

// ====================
// PUBLISH SENSOR DATA
// ====================
void publishSensorData() {
  if (!mqttClient.connected()) {
    return; // Skip publishing if not connected
  }
  
  snprintf(msgBuffer, sizeof(msgBuffer), "%.1f", temperature);
  mqttClient.publish(TOPIC_TEMP, msgBuffer);
  
  snprintf(msgBuffer, sizeof(msgBuffer), "%.1f", humidity);
  mqttClient.publish(TOPIC_HUMID, msgBuffer);
  
  snprintf(msgBuffer, sizeof(msgBuffer), "%d", heartRate);
  mqttClient.publish(TOPIC_HEARTRATE, msgBuffer);
  
  snprintf(msgBuffer, sizeof(msgBuffer), "%d", spo2);
  mqttClient.publish(TOPIC_SPO2, msgBuffer);
  
  snprintf(msgBuffer, sizeof(msgBuffer), "%d", fanSpeed);
  mqttClient.publish(TOPIC_FAN_SPEED, msgBuffer);
  
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

void readMAX30102() {
  if (!max30102Connected) {
    heartRate = 0;
    spo2 = 0;
    return;
  }
  
  long irValue = particleSensor.getIR();
  
  // Check if finger is detected (IR value > 50000 indicates finger presence)
  if (irValue < 50000) {
    heartRate = 0;
    spo2 = 0;
    return;
  }
  
  // Check for heartbeat
  if (checkForBeat(irValue) == true) {
    long delta = millis() - lastBeat;
    lastBeat = millis();
    
    beatsPerMinute = 60 / (delta / 1000.0);
    
    // Only accept reasonable heart rates (40-200 BPM)
    if (beatsPerMinute > 40 && beatsPerMinute < 200) {
      rates[rateSpot++] = (byte)beatsPerMinute;
      rateSpot %= RATE_SIZE;
      
      // Calculate average
      beatAvg = 0;
      for (byte x = 0; x < RATE_SIZE; x++) {
        beatAvg += rates[x];
      }
      beatAvg /= RATE_SIZE;
      
      heartRate = beatAvg;
    }
  }
  
  // Read SpO2 - simplified approach
  long redValue = particleSensor.getRed();
  
  if (irValue > 50000 && redValue > 50000) {
    // Basic SpO2 calculation (simplified)
    float ratio = (float)redValue / (float)irValue;
    
    // Empirical formula (approximate)
    if (ratio > 0.4 && ratio < 2.0) {
      spo2 = 110 - 25 * ratio;
      
      // Constrain to reasonable values
      if (spo2 < 70) spo2 = 70;
      if (spo2 > 100) spo2 = 100;
    }
  }
  
  Serial.printf("IR: %ld, Red: %ld, HR: %d, SpO2: %d\n", 
                irValue, redValue, heartRate, spo2);
}

// ====================
// FAN CONTROL
// ====================
void controlFan() {
  if (autoMode) {
    fanSpeed = mlModel.predict(temperature, humidity, heartRate, spo2);
  }
  
  // Constrain fan speed
  fanSpeed = constrain(fanSpeed, 0, 100);
  
  // Apply fan speed via PWM
  int pwmValue = map(fanSpeed, 0, 100, 0, 255);
  analogWrite(MOSFET_PIN, pwmValue);
}

// ====================
// OLED DISPLAY
// ====================
void updateDisplay() {
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  
  // Header
  display.setCursor(0, 0);
  display.print("TempSense Cooler");
  display.drawLine(0, 9, 128, 9, SSD1306_WHITE);
  
  // Connection Status
  display.setCursor(0, 12);
  display.print("WiFi:");
  display.setCursor(40, 12);
  display.print(WiFi.status() == WL_CONNECTED ? "OK" : "X");
  
  display.setCursor(70, 12);
  display.print("MQTT:");
  display.setCursor(105, 12);
  display.print(mqttClient.connected() ? "OK" : "X");
  
  // Sensor Data
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
  
  // Fan indicator
  display.setCursor(85, 54);
  display.printf("F:%d%%", fanSpeed);
  
  // Mode indicator
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
  
  // Initialize I2C
  Wire.begin(I2C_SDA, I2C_SCL);
  Serial.println("I2C initialized");
  
  // Initialize OLED
  if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println("OLED initialization failed!");
  } else {
    Serial.println("OLED initialized");
    showLogo();
  }
  
  // Initialize DHT22
  dht.begin();
  Serial.println("DHT22 initialized");
  
  display.clearDisplay();
  display.setTextSize(1);
  display.setCursor(0, 0);
  display.println("Initializing...");
  display.display();
  
  // Initialize MAX30102 with proper settings
  Serial.println("Initializing MAX30102...");
  if (particleSensor.begin(Wire, I2C_SPEED_STANDARD)) {
    Serial.println("MAX30102 found!");
    
    // Configure sensor with optimal settings
    byte ledBrightness = 0x1F; // Options: 0=Off to 255=50mA
    byte sampleAverage = 4;    // Options: 1, 2, 4, 8, 16, 32
    byte ledMode = 2;          // Options: 1=Red only, 2=Red+IR, 3=Red+IR+Green
    int sampleRate = 100;      // Options: 50, 100, 200, 400, 800, 1000, 1600, 3200
    int pulseWidth = 411;      // Options: 69, 118, 215, 411
    int adcRange = 4096;       // Options: 2048, 4096, 8192, 16384
    
    particleSensor.setup(ledBrightness, sampleAverage, ledMode, sampleRate, pulseWidth, adcRange);
    
    // Turn on Red LED to indicate sensor is active
    particleSensor.setPulseAmplitudeRed(0x0A);  // Turn Red LED to low to indicate sensor is running
    particleSensor.setPulseAmplitudeIR(0x1F);   // IR LED brightness
    
    max30102Connected = true;
    Serial.println("MAX30102 configured successfully");
    
    display.println("MAX30102: OK");
    display.display();
  } else {
    Serial.println("MAX30102 not found!");
    max30102Connected = false;
    
    display.println("MAX30102: FAILED");
    display.display();
  }
  
  delay(1000);
  
  // Setup PWM for fan
  pinMode(MOSFET_PIN, OUTPUT);
  analogWrite(MOSFET_PIN, 0);
  Serial.println("Fan controller initialized");
  
  // Initialize WiFi
  connectToWiFi();
  
  // Initialize MQTT
  mqttClient.setServer(MQTT_HOST, MQTT_PORT);
  mqttClient.setCallback(mqttCallback);
  mqttClient.setKeepAlive(60);
  mqttClient.setBufferSize(512);
  
  // Connect to MQTT
  connectToMqtt();
  
  // Initialize rate array
  for (byte x = 0; x < RATE_SIZE; x++) {
    rates[x] = 0;
  }
  
  Serial.println("Setup complete!");
  
  display.clearDisplay();
  display.setTextSize(1);
  display.setCursor(0, 0);
  display.println("System Ready!");
  display.display();
  delay(1000);
}

// ====================
// MAIN LOOP
// ====================
void loop() {
  // Maintain WiFi connection
  if (WiFi.status() != WL_CONNECTED) {
    connectToWiFi();
  }
  
  // Maintain MQTT connection
  if (!mqttClient.connected()) {
    connectToMqtt();
  }
  mqttClient.loop();
  
  // Read sensors at regular intervals
  if (millis() - lastSensorUpdate >= sensorInterval) {
    // Read environmental sensors
    readDHT22();
    
    // Read biometric sensor
    readMAX30102();
    
    // Control fan
    controlFan();
    
    // Publish data
    publishSensorData();
    
    // Update display
    updateDisplay();
    
    // Debug output
    Serial.printf("T:%.1f°C H:%.1f%% HR:%d SpO2:%d%% Fan:%d%% Mode:%s MAX30102:%s\n",
                  temperature, humidity, heartRate, spo2, fanSpeed, 
                  autoMode ? "AUTO" : "MANUAL",
                  max30102Connected ? "OK" : "DISCONNECTED");
    
    lastSensorUpdate = millis();
  }
  
  delay(50);  // Small delay to prevent watchdog issues
}