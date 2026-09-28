Security Design
Required Controls
Password hashing using Argon2id or bcrypt
Role-Based Access Control
API authentication
MQTT authentication and ACL
Prepared SQL statements
Input validation
CSRF protection where applicable
Rate limiting
Command authorization
Audit logging
No plaintext secrets in Git
Command Safety
Every control command requires permission check, device online check, safety validation, command log, acknowledgement, and timeout handling.