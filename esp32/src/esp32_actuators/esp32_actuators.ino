#include <Arduino.h>
#include <esp_system.h>
#include <WiFi.h>
#include <WiFiManager.h>
#include <ArduinoMqttClient.h>
#include <ArduinoJson.h>
#include <Preferences.h>
#include <DHT.h>
#include <time.h>

// ============================================================
// SMART FARM ESP32 ACTUATORS & SENSORS FIRMWARE
// Phase 10.10: Dual Relay Control
//
// Actuators:
//   water_pump_01  -> GPIO23
//   oxygen_pump_01 -> GPIO22
//
// Relay Module:
//   4 Channel 5V Solid State Relay
//   High Level Trigger / Active HIGH
//
// Logic:
//   LOW  = OFF / Status LED OFF
//   HIGH = ON  / Status LED ON
// ============================================================

const char* FIRMWARE_VERSION = "0.3.1";
const char* CONFIG_NAMESPACE = "smartfarm";

// ============================================================
// Timing
// ============================================================

const unsigned long HEARTBEAT_INTERVAL_MS = 30000;
const unsigned long SENSOR_READ_INTERVAL_MS = 10000;
const unsigned long MQTT_RECONNECT_MIN_MS = 3000;
const unsigned long MQTT_RECONNECT_MAX_MS = 60000;
const unsigned long BOOT_BUTTON_HOLD_MS = 3000;

// ============================================================
// GPIO
// ============================================================

const int BOOT_BUTTON_PIN = 0;

// --- Sensors ---
const int SOIL_MOISTURE_PIN = 34;
const int DHT_PIN = 4;
const int DHT_TYPE = DHT11;

// --- Actuators ---
const int RELAY_PIN = 23;         // Water Pump
const int OXYGEN_RELAY_PIN = 22;  // Oxygen Pump

// Relay is Active HIGH:
// LOW  = OFF
// HIGH = ON

DHT dht(DHT_PIN, DHT_TYPE);

// ============================================================
// Soil Moisture Calibration
// ============================================================

const int SOIL_DRY_RAW = 3100;
const int SOIL_WET_RAW = 1350;

// ============================================================
// Actuator State / Fail-safe
// ============================================================

bool waterPumpState = false;
bool oxygenPumpState = false;

unsigned long waterPumpTurnedOnAt = 0;
unsigned long oxygenPumpTurnedOnAt = 0;

unsigned long waterPumpMaxRuntimeSeconds = 900;
unsigned long oxygenPumpMaxRuntimeSeconds = 900;

// ============================================================
// Smart Farm Configuration
// ============================================================

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

// ============================================================
// Libraries / Clients
// ============================================================

Preferences preferences;
WiFiManager wifiManager;
WiFiClient wifiClient;
MqttClient mqttClient(wifiClient);

// ============================================================
// Runtime Flags
// ============================================================

bool shouldSaveConfig = false;
bool ntpConfigured = false;

unsigned long lastHeartbeatAt = 0;
unsigned long lastSensorReadAt = 0;
unsigned long lastMqttConnectAttemptAt = 0;

unsigned long mqttReconnectDelayMs =
    MQTT_RECONNECT_MIN_MS;

// ============================================================
// Forward Declarations
// ============================================================

void onMqttMessage(int messageSize);

void handleCommand(
  String topic,
  String payload
);

bool publishActuatorState(
  const String& actuatorId,
  const String& state,
  bool retained
);

bool publishCommandAck(
  const String& commandId,
  const String& actuatorId,
  const String& result,
  const String& state,
  const String& traceId
);

void checkSafetyFailSafe();
bool publishSoilMoisture();

