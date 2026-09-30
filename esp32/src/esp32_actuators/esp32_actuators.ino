#include <Arduino.h>
#include <WiFi.h>
#include <WiFiManager.h>
#include <ArduinoMqttClient.h>
#include <ArduinoJson.h>
#include <Preferences.h>
#include <DHT.h>
#include <time.h>

// ============================================================
// SMART FARM ESP32 ACTUATORS & SENSORS FIRMWARE
// Phase 7: Relay Control, Command Subscription, and Fail-safe
// ============================================================

const char* FIRMWARE_VERSION = "0.3.0";
const char* CONFIG_NAMESPACE = "smartfarm";

const unsigned long HEARTBEAT_INTERVAL_MS = 30000;
const unsigned long SENSOR_READ_INTERVAL_MS = 10000;
const unsigned long MQTT_RECONNECT_MIN_MS = 3000;
const unsigned long MQTT_RECONNECT_MAX_MS = 60000;
const unsigned long BOOT_BUTTON_HOLD_MS = 3000;

const int BOOT_BUTTON_PIN = 0;

// --- Hardware Pins ---
const int SOIL_MOISTURE_PIN = 34; 
const int DHT_PIN = 4;           
const int DHT_TYPE = DHT11;
const int RELAY_PIN = 26;        // GPIO สำหรับควบคุม Relay (เช่น ปั๊มน้ำ)

DHT dht(DHT_PIN, DHT_TYPE);

// --- Soil Moisture Calibration ---
const int SOIL_DRY_RAW = 3100; 
const int SOIL_WET_RAW = 1350; 

// --- Actuator / Fail-safe State ---
bool relayState = false;          // false = OFF, true = ON
unsigned long relayTurnedOnAt = 0;
unsigned long maxRuntimeSeconds = 900; // ค่าเริ่มต้น 15 นาที (900 วินาที) ตามกฎความปลอดภัย

struct SmartFarmConfig {
  String farmId;
  String zoneId;
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

// Forward Declarations
void onMqttMessage(int messageSize);
void handleCommand(String topic, String payload);
bool publishActuatorState(const String& actuatorId, const String& state, bool retained);
bool publishCommandAck(const String& commandId, const String& actuatorId, const String& result, const String& state, const String& traceId);
void checkSafetyFailSafe();

void setup() {
  Serial.begin(115200);
  delay(500);

  Serial.println();
  Serial.println("==============================================");
  Serial.println("SMART FARM ESP32 ACTUATORS FIRMWARE");
  Serial.print("Firmware Version: ");
  Serial.println(FIRMWARE_VERSION);
  Serial.println("==============================================");

  // Initialize Hardware Pins
  pinMode(SOIL_MOISTURE_PIN, INPUT);
  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, HIGH); // สมมติว่าเป็น Active Low: HIGH = ปิด (OFF)
  
  dht.begin();

  // Load NVS Config
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

  // Check BOOT button for factory reset
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
      Serial.println("[CONFIG] Configuration cleared.");
      delay(1000);
      ESP.restart();
    }
  }

  bool forcePortal = (config.mqttHost.length() == 0);

  char farmIdBuf[32], zoneIdBuf[32], esp32IdBuf[48], mqttHostBuf[128], mqttPortBuf[8], mqttUserBuf[64], mqttPassBuf[128];
  config.farmId.toCharArray(farmIdBuf, sizeof(farmIdBuf));
  config.zoneId.toCharArray(zoneIdBuf, sizeof(zoneIdBuf));
  config.esp32Id.toCharArray(esp32IdBuf, sizeof(esp32IdBuf));
  config.mqttHost.toCharArray(mqttHostBuf, sizeof(mqttHostBuf));
  snprintf(mqttPortBuf, sizeof(mqttPortBuf), "%u", config.mqttPort);
  config.mqttUsername.toCharArray(mqttUserBuf, sizeof(mqttUserBuf));
  config.mqttPassword.toCharArray(mqttPassBuf, sizeof(mqttPassBuf));

  WiFiManagerParameter customHtml("<p><strong>Smart Farm Actuator Settings</strong></p>");
  WiFiManagerParameter pFarmId("farm_id", "Farm ID", farmIdBuf, sizeof(farmIdBuf));
  WiFiManagerParameter pZoneId("zone_id", "Zone ID", zoneIdBuf, sizeof(zoneIdBuf));
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

  String apName = "smartfarm-actuator-" + String((uint32_t)ESP.getEfuseMac(), HEX);
  bool connected = forcePortal ? wifiManager.startConfigPortal(apName.c_str()) : wifiManager.autoConnect(apName.c_str());

  if (!connected) {
    Serial.println("[WIFI] Connection failed. Restarting...");
    delay(3000);
    ESP.restart();
  }

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

  Serial.println("[WIFI] Connected. IP: " + WiFi.localIP().toString());
}

