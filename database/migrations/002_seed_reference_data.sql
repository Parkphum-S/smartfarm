-- SMART FARM IoT CONTROL & AI PLATFORM
-- Migration: 002_seed_reference_data.sql
-- Purpose: Initial reference data

USE smartfarm;

INSERT INTO roles (code, name, description) VALUES
    ('admin', 'Admin', 'Full system access including users, security, and system settings.'),
    ('manager', 'Manager', 'Manages farms, zones, devices, automation, schedules, and reports.'),
    ('operator', 'Operator', 'Views data and controls authorized devices.'),
    ('viewer', 'Viewer', 'Read-only access to authorized farm information.')
ON DUPLICATE KEY UPDATE
    name = VALUES(name),
    description = VALUES(description);

INSERT INTO sensor_types (code, name, measurement_type, default_unit, description) VALUES
    ('npk', 'NPK Sensor', 'nutrient', 'mg/kg', 'Nitrogen, phosphorus, and potassium measurement.'),
    ('soil_ph', 'Soil pH Sensor', 'ph', 'pH', 'Soil acidity and alkalinity measurement.'),
    ('soil_moisture', 'Soil Moisture Sensor', 'moisture', '%', 'Soil moisture percentage.'),
    ('water_level', 'Water Level Sensor', 'level', '%', 'Water tank, pond, or reservoir level.'),
    ('water_temperature', 'Water Temperature Sensor', 'temperature', '°C', 'Water temperature.'),
    ('air_temperature', 'Air Temperature Sensor', 'temperature', '°C', 'Ambient air temperature.'),
    ('air_humidity', 'Air Humidity Sensor', 'humidity', '%', 'Ambient relative humidity.'),
    ('light', 'Light Sensor', 'illuminance', 'lux', 'Light intensity.'),
    ('rain', 'Rain Sensor', 'rain', 'boolean', 'Rain detection.'),
    ('wind_speed', 'Wind Speed Sensor', 'wind_speed', 'm/s', 'Wind speed.'),
    ('wind_direction', 'Wind Direction Sensor', 'wind_direction', 'degree', 'Wind direction.'),
    ('solar_radiation', 'Solar Radiation Sensor', 'solar_radiation', 'W/m²', 'Solar radiation.'),
    ('air_pressure', 'Air Pressure Sensor', 'pressure', 'hPa', 'Atmospheric pressure.'),
    ('dissolved_oxygen', 'Dissolved Oxygen Sensor', 'oxygen', 'mg/L', 'Dissolved oxygen for aquaculture.'),
    ('energy_meter', 'Energy Meter', 'energy', 'kWh', 'Electrical energy consumption.')
ON DUPLICATE KEY UPDATE
    name = VALUES(name),
    measurement_type = VALUES(measurement_type),
    default_unit = VALUES(default_unit),
    description = VALUES(description);

INSERT INTO actuator_types (code, name, control_type, description) VALUES
    ('main_water_pump', 'Main Water Pump', 'relay', 'Main water supply pump.'),
    ('irrigation_pump', 'Irrigation Pump', 'relay', 'Pump for irrigation.'),
    ('fertilizer_pump', 'Fertilizer Pump', 'relay', 'Pump for fertilizer solution.'),
    ('fish_pond_pump', 'Fish Pond Pump', 'relay', 'Water circulation pump for fish pond.'),
    ('aerator', 'Oxygen or Aerator Pump', 'relay', 'Aerator for fish pond.'),
    ('irrigation_valve', 'Irrigation Valve', 'relay', 'Solenoid irrigation valve.'),
    ('farm_fan', 'Farm Fan', 'relay', 'Ventilation fan.'),
    ('farm_lighting', 'Farm Lighting', 'relay', 'Farm lighting device.'),
    ('relay_device', 'Other Relay Device', 'relay', 'Generic relay-controlled device.')
ON DUPLICATE KEY UPDATE
    name = VALUES(name),
    control_type = VALUES(control_type),
    description = VALUES(description);

INSERT INTO crops (code, name, crop_category, description) VALUES
    ('vegetable_generic', 'ผักสวนครัว', 'vegetable', 'Generic vegetable crop profile.'),
    ('chili', 'พริก', 'vegetable', 'Chili crop.'),
    ('eggplant', 'มะเขือ', 'vegetable', 'Eggplant crop.'),
    ('lettuce', 'ผักกาด', 'vegetable', 'Lettuce crop.'),
    ('kale', 'คะน้า', 'vegetable', 'Kale crop.'),
    ('cucumber', 'แตงกวา', 'vegetable', 'Cucumber crop.'),
    ('durian', 'ทุเรียน', 'fruit_tree', 'Durian fruit tree.'),
    ('mango', 'มะม่วง', 'fruit_tree', 'Mango fruit tree.'),
    ('longan', 'ลำไย', 'fruit_tree', 'Longan fruit tree.'),
    ('lime', 'มะนาว', 'fruit_tree', 'Lime fruit tree.')
ON DUPLICATE KEY UPDATE
    name = VALUES(name),
    crop_category = VALUES(crop_category),
    description = VALUES(description);

INSERT INTO schema_migrations (migration_name)
VALUES ('002_seed_reference_data.sql')
ON DUPLICATE KEY UPDATE migration_name = VALUES(migration_name);