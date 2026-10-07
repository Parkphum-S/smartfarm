#include <Arduino.h>
#include <WiFi.h>
#include <WiFiManager.h>
#include <ArduinoMqttClient.h>
#include <ArduinoJson.h>
#include <Preferences.h>
#include <DHT.h>
#include <time.h>
#include <esp_system.h>

// ============================================================
// SMART FARM — ESPDUINO-32 HW-729
// Role: CONTROLLER
// Zone: zone_03 (Fruit Zone)
// ============================================================

#define FIRMWARE_VERSION "0.1.0"

static const char* CONFIG_NAMESPACE = "smartfarm";

// ------------------------------------------------------------
// Identity
// ------------------------------------------------------------

static const char* DEFAULT_FARM_ID = "farm_001";
static const char* DEFAULT_ZONE_ID = "zone_03";
static const char* DEFAULT_DEVICE_ID = "ESPDUINO-32 HW-729";

// ------------------------------------------------------------
// Hardware
// ------------------------------------------------------------

static constexpr uint8_t DHT_PIN = 4;
static constexpr uint8_t DHT_TYPE = DHT11;

static constexpr uint8_t SOIL_MOISTURE_PIN = 34;

// 4-channel solid-state relay, Low-Level Trigger
static constexpr uint8_t WATER_PUMP_IN_PIN = 16;
static constexpr uint8_t WATER_PUMP_OUT_PIN = 17;

// Reserved relay channels
static constexpr uint8_t RELAY_CH3_PIN = 25;
static constexpr uint8_t RELAY_CH4_PIN = 26;

// Low-Level Trigger:
// LOW  = ON
// HIGH = OFF
static constexpr uint8_t RELAY_ON = LOW;
static constexpr uint8_t RELAY_OFF = HIGH;

struct ActuatorRuntime {
  String actuatorCode;
  uint8_t pin;
  bool isOn;
  unsigned long turnedOnAtMs;
  unsigned long maximumRuntimeMs;
};


// ------------------------------------------------------------
// Soil Moisture Reference Calibration
// ------------------------------------------------------------

static constexpr int SOIL_DRY_RAW = 4095;
static constexpr int SOIL_WET_RAW = 1152;

// ------------------------------------------------------------
// MQTT
// ------------------------------------------------------------

static constexpr uint16_t DEFAULT_MQTT_PORT = 1883;

static const char* DEFAULT_MQTT_HOST = "192.168.1.60";
static const char* DEFAULT_MQTT_USERNAME = "esp32_001";
static const char* DEFAULT_MQTT_PASSWORD = "";

static const char* DEFAULT_NTP_SERVER = "pool.ntp.org";

// ------------------------------------------------------------
// Runtime Configuration
// ------------------------------------------------------------

struct SmartFarmConfig {
  String farmId;
  String zoneId;
  String deviceId;

  String mqttHost;
  uint16_t mqttPort;

  String mqttUsername;
  String mqttPassword;

  String ntpServer;
};

SmartFarmConfig config;

Preferences preferences;

WiFiClient wifiClient;
MqttClient mqttClient(wifiClient);

DHT dht(DHT_PIN, DHT_TYPE);

// ------------------------------------------------------------
// Configuration / NVS
// ------------------------------------------------------------

void loadConfiguration() {
  preferences.begin(CONFIG_NAMESPACE, true);

  config.farmId = preferences.getString("farm_id", DEFAULT_FARM_ID);
  config.zoneId = preferences.getString("zone_id", DEFAULT_ZONE_ID);
  config.deviceId = preferences.getString("device_id", DEFAULT_DEVICE_ID);

  config.mqttHost = preferences.getString("mqtt_host", DEFAULT_MQTT_HOST);
  config.mqttPort = preferences.getUShort("mqtt_port", DEFAULT_MQTT_PORT);

  config.mqttUsername =
      preferences.getString("mqtt_user", DEFAULT_MQTT_USERNAME);
  config.mqttPassword =
      preferences.getString("mqtt_pass", DEFAULT_MQTT_PASSWORD);

  config.ntpServer =
      preferences.getString("ntp_server", DEFAULT_NTP_SERVER);

  preferences.end();
}

void saveConfiguration() {
  preferences.begin(CONFIG_NAMESPACE, false);

  preferences.putString("farm_id", config.farmId);
  preferences.putString("zone_id", config.zoneId);
  preferences.putString("device_id", config.deviceId);

  preferences.putString("mqtt_host", config.mqttHost);
  preferences.putUShort("mqtt_port", config.mqttPort);

  preferences.putString("mqtt_user", config.mqttUsername);
  preferences.putString("mqtt_pass", config.mqttPassword);

  preferences.putString("ntp_server", config.ntpServer);

  preferences.end();
}

