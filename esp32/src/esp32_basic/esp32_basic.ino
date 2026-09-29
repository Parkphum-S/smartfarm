#include <Arduino.h>
#include <WiFi.h>
#include <WiFiManager.h>
#include <ArduinoMqttClient.h>
#include <ArduinoJson.h>
#include <Preferences.h>
#include <time.h>

// ============================================================
// SMART FARM ESP32 BASIC FIRMWARE
// Phase 5: Wi-Fi Provisioning, MQTT, Heartbeat, and LWT
//
// Important:
// - No Wi-Fi credential, MQTT host, MQTT IP, or MQTT password
//   is hard-coded in this firmware.
// - Runtime configuration is provisioned through WiFiManager.
// - Configuration is stored in ESP32 NVS using Preferences.
// ============================================================

// -------------------- Firmware Identity ---------------------

const char* FIRMWARE_VERSION = "0.1.0";
const char* CONFIG_NAMESPACE = "smartfarm";

const unsigned long HEARTBEAT_INTERVAL_MS = 30000;
const unsigned long MQTT_RECONNECT_MIN_MS = 3000;
const unsigned long MQTT_RECONNECT_MAX_MS = 60000;
const unsigned long BOOT_BUTTON_HOLD_MS = 3000;

const int BOOT_BUTTON_PIN = 0;

// -------------------- Runtime Configuration -----------------

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
unsigned long lastMqttConnectAttemptAt = 0;
unsigned long mqttReconnectDelayMs = MQTT_RECONNECT_MIN_MS;

// -------------------- Utility Functions ---------------------

void copyStringToBuffer(const String& value, char* buffer, size_t bufferSize) {
  value.toCharArray(buffer, bufferSize);
}

String getChipIdSuffix() {
  uint64_t chipId = ESP.getEfuseMac();
  char suffix[7];

  snprintf(
    suffix,
    sizeof(suffix),
    "%06llX",
    static_cast<unsigned long long>(chipId & 0xFFFFFF)
  );

  return String(suffix);
}

String createDefaultAccessPointName() {
  return "smartfarm-setup-" + getChipIdSuffix();
}

String createDefaultHostname() {
  return "smartfarm-" + getChipIdSuffix();
}

String getStatusTopic() {
  return "farm/" + config.farmId +
         "/esp32/" + config.esp32Id +
         "/status";
}

String getTelemetryTopic() {
  return "farm/" + config.farmId +
         "/esp32/" + config.esp32Id +
         "/telemetry";
}

bool hasRequiredMqttConfiguration() {
  return config.farmId.length() > 0 &&
         config.zoneId.length() > 0 &&
         config.esp32Id.length() > 0 &&
         config.mqttHost.length() > 0 &&
         config.mqttPort > 0 &&
         config.mqttUsername.length() > 0 &&
         config.mqttPassword.length() > 0;
}

String getUtcTimestampOrEmpty() {
  time_t now = time(nullptr);

  // Unix timestamp 1704067200 = 2024-01-01T00:00:00Z
  // If NTP is unavailable, return an empty string.
  if (now < 1704067200) {
    return "";
  }

  struct tm utcTime;
  gmtime_r(&now, &utcTime);

  char timestamp[30];
  strftime(timestamp, sizeof(timestamp), "%Y-%m-%dT%H:%M:%SZ", &utcTime);

  return String(timestamp);
}

// -------------------- Preferences / NVS ---------------------

void loadConfiguration() {
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
}

void saveConfiguration() {
  preferences.begin(CONFIG_NAMESPACE, false);

  preferences.putString("farm_id", config.farmId);
  preferences.putString("zone_id", config.zoneId);
  preferences.putString("esp32_id", config.esp32Id);
  preferences.putString("mqtt_host", config.mqttHost);
  preferences.putUShort("mqtt_port", config.mqttPort);
  preferences.putString("mqtt_user", config.mqttUsername);
  preferences.putString("mqtt_pass", config.mqttPassword);
  preferences.putString("ntp_server", config.ntpServer);

  preferences.end();
}

void clearConfiguration() {
  preferences.begin(CONFIG_NAMESPACE, false);
  preferences.clear();
  preferences.end();

  wifiManager.resetSettings();

  Serial.println("[CONFIG] Wi-Fi and Smart Farm configuration cleared.");
}

// -------------------- WiFiManager ---------------------------

