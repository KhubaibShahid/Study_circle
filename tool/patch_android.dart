// Run once after `flutter create` and `flutterfire configure`:
//   dart run tool/patch_android.dart
//
// Adds notification/alarm permissions + receivers to AndroidManifest.xml and
// enables core library desugaring (required by flutter_local_notifications).
import 'dart:io';

void main() {
  _patchManifest();
  _patchGradle();
  _addGoogleServicesPlugin();
  stdout.writeln('\n✅ Android project patched. Now run: flutter run   (or flutter build apk --release)');
}

void _patchManifest() {
  final f = File('android/app/src/main/AndroidManifest.xml');
  if (!f.existsSync()) {
    stderr.writeln('❌ ${f.path} not found. Run `flutter create --platforms=android .` first.');
    exit(1);
  }
  var m = f.readAsStringSync();

  const perms = '''
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.VIBRATE"/>
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
    <uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT"/>
''';
  const receivers = '''
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
''';

  if (!m.contains('POST_NOTIFICATIONS')) {
    m = m.replaceFirstMapped(RegExp(r'<manifest[^>]*>'), (x) => '${x.group(0)}\n$perms');
  }
  if (!m.contains('ScheduledNotificationReceiver')) {
    m = m.replaceFirst('</application>', '$receivers    </application>');
  }
  // Show alarms over the lock screen.
  if (!m.contains('showWhenLocked')) {
    m = m.replaceFirst('android:name=".MainActivity"',
        'android:name=".MainActivity"\n            android:showWhenLocked="true"\n            android:turnScreenOn="true"');
  }
  m = m.replaceFirst(RegExp(r'android:label="[^"]*"'), 'android:label="StudyCircle"');
  f.writeAsStringSync(m);
  stdout.writeln('• AndroidManifest.xml patched');
}

void _patchGradle() {
  final kts = File('android/app/build.gradle.kts');
  final groovy = File('android/app/build.gradle');
  final isKts = kts.existsSync();
  final f = isKts ? kts : groovy;
  if (!f.existsSync()) {
    stderr.writeln('❌ android/app/build.gradle(.kts) not found.');
    exit(1);
  }
  var g = f.readAsStringSync();

  if (!g.contains('esugaring')) {
    final flag = isKts ? 'isCoreLibraryDesugaringEnabled = true' : 'coreLibraryDesugaringEnabled true';
    if (g.contains('compileOptions {')) {
      g = g.replaceFirst('compileOptions {', 'compileOptions {\n        $flag');
    } else {
      g = g.replaceFirst(RegExp(r'android\s*\{'),
          'android {\n    compileOptions {\n        $flag\n    }');
    }
    g += isKts
        ? '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
        : "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n";
  }

  // Firebase Auth needs minSdk 23.
  g = g
      .replaceAll('minSdk = flutter.minSdkVersion', 'minSdk = 23')
      .replaceAll('minSdkVersion flutter.minSdkVersion', 'minSdkVersion 23');

  f.writeAsStringSync(g);
  stdout.writeln('• ${f.path} patched (desugaring + minSdk 23)');
}

/// Registers the Google Services Gradle plugin so google-services.json is read.
void _addGoogleServicesPlugin() {
  if (!File('android/app/google-services.json').existsSync()) {
    stderr.writeln('⚠️  android/app/google-services.json is missing — download it from the Firebase console.');
  }
  const id = 'com.google.gms.google-services';

  for (final path in ['android/settings.gradle.kts', 'android/settings.gradle']) {
    final f = File(path);
    if (!f.existsSync()) continue;
    var s = f.readAsStringSync();
    if (!s.contains(id)) {
      final line = path.endsWith('.kts')
          ? '    id("$id") version "4.4.2" apply false'
          : '    id "$id" version "4.4.2" apply false';
      s = s.replaceFirst(RegExp(r'^plugins\s*\{', multiLine: true), 'plugins {\n$line');
      f.writeAsStringSync(s);
      stdout.writeln('• $path: Google Services plugin declared');
    }
  }

  for (final path in ['android/app/build.gradle.kts', 'android/app/build.gradle']) {
    final f = File(path);
    if (!f.existsSync()) continue;
    var s = f.readAsStringSync();
    if (!s.contains(id)) {
      final line = path.endsWith('.kts') ? '    id("$id")' : '    id "$id"';
      s = s.replaceFirst(RegExp(r'^plugins\s*\{', multiLine: true), 'plugins {\n$line');
      f.writeAsStringSync(s);
      stdout.writeln('• $path: Google Services plugin applied');
    }
  }
}