void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    WiFi.reconnect();
    delay(1000);
    return;
  }

  if (!ntpConfigured && config.ntpServer.length() > 0) {
    configTime(0, 0, config.ntpServer.c_str());
    ntpConfigured = true;
  }

  // MQTT Maintenance & Message Polling
  if (!mqttClient.connected()) {
    unsigned long now = millis();
    if (now - lastMqttConnectAttemptAt >= mqttReconnectDelayMs) {
      lastMqttConnectAttemptAt = now;
      
      String willTopic = "farm/" + config.farmId + "/esp32/" + config.esp32Id + "/status";
      String willPayload = "{\"farm_id\":\"" + config.farmId + "\",\"esp32_id\":\"" + config.esp32Id + "\",\"status\":\"offline\"}";
      
      mqttClient.setId(config.esp32Id.c_str());
      mqttClient.setUsernamePassword(config.mqttUsername.c_str(), config.mqttPassword.c_str());
      mqttClient.beginWill(willTopic.c_str(), willPayload.length(), true, 1);
      mqttClient.print(willPayload);
      mqttClient.endWill();

      if (mqttClient.connect(config.mqttHost.c_str(), config.mqttPort)) {
        mqttReconnectDelayMs = MQTT_RECONNECT_MIN_MS;
        // Subscribe to Zone Commands
        String cmdTopic = "farm/" + config.farmId + "/zone/" + config.zoneId + "/actuator/+/command";
        mqttClient.subscribe(cmdTopic.c_str(), 1);
        mqttClient.onMessage(onMqttMessage);
        
        // Publish Online Status & Initial State
        // สมมติชื่อ Actuator หลักคือ irrigation_pump_001
        publishActuatorState("irrigation_pump_001", relayState ? "on" : "off", true);
      } else {
        mqttReconnectDelayMs = min(mqttReconnectDelayMs * 2, MQTT_RECONNECT_MAX_MS);
      }
    }
  } else {
    mqttClient.poll();
  }

  // Heartbeat
  if (mqttClient.connected() && millis() - lastHeartbeatAt >= HEARTBEAT_INTERVAL_MS) {
    lastHeartbeatAt = millis();
    StaticJsonDocument<256> doc;
    doc["farm_id"] = config.farmId;
    doc["esp32_id"] = config.esp32Id;
    doc["status"] = "online";
    doc["reason"] = "heartbeat";
    String statusTopic = "farm/" + config.farmId + "/esp32/" + config.esp32Id + "/status";
    size_t len = measureJson(doc);
    if (mqttClient.beginMessage(statusTopic.c_str(), len, true, 1)) {
      serializeJson(doc, mqttClient);
      mqttClient.endMessage();
    }
  }

  // Hardware Safety Fail-safe Check
  checkSafetyFailSafe();

  delay(50);
}

// --- MQTT Command Listener ---
void onMqttMessage(int messageSize) {
  String topic = mqttClient.messageTopic();
  String payload = "";
  while (mqttClient.available()) {
    payload += (char)mqttClient.read();
  }
  Serial.println("[MQTT] Received command on topic: " + topic);
  handleCommand(topic, payload);
}

