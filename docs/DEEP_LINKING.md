# Deep Linking Setup (Gmail → App)

Goal of Milestone 0: Click a Forgejo PR link inside Gmail and land directly inside the AgentForge app on the correct PR.

## Supported URL shapes

The router currently accepts:

- `https://your-forgejo.example.com/owner/repo/pulls/42`
- `https://your-forgejo.example.com/owner/repo/pull/42`

(The host is ignored for routing; only the path matters.)

## Android

Add an intent filter in `android/app/src/main/AndroidManifest.xml` inside the main `<activity>`:

```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data
        android:scheme="https"
        android:host="YOUR_FORGEJO_HOST"
        android:pathPrefix="/" />
</intent-filter>
```

Also host an `assetlinks.json` on your Forgejo domain (or a helper domain) for App Links verification.

## iOS

1. Add the associated domain capability.
2. In `ios/Runner/Info.plist` add the URL types / associated domains.
3. Host an Apple App Site Association (AASA) file on the domain.

## Testing the first demo

1. `flutter run` on a real device (preferred) or emulator.
2. Send yourself a Gmail containing a real Forgejo PR link.
3. Tap the link → the app should open and show the PR detail screen with the correct owner/repo/number.

Once this works, Milestone 0 is complete.