void configureWiFi() {
  WiFiManager wm;

  String apName =
      "smartfarm-hw729-" +
      String((uint32_t)ESP.getEfuseMac(), HEX);

  WiFiManagerParameter farmParam(
      "farm_id",
      "Farm ID",
      config.farmId.c_str(),
      64);

  WiFiManagerParameter zoneParam(
      "zone_id",
      "Zone ID",
      config.zoneId.c_str(),
      64);

  WiFiManagerParameter deviceParam(
      "device_id",
      "Device ID",
      config.deviceId.c_str(),
      100);

  WiFiManagerParameter mqttHostParam(
      "mqtt_host",
      "MQTT Host/IP",
      config.mqttHost.c_str(),
      64);

  WiFiManagerParameter mqttPortParam(
      "mqtt_port",
      "MQTT Port",
      String(config.mqttPort).c_str(),
      6);

  WiFiManagerParameter mqttUserParam(
      "mqtt_user",
      "MQTT Username",
      config.mqttUsername.c_str(),
      64);

  WiFiManagerParameter mqttPassParam(
      "mqtt_pass",
      "MQTT Password",
      config.mqttPassword.c_str(),
      64);

  wm.addParameter(&farmParam);
  wm.addParameter(&zoneParam);
  wm.addParameter(&deviceParam);
  wm.addParameter(&mqttHostParam);
  wm.addParameter(&mqttPortParam);
  wm.addParameter(&mqttUserParam);
  wm.addParameter(&mqttPassParam);

  bool connected;

  connected = wm.autoConnect(apName.c_str());

  if (!connected) {
    ESP.restart();
  }

  config.farmId = farmParam.getValue();
  config.zoneId = zoneParam.getValue();
  config.deviceId = deviceParam.getValue();
  config.mqttHost = mqttHostParam.getValue();

  int mqttPort = atoi(mqttPortParam.getValue());
  if (mqttPort > 0 && mqttPort <= 65535) {
    config.mqttPort = static_cast<uint16_t>(mqttPort);
  }

  config.mqttUsername = mqttUserParam.getValue();
  config.mqttPassword = mqttPassParam.getValue();

  saveConfiguration();
}

// ------------------------------------------------------------
// Runtime State
// ------------------------------------------------------------

bool mqttConnected = false;

unsigned long lastSensorReadMs = 0;
unsigned long lastHeartbeatMs = 0;

static constexpr unsigned long SENSOR_READ_INTERVAL_MS = 10000;
static constexpr unsigned long HEARTBEAT_INTERVAL_MS = 30000;

// ------------------------------------------------------------
// MQTT Topic Helpers
// ------------------------------------------------------------

String makeSensorTopic(const String& sensorCode) {
  return "farm/" + config.farmId +
         "/zone/" + config.zoneId +
         "/sensor/" + sensorCode +
         "/reading";
}

String makeActuatorCommandTopic() {
  return "farm/" + config.farmId +
         "/zone/" + config.zoneId +
         "/actuator/+/command";
}

String makeOtaCommandTopic() {
  return "farm/" + config.farmId +
         "/esp32/" + config.deviceId +
         "/ota/command";
}

String makeActuatorStateTopic(const String& actuatorCode) {
  return "farm/" + config.farmId +
         "/zone/" + config.zoneId +
         "/actuator/" + actuatorCode +
         "/state";
}

String makeDeviceStatusTopic() {
  return "farm/" + config.farmId +
         "/esp32/" + config.deviceId +
         "/status";
}

// ------------------------------------------------------------
// MQTT Connection
// ------------------------------------------------------------

bool connectToMqtt() {
  if (WiFi.status() != WL_CONNECTED) {
    return false;
  }

  if (config.mqttHost.length() == 0) {
    return false;
  }

  mqttClient.setId(config.deviceId);

  if (config.mqttUsername.length() > 0) {
    mqttClient.setUsernamePassword(
        config.mqttUsername,
        config.mqttPassword);
  }

  String willTopic = makeDeviceStatusTopic();

  StaticJsonDocument<256> willDoc;
  willDoc["farm_id"] = config.farmId;
  willDoc["esp32_id"] = config.deviceId;
  willDoc["status"] = "offline";

  String willPayload;
  serializeJson(willDoc, willPayload);

  mqttClient.beginWill(
      willTopic.c_str(),
      willPayload.length(),
      true,
      1);
  mqttClient.print(willPayload);
  mqttClient.endWill();

  Serial.printf(
      "[MQTT] Connecting to %s:%u\n",
      config.mqttHost.c_str(),
      config.mqttPort);

  if (!mqttClient.connect(config.mqttHost.c_str(), config.mqttPort)) {
    Serial.print("[MQTT] Connection failed, error=");
    Serial.println(mqttClient.connectError());
    return false;
  }

  mqttConnected = true;

  String commandTopic = makeActuatorCommandTopic();

  if (!mqttClient.subscribe(commandTopic, 1)) {
    Serial.println("[MQTT] Actuator command subscribe failed");
  } else {
    mqttClient.onMessage(onMqttMessage);
    Serial.print("[MQTT] Subscribed: ");
    Serial.println(commandTopic);
  }
  Serial.println("[MQTT] Connected");

  return true;
}