String generateUuidV4() {
  uint8_t bytes[16];

  for (int i = 0; i < 16; i += 4) {
    uint32_t value = esp_random();

    bytes[i]     = (value >> 24) & 0xFF;
    bytes[i + 1] = (value >> 16) & 0xFF;
    bytes[i + 2] = (value >> 8) & 0xFF;
    bytes[i + 3] = value & 0xFF;
  }

  // UUID version 4.
  bytes[6] = (bytes[6] & 0x0F) | 0x40;

  // UUID variant RFC 4122.
  bytes[8] = (bytes[8] & 0x3F) | 0x80;

  char uuid[37];

  snprintf(
    uuid,
    sizeof(uuid),
    "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
    bytes[0], bytes[1], bytes[2], bytes[3],
    bytes[4], bytes[5],
    bytes[6], bytes[7],
    bytes[8], bytes[9],
    bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
  );

  return String(uuid);
}


// ============================================================
// SETUP
// ============================================================

void setup() {

  Serial.begin(115200);

  delay(500);

  Serial.println();
  Serial.println("==============================================");
  Serial.println("SMART FARM ESP32 ACTUATORS FIRMWARE");
  Serial.print("Firmware Version: ");
  Serial.println(FIRMWARE_VERSION);
  Serial.println("==============================================");

  // ==========================================================
  // Initialize Hardware Pins
  // ==========================================================

  pinMode(SOIL_MOISTURE_PIN, INPUT);

  // Water Pump - GPIO23
  pinMode(RELAY_PIN, OUTPUT);

  // Active HIGH:
  // LOW = OFF
  digitalWrite(RELAY_PIN, LOW);

  // Oxygen Pump - GPIO22
  pinMode(OXYGEN_RELAY_PIN, OUTPUT);

  // Active HIGH:
  // LOW = OFF
  digitalWrite(OXYGEN_RELAY_PIN, LOW);

  Serial.println("[GPIO] Water Pump  : GPIO23 / OFF");
  Serial.println("[GPIO] Oxygen Pump : GPIO22 / OFF");

  dht.begin();

  // ==========================================================
  // Load NVS Config
  // ==========================================================

  preferences.begin(
    CONFIG_NAMESPACE,
    true
  );

  config.farmId =
      preferences.getString(
        "farm_id",
        "farm_001"
      );

  config.zoneId =
      preferences.getString(
        "zone_id",
        "zone_01"
      );

  config.esp32Id =
      preferences.getString(
        "esp32_id",
        "esp32_001"
      );

  config.mqttHost =
      preferences.getString(
        "mqtt_host",
        ""
      );

  config.mqttPort =
      preferences.getUShort(
        "mqtt_port",
        1883
      );

  config.mqttUsername =
      preferences.getString(
        "mqtt_user",
        "esp32_001"
      );

  config.mqttPassword =
      preferences.getString(
        "mqtt_pass",
        ""
      );

  config.ntpServer =
      preferences.getString(
        "ntp_server",
        "pool.ntp.org"
      );

  preferences.end();

  // ==========================================================
  // Check BOOT button for factory reset
  // ==========================================================

  pinMode(
    BOOT_BUTTON_PIN,
    INPUT_PULLUP
  );

  if (digitalRead(BOOT_BUTTON_PIN) == LOW) {

    unsigned long pressedAt = millis();

    bool resetTriggered = false;

    while (
      digitalRead(BOOT_BUTTON_PIN) == LOW
    ) {

      if (
        millis() - pressedAt >=
        BOOT_BUTTON_HOLD_MS
      ) {

        resetTriggered = true;
        break;
      }

      delay(50);
    }

    if (resetTriggered) {

      preferences.begin(
        CONFIG_NAMESPACE,
        false
      );

      preferences.clear();

      preferences.end();

      wifiManager.resetSettings();

      Serial.println(
        "[CONFIG] Configuration cleared."
      );

      delay(1000);

      ESP.restart();
    }
  }

  // ==========================================================
  // WiFi Configuration
  // ==========================================================

  bool forcePortal =
      (config.mqttHost.length() == 0);

  char farmIdBuf[32];
  char zoneIdBuf[32];
  char esp32IdBuf[48];
  char mqttHostBuf[128];
  char mqttPortBuf[8];
  char mqttUserBuf[64];
  char mqttPassBuf[128];

  config.farmId.toCharArray(
    farmIdBuf,
    sizeof(farmIdBuf)
  );

  config.zoneId.toCharArray(
    zoneIdBuf,
    sizeof(zoneIdBuf)
  );

  config.esp32Id.toCharArray(
    esp32IdBuf,
    sizeof(esp32IdBuf)
  );

  config.mqttHost.toCharArray(
    mqttHostBuf,
    sizeof(mqttHostBuf)
  );

  snprintf(
    mqttPortBuf,
    sizeof(mqttPortBuf),
    "%u",
    config.mqttPort
  );

  config.mqttUsername.toCharArray(
    mqttUserBuf,
    sizeof(mqttUserBuf)
  );

  config.mqttPassword.toCharArray(
    mqttPassBuf,
    sizeof(mqttPassBuf)
  );

  // ==========================================================
  // WiFiManager Parameters
  // ==========================================================

  WiFiManagerParameter customHtml(
    "<p><strong>Smart Farm Actuator Settings</strong></p>"
  );

  WiFiManagerParameter pFarmId(
    "farm_id",
    "Farm ID",
    farmIdBuf,
    sizeof(farmIdBuf)
  );

  WiFiManagerParameter pZoneId(
    "zone_id",
    "Zone ID",
    zoneIdBuf,
    sizeof(zoneIdBuf)
  );

  WiFiManagerParameter pEsp32Id(
    "esp32_id",
    "ESP32 ID",
    esp32IdBuf,
    sizeof(esp32IdBuf)
  );

  WiFiManagerParameter pMqttHost(
    "mqtt_host",
    "MQTT Host / IP",
    mqttHostBuf,
    sizeof(mqttHostBuf)
  );

  WiFiManagerParameter pMqttPort(
    "mqtt_port",
    "MQTT Port",
    mqttPortBuf,
    sizeof(mqttPortBuf)
  );

  WiFiManagerParameter pMqttUser(
    "mqtt_user",
    "MQTT Username",
    mqttUserBuf,
    sizeof(mqttUserBuf)
  );

  WiFiManagerParameter pMqttPass(
    "mqtt_pass",
    "MQTT Password",
    mqttPassBuf,
    sizeof(mqttPassBuf)
  );

  wifiManager.addParameter(
    &customHtml
  );

  wifiManager.addParameter(
    &pFarmId
  );

  wifiManager.addParameter(
    &pZoneId
  );

  wifiManager.addParameter(
    &pEsp32Id
  );

  wifiManager.addParameter(
    &pMqttHost
  );

  wifiManager.addParameter(
    &pMqttPort
  );

  wifiManager.addParameter(
    &pMqttUser
  );

  wifiManager.addParameter(
    &pMqttPass
  );

  // ==========================================================
  // Start WiFi
  // ==========================================================

  String apName =
      "smartfarm-actuator-" +
      String(
        (uint32_t)ESP.getEfuseMac(),
        HEX
      );

  bool connected =
      forcePortal
        ? wifiManager.startConfigPortal(
            apName.c_str()
          )
        : wifiManager.autoConnect(
            apName.c_str()
          );

  if (!connected) {

    Serial.println(
      "[WIFI] Connection failed. Restarting..."
    );

    delay(3000);

    ESP.restart();
  }

  // ==========================================================
  // Save Configuration
  // ==========================================================

  config.farmId =
      pFarmId.getValue();

  config.zoneId =
      pZoneId.getValue();

  config.esp32Id =
      pEsp32Id.getValue();

  config.mqttHost =
      pMqttHost.getValue();

  config.mqttPort =
      String(
        pMqttPort.getValue()
      ).toInt();

  config.mqttUsername =
      pMqttUser.getValue();

  config.mqttPassword =
      pMqttPass.getValue();

  preferences.begin(
    CONFIG_NAMESPACE,
    false
  );

  preferences.putString(
    "farm_id",
    config.farmId
  );

  preferences.putString(
    "zone_id",
    config.zoneId
  );

  preferences.putString(
    "esp32_id",
    config.esp32Id
  );

  preferences.putString(
    "mqtt_host",
    config.mqttHost
  );

  preferences.putUShort(
    "mqtt_port",
    config.mqttPort
  );

  preferences.putString(
    "mqtt_user",
    config.mqttUsername
  );

  preferences.putString(
    "mqtt_pass",
    config.mqttPassword
  );

  preferences.end();

  Serial.println(
    "[WIFI] Connected. IP: " +
    WiFi.localIP().toString()
  );
}