void onConfigSaveRequested() {
  shouldSaveConfig = true;
  Serial.println("[CONFIG] WiFiManager requested configuration save.");
}

bool isBootButtonHeld() {
  pinMode(BOOT_BUTTON_PIN, INPUT_PULLUP);

  if (digitalRead(BOOT_BUTTON_PIN) != LOW) {
    return false;
  }

  Serial.println("[CONFIG] BOOT button detected. Hold for 3 seconds to reset.");

  unsigned long pressedAt = millis();

  while (digitalRead(BOOT_BUTTON_PIN) == LOW) {
    if (millis() - pressedAt >= BOOT_BUTTON_HOLD_MS) {
      return true;
    }

    delay(50);
  }

  return false;
}

bool startProvisioningPortal(bool forcePortal) {
  char farmIdBuffer[32];
  char zoneIdBuffer[32];
  char esp32IdBuffer[48];
  char mqttHostBuffer[128];
  char mqttPortBuffer[8];
  char mqttUsernameBuffer[64];
  char mqttPasswordBuffer[128];
  char ntpServerBuffer[128];

  copyStringToBuffer(config.farmId, farmIdBuffer, sizeof(farmIdBuffer));
  copyStringToBuffer(config.zoneId, zoneIdBuffer, sizeof(zoneIdBuffer));
  copyStringToBuffer(config.esp32Id, esp32IdBuffer, sizeof(esp32IdBuffer));
  copyStringToBuffer(config.mqttHost, mqttHostBuffer, sizeof(mqttHostBuffer));

  snprintf(
    mqttPortBuffer,
    sizeof(mqttPortBuffer),
    "%u",
    config.mqttPort
  );

  copyStringToBuffer(
    config.mqttUsername,
    mqttUsernameBuffer,
    sizeof(mqttUsernameBuffer)
  );

  copyStringToBuffer(
    config.mqttPassword,
    mqttPasswordBuffer,
    sizeof(mqttPasswordBuffer)
  );

  copyStringToBuffer(
    config.ntpServer,
    ntpServerBuffer,
    sizeof(ntpServerBuffer)
  );

  WiFiManagerParameter customHtml(
    "<p><strong>SMART FARM ESP32 Provisioning</strong></p>"
    "<p>Configure Wi-Fi and MQTT settings. Do not use production secrets on an untrusted network.</p>"
  );

  WiFiManagerParameter farmIdParameter(
    "farm_id",
    "Farm ID",
    farmIdBuffer,
    sizeof(farmIdBuffer)
  );

  WiFiManagerParameter zoneIdParameter(
    "zone_id",
    "Zone ID",
    zoneIdBuffer,
    sizeof(zoneIdBuffer)
  );

  WiFiManagerParameter esp32IdParameter(
    "esp32_id",
    "ESP32 ID",
    esp32IdBuffer,
    sizeof(esp32IdBuffer)
  );

  WiFiManagerParameter mqttHostParameter(
    "mqtt_host",
    "MQTT Hostname or IP",
    mqttHostBuffer,
    sizeof(mqttHostBuffer)
  );

  WiFiManagerParameter mqttPortParameter(
    "mqtt_port",
    "MQTT Port",
    mqttPortBuffer,
    sizeof(mqttPortBuffer)
  );

  WiFiManagerParameter mqttUsernameParameter(
    "mqtt_user",
    "MQTT Username",
    mqttUsernameBuffer,
    sizeof(mqttUsernameBuffer)
  );

  WiFiManagerParameter mqttPasswordParameter(
    "mqtt_pass",
    "MQTT Password",
    mqttPasswordBuffer,
    sizeof(mqttPasswordBuffer)
  );

  WiFiManagerParameter ntpServerParameter(
    "ntp_server",
    "NTP Server (optional)",
    ntpServerBuffer,
    sizeof(ntpServerBuffer)
  );

  wifiManager.setSaveConfigCallback(onConfigSaveRequested);
  wifiManager.setConfigPortalTimeout(300);
  wifiManager.setConnectTimeout(30);
  wifiManager.setHostname(createDefaultHostname().c_str());

  wifiManager.addParameter(&customHtml);
  wifiManager.addParameter(&farmIdParameter);
  wifiManager.addParameter(&zoneIdParameter);
  wifiManager.addParameter(&esp32IdParameter);
  wifiManager.addParameter(&mqttHostParameter);
  wifiManager.addParameter(&mqttPortParameter);
  wifiManager.addParameter(&mqttUsernameParameter);
  wifiManager.addParameter(&mqttPasswordParameter);
  wifiManager.addParameter(&ntpServerParameter);

  String accessPointName = createDefaultAccessPointName();

  bool connected = false;

  if (forcePortal) {
    Serial.println("[WIFI] Starting forced provisioning portal.");
    connected = wifiManager.startConfigPortal(accessPointName.c_str());
  } else {
    Serial.println("[WIFI] Connecting using saved Wi-Fi settings.");
    connected = wifiManager.autoConnect(accessPointName.c_str());
  }

  if (!connected) {
    Serial.println("[WIFI] Wi-Fi connection or provisioning timed out.");
    return false;
  }

  config.farmId = farmIdParameter.getValue();
  config.zoneId = zoneIdParameter.getValue();
  config.esp32Id = esp32IdParameter.getValue();
  config.mqttHost = mqttHostParameter.getValue();
  config.mqttPort = static_cast<uint16_t>(
    String(mqttPortParameter.getValue()).toInt()
  );
  config.mqttUsername = mqttUsernameParameter.getValue();
  config.mqttPassword = mqttPasswordParameter.getValue();
  config.ntpServer = ntpServerParameter.getValue();

  if (shouldSaveConfig || !hasRequiredMqttConfiguration()) {
    saveConfiguration();
    shouldSaveConfig = false;
    Serial.println("[CONFIG] Smart Farm configuration saved to NVS.");
  }

  return true;
}