void maintainMqttConnection() {
  if (WiFi.status() != WL_CONNECTED) {
    mqttConnected = false;
    return;
  }

  if (!mqttClient.connected()) {
    mqttConnected = false;

    static unsigned long lastReconnectAttemptMs = 0;
    static unsigned long reconnectDelayMs = 3000;

    const unsigned long now = millis();

    if (now - lastReconnectAttemptMs >= reconnectDelayMs) {
      lastReconnectAttemptMs = now;

      if (connectToMqtt()) {
        reconnectDelayMs = 3000;
      } else {
        reconnectDelayMs =
            min(reconnectDelayMs * 2UL, 60000UL);
      }
    }

    return;
  }

  mqttConnected = true;
  mqttClient.poll();
}

// ------------------------------------------------------------
// Sensor Helpers
// ------------------------------------------------------------

String makeMessageId(const String& sensorCode) {
  uint32_t r1 = esp_random();
  uint32_t r2 = esp_random();
  uint32_t r3 = esp_random();
  uint32_t r4 = esp_random();

  char uuid[37];

  snprintf(
      uuid,
      sizeof(uuid),
      "%08lx-%04lx-4%03lx-%04lx-%08lx%04lx",
      (unsigned long)r1,
      (unsigned long)(r2 & 0xFFFF),
      (unsigned long)(r3 & 0x0FFF),
      (unsigned long)((r4 & 0x3FFF) | 0x8000),
      (unsigned long)r1,
      (unsigned long)(r2 & 0xFFFF));

  return String(uuid);
}

float readSoilMoisturePercent(int& rawValue) {
  rawValue = analogRead(SOIL_MOISTURE_PIN);

  float percentage =
      ((float)(SOIL_DRY_RAW - rawValue) /
       (float)(SOIL_DRY_RAW - SOIL_WET_RAW)) *
      100.0f;

  return constrain(percentage, 0.0f, 100.0f);
}

bool publishSensorReading(
    const String& sensorCode,
    const String& sensorType,
    float value,
    const String& unit,
    int rawValue = -1) {

  if (!mqttClient.connected()) {
    return false;
  }

  String topic = makeSensorTopic(sensorCode);

  StaticJsonDocument<512> doc;

  doc["message_id"] = makeMessageId(sensorCode);
  doc["farm_id"] = config.farmId;
  doc["esp32_id"] = config.deviceId;
  doc["zone_id"] = config.zoneId;
  doc["sensor_id"] = sensorCode;
  doc["sensor_type"] = sensorType;
  doc["value"] = value;
  doc["unit"] = unit;
  doc["quality"] = "good";
  doc["status"] = "ok";

  if (rawValue >= 0) {
    doc["raw_value"] = rawValue;
  }

  size_t payloadSize = measureJson(doc);

  mqttClient.beginMessage(topic, payloadSize, false, 1);
  serializeJson(doc, mqttClient);
  bool result = mqttClient.endMessage();

  if (!result) {
    Serial.print("[MQTT] Sensor publish failed: ");
    Serial.println(sensorCode);
    return false;
  }

  Serial.print("[SENSOR] ");
  Serial.print(sensorCode);
  Serial.print(" raw=");
  Serial.print(rawValue);
  Serial.print(" = ");
  Serial.print(value);
  Serial.print(" ");
  Serial.println(unit);

  return true;
}

void readAndPublishSensors() {
  if (!mqttClient.connected()) {
    return;
  }

  int soilRaw = 0;
  float soilMoisture = readSoilMoisturePercent(soilRaw);

  publishSensorReading(
      "soil_moisture_001",
      "soil_moisture",
      soilMoisture,
      "%",
      soilRaw);

  float temperature = dht.readTemperature();
  float humidity = dht.readHumidity();

  if (isnan(temperature) || isnan(humidity)) {
    Serial.println("[DHT11] Read failed");
    return;
  }

  publishSensorReading(
      "temperature_001",
      "air_temperature",
      temperature,
      "°C");

  publishSensorReading(
      "humidity_001",
      "air_humidity",
      humidity,
      "%");
}

