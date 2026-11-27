# Ship Jingle to TestFlight

The Apple Developer Program enrollment for the Individual account is planned by 1 December 2026 and is still pending. Nothing below can be signed or uploaded until Apple approves that membership. You can still run Jingle in Expo Go, the iOS Simulator, or the web preview without that membership. Do not commit Apple passwords, API keys, `.p8` keys, or provisioning profiles. The source is public under the MIT license; signing material stays out of git.

Bundle id, already set in `app.json`: `app.jingle.ios`

## 1. Finish the Apple account

1. Enroll the Individual membership at [developer.apple.com/programs/enroll](https://developer.apple.com/programs/enroll/).
2. Use the Apple ID that should own the app. Individual accounts use a person's legal name as the seller.
3. Wait until Apple says the membership is active. Certificates and TestFlight stay locked before that.

## 2. Create the app record

1. Sign in to [App Store Connect](https://appstoreconnect.apple.com/).
2. Identifiers: register an explicit App ID `app.jingle.ios`. Do not use a wildcard. Capabilities: none beyond the defaults. Push is off; Jingle uses local notifications only.
3. Apps: new iOS app.
   - Name: Jingle
   - Primary language: English
   - Bundle ID: `app.jingle.ios`
   - SKU: `jingle-ios`
4. Leave the build empty until EAS uploads one. Export compliance is already answered in the app (`ITSAppUsesNonExemptEncryption` is false). There is no custom encryption.
5. App Privacy: Data Not Collected. Jingle has no account, analytics, or advertising. Paste the privacy policy URL. After this repo is public, use `https://github.com/m-fin/jingle-ios/blob/main/PRIVACY.md`, or host [PRIVACY.md](PRIVACY.md) on your own https page. The same text is in the app under Settings → Privacy policy. Optional: set `EXPO_PUBLIC_PRIVACY_POLICY_URL` in `.env.local` (see `.env.example`) so Settings can open that page. Do not commit `.env.local`.
6. Support URL: `https://github.com/m-fin/jingle-ios`. Age rating: no restricted content. The app does not use Sign in with Apple, payments, or tracking.

## 3. Connect EAS once

On a machine with the repo:

```bash
npm install
npm install -g eas-cli
eas login
eas init
```

`eas init` writes an EAS project id into `app.json`. That id is not a secret. Do not run `eas init` with a token checked into git, and do not commit `credentials.json`, `.p8`, or `.mobileprovision` files. Those are gitignored.

`eas.json` uses remote versioning. EAS stores the iOS build number for the production profile, so TestFlight builds increment without hand-editing the repo.

## 4. Build for TestFlight

```bash
eas build --platform ios --profile production
```

The production profile is `distribution: store` with `autoIncrement`. EAS will ask for the Apple team the first time and can create the distribution certificate and provisioning profile. Let EAS hold those credentials. They never belong in this repo.

The build runs on Expo's Macs. A Linux checkout cannot compile the iOS binary locally.

## 5. Upload

When the build status is finished:

```bash
eas submit --platform ios --profile production
```

Choose the build you just made. EAS will ask for an App Store Connect app if it cannot infer one. After the upload processes, the build appears in App Store Connect under TestFlight. Processing often takes a few minutes and sometimes longer.

## 6. Install

1. App Store Connect → Jingle → TestFlight.
2. Internal testing: add yourself. Internal testers must be App Store Connect users on the team.
3. Install TestFlight on the iPhone, accept the invite, install Jingle.
4. Open Jingle, allow notifications, and leave the clock on the nightstand if you want it to ring in the app. Locking the phone hands the alarm to a local notification.

Smoke test:

- The seeded alarm is 6:00 AM, weekdays, Dawn, snooze 9 minutes.
- Edit the time, repeat days, sound, snooze, and machine mode, then save.
- Toggle an alarm off and on.
- Tap Dark. The face goes black. Tap to bring it back.
- Preview a tone in the editor.
- Tap Try this wake on the clock. The ringing screen says PREVIEW, plays the tone, and Done leaves the alarm unchanged.
- Set an alarm one minute ahead and confirm the ringing screen, snooze, and I'm up.

## Platform limits to know before the pitch

- **Silent switch.** While Jingle is open, playback is set to play in silent mode and the clock stays awake. The Xcode app in `ios-native/` also rings on a locked phone with the switch on silent when Alarms are allowed (iOS 26) or when Jingle is left running. The Expo app still hands a locked phone to a local notification, which the Ring/Silent switch can mute. Critical Alerts (`com.apple.developer.usernotifications.critical-alerts`) are not requested.
- **Notification length.** Custom sounds must be under 30 seconds. Jingle's tones are original and shorter than that. The in-app ringing screen loops the tone until you snooze or get up. A locked phone plays the tone once.
- **64 pending notifications.** iOS keeps at most 64 scheduled local notifications. Jingle caps what it schedules and prefers the real alarm over machine mode if a phone is full of repeats.
- **Time Sensitive.** Alarm notifications use Time Sensitive interruption level so they can surface during Focus when the person allows it. Focus can still be configured to hide them.
- **No push server.** Remote notifications are disabled in the config plugin. There is nothing to host.

## Still needed before the App Store

- Apple Developer approval (planned by 1 December 2026), then the Apple ID EAS should use. `eas submit` asks for it. `eas.json` does not store it.
- Register the bundle id `app.jingle.ios` on that team. It is set in `app.json` and has not been reserved until the account exists.
- Screenshots from a real iPhone or the Simulator, a 1024 icon is already in the repo, and the privacy policy URL above.
- Whether to apply for Critical Alerts. Without that entitlement, a locked iPhone follows the silent switch.
- Whether the phone should keep snooze and extra alarms. The hardware PRD says one alarm and no snooze. This app ships both, and snooze can be turned off per alarm.
- Different wake audio later, if wanted. Replace the files in `assets/sounds` and keep the same filenames, or regenerate them with `python3 scripts/generate-sounds.py`. Do not drop in copyrighted music.
