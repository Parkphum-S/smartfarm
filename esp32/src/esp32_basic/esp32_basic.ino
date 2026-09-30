#include <Arduino.h>
#include <WiFi.h>
#include <WiFiManager.h>
#include <ArduinoMqttClient.h>
#include <ArduinoJson.h>
#include <Preferences.h>
#include <DHT.h>
#include <time.h>

// ============================================================
// SMART FARM ESP32 SENSORS FIRMWARE
// Phase 6: Capacitive Soil Moisture v1.2 & DHT11 Telemetry
// ============================================================

const char* FIRMWARE_VERSION = "0.2.0";
const char* CONFIG_NAMESPACE = "smartfarm";

const unsigned long HEARTBEAT_INTERVAL_MS = 30000;
const unsigned long SENSOR_READ_INTERVAL_MS = 10000; // อ่านค่าทุก 10 วินาทีเพื่อการทดสอบ
const unsigned long MQTT_RECONNECT_MIN_MS = 3000;
const unsigned long MQTT_RECONNECT_MAX_MS = 60000;
const unsigned long BOOT_BUTTON_HOLD_MS = 3000;

const int BOOT_BUTTON_PIN = 0;

// --- Sensor Hardware Pins ---
const int SOIL_MOISTURE_PIN = 34; // ADC1_CH6 (Input Only)
const int DHT_PIN = 4;           // Digital GPIO for DHT11
const int DHT_TYPE = DHT11;

DHT dht(DHT_PIN, DHT_TYPE);

// --- Soil Moisture Calibration Constants ---
// ค่าดิบ (Raw ADC 0-4095) ของดินแห้งสนิทและดินเปียกชุ่มน้ำ (ต้องปรับจูนตามหน้างานจริง)
const int SOIL_DRY_RAW = 3100; 
const int SOIL_WET_RAW = 1350; 

struct SmartFarmConfig {
  String farmId;
  String zoneId;     // Zone หลัก (เช่น zone_01)
  String esp32Id;
  String mqttHost;
  uint16_t mqttPort;
  String mqttUsername;
  String mqttPassword;
  String ntpServer;
};

SmartFarmConfig config;

Preferences preferences;
WiFiManager wifiManager;
WiFiClient wifiClient;
MqttClient mqttClient(wifiClient);

bool shouldSaveConfig = false;
bool ntpConfigured = false;

unsigned long lastHeartbeatAt = 0;
unsigned long lastSensorReadAt = 0;
unsigned long lastMqttConnectAttemptAt = 0;
unsigned long mqttReconnectDelayMs = MQTT_RECONNECT_MIN_MS;

// Forward declarations
void copyStringToBuffer(const String& value, char* buffer, size_t bufferSize);
String getChipIdSuffix();
String getStatusTopic();
String getSensorReadingTopic(const String& zoneId, const String& sensorId);
bool hasRequiredMqttConfiguration();
String getUtcTimestampOrEmpty();
bool publishJson(const String& topic, JsonDocument& document, bool retained, int qos);
bool publishDeviceStatus(const char* status, const char* reason, bool retained);
bool connectToMqtt();
void maintainMqttConnection();
void publishHeartbeatIfDue();
void maintainWiFiConnection();
void readAndPublishSensors();