// ------------------------------------------------------------
// Device Heartbeat
// ------------------------------------------------------------


void publishDeviceHeartbeat() {
  if (!mqttClient.connected()) {
    return;
  }

  String topic = makeDeviceStatusTopic();

  StaticJsonDocument<384> doc;

  doc["farm_id"] = config.farmId;
  doc["esp32_id"] = config.deviceId;
  doc["zone_id"] = config.zoneId;
  doc["status"] = "online";
  doc["firmware_version"] = FIRMWARE_VERSION;
  doc["uptime_seconds"] = millis() / 1000UL;
  doc["wifi_rssi"] = WiFi.RSSI();

  size_t payloadSize = measureJson(doc);

  mqttClient.beginMessage(topic, payloadSize, true, 1);
  serializeJson(doc, mqttClient);
  mqttClient.endMessage();
}

// ------------------------------------------------------------
// Actuator Control
// ------------------------------------------------------------

ActuatorRuntime waterPumpIn = {
    "water_pump_in_001",
    WATER_PUMP_IN_PIN,
    false,
    0,
    300000UL
};

ActuatorRuntime waterPumpOut = {
    "water_pump_out_001",
    WATER_PUMP_OUT_PIN,
    false,
    0,
    300000UL
};

ActuatorRuntime* findActuator(const String& actuatorCode) {
  if (actuatorCode == waterPumpIn.actuatorCode) {
    return &waterPumpIn;
  }

  if (actuatorCode == waterPumpOut.actuatorCode) {
    return &waterPumpOut;
  }

  return nullptr;
}

void setActuatorState(
    ActuatorRuntime& actuator,
    bool turnOn) {

  digitalWrite(
      actuator.pin,
      turnOn ? RELAY_ON : RELAY_OFF);

  actuator.isOn = turnOn;

  if (turnOn) {
    actuator.turnedOnAtMs = millis();
  } else {
    actuator.turnedOnAtMs = 0;
  }
}

void publishActuatorState(
    const ActuatorRuntime& actuator) {

  if (!mqttClient.connected()) {
    return;
  }

  String topic =
      makeActuatorStateTopic(actuator.actuatorCode);

  StaticJsonDocument<384> doc;

  doc["farm_id"] = config.farmId;
  doc["esp32_id"] = config.deviceId;
  doc["zone_id"] = config.zoneId;
  doc["actuator_id"] = actuator.actuatorCode;
  doc["actual_state"] = actuator.isOn ? "on" : "off";
  doc["device_health"] = "online";

  size_t payloadSize = measureJson(doc);

  mqttClient.beginMessage(topic, payloadSize, true, 1);
  serializeJson(doc, mqttClient);
  mqttClient.endMessage();
}

void publishCommandAck(
    const String& commandId,
    const String& actuatorCode,
    const String& result,
    const String& actualState,
    const String& traceId) {

  if (!mqttClient.connected()) {
    return;
  }

  String topic =
      "farm/" + config.farmId +
      "/zone/" + config.zoneId +
      "/actuator/" + actuatorCode +
      "/command/ack";

  StaticJsonDocument<512> doc;

  doc["command_id"] = commandId;
  doc["actuator_id"] = actuatorCode;
  doc["result"] = result;
  doc["actual_state"] = actualState;

  if (traceId.length() > 0) {
    doc["trace_id"] = traceId;
  }

  size_t payloadSize = measureJson(doc);

  mqttClient.beginMessage(topic, payloadSize, false, 1);
  serializeJson(doc, mqttClient);
  mqttClient.endMessage();
}

