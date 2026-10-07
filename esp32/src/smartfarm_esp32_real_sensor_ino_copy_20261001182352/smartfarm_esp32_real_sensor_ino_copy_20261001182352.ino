#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>

const char* ssid = "singha wifi";
const char* password = "@e22mgp!1234";
const char* mqtt_server = "192.168.1.60";

const char* mqtt_user = "esp32_001";
const char* mqtt_pass = "123456"; // ใช้รหัสผ่านจริงที่ตั้งไว้

WiFiClient espClient;
PubSubClient client(espClient);

const char* clientID = "esp32_001";
const char* pubTopic = "farm/farm_001/zone/zone_01/sensor/soil_moisture_01/reading";
const char* subTopic = "farm/farm_001/zone/zone_01/actuator/water_pump_01/command";
const char* stateTopic = "farm/farm_001/zone/zone_01/actuator/water_pump_01/state";

// กำหนดพินควบคุมรีเลย์ (ใช้ GPIO 23 ที่ปลอดภัยต่อการ Boot)
const int RELAY_PIN = 23;

// รีเลย์ทั่วไปมักเป็น Active LOW (LOW = เปิด, HIGH = ปิด)
const boolean RELAY_ON = LOW;
const boolean RELAY_OFF = HIGH;

const int SOIL_PIN = 34;
unsigned long lastMsg = 0;
const long interval = 5000;

// ค่า Calibration ที่ได้จากฮาร์ดแวร์จริง
const int WET_RAW = 0;
const int DRY_RAW = 4095;

void setup_wifi() {
  delay(10);
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi connected");
}

void callback(char* topic, byte* payload, unsigned int length) {
  String message = "";
  for (int i = 0; i < length; i++) {
    message += (char)payload[i];
  }
  Serial.printf("Command received [%s]: %s\n", topic, message.c_str());

  // ตรวจสอบ Topic คำสั่งปั๊มน้ำ
  if (String(topic) == subTopic) {
    if (message == "ON") {
      digitalWrite(RELAY_PIN, RELAY_ON);
      Serial.println("-> Real Actuator: Water Pump turned ON");
      client.publish(stateTopic, "ON");
    } else if (message == "OFF") {
      digitalWrite(RELAY_PIN, RELAY_OFF);
      Serial.println("-> Real Actuator: Water Pump turned OFF");
      client.publish(stateTopic, "OFF");
    }
  }
}

void reconnect() {
  while (!client.connected()) {
    if (client.connect(clientID, mqtt_user, mqtt_pass)) {
      // Subscribe รับคำสั่งควบคุมแอคชูเอเตอร์
      client.subscribe(subTopic);
    } else {
      delay(5000);
    }
  }
}

void setup() {
  Serial.begin(115200);

  // ตั้งค่าพินรีเลย์และปิดการทำงานเริ่มต้นเพื่อความปลอดภัย
  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, RELAY_OFF);

  setup_wifi();
  client.setServer(mqtt_server, 1883);
  client.setCallback(callback);
}

void loop() {
  if (!client.connected()) {
    reconnect();
  }
  client.loop();

  unsigned long now = millis();
  if (now - lastMsg > interval) {
    lastMsg = now;

    // 1. อ่านค่าดิบ
    int rawValue = analogRead(SOIL_PIN);

    // 2. คำนวณแปลงค่า Raw (0-4095) เป็นเปอร์เซ็นต์ความชื้น (0-100%)
    float moisturePercent = (1.0 - ((float)(rawValue - WET_RAW) / (DRY_RAW - WET_RAW))) * 100.0;
    
    // จำกัดค่าให้อยู่ในช่วง 0 ถึง 100 เสมอ
    if (moisturePercent < 0) moisturePercent = 0;
    if (moisturePercent > 100) moisturePercent = 100;

    // สร้าง JSON Payload
    JsonDocument doc;
    doc["message_id"] = String(millis());
    doc["device_id"] = "esp32_001";
    doc["zone_id"] = "zone_01";
    doc["sensor_code"] = "soil_moisture_01";
    doc["value"] = serialized(String(moisturePercent, 1));
    doc["unit"] = "%";
    doc["status"] = "valid";
    doc["raw_value"] = rawValue;

    char jsonBuffer[256];
    serializeJson(doc, jsonBuffer);

    Serial.print("Publishing calibrated soil moisture: ");
    Serial.println(jsonBuffer);
    client.publish(pubTopic, jsonBuffer);
  }
}