void setup() {
  Serial.begin(115200);
  delay(500);

  Serial.println();
  Serial.println("==============================================");
  Serial.println("SMART FARM ESP32 SENSORS FIRMWARE");
  Serial.print("Firmware Version: ");
  Serial.println(FIRMWARE_VERSION);
  Serial.println("==============================================");

  // Initialize Sensors
  pinMode(SOIL_MOISTURE_PIN, INPUT);
  dht.begin();

  // Load configuration from NVS
  preferences.begin(CONFIG_NAMESPACE, true);
  config.farmId = preferences.getString("farm_id", "farm_001");
  config.zoneId = preferences.getString("zone_id", "zone_01");
  config.esp32Id = preferences.getString("esp32_id", "esp32_001");
  config.mqttHost = preferences.getString("mqtt_host", "");
  config.mqttPort = preferences.getUShort("mqtt_port", 1883);
  config.mqttUsername = preferences.getString("mqtt_user", "esp32_001");
  config.mqttPassword = preferences.getString("mqtt_pass", "");
  config.ntpServer = preferences.getString("ntp_server", "pool.ntp.org");
  preferences.end();

  // Check boot button for config reset
  pinMode(BOOT_BUTTON_PIN, INPUT_PULLUP);
  if (digitalRead(BOOT_BUTTON_PIN) == LOW) {
    unsigned long pressedAt = millis();
    bool resetTriggered = false;
    while (digitalRead(BOOT_BUTTON_PIN) == LOW) {
      if (millis() - pressedAt >= BOOT_BUTTON_HOLD_MS) {
        resetTriggered = true;
        break;
      }
      delay(50);
    }
    if (resetTriggered) {
      preferences.begin(CONFIG_NAMESPACE, false);
      preferences.clear();
      preferences.end();
      wifiManager.resetSettings();
      Serial.println("[CONFIG] Configuration cleared via BOOT button.");
      delay(1000);
      ESP.restart();
    }
  }

  bool forcePortal = (config.mqttHost.length() == 0);

  // Setup WiFiManager parameters
  char farmIdBuf[32], zoneIdBuf[32], esp32IdBuf[48], mqttHostBuf[128], mqttPortBuf[8], mqttUserBuf[64], mqttPassBuf[128];
  config.farmId.toCharArray(farmIdBuf, sizeof(farmIdBuf));
  config.zoneId.toCharArray(zoneIdBuf, sizeof(zoneIdBuf));
  config.esp32Id.toCharArray(esp32IdBuf, sizeof(esp32IdBuf));
  config.mqttHost.toCharArray(mqttHostBuf, sizeof(mqttHostBuf));
  snprintf(mqttPortBuf, sizeof(mqttPortBuf), "%u", config.mqttPort);
  config.mqttUsername.toCharArray(mqttUserBuf, sizeof(mqttUserBuf));
  config.mqttPassword.toCharArray(mqttPassBuf, sizeof(mqttPassBuf));

  WiFiManagerParameter customHtml("<p><strong>Smart Farm Sensor Settings</strong></p>");
  WiFiManagerParameter pFarmId("farm_id", "Farm ID", farmIdBuf, sizeof(farmIdBuf));
  WiFiManagerParameter pZoneId("zone_id", "Zone ID (Default)", zoneIdBuf, sizeof(zoneIdBuf));
  WiFiManagerParameter pEsp32Id("esp32_id", "ESP32 ID", esp32IdBuf, sizeof(esp32IdBuf));
  WiFiManagerParameter pMqttHost("mqtt_host", "MQTT Host / IP", mqttHostBuf, sizeof(mqttHostBuf));
  WiFiManagerParameter pMqttPort("mqtt_port", "MQTT Port", mqttPortBuf, sizeof(mqttPortBuf));
  WiFiManagerParameter pMqttUser("mqtt_user", "MQTT Username", mqttUserBuf, sizeof(mqttUserBuf));
  WiFiManagerParameter pMqttPass("mqtt_pass", "MQTT Password", mqttPassBuf, sizeof(mqttPassBuf));

  wifiManager.addParameter(&customHtml);
  wifiManager.addParameter(&pFarmId);
  wifiManager.addParameter(&pZoneId);
  wifiManager.addParameter(&pEsp32Id);
  wifiManager.addParameter(&pMqttHost);
  wifiManager.addParameter(&pMqttPort);
  wifiManager.addParameter(&pMqttUser);
  wifiManager.addParameter(&pMqttPass);

  String apName = "smartfarm-sensor-" + getChipIdSuffix();
  bool connected = false;
  if (forcePortal) {
    connected = wifiManager.startConfigPortal(apName.c_str());
  } else {
    connected = wifiManager.autoConnect(apName.c_str());
  }

  if (!connected) {
    Serial.println("[WIFI] Failed to connect or portal timeout. Restarting...");
    delay(3000);
    ESP.restart();
  }

  // Save parameters if updated
  config.farmId = pFarmId.getValue();
  config.zoneId = pZoneId.getValue();
  config.esp32Id = pEsp32Id.getValue();
  config.mqttHost = pMqttHost.getValue();
  config.mqttPort = String(pMqttPort.getValue()).toInt();
  config.mqttUsername = pMqttUser.getValue();
  config.mqttPassword = pMqttPass.getValue();

  preferences.begin(CONFIG_NAMESPACE, false);
  preferences.putString("farm_id", config.farmId);
  preferences.putString("zone_id", config.zoneId);
  preferences.putString("esp32_id", config.esp32Id);
  preferences.putString("mqtt_host", config.mqttHost);
  preferences.putUShort("mqtt_port", config.mqttPort);
  preferences.putString("mqtt_user", config.mqttUsername);
  preferences.putString("mqtt_pass", config.mqttPassword);
  preferences.end();

  Serial.println("[WIFI] Connected successfully.");
  Serial.print("[WIFI] IP Address: ");
  Serial.println(WiFi.localIP());
}

