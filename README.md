# Jingle

Your wake up morning companion. A native iPhone alarm clock for Frog Finley, built with Expo SDK 58, TypeScript, and expo-router.

Jingle is the bedside clock from the product brief: a dark face, one obvious alarm, time taken from the phone instead of a manual, and a display that can go fully black. The iPhone app also keeps repeat alarms, original wake tones, snooze, and a gentle machine-mode tone, because a phone can hold more than the one-button hardware.

Bundle id: `app.jingle.ios`

## Run

```bash
npm install
npm run typecheck
npm test
npx expo start
```

Press `i` for the iOS simulator on a Mac, or scan the QR code with the Expo Go app. Web is a preview of the interface; locking, notifications, haptics, and brightness behave on a real iPhone.

## What stays on the phone

Alarms, snooze, and appearance are stored on device with Async Storage. There is no account and no network API. Wake sounds in `assets/sounds` are original tones synthesized by `scripts/generate-sounds.py`.

## TestFlight

See [TESTFLIGHT.md](TESTFLIGHT.md). The production profile lives in `eas.json`. An Apple Developer membership is still required before a build can be signed.

## Product notes

The hardware PRD locks one alarm, no snooze, and no phone app. This iOS app follows the phone brief instead: create, edit, and repeat alarms, snooze, local notifications, a bedside clock, dark and day faces, and haptics. The default alarm is still 6:00 AM on weekdays.
