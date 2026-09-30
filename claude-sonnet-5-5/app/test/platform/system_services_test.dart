import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/platform/real_platform_services.dart';

/// The system implementations of the alert, haptics and screen-awake services,
/// without a phone: the vibration goes through Flutter's own platform channel,
/// and the plugins for sound and wake lock are simply not there.
void main() {
  final calls = <String>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') calls.add('${call.arguments}');
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });

  group('SystemHaptics', () {
    testWidgets('a tap is a light impact and the finish of something a heavy one', (tester) async {
      SystemHaptics()
        ..tap()
        ..heavy();
      await tester.pump();
      expect(calls, ['HapticFeedbackType.lightImpact', 'HapticFeedbackType.heavyImpact']);
    });
  });

  group('SystemTimerAlerts', () {
    testWidgets('an alert without sound vibrates four times, a third of a second apart', (tester) async {
      final alerts = SystemTimerAlerts();
      await alerts.alert(sound: false);
      await tester.pump();
      expect(calls, hasLength(1), reason: 'the first pulse comes at once');
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 360));
      }
      expect(calls, hasLength(4));
      expect(calls.toSet(), {'HapticFeedbackType.heavyImpact'});
    });

    testWidgets('stopping ends the vibration early', (tester) async {
      final alerts = SystemTimerAlerts();
      await alerts.alert(sound: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 360));
      await alerts.stop();
      final before = calls.length;
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 360));
      }
      expect(calls.length, before);
    });

    testWidgets('a device without audio still gets the vibration and no error', (tester) async {
      // There is no audio plugin in a test: playing the chime fails, and the alert carries on.
      final alerts = SystemTimerAlerts();
      await alerts.alert(sound: true);
      await tester.pump();
      expect(calls, isNotEmpty);
      await alerts.stop();
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('an alert after a stop starts vibrating again', (tester) async {
      final alerts = SystemTimerAlerts();
      await alerts.stop();
      await alerts.alert(sound: false);
      await tester.pump();
      expect(calls, hasLength(1));
      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('SystemScreenAwake', () {
    test('turning the wake lock on and off never throws, even where it is not available', () async {
      final awake = SystemScreenAwake();
      await awake.keepAwake(true);
      await awake.keepAwake(false);
    });
  });

  test('the system services are all there', () {
    final services = systemPlatformServices();
    expect(services.files, isA<SystemBackupFileGateway>());
    expect(services.alerts, isA<SystemTimerAlerts>());
    expect(services.awake, isA<SystemScreenAwake>());
    expect(services.haptics, isA<SystemHaptics>());
  });
}
