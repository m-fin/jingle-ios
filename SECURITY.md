# Security

Jingle has no backend. Alarms and settings stay on the device. The repository must not contain signing material or account tokens.

Do not commit:

- `.env` or `.env.local` (`.env.example` is the only env file that belongs in git)
- Expo tokens, Apple IDs used as secrets, or App Store Connect API keys
- Certificates and keys (`.p8`, `.p12`, `.cer`, `.key`, `.pem`)
- Provisioning profiles (`.mobileprovision`)
- `credentials.json`, `GoogleService-Info.plist`, or `google-services.json`

Let EAS hold distribution certificates. Steps for a store build are in [TESTFLIGHT.md](TESTFLIGHT.md).

To report a vulnerability, open a GitHub issue and leave live credentials out of the report.