void loop() {
  maintainWiFiConnection();

  if (WiFi.status() == WL_CONNECTED) {
    // Configure NTP once connected
    if (!ntpConfigured && config.ntpServer.length() > 0) {
      configTime(0, 0, config.ntpServer.c_str());
      ntpConfigured = true;
    }

    maintainMqttConnection();
    publishHeartbeatIfDue();
    readAndPublishSensors();
  }

  delay(50);
}

// --- Sensor Reading & Publishing Logic ---
void readAndPublishSensors() {
  if (!mqttClient.connected()) {
    return;
  }

  unsigned long now = millis();
  if (now - lastSensorReadAt < SENSOR_READ_INTERVAL_MS) {
    return;
  }
  lastSensorReadAt = now;

  String timestamp = getUtcTimestampOrEmpty();

  // 1. Read Soil Moisture (Zone 01 / custom zone)
  int rawSoil = 0;
  // ทำ Moving Average อ่าน 5 ครั้งเพื่อกรอง Noise
  for (int i = 0; i < 5; i++) {
    rawSoil += analogRead(SOIL_MOISTURE_PIN);
    delay(10);
  }
  rawSoil /= 5;

  // คำนวณกลับด้านเพราะ Capacitive Sensor ค่ายิ่งน้อยยิ่งเปียก ยิ่งมากยิ่งแห้ง
  float soilMoisturePercent = map(rawSoil, SOIL_DRY_RAW, SOIL_WET_RAW, 0, 100);
  soilMoisturePercent = constrain(soilMoisturePercent, 0.0, 100.0);

  StaticJsonDocument<512> soilDoc;
  soilDoc["message_id"] = "soil-" + String(millis());
  soilDoc["farm_id"] = config.farmId;
  soilDoc["esp32_id"] = config.esp32Id;
  soilDoc["zone_id"] = config.zoneId; // หรือกำหนดแยก Zone ตามต้องการ
  soilDoc["sensor_id"] = "soil_moisture_001";
  soilDoc["sensor_type"] = "soil_moisture";
  soilDoc["value"] = serialized(String(soilMoisturePercent, 1));
  soilDoc["unit"] = "%";
  soilDoc["raw_value"] = rawSoil;
  soilDoc["quality"] = "valid";
  soilDoc["status"] = "ok";
  if (timestamp.length() > 0) soilDoc["timestamp"] = timestamp;

  String soilTopic = getSensorReadingTopic(config.zoneId, "soil_moisture_001");
  publishJson(soilTopic, soilDoc, false, 1);
  Serial.println("[SENSOR] Published Soil Moisture: " + String(soilMoisturePercent) + "% (Raw: " + String(rawSoil) + ")");


  // 2. Read DHT11 Temperature (Zone 03 / or config zone)
  float temperature = dht.readTemperature(); // Celsius
  float humidity = dht.readHumidity();

  if (isnan(temperature) || isnan(humidity)) {
    Serial.println("[SENSOR] Error: Failed to read from DHT sensor!");
  } else {
    // Publish Temperature
    StaticJsonDocument<512> tempDoc;
    tempDoc["message_id"] = "temp-" + String(millis());
    tempDoc["farm_id"] = config.farmId;
    tempDoc["esp32_id"] = config.esp32Id;
    tempDoc["zone_id"] = "zone_03"; // ตามสเปกผู้ใช้ Temperature อยู่ Zone 03
    tempDoc["sensor_id"] = "temperature_001";
    tempDoc["sensor_type"] = "air_temperature";
    tempDoc["value"] = serialized(String(temperature, 1));
    tempDoc["unit"] = "°C";
    tempDoc["quality"] = "valid";
    tempDoc["status"] = "ok";
    if (timestamp.length() > 0) tempDoc["timestamp"] = timestamp;

    String tempTopic = getSensorReadingTopic("zone_03", "temperature_001");
    publishJson(tempTopic, tempDoc, false, 1);
    Serial.println("[SENSOR] Published Temperature: " + String(temperature) + " °C");

    // Publish Humidity เสริมจาก DHT11 ตัวเดียวกัน
    StaticJsonDocument<512> humDoc;
    humDoc["message_id"] = "hum-" + String(millis());
    humDoc["farm_id"] = config.farmId;
    humDoc["esp32_id"] = config.esp32Id;
    humDoc["zone_id"] = "zone_03";
    humDoc["sensor_id"] = "humidity_001";
    humDoc["sensor_type"] = "air_humidity";
    humDoc["value"] = serialized(String(humidity, 1));
    humDoc["unit"] = "%";
    humDoc["quality"] = "valid";
    humDoc["status"] = "ok";
    if (timestamp.length() > 0) humDoc["timestamp"] = timestamp;

    String humTopic = getSensorReadingTopic("zone_03", "humidity_001");
    publishJson(humTopic, humDoc, false, 1);
    Serial.println("[SENSOR] Published Humidity: " + String(humidity) + " %");
  }
}

