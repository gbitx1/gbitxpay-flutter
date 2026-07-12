# Example

Minimal app: `configure()` once, `present()` per payment, read the typed result (UX only — fulfil on your server from the signed webhook).

This directory ships only `lib/` + `pubspec.yaml`. Generate the platform folders once:

```sh
cd example
flutter create .
flutter pub get
```

Then make **two** required edits before running on device:

**1. Android — host must be a `FlutterFragmentActivity`** (the native checkout is a DialogFragment):

```kotlin
// example/android/app/src/main/kotlin/.../MainActivity.kt
package com.example.gbitx_pay_flutter_example

import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
```

**2. iOS — resolve the native pod for local dev** (until `GbitXPay` is on CocoaPods trunk), add to `example/ios/Podfile` inside the `Runner` target:

```ruby
pod 'GbitXPay', :path => '../../../ios'   # path to sdk/ios
```
and for the Android native SDK, publish it to your local Maven once:
```sh
( cd ../../android && ./gradlew :pay-android:publishToMavenLocal )
```

Finally set `myBackend` and a real `pk_test_…` in `lib/main.dart`, then `flutter run`.
