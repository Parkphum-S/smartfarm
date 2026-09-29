# MQTT Design

## Broker

- Broker: Eclipse Mosquitto
- Host: Raspberry Pi Local IoT Gateway
- Transport: MQTT over TCP in the Local Network
- Default Port: `1883`
- Anonymous Access: Disabled
- Authentication: Username and password
- Authorization: Topic-based ACL
- Persistence: Enabled

## Security Principles

- Each ESP32 has a unique MQTT username and password.
- Each ESP32 receives only the ACL permissions it requires.
- Backend uses a dedicated MQTT account.
- Flutter Web and Mobile must access MQTT indirectly through the Backend API.
- MQTT credentials are stored outside Git.
- MQTT port is limited to the local LAN by UFW.
- Device commands are never retained.
- TLS is planned for the Security and Production hardening phase.

## Topic Standard

```text
farm/{farm_id}/esp32/{esp32_id}/status
farm/{farm_id}/esp32/{esp32_id}/telemetry

farm/{farm_id}/zone/{zone_id}/sensor/{sensor_id}/reading

farm/{farm_id}/zone/{zone_id}/actuator/{actuator_id}/command
farm/{farm_id}/zone/{zone_id}/actuator/{actuator_id}/ack
farm/{farm_id}/zone/{zone_id}/actuator/{actuator_id}/state

farm/{farm_id}/alert/{alert_id}
farm/{farm_id}/system/status
```

## Topic Ownership

| Topic Type | Publisher | Subscriber | Retained |
|---|---|---|---|
| ESP32 Status | ESP32 | Backend | Yes |
| ESP32 Telemetry | ESP32 | Backend | No |
| Sensor Reading | ESP32 | Backend | No |
| Actuator Command | Backend | ESP32 | No |
| Command ACK | ESP32 | Backend | No |
| Actuator State | ESP32 | Backend | Yes |
| Alert | Backend | Realtime Service | No |
| System Status | Backend | Authorized Services | Yes |

## Quality of Service

| Message Type | QoS |
|---|---:|
| Status | 1 |
| Sensor Reading | 1 |
| Device Command | 1 |
| Device ACK | 1 |
| Device State | 1 |
| Non-critical Telemetry | 0 or 1 |

## Last Will and Testament

Every ESP32 must configure an LWT message before connecting:

```text
Topic: farm/{farm_id}/esp32/{esp32_id}/status
Payload status: offline
QoS: 1
Retain: true
```

After successful connection, ESP32 must publish its `online` status to the same topic with QoS 1 and Retain enabled.

## Command Safety Rules

- Commands must contain `command_id`.
- Commands must contain `trace_id`.
- Commands must not use MQTT Retain.
- ESP32 must validate command structure before execution.
- ESP32 must publish an ACK after processing a command.
- ESP32 must enforce local maximum runtime fail-safe.
- Backend must record command lifecycle in `device_commands`.

## Example Sensor Reading

```json
{
  "message_id": "uuid",
  "farm_id": "farm_001",
  "esp32_id": "esp32_001",
  "zone_id": "zone_01",
  "sensor_id": "soil_moisture_001",
  "timestamp": "2026-09-29T10:00:00Z",
  "value": 32.5,
  "unit": "%",
  "quality": "valid",
  "status": "ok"
}
```