// ============================================================
// LOOP
// ============================================================


// ============================================================
// MQTT Publisher - Soil Moisture
// ============================================================

bool publishSoilMoisture() {

  if (!mqttClient.connected()) {
    return false;
  }

  int rawValue = analogRead(
    SOIL_MOISTURE_PIN
  );

  float soilMoisture =
      ((float)(SOIL_DRY_RAW - rawValue) /
       (float)(SOIL_DRY_RAW - SOIL_WET_RAW)) *
      100.0f;

  soilMoisture = constrain(
    soilMoisture,
    0.0f,
    100.0f
  );

  String sensorTopic =
      "farm/" +
      config.farmId +
      "/zone/" +
      config.zoneId +
      "/sensor/soil_moisture_01/reading";

  StaticJsonDocument<256> doc;

  String messageId = generateUuidV4();

  doc["message_id"] = messageId;

  doc["value"] = soilMoisture;
  doc["unit"] = "%";
  doc["status"] = "ok";

  String payload;

  serializeJson(
    doc,
    payload
  );

  if (
    !mqttClient.beginMessage(
      sensorTopic.c_str(),
      payload.length(),
      false,
      1
    )
  ) {
    Serial.println(
      "[SENSOR] Failed to begin MQTT message."
    );
    return false;
  }

  mqttClient.print(payload);

  if (!mqttClient.endMessage()) {
    Serial.println(
      "[SENSOR] Failed to publish Soil Moisture."
    );
    return false;
  }

  Serial.print(
    "[SENSOR] Soil Moisture: "
  );

  Serial.print(
    soilMoisture,
    1
  );

  Serial.print(
    "% (RAW="
  );

  Serial.print(
    rawValue
  );

  Serial.println(")");

  return true;
}