// --- Helper Functions ---
String getChipIdSuffix() {
  uint64_t chipId = ESP.getEfuseMac();
  char suffix[7];
  snprintf(suffix, sizeof(suffix), "%06llX", (unsigned long long)(chipId & 0xFFFFFF));
  return String(suffix);
}

String getStatusTopic() {
  return "farm/" + config.farmId + "/esp32/" + config.esp32Id + "/status";
}

String getSensorReadingTopic(const String& zoneId, const String& sensorId) {
  return "farm/" + config.farmId + "/zone/" + zoneId + "/sensor/" + sensorId + "/reading";
}

bool hasRequiredMqttConfiguration() {
  return config.farmId.length() > 0 && config.mqttHost.length() > 0 && config.mqttUsername.length() > 0;
}

String getUtcTimestampOrEmpty() {
  time_t now = time(nullptr);
  if (now < 1704067200) return "";
  struct tm utcTime;
  gmtime_r(&now, &utcTime);
  char buf[30];
  strftime(buf, sizeof(buf), "%Y-%m-%dT%H:%M:%SZ", &utcTime);
  return String(buf);
}

bool publishJson(const String& topic, JsonDocument& doc, bool retained, int qos) {
  if (!mqttClient.connected()) return false;
  size_t len = measureJson(doc);
  if (!mqttClient.beginMessage(topic.c_str(), len, retained, qos)) return false;
  serializeJson(doc, mqttClient);
  return mqttClient.endMessage();
}

bool publishDeviceStatus(const char* status, const char* reason, bool retained) {
  StaticJsonDocument<512> doc;
  doc["farm_id"] = config.farmId;
  doc["esp32_id"] = config.esp32Id;
  doc["status"] = status;
  doc["reason"] = reason;
  doc["firmware_version"] = FIRMWARE_VERSION;
  doc["rssi"] = WiFi.RSSI();
  doc["uptime_seconds"] = millis() / 1000;
  return publishJson(getStatusTopic(), doc, retained, 1);
}

bool connectToMqtt() {
  if (WiFi.status() != WL_CONNECTED || !hasRequiredMqttConfiguration()) return false;
  
  String willTopic = getStatusTopic();
  String willPayload = "{\"farm_id\":\"" + config.farmId + "\",\"esp32_id\":\"" + config.esp32Id + "\",\"status\":\"offline\"}";

  mqttClient.setId(config.esp32Id.c_str());
  mqttClient.setUsernamePassword(config.mqttUsername.c_str(), config.mqttPassword.c_str());
  mqttClient.beginWill(willTopic.c_str(), willPayload.length(), true, 1);
  mqttClient.print(willPayload);
  mqttClient.endWill();

  if (!mqttClient.connect(config.mqttHost.c_str(), config.mqttPort)) {
    return false;
  }
  
  mqttReconnectDelayMs = MQTT_RECONNECT_MIN_MS;
  publishDeviceStatus("online", "mqtt_connected", true);
  return true;
}

void maintainMqttConnection() {
  if (mqttClient.connected()) {
    mqttClient.poll();
    return;
  }
  unsigned long now = millis();
  if (now - lastMqttConnectAttemptAt < mqttReconnectDelayMs) return;
  lastMqttConnectAttemptAt = now;
  if (!connectToMqtt()) {
    mqttReconnectDelayMs = min(mqttReconnectDelayMs * 2, MQTT_RECONNECT_MAX_MS);
  }
}

void publishHeartbeatIfDue() {
  if (!mqttClient.connected()) return;
  unsigned long now = millis();
  if (now - lastHeartbeatAt < HEARTBEAT_INTERVAL_MS) return;
  lastHeartbeatAt = now;
  publishDeviceStatus("online", "heartbeat", true);
}

void maintainWiFiConnection() {
  if (WiFi.status() == WL_CONNECTED) return;
  WiFi.reconnect();
}