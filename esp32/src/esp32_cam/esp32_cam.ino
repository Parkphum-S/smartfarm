#include <Arduino.h>
#include <WiFi.h>
#include <WebServer.h>
#include <WiFiManager.h>
#include "esp_camera.h"

// ============================================================
// Smart Farm ESP32-CAM
// HTTP Camera Server v0.2.0
// Board: AI Thinker ESP32-CAM
// ============================================================

// ============================================================
// AI Thinker ESP32-CAM Pin Map
// ============================================================

#define PWDN_GPIO_NUM     32
#define RESET_GPIO_NUM    -1
#define XCLK_GPIO_NUM      0
#define SIOD_GPIO_NUM     26
#define SIOC_GPIO_NUM     27

#define Y9_GPIO_NUM       35
#define Y8_GPIO_NUM       34
#define Y7_GPIO_NUM       39
#define Y6_GPIO_NUM       36
#define Y5_GPIO_NUM       21
#define Y4_GPIO_NUM       19
#define Y3_GPIO_NUM       18
#define Y2_GPIO_NUM        5
#define VSYNC_GPIO_NUM    25
#define HREF_GPIO_NUM     23
#define PCLK_GPIO_NUM     22

#define LED_GPIO_NUM       4

// ============================================================
// HTTP Server
// ============================================================

WebServer server(80);

// ============================================================
// Camera
// ============================================================

bool initCamera() {
  camera_config_t config;

  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;

  config.pin_d0 = Y2_GPIO_NUM;
  config.pin_d1 = Y3_GPIO_NUM;
  config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM;
  config.pin_d4 = Y6_GPIO_NUM;
  config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM;
  config.pin_d7 = Y9_GPIO_NUM;

  config.pin_xclk = XCLK_GPIO_NUM;
  config.pin_pclk = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM;
  config.pin_href = HREF_GPIO_NUM;
  config.pin_sccb_sda = SIOD_GPIO_NUM;
  config.pin_sccb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;

  config.xclk_freq_hz = 10000000;
  config.pixel_format = PIXFORMAT_JPEG;

  config.frame_size = FRAMESIZE_UXGA;
  config.grab_mode = CAMERA_GRAB_WHEN_EMPTY;
  config.fb_location = CAMERA_FB_IN_PSRAM;
  config.jpeg_quality = 12;
  config.fb_count = 1;

  if (psramFound()) {
    config.jpeg_quality = 10;
    config.fb_count = 2;
    config.grab_mode = CAMERA_GRAB_LATEST;
  } else {
    config.frame_size = FRAMESIZE_SVGA;
    config.fb_location = CAMERA_FB_IN_DRAM;
  }

  esp_err_t err = esp_camera_init(&config);

  if (err != ESP_OK) {
    Serial.printf("Camera init failed: 0x%X\n", err);
    return false;
  }

  sensor_t *sensor = esp_camera_sensor_get();

  if (sensor != nullptr) {
    Serial.printf("Camera sensor PID: 0x%04X\n", sensor->id.PID);
    Serial.printf("Camera sensor VER: 0x%02X\n", sensor->id.VER);

    if (config.pixel_format == PIXFORMAT_JPEG) {
      sensor->set_framesize(sensor, FRAMESIZE_QVGA);
      Serial.println("Camera sensor frame size: QVGA");
    }
  }

  Serial.println("Camera init: PASS");

  Serial.println("Camera capture test: START");

  camera_fb_t *fb = esp_camera_fb_get();

  if (fb == nullptr) {
    Serial.println("Camera capture test: FAIL (fb=null)");
  } else {
    Serial.printf(
        "Camera capture test: PASS (%ux%u, %u bytes)\n",
        fb->width,
        fb->height,
        fb->len
    );

    esp_camera_fb_return(fb);
  }

  return true;
}

// ============================================================
// HTTP Handlers
// ============================================================

void handleRoot() {
  String message;

  message += "Smart Farm ESP32-CAM\n";
  message += "Firmware: 0.2.0\n";
  message += "Camera: OK\n";
  message += "HTTP Server: OK\n";
  message += "\n";
  message += "Endpoints:\n";
  message += "GET /capture\n";

  server.send(200, "text/plain", message);
}

void handleCapture() {
  Serial.println("[HTTP] /capture");

  camera_fb_t *fb = esp_camera_fb_get();

  if (fb == nullptr) {
    Serial.println("[CAMERA] Capture failed");

    server.send(
        500,
        "text/plain",
        "Camera capture failed"
    );

    return;
  }

  Serial.printf(
      "[CAMERA] JPEG %ux%u %u bytes\n",
      fb->width,
      fb->height,
      fb->len
  );

  server.sendHeader("Cache-Control", "no-store");
  server.send_P(
      200,
      "image/jpeg",
      reinterpret_cast<const char *>(fb->buf),
      fb->len
  );

  esp_camera_fb_return(fb);
}

void handleNotFound() {
  server.send(
      404,
      "text/plain",
      "Not Found"
  );
}

// ============================================================
// HTTP Server Setup
// ============================================================

void initHttpServer() {
  server.on("/", HTTP_GET, handleRoot);
  server.on("/capture", HTTP_GET, handleCapture);
  server.onNotFound(handleNotFound);

  server.begin();

  Serial.println("[HTTP] Server started on port 80");
  Serial.println("[HTTP] GET /");
  Serial.println("[HTTP] GET /capture");
}

// ============================================================
// Wi-Fi
// ============================================================

bool initWiFi() {
  WiFi.mode(WIFI_STA);

  String apName =
      "smartfarm-camera-" +
      String((uint32_t)(ESP.getEfuseMac() & 0xFFFFFF), HEX);

  WiFiManager wifiManager;

  // Keep previously saved Wi-Fi credentials.

  Serial.println("[WIFI] Connecting...");

  bool connected = wifiManager.autoConnect(apName.c_str());

  if (!connected) {
    Serial.println("[WIFI] Connection failed");
    return false;
  }

  Serial.println("[WIFI] Connected");
  Serial.print("[WIFI] IP Address: ");
  Serial.println(WiFi.localIP());

  return true;
}

// ============================================================
// Setup
// ============================================================

void setup() {
  Serial.begin(115200);
  delay(500);

  Serial.println();
  Serial.println("========================================");
  Serial.println(" Smart Farm ESP32-CAM");
  Serial.println(" AI Thinker ESP32-CAM");
  Serial.println(" Firmware v0.2.0");
  Serial.println("========================================");

  Serial.printf(
      "PSRAM: %s\n",
      psramFound() ? "FOUND" : "NOT FOUND"
  );

  // TEMPORARY WIFI ISOLATION TEST
  // Camera initialization is intentionally skipped.
  // initCamera() remains unchanged for restoration after the test.

  if (!initWiFi()) {
    Serial.println("[FATAL] Wi-Fi initialization failed");
    return;
  }

  initHttpServer();

  Serial.println("[SYSTEM] Camera server ready");
  Serial.print("[SYSTEM] Open: http://");
  Serial.print(WiFi.localIP());
  Serial.println("/");
}

// ============================================================
// Loop
// ============================================================

void loop() {
  server.handleClient();
  delay(2);
}