// -------------------- Time ----------------------------------

void configureNtpIfAvailable() {
  if (ntpConfigured || WiFi.status() != WL_CONNECTED) {
    return;
  }

  if (config.ntpServer.length() == 0) {
    Serial.println("[TIME] NTP server is not configured. Timestamp will be unavailable.");
    return;
  }

  configTime(0, 0, config.ntpServer.c_str());
  ntpConfigured = true;

  Serial.print("[TIME] NTP configured using server: ");
  Serial.println(config.ntpServer);
}

// -------------------- MQTT ----------------------------------

bool publishJson(
  const String& topic,
  JsonDocument& document,
  bool retained,
  int qos
) {
  if (!mqttClient.connected()) {
    return false;
  }

  size_t payloadLength = measureJson(document);

  if (!mqttClient.beginMessage(
        topic.c_str(),
        payloadLength,
        retained,
        qos
      )) {
    Serial.println("[MQTT] Failed to begin MQTT message.");
    return false;
  }

  serializeJson(document, mqttClient);

  if (!mqttClient.endMessage()) {
    Serial.print("[MQTT] Failed to publish message. Error code: ");
    Serial.println(mqttClient.connectError());
    return false;
  }

  return true;
}

bool publishDeviceStatus(
  const char* status,
  const char* reason,
  bool retained
) {
  StaticJsonDocument<768> document;

  String timestamp = getUtcTimestampOrEmpty();

  document["message_id"] = String("status-") + String(millis());
  document["farm_id"] = config.farmId;
  document["zone_id"] = config.zoneId;
  document["esp32_id"] = config.esp32Id;
  document["status"] = status;
  document["reason"] = reason;
  document["firmware_version"] = FIRMWARE_VERSION;
  document["rssi"] = WiFi.RSSI();
  document["uptime_seconds"] = millis() / 1000;
  document["ip_address"] = WiFi.localIP().toString();

  if (timestamp.length() > 0) {
    document["timestamp"] = timestamp;
  } else {
    document["timestamp"] = nullptr;
    document["timestamp_status"] = "ntp_unavailable";
  }

  bool published = publishJson(getStatusTopic(), document, retained, 1);

  if (published) {
    Serial.print("[MQTT] Published status: ");
    Serial.println(status);
  }

  return published;
}

