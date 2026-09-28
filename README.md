# SMART FARM IoT CONTROL & AI PLATFORM

ระบบควบคุมฟาร์มอัจฉริยะแบบ Local-First สำหรับตรวจวัด Sensor, ควบคุม Actuator, จัดการ Zone, ตั้ง Schedule, ทำ Automation, แจ้งเตือน, สร้างรายงาน และใช้ AI ช่วยวิเคราะห์ข้อมูล

## Core Principles

- Local Network First
- Internet Optional
- No Hard-coded IP Address
- MQTT for IoT Communication
- REST API for Web and Mobile Applications
- Safety Rules Override Automation and AI
- Open Source and Low-Cost Focus
- Scalable from a small farm to multiple farms

## Project Structure

```text
smartfarm/
├── backend/        PHP REST API, Scheduler, MQTT Consumer
├── flutter_app/    Flutter Web and Mobile Application
├── esp32/          ESP32 Firmware
├── ai/             AI Analysis and Models
├── database/       Database Schema and Migrations
├── mqtt/           MQTT Configuration and ACL
├── docs/           Technical Documentation
├── scripts/        Setup, Backup, and Maintenance Scripts
├── tests/          Integration and End-to-End Tests
└── deployment/     Raspberry Pi Deployment Files