void loop() {

  // ==========================================================
  // WiFi
  // ==========================================================

  if (WiFi.status() != WL_CONNECTED) {

    WiFi.reconnect();

    delay(1000);

    return;
  }

  // ==========================================================
  // NTP
  // ==========================================================

  if (
    !ntpConfigured &&
    config.ntpServer.length() > 0
  ) {

    configTime(
      0,
      0,
      config.ntpServer.c_str()
    );

    ntpConfigured = true;
  }

  // ==========================================================
  // MQTT Maintenance
  // ==========================================================

  if (!mqttClient.connected()) {

    unsigned long now = millis();

    if (
      now - lastMqttConnectAttemptAt >=
      mqttReconnectDelayMs
    ) {

      lastMqttConnectAttemptAt = now;

      String willTopic =
          "farm/" +
          config.farmId +
          "/esp32/" +
          config.esp32Id +
          "/status";

      String willPayload =
          "{\"farm_id\":\"" +
          config.farmId +
          "\",\"esp32_id\":\"" +
          config.esp32Id +
          "\",\"status\":\"offline\"}";

      mqttClient.setId(
        config.esp32Id.c_str()
      );

      mqttClient.setUsernamePassword(
        config.mqttUsername.c_str(),
        config.mqttPassword.c_str()
      );

      mqttClient.beginWill(
        willTopic.c_str(),
        willPayload.length(),
        true,
        1
      );

      mqttClient.print(
        willPayload
      );

      mqttClient.endWill();

      if (
        mqttClient.connect(
          config.mqttHost.c_str(),
          config.mqttPort
        )
      ) {

        mqttReconnectDelayMs =
            MQTT_RECONNECT_MIN_MS;

        // ====================================================
        // Subscribe to Zone Commands
        // ====================================================

        String cmdTopic =
            "farm/" +
            config.farmId +
            "/zone/" +
            config.zoneId +
            "/actuator/+/command";

        mqttClient.subscribe(
          cmdTopic.c_str(),
          1
        );

        mqttClient.onMessage(
          onMqttMessage
        );

        // ====================================================
        // Publish Initial Actuator States
        // ====================================================

        publishActuatorState(
          "water_pump_01",
          waterPumpState
            ? "on"
            : "off",
          true
        );

        publishActuatorState(
          "oxygen_pump_01",
          oxygenPumpState
            ? "on"
            : "off",
          true
        );

        Serial.println(
          "[MQTT] Subscribed to actuator commands."
        );

      } else {

        mqttReconnectDelayMs =
            min(
              mqttReconnectDelayMs * 2,
              MQTT_RECONNECT_MAX_MS
            );
      }
    }

  } else {

    mqttClient.poll();
  }
    // ==========================================================
  // Soil Moisture Sensor
  // ==========================================================

  if (
    mqttClient.connected() &&
    millis() - lastSensorReadAt >=
    SENSOR_READ_INTERVAL_MS
  ) {

    lastSensorReadAt = millis();

    publishSoilMoisture();
  }

  // ==========================================================
  // Heartbeat
  // ==========================================================

  if (
    mqttClient.connected() &&
    millis() - lastHeartbeatAt >=
    HEARTBEAT_INTERVAL_MS
  ) {

    lastHeartbeatAt = millis();

    StaticJsonDocument<256> doc;



    doc["farm_id"] =
        config.farmId;

    doc["esp32_id"] =
        config.esp32Id;

    doc["status"] =
        "online";

    doc["reason"] =
        "heartbeat";

    String statusTopic =
        "farm/" +
        config.farmId +
        "/esp32/" +
        config.esp32Id +
        "/status";

    size_t len =
        measureJson(doc);

    if (
      mqttClient.beginMessage(
        statusTopic.c_str(),
        len,
        true,
        1
      )
    ) {

      serializeJson(
        doc,
        mqttClient
      );

      mqttClient.endMessage();
    }
  }

  // ==========================================================
  // Hardware Safety Fail-safe
  // ==========================================================

  checkSafetyFailSafe();

  delay(50);
}