bool connectToMqtt() {
  if (WiFi.status() != WL_CONNECTED) {
    return false;
  }

  if (!hasRequiredMqttConfiguration()) {
    Serial.println("[MQTT] Required MQTT configuration is missing.");
    return false;
  }

  String willPayload =
    "{\"farm_id\":\"" + config.farmId +
    "\",\"zone_id\":\"" + config.zoneId +
    "\",\"esp32_id\":\"" + config.esp32Id +
    "\",\"status\":\"offline\"" +
    ",\"reason\":\"unexpected_disconnect\"" +
    ",\"firmware_version\":\"" + String(FIRMWARE_VERSION) + "\"}";

  mqttClient.setId(config.esp32Id.c_str());
  mqttClient.setUsernamePassword(
    config.mqttUsername.c_str(),
    config.mqttPassword.c_str()
  );

  mqttClient.beginWill(
    getStatusTopic().c_str(),
    willPayload.length(),
    true,
    1
  );

  mqttClient.print(willPayload);
  mqttClient.endWill();

  Serial.print("[MQTT] Connecting to ");
  Serial.print(config.mqttHost);
  Serial.print(":");
  Serial.println(config.mqttPort);

  bool connected = mqttClient.connect(
    config.mqttHost.c_str(),
    config.mqttPort
  );

  if (!connected) {
    Serial.print("[MQTT] Connection failed. Error code: ");
    Serial.println(mqttClient.connectError());
    return false;
  }

  Serial.println("[MQTT] Connected successfully.");

  mqttReconnectDelayMs = MQTT_RECONNECT_MIN_MS;
  lastHeartbeatAt = 0;

  publishDeviceStatus("online", "mqtt_connected", true);

  return true;
}

void maintainMqttConnection() {
  if (mqttClient.connected()) {
    mqttClient.poll();
    return;
  }

  unsigned long now = millis();

  if (now - lastMqttConnectAttemptAt < mqttReconnectDelayMs) {
    return;
  }

  lastMqttConnectAttemptAt = now;

  if (connectToMqtt()) {
    return;
  }

  mqttReconnectDelayMs = min(
    mqttReconnectDelayMs * 2,
    MQTT_RECONNECT_MAX_MS
  );

  Serial.print("[MQTT] Next reconnect delay in ms: ");
  Serial.println(mqttReconnectDelayMs);
}

void publishHeartbeatIfDue() {
  if (!mqttClient.connected()) {
    return;
  }

  unsigned long now = millis();

  if (now - lastHeartbeatAt < HEARTBEAT_INTERVAL_MS) {
    return;
  }

  lastHeartbeatAt = now;
  publishDeviceStatus("online", "heartbeat", true);
}

// -------------------- Wi-Fi Maintenance ---------------------

void maintainWiFiConnection() {
  if (WiFi.status() == WL_CONNECTED) {
    return;
  }

  Serial.println("[WIFI] Wi-Fi disconnected. Attempting reconnect.");
  WiFi.reconnect();
}

// -------------------- Arduino Setup / Loop ------------------

void setup() {
  Serial.begin(115200);
  delay(500);

  Serial.println();
  Serial.println("==============================================");
  Serial.println("SMART FARM ESP32 BASIC FIRMWARE");
  Serial.print("Firmware Version: ");
  Serial.println(FIRMWARE_VERSION);
  Serial.println("==============================================");

  loadConfiguration();

  if (isBootButtonHeld()) {
    clearConfiguration();
    delay(1000);
    ESP.restart();
  }

  bool forcePortal = !hasRequiredMqttConfiguration();

  if (!startProvisioningPortal(forcePortal)) {
    Serial.println("[SYSTEM] Provisioning failed or timed out. Restarting.");
    delay(3000);
    ESP.restart();
  }

  if (!hasRequiredMqttConfiguration()) {
    Serial.println("[SYSTEM] MQTT configuration is incomplete.");
    Serial.println("[SYSTEM] Restart and use the provisioning portal again.");
    delay(3000);
    ESP.restart();
  }

  Serial.println("[WIFI] Connected.");
  Serial.print("[WIFI] IP Address: ");
  Serial.println(WiFi.localIP());

  Serial.print("[CONFIG] Farm ID: ");
  Serial.println(config.farmId);

  Serial.print("[CONFIG] Zone ID: ");
  Serial.println(config.zoneId);

  Serial.print("[CONFIG] ESP32 ID: ");
  Serial.println(config.esp32Id);

  Serial.print("[CONFIG] MQTT Host: ");
  Serial.println(config.mqttHost);

  Serial.print("[CONFIG] MQTT Port: ");
  Serial.println(config.mqttPort);

  Serial.print("[CONFIG] MQTT Username: ");
  Serial.println(config.mqttUsername);

  configureNtpIfAvailable();
}

void loop() {
  maintainWiFiConnection();

  if (WiFi.status() == WL_CONNECTED) {
    configureNtpIfAvailable();
    maintainMqttConnection();
    publishHeartbeatIfDue();
  }

  delay(10);
}