void handleCommand(String topic, String payload) {
  StaticJsonDocument<512> doc;
  DeserializationError error = deserializeJson(doc, payload);
  if (error) {
    Serial.println("[ERROR] Failed to parse command JSON");
    return;
  }

  String commandId = doc["command_id"] | "";
  String action = doc["action"] | "";
  String traceId = doc["trace_id"] | "";
  unsigned long requestedMaxRuntime = doc["max_runtime_seconds"] | 900;

  // ดึง actuator_id จาก Topic หรือ JSON
  // ตัวอย่าง Topic: farm/farm_001/zone/zone_01/actuator/irrigation_pump_001/command
  int lastSlash = topic.lastIndexOf('/');
  int secondLastSlash = topic.lastIndexOf('/', lastSlash - 1);
  String actuatorId = topic.substring(secondLastSlash + 1, lastSlash);

  if (action == "on" || action == "open") {
    relayState = true;
    digitalWrite(RELAY_PIN, LOW); // Active Low เปิด Relay
    relayTurnedOnAt = millis();
    maxRuntimeSeconds = requestedMaxRuntime;
    Serial.println("[ACTUATOR] " + actuatorId + " turned ON. Max runtime: " + String(maxRuntimeSeconds) + "s");
  } else if (action == "off" || action == "close") {
    relayState = false;
    digitalWrite(RELAY_PIN, HIGH); // ปิด Relay
    Serial.println("[ACTUATOR] " + actuatorId + " turned OFF.");
  }

  // Publish State and ACK
  publishActuatorState(actuatorId, relayState ? "on" : "off", true);
  if (commandId.length() > 0) {
    publishCommandAck(commandId, actuatorId, "executed", relayState ? "on" : "off", traceId);
  }
}

// --- Safety Fail-safe Watchdog ---
void checkSafetyFailSafe() {
  if (relayState) {
    unsigned long elapsedSeconds = (millis() - relayTurnedOnAt) / 1000;
    if (elapsedSeconds >= maxRuntimeSeconds) {
      Serial.println("[SAFETY] Maximum runtime exceeded (" + String(elapsedSeconds) + "s). Triggering Fail-safe: Turning OFF relay!");
      relayState = false;
      digitalWrite(RELAY_PIN, HIGH); // บังคับปิด
      publishActuatorState("irrigation_pump_001", "off", true);
    }
  }
}

// --- MQTT Publisher Helpers ---
bool publishActuatorState(const String& actuatorId, const String& state, bool retained) {
  if (!mqttClient.connected()) return false;
  StaticJsonDocument<256> doc;
  doc["actuator_id"] = actuatorId;
  doc["actual_state"] = state;
  doc["device_health"] = "online";
  doc["updated_at"] = time(nullptr) > 1704067200 ? String(time(nullptr)) : "ok";

  String stateTopic = "farm/" + config.farmId + "/zone/" + config.zoneId + "/actuator/" + actuatorId + "/state";
  size_t len = measureJson(doc);
  if (mqttClient.beginMessage(stateTopic.c_str(), len, retained, 1)) {
    serializeJson(doc, mqttClient);
    return mqttClient.endMessage();
  }
  return false;
}

bool publishCommandAck(const String& commandId, const String& actuatorId, const String& result, const String& state, const String& traceId) {
  if (!mqttClient.connected()) return false;
  StaticJsonDocument<256> doc;
  doc["command_id"] = commandId;
  doc["actuator_id"] = actuatorId;
  doc["result"] = result;
  doc["actual_state"] = state;
  doc["trace_id"] = traceId;

  String ackTopic = "farm/" + config.farmId + "/zone/" + config.zoneId + "/actuator/" + actuatorId + "/ack";
  size_t len = measureJson(doc); // แก้ไข type typo เล็กน้อยเป็น size_t
  if (mqttClient.beginMessage(ackTopic.c_str(), len, false, 1)) { 
    serializeJson(doc, mqttClient);
    return mqttClient.endMessage();
  }
  return false;
}