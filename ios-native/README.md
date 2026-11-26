# Jingle for Xcode

Native SwiftUI alarm clock for iPhone. Bundle id `app.jingle.ios`. Version 1.0.0 (1).

Designed by Matthew Finley. The source is MIT, same as the rest of this repository. Copyright 2026 Matthew Finley.

This folder sits beside the Expo app. It does not replace it. Alarms are dismiss-only. The featured wake is an original synthesis of Jingle Bells: sleigh-bell clusters, a warm body tone, and a smooth rise in volume.

Jingle keeps alarms on the phone. There is no account, no tracking, and no collected data. The privacy manifest declares UserDefaults reason `CA92.1` only.

## Open it on a Mac

You need Xcode 16 or newer and the Individual Apple Developer Program membership. A free Personal Team cannot sign Time Sensitive notifications or the App Group, so a device build waits until that membership is active. See [TESTFLIGHT.md](../TESTFLIGHT.md). Do not commit certificates, profiles, `.p8` keys, or passwords.

1. Install Xcode from the Mac App Store and open it once so it finishes its components.
2. Plug in the iPhone, tap Trust, and keep it unlocked for the first install.
3. In Terminal, or from Finder, open the project:

   ```bash
   open ios-native/Jingle.xcodeproj
   ```

4. The scheme list should show **Jingle**. If it does not, choose Product → Scheme → Jingle.
5. Set the run destination to your iPhone, not a simulator. The locked-phone check below needs a real device.
6. Select the **Jingle** target, then Signing & Capabilities. Set **Team** to your Individual Team. Leave the bundle id as `app.jingle.ios`.
7. Select the **JingleWidgets** target and set the same team. Leave its bundle id as `app.jingle.ios.widgets`.
8. Let Xcode register these capabilities. Do not add any other entitlement.
   - App Group `group.app.jingle.ios` on both targets
   - Time Sensitive Notifications on the app target only
9. The App ID `app.jingle.ios` is the same one the Expo app uses. Adding the App Group and Time Sensitive Notifications does not turn on remote push. Do not enable Critical Alerts. That entitlement is not in this project, and adding it without Apple’s prior approval breaks signing.
10. Press Run.

On first launch Jingle asks for notifications (alert, sound, and badge). Then:

- Settings → Notifications → Jingle: allow notifications, sounds, and Time Sensitive Notifications.
- Settings → Jingle → Live Activities: on.
- Set the Ring/Silent switch to Ring before a locked-phone test.

The app group is how the home screen widget and the Live Activity read the next alarm. If the group is missing, the widget stays empty even though the app itself still stores alarms.

`project.yml` describes the same targets for XcodeGen. The checked-in `Jingle.xcodeproj` is the project to open. You do not need to regenerate it.

## What the morning does

The main screen shows the next alarm, a countdown, the alarm list, and a **+** button. Add or edit an alarm to set the time, a label, weekday pills, a wake tone, and how long the volume takes to rise. **Try this wake** previews the rise. Jingle Bells is the featured tone. Hearth, Amber, Linen, and Tide are quieter drones.

An empty weekday row rings once and then turns off. Weekdays, weekends, and every day keep repeating. Dismiss is the only action, in the app, on the notification, and on the Live Activity.

While a wake is playing, Jingle uses an audio session with category Playback and Mix With Others, plus the `audio` background mode. That session follows the volume buttons and keeps going if you leave the app. It also mixes with the iOS Clock app, so the two can sound together.

A locked iPhone still starts from a local notification. That notification uses the Time Sensitive interruption level and a short Jingle Bells file. It follows notification settings and the Ring/Silent switch. The in-app rise takes over when Jingle is open or already playing.

If notifications, sound, or Time Sensitive alerts are off, the main screen shows a short banner and an **Open Settings** button (or **Allow Notifications** if iOS has not asked yet).

## Locked-phone check before TestFlight

Do this on the iPhone before you archive.

1. Run Jingle from Xcode onto the phone.
2. Allow notifications. Turn on Sounds and Time Sensitive Notifications for Jingle. Turn on Live Activities.
3. Set the Ring/Silent switch to Ring.
4. Add an alarm two or three minutes ahead. Pick Jingle Bells and a 30 second rise.
5. Leave Jingle, lock the phone, and wait.
6. The lock screen should show Jingle’s alert and, when a next alarm is armed, the Live Activity. The short bell tone plays from the notification. Open Jingle and tap **Dismiss**. A one-time alarm turns off. A repeating alarm stays armed for the next day.

Home Screen widgets (small and medium) and Lock Screen widgets (rectangular and circular) show the next alarm. Add them from the widget gallery under Jingle.

## Same-Time Native Clock Coexistence Test

Jingle is built to sit beside the iOS Clock app when both are set for the same minute.

1. On the iPhone, open Clock and set an alarm for a minute a few minutes from now.
2. In Jingle, set an alarm for that same minute. Use Jingle Bells and a 30 second rise. Leave Jingle’s alarm on.
3. Confirm notifications, sound, and Time Sensitive alerts are on for Jingle, and Live Activities are on. Set the Ring/Silent switch to Ring.
4. Lock the phone and wait for the minute.
5. Both alerts should appear. Clock and Jingle should both be audible. Jingle mixes; it does not take the audio session away from Clock.
6. Look at the Lock Screen. Jingle’s Live Activity and Clock’s alarm should both be there, stacked. On the Dynamic Island, one activity is compact and the other is minimal. Jingle’s minimal form is the bell.
7. If Clock’s alarm interrupts Jingle’s audio, Jingle’s Live Activity stays up. When the interruption ends, and you have not tapped Dismiss, Jingle’s wake resumes.
8. Dismiss Jingle. Clock’s alarm should still be there until you stop it in Clock. Then run the minute again the other way: dismiss Clock first and confirm Jingle is still armed.

## Tests

Core scheduling, the rise curve, the Jingle Bells voice, storage, notification ids, audio-interruption state, and permission readiness live in the `JingleCore` package. They run on Linux and on a Mac:

```bash
cd ios-native/JingleCore
swift test
```

In Xcode you can also test the JingleCore package from the package navigator.

The short notification tones in `Jingle/Sounds` come from that same synthesizer:

```bash
cd ios-native/JingleCore
swift run -c release JingleRender ../Jingle/Sounds
```

## Optional later upgrades

This build targets iOS 17 and does not request either of these.

**Critical Alerts.** Apple grants `com.apple.developer.usernotifications.critical-alerts` only after a separate approval. With that entitlement, a notification can play when the Ring/Silent switch is on silent and when Focus is on. Adding the entitlement before Apple approves it breaks signing, so it is not in `Jingle.entitlements`.

**AlarmKit (iOS 26 and later).** [AlarmKit](https://developer.apple.com/documentation/alarmkit) lets an app schedule alarms that can break through silent mode and Focus, and show on the Lock Screen, in the Dynamic Island, in StandBy, and on a paired Apple Watch. Adopting it means raising the deployment target to iOS 26, adding `NSAlarmKitUsageDescription`, and calling `AlarmManager.requestAuthorization()` before scheduling. Keep the wake dismiss-only if you add it. This project does not link AlarmKit.