// ============================================================
// MQTT Command Listener
// ============================================================

void onMqttMessage(
  int messageSize
) {

  String topic =
      mqttClient.messageTopic();

  String payload = "";

  while (
    mqttClient.available()
  ) {

    payload +=
        (char)mqttClient.read();
  }

  Serial.println(
    "[MQTT] Received command on topic: " +
    topic
  );

  handleCommand(
    topic,
    payload
  );
}

// ============================================================
// Handle Actuator Command
// ============================================================

void handleCommand(
  String topic,
  String payload
) {

  StaticJsonDocument<512> doc;

  DeserializationError error =
      deserializeJson(
        doc,
        payload
      );

  if (error) {

    Serial.println(
      "[ERROR] Failed to parse command JSON"
    );

    return;
  }

  String commandId =
      doc["command_id"] | "";

  String action =
      doc["action"] | "";

  action.toLowerCase();

  String traceId =
      doc["trace_id"] | "";

  unsigned long requestedMaxRuntime =
      doc["max_runtime_seconds"] | 900;

  // ==========================================================
  // Extract actuator_id from topic
  //
  // .../actuator/{actuator_id}/command
  // ==========================================================

  int lastSlash =
      topic.lastIndexOf('/');

  int secondLastSlash =
      topic.lastIndexOf(
        '/',
        lastSlash - 1
      );

  String actuatorId =
      topic.substring(
        secondLastSlash + 1,
        lastSlash
      );

  bool knownActuator = false;
  bool actualState = false;

  // ==========================================================
  // WATER PUMP
  // GPIO23
  // Active HIGH
  // ==========================================================

  if (
    actuatorId == "water_pump_01"
  ) {

    knownActuator = true;

    // --------------------------------------------------------
    // ON
    // --------------------------------------------------------

    if (
      action == "on" ||
      action == "open"
    ) {

      waterPumpState = true;

      digitalWrite(
        RELAY_PIN,
        HIGH
      );

      waterPumpTurnedOnAt =
          millis();

      waterPumpMaxRuntimeSeconds =
          requestedMaxRuntime;

      Serial.println(
        "[ACTUATOR] water_pump_01 "
        "turned ON. GPIO23 HIGH. "
        "Max runtime: " +
        String(
          waterPumpMaxRuntimeSeconds
        ) +
        "s"
      );
    }

    // --------------------------------------------------------
    // OFF
    // --------------------------------------------------------

    else if (
      action == "off" ||
      action == "close"
    ) {

      waterPumpState = false;

      digitalWrite(
        RELAY_PIN,
        LOW
      );

      Serial.println(
        "[ACTUATOR] water_pump_01 "
        "turned OFF. GPIO23 LOW."
      );
    }

    actualState =
        waterPumpState;
  }

  // ==========================================================
  // OXYGEN PUMP
  // GPIO22
  // Active HIGH
  // ==========================================================

  else if (
    actuatorId == "oxygen_pump_01"
  ) {

    knownActuator = true;

    // --------------------------------------------------------
    // ON
    // --------------------------------------------------------

    if (
      action == "on" ||
      action == "open"
    ) {

      oxygenPumpState = true;

      digitalWrite(
        OXYGEN_RELAY_PIN,
        HIGH
      );

      oxygenPumpTurnedOnAt =
          millis();

      oxygenPumpMaxRuntimeSeconds =
          requestedMaxRuntime;

      Serial.println(
        "[ACTUATOR] oxygen_pump_01 "
        "turned ON. GPIO22 HIGH. "
        "Max runtime: " +
        String(
          oxygenPumpMaxRuntimeSeconds
        ) +
        "s"
      );
    }

    // --------------------------------------------------------
    // OFF
    // --------------------------------------------------------

    else if (
      action == "off" ||
      action == "close"
    ) {

      oxygenPumpState = false;

      digitalWrite(
        OXYGEN_RELAY_PIN,
        LOW
      );

      Serial.println(
        "[ACTUATOR] oxygen_pump_01 "
        "turned OFF. GPIO22 LOW."
      );
    }

    actualState =
        oxygenPumpState;
  }

  // ==========================================================
  // UNKNOWN ACTUATOR
  // ==========================================================

  else {

    Serial.println(
      "[ACTUATOR] Unknown actuator: " +
      actuatorId
    );

    if (
      commandId.length() > 0
    ) {

      publishCommandAck(
        commandId,
        actuatorId,
        "rejected",
        "off",
        traceId
      );
    }

    return;
  }

  // ==========================================================
  // INVALID ACTION
  // ==========================================================

  if (
    action != "on" &&
    action != "off" &&
    action != "open" &&
    action != "close"
  ) {

    Serial.println(
      "[ACTUATOR] Invalid action: " +
      action
    );

    if (
      commandId.length() > 0
    ) {

      publishCommandAck(
        commandId,
        actuatorId,
        "rejected",
        actualState
          ? "on"
          : "off",
        traceId
      );
    }

    return;
  }

  // ==========================================================
  // Publish Actual State
  // ==========================================================

  if (knownActuator) {

    publishActuatorState(
      actuatorId,
      actualState
        ? "on"
        : "off",
      true
    );

    // ========================================================
    // Publish ACK
    // ========================================================

    if (
      commandId.length() > 0
    ) {

      publishCommandAck(
        commandId,
        actuatorId,
        "executed",
        actualState
          ? "on"
          : "off",
        traceId
      );
    }
  }
}

