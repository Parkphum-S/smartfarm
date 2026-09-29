-- SMART FARM IoT CONTROL & AI PLATFORM
-- Migration: 001_initial_schema.sql
-- Purpose: Initial relational database schema
-- Database engine: MariaDB
-- Time policy: Application stores timestamps in UTC using DATETIME(3)

CREATE DATABASE IF NOT EXISTS smartfarm
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE smartfarm;

CREATE TABLE IF NOT EXISTS schema_migrations (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    migration_name VARCHAR(255) NOT NULL,
    applied_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    UNIQUE KEY uq_schema_migrations_name (migration_name)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS roles (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    code VARCHAR(50) NOT NULL,
    name VARCHAR(100) NOT NULL,
    description VARCHAR(255) NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    UNIQUE KEY uq_roles_code (code)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS users (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    username VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    display_name VARCHAR(150) NOT NULL,
    phone_number VARCHAR(50) NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'active',
    last_login_at DATETIME(3) NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    UNIQUE KEY uq_users_username (username),
    UNIQUE KEY uq_users_email (email),
    KEY idx_users_status (status)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS user_roles (
    user_id BIGINT UNSIGNED NOT NULL,
    role_id BIGINT UNSIGNED NOT NULL,
    assigned_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (user_id, role_id),
    CONSTRAINT fk_user_roles_user
        FOREIGN KEY (user_id) REFERENCES users(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_user_roles_role
        FOREIGN KEY (role_id) REFERENCES roles(id)
        ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS farms (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    code VARCHAR(50) NOT NULL,
    name VARCHAR(150) NOT NULL,
    description TEXT NULL,
    address_text VARCHAR(500) NULL,
    latitude DECIMAL(10,7) NULL,
    longitude DECIMAL(10,7) NULL,
    timezone VARCHAR(100) NOT NULL DEFAULT 'Asia/Bangkok',
    status VARCHAR(30) NOT NULL DEFAULT 'active',
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    UNIQUE KEY uq_farms_code (code),
    KEY idx_farms_status (status)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS zones (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    farm_id BIGINT UNSIGNED NOT NULL,
    code VARCHAR(50) NOT NULL,
    name VARCHAR(150) NOT NULL,
    zone_type VARCHAR(100) NOT NULL,
    description TEXT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'active',
    sort_order INT UNSIGNED NOT NULL DEFAULT 0,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    UNIQUE KEY uq_zones_farm_code (farm_id, code),
    KEY idx_zones_farm_status (farm_id, status),
    CONSTRAINT fk_zones_farm
        FOREIGN KEY (farm_id) REFERENCES farms(id)
        ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS firmware_versions (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    version VARCHAR(100) NOT NULL,
    device_family VARCHAR(100) NOT NULL DEFAULT 'esp32',
    release_notes TEXT NULL,
    file_path VARCHAR(500) NULL,
    checksum_sha256 VARCHAR(128) NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'draft',
    released_at DATETIME(3) NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    UNIQUE KEY uq_firmware_versions_family_version (device_family, version)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS esp32_devices (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    farm_id BIGINT UNSIGNED NOT NULL,
    zone_id BIGINT UNSIGNED NULL,
    firmware_version_id BIGINT UNSIGNED NULL,
    device_code VARCHAR(100) NOT NULL,
    name VARCHAR(150) NOT NULL,
    description TEXT NULL,
    mac_address VARCHAR(17) NULL,
    ip_address VARCHAR(45) NULL,
    mqtt_client_id VARCHAR(150) NOT NULL,
    wifi_rssi INT NULL,
    uptime_seconds BIGINT UNSIGNED NULL,
    last_seen_at DATETIME(3) NULL,
    last_boot_at DATETIME(3) NULL,
    firmware_version_text VARCHAR(100) NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'offline',
    enabled TINYINT(1) NOT NULL DEFAULT 1,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    UNIQUE KEY uq_esp32_devices_farm_code (farm_id, device_code),
    UNIQUE KEY uq_esp32_devices_mqtt_client_id (mqtt_client_id),
    UNIQUE KEY uq_esp32_devices_mac_address (mac_address),
    KEY idx_esp32_devices_zone_status (zone_id, status),
    KEY idx_esp32_devices_last_seen (last_seen_at),
    CONSTRAINT fk_esp32_devices_farm
        FOREIGN KEY (farm_id) REFERENCES farms(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_esp32_devices_zone
        FOREIGN KEY (zone_id) REFERENCES zones(id)
        ON DELETE SET NULL,
    CONSTRAINT fk_esp32_devices_firmware
        FOREIGN KEY (firmware_version_id) REFERENCES firmware_versions(id)
        ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS sensor_types (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    code VARCHAR(100) NOT NULL,
    name VARCHAR(150) NOT NULL,
    measurement_type VARCHAR(100) NOT NULL,
    default_unit VARCHAR(50) NULL,
    description TEXT NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    UNIQUE KEY uq_sensor_types_code (code)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS sensors (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    farm_id BIGINT UNSIGNED NOT NULL,
    zone_id BIGINT UNSIGNED NOT NULL,
    esp32_device_id BIGINT UNSIGNED NOT NULL,
    sensor_type_id BIGINT UNSIGNED NOT NULL,
    sensor_code VARCHAR(100) NOT NULL,
    name VARCHAR(150) NOT NULL,
    hardware_identifier VARCHAR(150) NULL,
    interface_type VARCHAR(50) NOT NULL DEFAULT 'gpio',
    connection_config_json LONGTEXT NULL,
    calibration_config_json LONGTEXT NULL,
    unit VARCHAR(50) NULL,
    valid_min DECIMAL(14,4) NULL,
    valid_max DECIMAL(14,4) NULL,
    sampling_interval_seconds INT UNSIGNED NOT NULL DEFAULT 300,
    status VARCHAR(30) NOT NULL DEFAULT 'active',
    last_reading_at DATETIME(3) NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    UNIQUE KEY uq_sensors_farm_code (farm_id, sensor_code),
    KEY idx_sensors_zone_status (zone_id, status),
    KEY idx_sensors_esp32_status (esp32_device_id, status),
    KEY idx_sensors_type (sensor_type_id),
    CONSTRAINT fk_sensors_farm
        FOREIGN KEY (farm_id) REFERENCES farms(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_sensors_zone
        FOREIGN KEY (zone_id) REFERENCES zones(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_sensors_esp32
        FOREIGN KEY (esp32_device_id) REFERENCES esp32_devices(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_sensors_type
        FOREIGN KEY (sensor_type_id) REFERENCES sensor_types(id)
        ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS actuator_types (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    code VARCHAR(100) NOT NULL,
    name VARCHAR(150) NOT NULL,
    control_type VARCHAR(100) NOT NULL,
    description TEXT NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    UNIQUE KEY uq_actuator_types_code (code)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS actuators (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    farm_id BIGINT UNSIGNED NOT NULL,
    zone_id BIGINT UNSIGNED NOT NULL,
    esp32_device_id BIGINT UNSIGNED NOT NULL,
    actuator_type_id BIGINT UNSIGNED NOT NULL,
    actuator_code VARCHAR(100) NOT NULL,
    name VARCHAR(150) NOT NULL,
    gpio_identifier VARCHAR(100) NULL,
    control_config_json LONGTEXT NULL,
    safe_default_state VARCHAR(30) NOT NULL DEFAULT 'off',
    maximum_runtime_seconds INT UNSIGNED NULL,
    control_mode VARCHAR(30) NOT NULL DEFAULT 'auto',
    status VARCHAR(30) NOT NULL DEFAULT 'active',
    enabled TINYINT(1) NOT NULL DEFAULT 1,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    UNIQUE KEY uq_actuators_farm_code (farm_id, actuator_code),
    KEY idx_actuators_zone_status (zone_id, status),
    KEY idx_actuators_esp32_status (esp32_device_id, status),
    CONSTRAINT fk_actuators_farm
        FOREIGN KEY (farm_id) REFERENCES farms(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_actuators_zone
        FOREIGN KEY (zone_id) REFERENCES zones(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_actuators_esp32
        FOREIGN KEY (esp32_device_id) REFERENCES esp32_devices(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_actuators_type
        FOREIGN KEY (actuator_type_id) REFERENCES actuator_types(id)
        ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS sensor_readings (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    sensor_id BIGINT UNSIGNED NOT NULL,
    farm_id BIGINT UNSIGNED NOT NULL,
    zone_id BIGINT UNSIGNED NOT NULL,
    esp32_device_id BIGINT UNSIGNED NOT NULL,
    message_id CHAR(36) NULL,
    value_decimal DECIMAL(14,4) NULL,
    value_text VARCHAR(255) NULL,
    unit VARCHAR(50) NULL,
    quality VARCHAR(30) NOT NULL DEFAULT 'valid',
    status VARCHAR(30) NOT NULL DEFAULT 'ok',
    recorded_at DATETIME(3) NOT NULL,
    received_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    raw_payload_json LONGTEXT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_sensor_readings_message_id (message_id),
    KEY idx_sensor_readings_sensor_recorded (sensor_id, recorded_at),
    KEY idx_sensor_readings_zone_recorded (zone_id, recorded_at),
    KEY idx_sensor_readings_esp32_recorded (esp32_device_id, recorded_at),
    CONSTRAINT fk_sensor_readings_sensor
        FOREIGN KEY (sensor_id) REFERENCES sensors(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_sensor_readings_farm
        FOREIGN KEY (farm_id) REFERENCES farms(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_sensor_readings_zone
        FOREIGN KEY (zone_id) REFERENCES zones(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_sensor_readings_esp32
        FOREIGN KEY (esp32_device_id) REFERENCES esp32_devices(id)
        ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS device_states (
    actuator_id BIGINT UNSIGNED NOT NULL,
    farm_id BIGINT UNSIGNED NOT NULL,
    zone_id BIGINT UNSIGNED NOT NULL,
    esp32_device_id BIGINT UNSIGNED NOT NULL,
    actual_state VARCHAR(30) NOT NULL DEFAULT 'unknown',
    desired_state VARCHAR(30) NOT NULL DEFAULT 'unknown',
    control_mode VARCHAR(30) NOT NULL DEFAULT 'auto',
    device_health VARCHAR(30) NOT NULL DEFAULT 'unknown',
    error_code VARCHAR(100) NULL,
    error_message VARCHAR(500) NULL,
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (actuator_id),
    KEY idx_device_states_zone_health (zone_id, device_health),
    KEY idx_device_states_esp32_health (esp32_device_id, device_health),
    CONSTRAINT fk_device_states_actuator
        FOREIGN KEY (actuator_id) REFERENCES actuators(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_device_states_farm
        FOREIGN KEY (farm_id) REFERENCES farms(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_device_states_zone
        FOREIGN KEY (zone_id) REFERENCES zones(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_device_states_esp32
        FOREIGN KEY (esp32_device_id) REFERENCES esp32_devices(id)
        ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS device_state_history (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    actuator_id BIGINT UNSIGNED NOT NULL,
    actual_state VARCHAR(30) NOT NULL,
    desired_state VARCHAR(30) NULL,
    control_mode VARCHAR(30) NULL,
    device_health VARCHAR(30) NULL,
    source VARCHAR(50) NOT NULL,
    changed_at DATETIME(3) NOT NULL,
    raw_payload_json LONGTEXT NULL,
    PRIMARY KEY (id),
    KEY idx_device_state_history_actuator_changed (actuator_id, changed_at),
    CONSTRAINT fk_device_state_history_actuator
        FOREIGN KEY (actuator_id) REFERENCES actuators(id)
        ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS device_commands (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    command_id CHAR(36) NOT NULL,
    farm_id BIGINT UNSIGNED NOT NULL,
    zone_id BIGINT UNSIGNED NOT NULL,
    actuator_id BIGINT UNSIGNED NOT NULL,
    esp32_device_id BIGINT UNSIGNED NOT NULL,
    requested_by_user_id BIGINT UNSIGNED NULL,
    source VARCHAR(50) NOT NULL,
    action VARCHAR(50) NOT NULL,
    payload_json LONGTEXT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'pending',
    requested_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    sent_at DATETIME(3) NULL,
    acknowledged_at DATETIME(3) NULL,
    executed_at DATETIME(3) NULL,
    timeout_at DATETIME(3) NULL,
    error_code VARCHAR(100) NULL,
    error_message VARCHAR(500) NULL,
    trace_id CHAR(36) NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_device_commands_command_id (command_id),
    KEY idx_device_commands_actuator_requested (actuator_id, requested_at),
    KEY idx_device_commands_status_requested (status, requested_at),
    KEY idx_device_commands_trace_id (trace_id),
    CONSTRAINT fk_device_commands_farm
        FOREIGN KEY (farm_id) REFERENCES farms(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_device_commands_zone
        FOREIGN KEY (zone_id) REFERENCES zones(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_device_commands_actuator
        FOREIGN KEY (actuator_id) REFERENCES actuators(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_device_commands_esp32
        FOREIGN KEY (esp32_device_id) REFERENCES esp32_devices(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_device_commands_user
        FOREIGN KEY (requested_by_user_id) REFERENCES users(id)
        ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS automation_rules (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    farm_id BIGINT UNSIGNED NOT NULL,
    zone_id BIGINT UNSIGNED NULL,
    name VARCHAR(150) NOT NULL,
    description TEXT NULL,
    priority INT NOT NULL DEFAULT 100,
    condition_json LONGTEXT NOT NULL,
    action_json LONGTEXT NOT NULL,
    safety_config_json LONGTEXT NULL,
    enabled TINYINT(1) NOT NULL DEFAULT 1,
    last_evaluated_at DATETIME(3) NULL,
    last_triggered_at DATETIME(3) NULL,
    created_by_user_id BIGINT UNSIGNED NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_automation_rules_farm_zone_enabled (farm_id, zone_id, enabled),
    KEY idx_automation_rules_priority (priority),
    CONSTRAINT fk_automation_rules_farm
        FOREIGN KEY (farm_id) REFERENCES farms(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_automation_rules_zone
        FOREIGN KEY (zone_id) REFERENCES zones(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_automation_rules_user
        FOREIGN KEY (created_by_user_id) REFERENCES users(id)
        ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS schedules (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    farm_id BIGINT UNSIGNED NOT NULL,
    zone_id BIGINT UNSIGNED NULL,
    name VARCHAR(150) NOT NULL,
    description TEXT NULL,
    schedule_type VARCHAR(50) NOT NULL,
    cron_expression VARCHAR(100) NULL,
    start_at DATETIME(3) NULL,
    end_at DATETIME(3) NULL,
    timezone VARCHAR(100) NOT NULL DEFAULT 'Asia/Bangkok',
    action_json LONGTEXT NOT NULL,
    priority INT NOT NULL DEFAULT 100,
    enabled TINYINT(1) NOT NULL DEFAULT 1,
    last_run_at DATETIME(3) NULL,
    next_run_at DATETIME(3) NULL,
    created_by_user_id BIGINT UNSIGNED NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_schedules_farm_zone_enabled (farm_id, zone_id, enabled),
    KEY idx_schedules_next_run (next_run_at),
    CONSTRAINT fk_schedules_farm
        FOREIGN KEY (farm_id) REFERENCES farms(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_schedules_zone
        FOREIGN KEY (zone_id) REFERENCES zones(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_schedules_user
        FOREIGN KEY (created_by_user_id) REFERENCES users(id)
        ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS crops (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    code VARCHAR(100) NOT NULL,
    name VARCHAR(150) NOT NULL,
    crop_category VARCHAR(100) NOT NULL,
    description TEXT NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    UNIQUE KEY uq_crops_code (code)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS crop_profiles (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    crop_id BIGINT UNSIGNED NOT NULL,
    growth_stage VARCHAR(100) NOT NULL DEFAULT 'default',
    temperature_min DECIMAL(6,2) NULL,
    temperature_max DECIMAL(6,2) NULL,
    humidity_min DECIMAL(6,2) NULL,
    humidity_max DECIMAL(6,2) NULL,
    soil_moisture_min DECIMAL(6,2) NULL,
    soil_moisture_max DECIMAL(6,2) NULL,
    ph_min DECIMAL(6,2) NULL,
    ph_max DECIMAL(6,2) NULL,
    nitrogen_min DECIMAL(10,2) NULL,
    nitrogen_max DECIMAL(10,2) NULL,
    phosphorus_min DECIMAL(10,2) NULL,
    phosphorus_max DECIMAL(10,2) NULL,
    potassium_min DECIMAL(10,2) NULL,
    potassium_max DECIMAL(10,2) NULL,
    vpd_min DECIMAL(6,3) NULL,
    vpd_max DECIMAL(6,3) NULL,
    irrigation_requirement_json LONGTEXT NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    UNIQUE KEY uq_crop_profiles_crop_stage (crop_id, growth_stage),
    CONSTRAINT fk_crop_profiles_crop
        FOREIGN KEY (crop_id) REFERENCES crops(id)
        ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS zone_crops (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    zone_id BIGINT UNSIGNED NOT NULL,
    crop_id BIGINT UNSIGNED NOT NULL,
    crop_profile_id BIGINT UNSIGNED NULL,
    planted_at DATE NULL,
    expected_harvest_at DATE NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'active',
    notes TEXT NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_zone_crops_zone_status (zone_id, status),
    CONSTRAINT fk_zone_crops_zone
        FOREIGN KEY (zone_id) REFERENCES zones(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_zone_crops_crop
        FOREIGN KEY (crop_id) REFERENCES crops(id)
        ON DELETE RESTRICT,
    CONSTRAINT fk_zone_crops_profile
        FOREIGN KEY (crop_profile_id) REFERENCES crop_profiles(id)
        ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS weather_data (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    farm_id BIGINT UNSIGNED NOT NULL,
    zone_id BIGINT UNSIGNED NULL,
    source VARCHAR(100) NOT NULL,
    temperature_c DECIMAL(6,2) NULL,
    humidity_percent DECIMAL(6,2) NULL,
    rainfall_mm DECIMAL(10,2) NULL,
    wind_speed_mps DECIMAL(8,2) NULL,
    wind_direction_deg DECIMAL(6,2) NULL,
    solar_radiation_wm2 DECIMAL(10,2) NULL,
    pressure_hpa DECIMAL(10,2) NULL,
    rain_detected TINYINT(1) NULL,
    forecast_json LONGTEXT NULL,
    recorded_at DATETIME(3) NOT NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_weather_data_farm_recorded (farm_id, recorded_at),
    KEY idx_weather_data_zone_recorded (zone_id, recorded_at),
    CONSTRAINT fk_weather_data_farm
        FOREIGN KEY (farm_id) REFERENCES farms(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_weather_data_zone
        FOREIGN KEY (zone_id) REFERENCES zones(id)
        ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS soil_data (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    farm_id BIGINT UNSIGNED NOT NULL,
    zone_id BIGINT UNSIGNED NOT NULL,
    sensor_id BIGINT UNSIGNED NULL,
    nitrogen_value DECIMAL(12,4) NULL,
    phosphorus_value DECIMAL(12,4) NULL,
    potassium_value DECIMAL(12,4) NULL,
    ph_value DECIMAL(8,4) NULL,
    moisture_percent DECIMAL(8,4) NULL,
    temperature_c DECIMAL(8,4) NULL,
    recorded_at DATETIME(3) NOT NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_soil_data_zone_recorded (zone_id, recorded_at),
    CONSTRAINT fk_soil_data_farm
        FOREIGN KEY (farm_id) REFERENCES farms(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_soil_data_zone
        FOREIGN KEY (zone_id) REFERENCES zones(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_soil_data_sensor
        FOREIGN KEY (sensor_id) REFERENCES sensors(id)
        ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS alerts (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    alert_code CHAR(36) NOT NULL,
    farm_id BIGINT UNSIGNED NOT NULL,
    zone_id BIGINT UNSIGNED NULL,
    esp32_device_id BIGINT UNSIGNED NULL,
    sensor_id BIGINT UNSIGNED NULL,
    actuator_id BIGINT UNSIGNED NULL,
    severity VARCHAR(30) NOT NULL,
    alert_type VARCHAR(100) NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'open',
    source VARCHAR(50) NOT NULL,
    opened_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    acknowledged_at DATETIME(3) NULL,
    acknowledged_by_user_id BIGINT UNSIGNED NULL,
    resolved_at DATETIME(3) NULL,
    resolved_by_user_id BIGINT UNSIGNED NULL,
    metadata_json LONGTEXT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_alerts_alert_code (alert_code),
    KEY idx_alerts_farm_status_opened (farm_id, status, opened_at),
    KEY idx_alerts_zone_status_opened (zone_id, status, opened_at),
    KEY idx_alerts_severity_status (severity, status),
    CONSTRAINT fk_alerts_farm
        FOREIGN KEY (farm_id) REFERENCES farms(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_alerts_zone
        FOREIGN KEY (zone_id) REFERENCES zones(id)
        ON DELETE SET NULL,
    CONSTRAINT fk_alerts_esp32
        FOREIGN KEY (esp32_device_id) REFERENCES esp32_devices(id)
        ON DELETE SET NULL,
    CONSTRAINT fk_alerts_sensor
        FOREIGN KEY (sensor_id) REFERENCES sensors(id)
        ON DELETE SET NULL,
    CONSTRAINT fk_alerts_actuator
        FOREIGN KEY (actuator_id) REFERENCES actuators(id)
        ON DELETE SET NULL,
    CONSTRAINT fk_alerts_ack_user
        FOREIGN KEY (acknowledged_by_user_id) REFERENCES users(id)
        ON DELETE SET NULL,
    CONSTRAINT fk_alerts_resolved_user
        FOREIGN KEY (resolved_by_user_id) REFERENCES users(id)
        ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS notifications (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    alert_id BIGINT UNSIGNED NULL,
    user_id BIGINT UNSIGNED NULL,
    channel VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'pending',
    sent_at DATETIME(3) NULL,
    read_at DATETIME(3) NULL,
    error_message VARCHAR(500) NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_notifications_user_status_created (user_id, status, created_at),
    KEY idx_notifications_alert (alert_id),
    CONSTRAINT fk_notifications_alert
        FOREIGN KEY (alert_id) REFERENCES alerts(id)
        ON DELETE SET NULL,
    CONSTRAINT fk_notifications_user
        FOREIGN KEY (user_id) REFERENCES users(id)
        ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ai_analysis (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    analysis_code CHAR(36) NOT NULL,
    farm_id BIGINT UNSIGNED NOT NULL,
    zone_id BIGINT UNSIGNED NULL,
    crop_id BIGINT UNSIGNED NULL,
    analysis_type VARCHAR(100) NOT NULL,
    risk_level VARCHAR(30) NOT NULL,
    risk_type VARCHAR(100) NULL,
    recommendation TEXT NOT NULL,
    explanation TEXT NOT NULL,
    confidence DECIMAL(5,4) NULL,
    suggested_action_json LONGTEXT NULL,
    input_snapshot_json LONGTEXT NOT NULL,
    requires_human_approval TINYINT(1) NOT NULL DEFAULT 1,
    status VARCHAR(30) NOT NULL DEFAULT 'active',
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    expires_at DATETIME(3) NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_ai_analysis_code (analysis_code),
    KEY idx_ai_analysis_farm_zone_created (farm_id, zone_id, created_at),
    CONSTRAINT fk_ai_analysis_farm
        FOREIGN KEY (farm_id) REFERENCES farms(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_ai_analysis_zone
        FOREIGN KEY (zone_id) REFERENCES zones(id)
        ON DELETE SET NULL,
    CONSTRAINT fk_ai_analysis_crop
        FOREIGN KEY (crop_id) REFERENCES crops(id)
        ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS mqtt_messages (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    message_id CHAR(36) NULL,
    farm_id BIGINT UNSIGNED NULL,
    esp32_device_id BIGINT UNSIGNED NULL,
    direction VARCHAR(20) NOT NULL,
    topic VARCHAR(500) NOT NULL,
    qos TINYINT UNSIGNED NOT NULL DEFAULT 0,
    retained TINYINT(1) NOT NULL DEFAULT 0,
    payload_json LONGTEXT NULL,
    processing_status VARCHAR(30) NOT NULL DEFAULT 'received',
    error_message VARCHAR(500) NULL,
    received_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    processed_at DATETIME(3) NULL,
    trace_id CHAR(36) NULL,
    PRIMARY KEY (id),
    KEY idx_mqtt_messages_topic_received (topic(191), received_at),
    KEY idx_mqtt_messages_esp32_received (esp32_device_id, received_at),
    KEY idx_mqtt_messages_status_received (processing_status, received_at),
    KEY idx_mqtt_messages_trace_id (trace_id),
    CONSTRAINT fk_mqtt_messages_farm
        FOREIGN KEY (farm_id) REFERENCES farms(id)
        ON DELETE SET NULL,
    CONSTRAINT fk_mqtt_messages_esp32
        FOREIGN KEY (esp32_device_id) REFERENCES esp32_devices(id)
        ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS system_logs (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    level VARCHAR(20) NOT NULL,
    component VARCHAR(100) NOT NULL,
    message TEXT NOT NULL,
    farm_id BIGINT UNSIGNED NULL,
    zone_id BIGINT UNSIGNED NULL,
    esp32_device_id BIGINT UNSIGNED NULL,
    user_id BIGINT UNSIGNED NULL,
    trace_id CHAR(36) NULL,
    context_json LONGTEXT NULL,
    logged_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_system_logs_component_logged (component, logged_at),
    KEY idx_system_logs_level_logged (level, logged_at),
    KEY idx_system_logs_trace_id (trace_id),
    CONSTRAINT fk_system_logs_farm
        FOREIGN KEY (farm_id) REFERENCES farms(id)
        ON DELETE SET NULL,
    CONSTRAINT fk_system_logs_zone
        FOREIGN KEY (zone_id) REFERENCES zones(id)
        ON DELETE SET NULL,
    CONSTRAINT fk_system_logs_esp32
        FOREIGN KEY (esp32_device_id) REFERENCES esp32_devices(id)
        ON DELETE SET NULL,
    CONSTRAINT fk_system_logs_user
        FOREIGN KEY (user_id) REFERENCES users(id)
        ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS dashboard_layouts (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    farm_id BIGINT UNSIGNED NOT NULL,
    zone_id BIGINT UNSIGNED NULL,
    user_id BIGINT UNSIGNED NULL,
    name VARCHAR(150) NOT NULL,
    description TEXT NULL,
    layout_scope VARCHAR(30) NOT NULL DEFAULT 'farm',
    is_default TINYINT(1) NOT NULL DEFAULT 0,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_dashboard_layouts_farm_zone (farm_id, zone_id),
    KEY idx_dashboard_layouts_user (user_id),
    CONSTRAINT fk_dashboard_layouts_farm
        FOREIGN KEY (farm_id) REFERENCES farms(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_dashboard_layouts_zone
        FOREIGN KEY (zone_id) REFERENCES zones(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_dashboard_layouts_user
        FOREIGN KEY (user_id) REFERENCES users(id)
        ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS dashboard_widgets (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    dashboard_layout_id BIGINT UNSIGNED NOT NULL,
    widget_type VARCHAR(100) NOT NULL,
    title VARCHAR(150) NULL,
    position_x INT NOT NULL DEFAULT 0,
    position_y INT NOT NULL DEFAULT 0,
    width INT NOT NULL DEFAULT 1,
    height INT NOT NULL DEFAULT 1,
    configuration_json LONGTEXT NOT NULL,
    sort_order INT NOT NULL DEFAULT 0,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_dashboard_widgets_layout_position (dashboard_layout_id, position_y, position_x),
    CONSTRAINT fk_dashboard_widgets_layout
        FOREIGN KEY (dashboard_layout_id) REFERENCES dashboard_layouts(id)
        ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS audit_logs (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id BIGINT UNSIGNED NULL,
    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(100) NOT NULL,
    entity_id VARCHAR(100) NULL,
    farm_id BIGINT UNSIGNED NULL,
    zone_id BIGINT UNSIGNED NULL,
    ip_address VARCHAR(45) NULL,
    user_agent VARCHAR(500) NULL,
    result VARCHAR(30) NOT NULL,
    before_data_json LONGTEXT NULL,
    after_data_json LONGTEXT NULL,
    trace_id CHAR(36) NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_audit_logs_user_created (user_id, created_at),
    KEY idx_audit_logs_entity (entity_type, entity_id),
    KEY idx_audit_logs_farm_created (farm_id, created_at),
    KEY idx_audit_logs_trace_id (trace_id),
    CONSTRAINT fk_audit_logs_user
        FOREIGN KEY (user_id) REFERENCES users(id)
        ON DELETE SET NULL,
    CONSTRAINT fk_audit_logs_farm
        FOREIGN KEY (farm_id) REFERENCES farms(id)
        ON DELETE SET NULL,
    CONSTRAINT fk_audit_logs_zone
        FOREIGN KEY (zone_id) REFERENCES zones(id)
        ON DELETE SET NULL
) ENGINE=InnoDB;

INSERT INTO schema_migrations (migration_name)
VALUES ('001_initial_schema.sql')
ON DUPLICATE KEY UPDATE migration_name = VALUES(migration_name);