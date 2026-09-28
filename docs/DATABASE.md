# Database Design

## Database Engine

MariaDB runs on the Raspberry Pi Local Server.

## Main Domains

| Domain | Main Tables |
|---|---|
| Identity | users, roles, user_roles |
| Farm Structure | farms, zones |
| IoT Devices | esp32_devices, sensors, actuators |
| Telemetry | sensor_readings, weather_data, soil_data |
| Device Control | device_states, device_commands |
| Automation | automation_rules, schedules |
| Alerts | alerts, notifications |
| Intelligence | crops, crop_profiles, ai_analysis |
| Audit and Logs | audit_logs, system_logs, mqtt_messages |

## Data Policy

- Store timestamps in UTC.
- Separate current state from historical data.
- Index high-volume telemetry by sensor ID and recorded timestamp.
- Use migrations for every schema change.
- Never store plaintext passwords.
EOF

cat > docs/MQTT.md <<'EOF'
# MQTT Design

## MQTT Broker

Mosquitto on Raspberry Pi is the local MQTT Broker.

## Topic Pattern

```text
farm/{farm_id}/esp32/{esp32_id}/status
farm/{farm_id}/esp32/{esp32_id}/telemetry
farm/{farm_id}/zone/{zone_id}/sensor/{sensor_id}/reading
farm/{farm_id}/zone/{zone_id}/actuator/{actuator_id}/command
farm/{farm_id}/zone/{zone_id}/actuator/{actuator_id}/ack
farm/{farm_id}/zone/{zone_id}/actuator/{actuator_id}/state
farm/{farm_id}/alert/{alert_id}
farm/{farm_id}/system/status