void handleActuatorCommand(
    const String& topic,
    const String& payload) {

  const String prefix =
      "farm/" + config.farmId +
      "/zone/" + config.zoneId +
      "/actuator/";

  if (!topic.startsWith(prefix)) {
    return;
  }

  const String suffix = topic.substring(prefix.length());
  const int commandPos = suffix.indexOf("/command");

  if (commandPos <= 0) {
    return;
  }

  const String actuatorCode =
      suffix.substring(0, commandPos);

  ActuatorRuntime* actuator =
      findActuator(actuatorCode);

  StaticJsonDocument<512> doc;

  DeserializationError error =
      deserializeJson(doc, payload);

  if (error) {
    Serial.println("[ACTUATOR] Invalid JSON");
    return;
  }

  const String commandId =
      doc["command_id"] | "";

  const String traceId =
      doc["trace_id"] | "";

  const String action =
      doc["action"] | "";

  if (actuator == nullptr) {
    publishCommandAck(
        commandId,
        actuatorCode,
        "rejected",
        "unknown",
        traceId);
    return;
  }

  bool turnOn;

  if (action == "on" || action == "open") {
    turnOn = true;
  } else if (action == "off" || action == "close") {
    turnOn = false;
  } else {
    publishCommandAck(
        commandId,
        actuatorCode,
        "rejected",
        actuator->isOn ? "on" : "off",
        traceId);
    return;
  }

  setActuatorState(*actuator, turnOn);

  publishActuatorState(*actuator);

  publishCommandAck(
      commandId,
      actuatorCode,
      "executed",
      actuator->isOn ? "on" : "off",
      traceId);

  Serial.print("[ACTUATOR] ");
  Serial.print(actuatorCode);
  Serial.print(" -> ");
  Serial.println(actuator->isOn ? "ON" : "OFF");
}


void maintainActuatorSafety() {
  ActuatorRuntime* actuators[] = {
      &waterPumpIn,
      &waterPumpOut
  };

  for (ActuatorRuntime* actuator : actuators) {
    if (!actuator->isOn) {
      continue;
    }

    if (millis() - actuator->turnedOnAtMs >=
        actuator->maximumRuntimeMs) {

      Serial.print("[SAFETY] Maximum runtime reached: ");
      Serial.println(actuator->actuatorCode);

      setActuatorState(*actuator, false);
      publishActuatorState(*actuator);
    }
  }
}

void onMqttMessage(int messageSize) {
  String topic = mqttClient.messageTopic();
  String payload;

  while (mqttClient.available()) {
    payload += static_cast<char>(mqttClient.read());
  }
  handleActuatorCommand(topic, payload);
}

// ------------------------------------------------------------
// Hardware Initialization
// ------------------------------------------------------------

void setupPins() {
  pinMode(SOIL_MOISTURE_PIN, INPUT);

  pinMode(WATER_PUMP_IN_PIN, OUTPUT);
  pinMode(WATER_PUMP_OUT_PIN, OUTPUT);
  pinMode(RELAY_CH3_PIN, OUTPUT);
  pinMode(RELAY_CH4_PIN, OUTPUT);

  // HW-729 uses low-level trigger relays:
  // HIGH = OFF, LOW = ON.
  // Force all relay channels OFF during boot.
  digitalWrite(WATER_PUMP_IN_PIN, RELAY_OFF);
  digitalWrite(WATER_PUMP_OUT_PIN, RELAY_OFF);
  digitalWrite(RELAY_CH3_PIN, RELAY_OFF);
  digitalWrite(RELAY_CH4_PIN, RELAY_OFF);

  waterPumpIn.isOn = false;
  waterPumpIn.turnedOnAtMs = 0;

  waterPumpOut.isOn = false;
  waterPumpOut.turnedOnAtMs = 0;
}

// ------------------------------------------------------------
// Forward Declarations
// ------------------------------------------------------------

void loadConfiguration();
void saveConfiguration();

void setupPins();

String makeSensorTopic(const String& sensorCode);
String makeActuatorCommandTopic();
String makeActuatorStateTopic(const String& actuatorCode);

void setup();
void loop();
void setup() {
  Serial.begin(115200);
  delay(500);

  delay(500);

  Serial.println();
  Serial.println("========================================");
  Serial.println(" Smart Farm ESPDUINO-32 HW-729");
  Serial.print(" Firmware: ");
  Serial.println(FIRMWARE_VERSION);
  Serial.println("========================================");

  setupPins();

  dht.begin();

  loadConfiguration();

  Serial.print("[CONFIG] MQTT username: ");
  Serial.println(config.mqttUsername);
  Serial.print("[CONFIG] MQTT password: ");
  Serial.println(config.mqttPassword.length() > 0 ? "<SET>" : "<EMPTY>");

  configureWiFi();

  configTime(0, 0, config.ntpServer.c_str());

  connectToMqtt();

  Serial.println("[BOOT] Initialization complete");
}

void loop() {
  maintainMqttConnection();

  if (mqttClient.connected()) {
    mqttClient.poll();
  }

  maintainActuatorSafety();

  const unsigned long now = millis();

  if (now - lastSensorReadMs >= SENSOR_READ_INTERVAL_MS) {
    lastSensorReadMs = now;
    readAndPublishSensors();
  }

  if (now - lastHeartbeatMs >= HEARTBEAT_INTERVAL_MS) {
    lastHeartbeatMs = now;
    publishDeviceHeartbeat();
  }

  delay(10);
}


