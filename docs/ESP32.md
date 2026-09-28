ESP32 Firmware Design
Responsibilities
Connect to farm Wi-Fi.
Connect and reconnect to local MQTT Broker.
Publish heartbeat and telemetry.
Read configured sensors.
Receive and validate actuator commands.
Control relays safely.
Publish command acknowledgement and actual device state.
Apply local maximum runtime fail-safe.

Security Rules
Do not hard-code Wi-Fi or MQTT credentials in source code.
Use provisioning or protected configuration storage.
Accept commands only from authorized MQTT topics.
Reject invalid command payloads. EOF