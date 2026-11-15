# Jingle

Your wake up morning companion. An iPhone alarm clock you can run without a paid Apple Developer account, and ship to the App Store once that account is active.

Jingle is a dark bedside clock. The time comes from the iPhone. The display can go fully black. A default alarm is ready at 6:00 AM on weekdays. You can add a few more, pick an original wake tone, turn snooze off, and play a quiet machine-mode tone before the alarm. There is no account and no server.

Designed by Matthew Finley. Source is released under the [MIT License](LICENSE). Copyright 2026 Matthew Finley.

The hardware notes in `assets/` describe a separate one-button clock (one alarm, no snooze, no phone). This repository is the iPhone app, which keeps repeat alarms and an optional snooze because a phone can hold them. Snooze can be turned off on each alarm.

## Run it without a paid Apple account

You need Node.js 22. A paid Apple Developer membership is not required for any of these:

```bash
npm install
cp .env.example .env.local   # optional; the sample has no secrets
npm test
npm run typecheck
npx expo start
```

- Press `w` for the web preview. Notifications, haptics, and brightness are limited in the browser. The clock, alarms, tones, dark face, and privacy policy all work there.
- On a phone, open the same SDK in Expo Go and scan the QR code. In-app ringing works. A standalone notification sound is part of the store build, not Expo Go.
- On a Mac, press `i` for the iOS Simulator. The Simulator does not need a paid membership. Signing a build for a physical device or TestFlight does.

Web is a preview of the interface. Locking the phone, local notifications, and the silent switch behave on a real iPhone.

## What stays on the phone

Alarms, snooze, and appearance are stored on device. Wake sounds in `assets/sounds` are original tones from `scripts/generate-sounds.py`. Do not replace them with copyrighted music.

The privacy policy is in the app (Settings → Privacy policy) and in [PRIVACY.md](PRIVACY.md).

## Configuration

Committed config uses placeholders only:

| File | What it is |
| --- | --- |
| `.env.example` | Copy to `.env.local`. The only value is an optional public https privacy-policy URL. Tokens and Apple credentials are named in comments and must stay empty in git. |
| `app.json` | Name, version `1.0.0`, bundle id `app.jingle.ios`, 1024×1024 icon, notification purpose string, export-compliance flag, and a privacy manifest that declares no tracking and no collected data. |
| `eas.json` | Simulator, internal, and App Store profiles. `submit.production` is empty so EAS asks for the Apple account at upload time instead of reading it from the repo. |

`private` is set in `package.json` so this package is not published to the npm registry. The source is still MIT.

There is no EAS project id in the repo yet. `eas init` writes one later. That id is not a secret. Signing certificates, `.p8` keys, provisioning profiles, and `credentials.json` are gitignored and must not be added. See [SECURITY.md](SECURITY.md).

To show “Privacy policy on the web” inside Settings, put an https URL in `.env.local`:

```bash
EXPO_PUBLIC_PRIVACY_POLICY_URL=https://github.com/m-fin/jingle-ios/blob/main/PRIVACY.md
```

Leave it blank and the in-app policy is still there. Use that same https URL in App Store Connect.

## App Store

Bundle id: `app.jingle.ios`  
Android package (not the v1 store target): `app.jingle`  
Icon: `assets/images/icon.png` (1024×1024, no alpha)  
Version: `1.0.0`  
Encryption: `ITSAppUsesNonExemptEncryption` is false. There is no custom cryptography.

Store signing, TestFlight, and review need the Apple Developer Program. Enrollment is planned by 1 December 2026. The steps that have to wait for that membership are in [TESTFLIGHT.md](TESTFLIGHT.md). A Linux checkout cannot compile the iOS binary; EAS builds it on a Mac once the account exists.

From the clock, **Try this wake** opens the ringing screen and plays the next alarm’s tone without changing the alarm. That is the path to confirm sound before a real morning.

## Checks

```bash
npm test
npm run typecheck
```

## Product notes

`assets/BRIEF.md`, `assets/FEATURES.md`, and `assets/PRD.md` are the hardware brief. They are not the iPhone feature list.
