# Database Design

## Database Engine

- Engine: MariaDB
- Database Name: `smartfarm`
- Character Set: `utf8mb4`
- Collation: `utf8mb4_unicode_ci`
- Storage Engine: InnoDB
- Timestamp Policy: Store application timestamps in UTC using `DATETIME(3)`

## Design Principles

- Local-first database hosted on Raspberry Pi.
- Relational schema with primary keys and foreign keys.
- Current state is separated from historical telemetry.
- Sensor and actuator definitions are dynamic.
- Every schema change uses a new SQL migration.
- Credentials and secrets are stored outside Git.
- Application database user has only required privileges.

## Main Domains

| Domain | Tables |
|---|---|
| Migration | `schema_migrations` |
| User and Access | `users`, `roles`, `user_roles` |
| Farm Structure | `farms`, `zones` |
| ESP32 | `esp32_devices`, `firmware_versions` |
| Sensor | `sensor_types`, `sensors`, `sensor_readings` |
| Actuator | `actuator_types`, `actuators`, `device_states`, `device_state_history`, `device_commands` |
| Automation | `automation_rules`, `schedules` |
| Crop | `crops`, `crop_profiles`, `zone_crops` |
| Environment | `weather_data`, `soil_data` |
| Alert | `alerts`, `notifications` |
| AI | `ai_analysis` |
| Dashboard | `dashboard_layouts`, `dashboard_widgets` |
| Logging | `mqtt_messages`, `system_logs`, `audit_logs` |

## Current State and Historical Data

| Data Type | Current Data Table | Historical Data Table |
|---|---|---|
| Actuator State | `device_states` | `device_state_history` |
| Sensor Value | Latest record queried from `sensor_readings` initially | `sensor_readings` |
| ESP32 Status | `esp32_devices` | `mqtt_messages`, `system_logs` |
| Command | Latest status in `device_commands` | `device_commands`, `audit_logs` |

## Telemetry Retention Strategy

Initial implementation stores raw readings in `sensor_readings`.

Future optimization:

1. Retain detailed raw telemetry for a configurable period.
2. Create hourly and daily aggregation tables for reporting.
3. Archive or delete expired raw data according to retention policy.
4. Review indexes and database size monthly.
5. Consider time-based table partitioning only after real volume justifies it.

## Migration Rules

1. Never modify a migration already applied to production.
2. Create the next ordered migration file instead.
3. Test every migration on a non-production database first.
4. Take a database backup before structural changes.
5. Record the migration in `schema_migrations`.
6. Keep migrations in Git.

## Security Rules

- Do not use MariaDB root account from the application.
- Use prepared statements in PHP.
- Do not store plaintext passwords.
- Restrict database user to `localhost`.
- Do not expose port `3306` to the network unless a future justified requirement exists.
- Store database credentials in `/etc/smartfarm/database.env`.
- Do not commit `.env` or server credential files into Git.