// ============================================================
// Safety Fail-safe Watchdog
// ============================================================

void checkSafetyFailSafe() {

  // ==========================================================
  // WATER PUMP SAFETY
  // ==========================================================

  if (waterPumpState) {

    unsigned long elapsedSeconds =
        (
          millis() -
          waterPumpTurnedOnAt
        ) / 1000;

    if (
      elapsedSeconds >=
      waterPumpMaxRuntimeSeconds
    ) {

      Serial.println(
        "[SAFETY] water_pump_01 "
        "maximum runtime exceeded. "
        "Turning OFF GPIO23."
      );

      waterPumpState = false;

      digitalWrite(
        RELAY_PIN,
        LOW
      );

      publishActuatorState(
        "water_pump_01",
        "off",
        true
      );
    }
  }

  // ==========================================================
  // OXYGEN PUMP SAFETY
  // ==========================================================

  if (oxygenPumpState) {

    unsigned long elapsedSeconds =
        (
          millis() -
          oxygenPumpTurnedOnAt
        ) / 1000;

    if (
      elapsedSeconds >=
      oxygenPumpMaxRuntimeSeconds
    ) {

      Serial.println(
        "[SAFETY] oxygen_pump_01 "
        "maximum runtime exceeded. "
        "Turning OFF GPIO22."
      );

      oxygenPumpState = false;

      digitalWrite(
        OXYGEN_RELAY_PIN,
        LOW
      );

      publishActuatorState(
        "oxygen_pump_01",
        "off",
        true
      );
    }
  }
}

