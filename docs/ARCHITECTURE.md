# System Architecture


## Architecture Style


SMART FARM uses a Local-First Edge Architecture.


```text

ESP32 → MQTT Broker on Raspberry Pi → Backend Services → MariaDB

                                             ↓

                                   REST API / Realtime

                                             ↓

                                  Flutter Web / Mobile