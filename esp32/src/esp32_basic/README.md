# ESP32 Basic Firmware

## Purpose

Phase 5 firmware provides:

- Wi-Fi provisioning through WiFiManager Captive Portal
- MQTT configuration stored in ESP32 NVS
- MQTT authentication
- MQTT Last Will and Testament
- Retained online/offline device status
- Heartbeat every 30 seconds
- Automatic Wi-Fi and MQTT reconnection
- Configuration reset through the BOOT button

## Supported MQTT Topic

```text
farm/{farm_id}/esp32/{esp32_id}/status
farm/{farm_id}/esp32/{esp32_id}/telemetry
```

Phase 5 publishes status only.

## Required Arduino Libraries

| Library | Purpose |
|---|---|
| WiFiManager | Wi-Fi and runtime configuration portal |
| ArduinoMqttClient | MQTT QoS 1 and Last Will support |
| ArduinoJson | JSON message payload |

## Provisioning Procedure

1. Upload firmware to ESP32.
2. ESP32 creates Wi-Fi Access Point named similar to:

   ```text
   smartfarm-setup-ABC123
   ```

3. Connect a phone or MacBook to that Access Point.
4. Open:

   ```text
   http://192.168.4.1
   ```

5. Select the farm Wi-Fi network and enter Wi-Fi password.
6. Fill in Smart Farm settings:

   | Field | Phase 4 Test Value |
   |---|---|
   | Farm ID | `farm_001` |
   | Zone ID | `zone_01` |
   | ESP32 ID | `esp32_001` |
   | MQTT Hostname or IP | Raspberry Pi address from DHCP reservation |
   | MQTT Port | `1883` |
   | MQTT Username | `esp32_001` |
   | MQTT Password | Password created in Phase 4 |
   | NTP Server | `pool.ntp.org` or a local NTP server |

7. Save configuration.
8. ESP32 connects to Wi-Fi and MQTT automatically.

## Reset Procedure

1. Disconnect ESP32 power.
2. Hold the physical `BOOT` button.
3. Reconnect power while continuing to hold `BOOT`.
4. Hold for at least 3 seconds.
5. Release the button.
6. ESP32 clears Wi-Fi and Smart Farm configuration, then restarts.
7. Connect to the provisioning Access Point again.

## MQTT Status Example

```json
{
  "message_id": "status-12345",
  "farm_id": "farm_001",
  "zone_id": "zone_01",
  "esp32_id": "esp32_001",
  "status": "online",
  "reason": "heartbeat",
  "firmware_version": "0.1.0",
  "rssi": -62,
  "uptime_seconds": 120,
  "ip_address": "assigned-at-runtime",
  "timestamp": "2026-09-29T10:00:00Z"
}
```

## Security Notes

- Never hard-code Wi-Fi credentials or MQTT credentials in firmware.
- MQTT credentials are entered only during local provisioning.
- Treat the provisioning Access Point as temporary and physically controlled.
- Do not provision devices on an untrusted network.
- Every ESP32 must have a unique MQTT username, password, and ACL entry in production.
- Configuration is stored in ESP32 NVS. NVS is not a substitute for hardware-backed encryption.
- Flash encryption, secure boot, MQTT TLS, and OTA signing will be planned in later security and production phases.