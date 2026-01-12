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
const long sensorInterval = 1000;  // Reduced from 2000 to 1000ms
bool max30102Connected = false;

// Heart rate detection - IMPROVED
const byte RATE_SIZE = 4;
byte rates[RATE_SIZE];
byte rateSpot = 0;
long lastBeat = 0;
float beatsPerMinute = 0;
int beatAvg = 0;

// NEW: Fast sampling for heart rate
unsigned long lastHeartRateSample = 0;
const long heartRateSampleInterval = 20; // Sample every 20ms for better beat detection

// SpO2 calculation variables - OPTIMIZED
#define SPO2_BUFFER_SIZE 50  // Increased for better accuracy
uint32_t irBuffer[SPO2_BUFFER_SIZE];
uint32_t redBuffer[SPO2_BUFFER_SIZE];
int bufferIndex = 0;
bool bufferFilled = false;
unsigned long lastSpO2Calc = 0;

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

// Calculate SpO2 from buffered data - FASTER
void calculateSpO2() {
  if (!bufferFilled) return;
  
  // Find max and min values
  uint32_t irMax = 0, irMin = 0xFFFFFFFF;
  uint32_t redMax = 0, redMin = 0xFFFFFFFF;
  
  for (int i = 0; i < SPO2_BUFFER_SIZE; i++) {
    if (irBuffer[i] > irMax) irMax = irBuffer[i];
    if (irBuffer[i] < irMin) irMin = irBuffer[i];
    if (redBuffer[i] > redMax) redMax = redBuffer[i];
    if (redBuffer[i] < redMin) redMin = redBuffer[i];
  }
  
  // Calculate AC and DC components
  float irAC = irMax - irMin;
  float irDC = (irMax + irMin) / 2.0;
  float redAC = redMax - redMin;
  float redDC = (redMax + redMin) / 2.0;
  
  // Avoid division by zero
  if (irAC < 100 || irDC < 100 || redDC < 100) {
    return;
  }
  
  // Calculate R value (ratio of ratios)
  float R = (redAC / redDC) / (irAC / irDC);
  
  // Convert R to SpO2 percentage using empirical formula
  if (R >= 0.4 && R <= 2.0) {
    // Standard empirical formula
    float calculatedSpO2 = 110.0 - 25.0 * R;
    
    // Constrain to realistic values
    spo2 = constrain((int)calculatedSpO2, 85, 100);
  }
}

// NEW: Continuous heart rate sampling
void sampleHeartRate() {
  if (!max30102Connected) {
    return;
  }
  
  long irValue = particleSensor.getIR();
  long redValue = particleSensor.getRed();
  
  // Check if finger is present (lowered threshold)
  if (irValue < 10000) {
    heartRate = 0;
    beatsPerMinute = 0;
    // Reset rate array
    for (byte x = 0; x < RATE_SIZE; x++) {
      rates[x] = 0;
    }
    rateSpot = 0;
    return;
  }
  
  // Store in SpO2 buffer
  irBuffer[bufferIndex] = irValue;
  redBuffer[bufferIndex] = redValue;
  bufferIndex++;
  
  if (bufferIndex >= SPO2_BUFFER_SIZE) {
    bufferIndex = 0;
    bufferFilled = true;
  }
  
  // Check for heartbeat using library function
  if (checkForBeat(irValue) == true) {
    // Calculate time between beats
    long delta = millis() - lastBeat;
    lastBeat = millis();
    
    // Calculate BPM
    beatsPerMinute = 60.0 / (delta / 1000.0);
    
    // Filter: only accept reasonable heart rates
    if (beatsPerMinute > 30 && beatsPerMinute < 220) {
      rates[rateSpot++] = (byte)beatsPerMinute;
      rateSpot %= RATE_SIZE;
      
      // Calculate running average
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
      
      Serial.printf("💓 BEAT! BPM: %.1f | Avg: %d | IR: %ld\n", beatsPerMinute, beatAvg, irValue);
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
  
  // Check finger presence
  if (irValue < 10000) {
    Serial.println("❌ No finger detected (IR < 10000)");
    return;
  }
  
  // Calculate SpO2 if buffer is filled
  if (bufferFilled && (millis() - lastSpO2Calc > 1000)) {
    calculateSpO2();
    lastSpO2Calc = millis();
    Serial.printf("SpO2: %d%% | HR: %d bpm | IR: %ld\n", spo2, heartRate, irValue);
  }
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
  Wire.setClock(400000);  // Set I2C to 400kHz for faster communication
  Serial.println("I2C initialized at 400kHz");
  
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
  
  // Initialize MAX30102 with OPTIMIZED settings for FAST response
  Serial.println("Initializing MAX30102...");
  if (particleSensor.begin(Wire, I2C_SPEED_FAST)) {
    Serial.println("MAX30102 found!");
    
    // OPTIMIZED SETTINGS for faster heart rate detection
    byte ledBrightness = 0x7F;  // High brightness (127/255)
    byte sampleAverage = 2;     // Average 2 samples for speed
    byte ledMode = 2;           // Red + IR mode
    byte sampleRate = 200;      // 200 samples per second
    int pulseWidth = 411;       // 411us pulse width
    int adcRange = 16384;       // 16-bit ADC range
    
    particleSensor.setup(ledBrightness, sampleAverage, ledMode, sampleRate, pulseWidth, adcRange);
    
    // Set LED amplitudes
    particleSensor.setPulseAmplitudeRed(0x0A);    // Low brightness for indicator
    particleSensor.setPulseAmplitudeIR(0x7F);     // High IR for better signal (127/255)
    particleSensor.setPulseAmplitudeGreen(0);     // Turn off green LED
    
    max30102Connected = true;
    Serial.println("✓ MAX30102 configured for FAST detection");
    Serial.println("✓ Sample Rate: 200 Hz");
    Serial.println("✓ Place finger firmly on sensor...");
    
    display.println("MAX30102: OK");
    display.println("Ready for finger");
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
  
  // Initialize all arrays
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
  display.println("");
  display.println("Place finger firmly");
  display.println("on sensor...");
  display.display();
  delay(2000);
}

// ====================
// MAIN LOOP
// ====================
void loop() {
  // PRIORITY 1: Fast heart rate sampling (every 20ms)
  if (millis() - lastHeartRateSample >= heartRateSampleInterval) {
    sampleHeartRate();
    lastHeartRateSample = millis();
  }
  
  // PRIORITY 2: Regular sensor updates (every 1 second)
  if (millis() - lastSensorUpdate >= sensorInterval) {
    // Read environmental sensors
    readDHT22();
    
    // Process MAX30102 data (SpO2 calculation)
    readMAX30102();
    
    // Control fan
    controlFan();
    
    // Publish data
    publishSensorData();
    
    // Update display
    updateDisplay();
    
    // Compact debug output
    Serial.printf("📊 T:%.1f°C | H:%.1f%% | HR:%d | SpO2:%d%% | Fan:%d%% | %s\n",
                  temperature, humidity, heartRate, spo2, fanSpeed, 
                  autoMode ? "AUTO" : "MANUAL");
    
    lastSensorUpdate = millis();
  }
  
  // PRIORITY 3: Network maintenance
  if (WiFi.status() != WL_CONNECTED) {
    connectToWiFi();
  }
  
  if (!mqttClient.connected()) {
    connectToMqtt();
  }
  mqttClient.loop();
  
  delay(10);  // Minimal delay for stability
}