// ============================================================
// MQTT Publisher - Actuator State
// ============================================================

bool publishActuatorState(
  const String& actuatorId,
  const String& state,
  bool retained
) {

  if (
    !mqttClient.connected()
  ) {

    return false;
  }

  StaticJsonDocument<256> doc;

  doc["actuator_id"] =
      actuatorId;

  doc["actual_state"] =
      state;

  doc["device_health"] =
      "online";

  doc["updated_at"] =
      time(nullptr) > 1704067200
        ? String(time(nullptr))
        : "ok";

  String stateTopic =
      "farm/" +
      config.farmId +
      "/zone/" +
      config.zoneId +
      "/actuator/" +
      actuatorId +
      "/state";

  size_t len =
      measureJson(doc);

  if (
    mqttClient.beginMessage(
      stateTopic.c_str(),
      len,
      retained,
      1
    )
  ) {

    serializeJson(
      doc,
      mqttClient
    );

    return mqttClient.endMessage();
  }

  return false;
}

// ============================================================
// MQTT Publisher - Command ACK
// ============================================================

bool publishCommandAck(
  const String& commandId,
  const String& actuatorId,
  const String& result,
  const String& state,
  const String& traceId
) {

  if (
    !mqttClient.connected()
  ) {

    return false;
  }

  StaticJsonDocument<256> doc;

  doc["command_id"] =
      commandId;

  doc["actuator_id"] =
      actuatorId;

  doc["result"] =
      result;

  doc["actual_state"] =
      state;

  doc["trace_id"] =
      traceId;

  String ackTopic =
      "farm/" +
      config.farmId +
      "/zone/" +
      config.zoneId +
      "/actuator/" +
      actuatorId +
      "/ack";

  size_t len =
      measureJson(doc);

  if (
    mqttClient.beginMessage(
      ackTopic.c_str(),
      len,
      false,
      1
    )
  ) {

    serializeJson(
      doc,
      mqttClient
    );

    return mqttClient.endMessage();
  }

  return false;
}
