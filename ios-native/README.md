# Jingle for Xcode

Native SwiftUI alarm clock for iPhone. Bundle id `app.jingle.ios`. Version 1.0.0 (1).

Designed by Matthew Finley. The source is MIT, same as the rest of this repository. Copyright 2026 Matthew Finley.

This folder sits beside the Expo app. It does not replace it. Alarms are dismiss-only. The featured wake is **A Pocket of Bells**, from *The Unstartled Morning* by Matthew Finley. Seven more original pieces are in the same picker.

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

On first launch Jingle asks for notifications (alert, sound, badge, and Time Sensitive) and, on iOS 26, for Alarms. Then:

- Settings → Notifications → Jingle: allow notifications, sounds, and Time Sensitive Notifications.
- Settings → Jingle → Live Activities: on.
- Allow Alarms when iOS asks. That is what rings with the phone locked and with the Ring/Silent switch on silent.

The app group is how the home screen widget and the Live Activity read the next alarm. If the group is missing, the widget stays empty even though the app itself still stores alarms.

`project.yml` describes the same targets for XcodeGen. The checked-in `Jingle.xcodeproj` is the project to open. You do not need to regenerate it.

## What the morning does

The main screen shows the next alarm, a countdown, the alarm list, and a **+** button. Add or edit an alarm to set the time, a label, weekday pills, a wake tone, and how long the volume takes to rise. **Try this wake** previews the piece. **A Pocket of Bells** is the featured tone. **Loose Bells, Slow Cadence** is the other bell piece. The rest are Keys in the Amber, Brass Under Linen, Brush Against the Block, Fifth Along the Floor, Harmonics on the Sill, and The Low Bloom.

An empty weekday row rings once and then turns off. Weekdays, weekends, and every day keep repeating. Dismiss is the only action, in the app, on the notification, and on the Live Activity.

While a wake is playing, Jingle uses an audio session with category Playback and Mix With Others, plus the `audio` background mode. Playback ignores the Ring/Silent switch. The session follows the volume buttons and keeps going if you leave the app. It also mixes with the iOS Clock app, so the two can sound together.

On iOS 26, an allowed Alarm is the locked-phone path. AlarmKit rings on the Lock Screen, in the background, and when the Ring/Silent switch is on silent. The tone is the same 28-second mono little-endian CAF, copied to the top of the app bundle. Jingle does not also post a sounding notification for that alarm, so the tone is not played twice.

Without AlarmKit (iOS 17 through 25, or Alarms denied), Jingle schedules a Time Sensitive notification with that CAF. The notification sound follows the Ring/Silent switch. If you leave Jingle running, it keeps an inaudible playback session in the background so the in-app tone can still start when the phone locks. Force-quitting Jingle ends that session. When Jingle is open, the notification delegate presents a banner, the notification list, and sound, and starts the same playback immediately.

If notifications, sound, or Time Sensitive alerts are off, the main screen shows a short banner and an **Open Settings** button (or **Allow Notifications** if iOS has not asked yet).

## Locked-phone check before TestFlight

Do this on a physical iPhone before you archive. The Simulator does not reproduce the Ring/Silent switch.

1. Run Jingle from Xcode onto the phone.
2. Allow notifications. Turn on Sounds and Time Sensitive Notifications for Jingle. Turn on Live Activities. On iOS 26, allow Alarms.
3. Add an alarm two or three minutes ahead. Leave the tone on A Pocket of Bells and choose a 30 second rise.
4. **Switch set to Ring, Jingle open.** Stay in Jingle. At the minute you should hear the tone and see the ringing screen, not only a banner.
5. **Switch set to Ring, phone locked.** Leave Jingle and lock the phone. The lock screen should show Jingle’s alert and, when a next alarm is armed, the Live Activity. The bell tone plays. Open Jingle and tap **Dismiss**.
6. **Switch set to Silent, phone locked.** Flip the Ring/Silent switch to silent, set another alarm a couple of minutes ahead, leave Jingle, and lock the phone. On iOS 26 with Alarms allowed, the tone still plays. Without Alarms, it still plays if Jingle was left running (not force-quit). Force-quit Jingle, set the switch to silent, and the locked notification stays quiet. That last case is the Ring/Silent switch, not a missing sound file.
7. A one-time alarm turns off after dismiss. A repeating alarm stays armed for the next day.

Home Screen widgets (small and medium) and Lock Screen widgets (rectangular and circular) show the next alarm. Add them from the widget gallery under Jingle.

## Same-Time Native Clock Coexistence Test

Jingle is built to sit beside the iOS Clock app when both are set for the same minute.

1. On the iPhone, open Clock and set an alarm for a minute a few minutes from now.
2. In Jingle, set an alarm for that same minute. Use A Pocket of Bells and a 30 second rise. Leave Jingle’s alarm on.
3. Confirm notifications, sound, and Time Sensitive alerts are on for Jingle, and Live Activities are on. Set the Ring/Silent switch to Ring.
4. Lock the phone and wait for the minute.
5. Both alerts should appear. Clock and Jingle should both be audible. Jingle mixes; it does not take the audio session away from Clock.
6. Look at the Lock Screen. Jingle’s Live Activity and Clock’s alarm should both be there, stacked. On the Dynamic Island, one activity is compact and the other is minimal. Jingle’s minimal form is the bell.
7. If Clock’s alarm interrupts Jingle’s audio, Jingle’s Live Activity stays up. When the interruption ends, and you have not tapped Dismiss, Jingle’s wake resumes.
8. Dismiss Jingle. Clock’s alarm should still be there until you stop it in Clock. Then run the minute again the other way: dismiss Clock first and confirm Jingle is still armed.

## Tests

Core scheduling, the rise curve, the eight wake-tone filenames, storage, notification ids, audio-interruption state, and permission readiness live in the `JingleCore` package. They run on Linux and on a Mac:

```bash
cd ios-native/JingleCore
swift test
```

In Xcode you can also test the JingleCore package from the package navigator.

The eight wake files in `Jingle/Sounds` are 28-second mono little-endian 16-bit CAF recordings. Xcode copies them to the top of the app bundle, so notification sounds, AlarmKit, and in-app playback all open them by filename. A big-endian payload, a `Sounds/` subfolder, or a name whose case does not match is rejected and the system default tone is used instead of a silent custom sound.

## Critical Alerts

This build targets iOS 17. AlarmKit covers the silent switch on iOS 26 and does not need a special entitlement.

**Critical Alerts** stay out of `Jingle.entitlements`. Apple grants `com.apple.developer.usernotifications.critical-alerts` only after a separate approval. Adding it before that approval breaks signing.
