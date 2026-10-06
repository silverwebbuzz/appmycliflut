// app_version.php (document/11-mobile-api-reference.md, "App update check").
import 'package:eclinicpro_patient/core/theme/app_theme.dart';
import 'package:eclinicpro_patient/features/app_update/domain/app_update.dart';
import 'package:eclinicpro_patient/features/app_update/presentation/app_update_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _optional = {
  'ok': true,
  'platform': 'android',
  'update': 'optional',
  'latest_version': '1.2.0',
  'latest_build': 7,
  'min_build': 5,
  'store_url': 'https://play.google.com/store/apps/details?id=x',
  'title': 'Update available',
  'message': 'A new version is available.',
  'notes': ['Faster checkout', 'Bug fixes'],
};

void main() {
  group('AppUpdateInfo', () {
    test('parses the documented optional answer', () {
      final u = AppUpdateInfo.fromJson(_optional);
      expect(u.kind, UpdateKind.optional);
      expect(u.latestBuild, 7);
      expect(u.notes, ['Faster checkout', 'Bug fixes']);
      expect(u.actionable, isTrue);
    });

    test('"nothing configured" is not actionable', () {
      final u = AppUpdateInfo.fromJson({
        'ok': true, 'platform': 'ios', 'update': 'none',
        'latest_version': null, 'latest_build': null, 'min_build': null,
        'store_url': null, 'title': null, 'message': null, 'notes': [],
      });
      expect(u.kind, UpdateKind.none);
      expect(u.actionable, isFalse);
    });

    test('required without a store link does nothing (fail open)', () {
      final u = AppUpdateInfo.fromJson({..._optional, 'update': 'required', 'store_url': null});
      expect(u.kind, UpdateKind.required);
      expect(u.actionable, isFalse);
    });

    test('an unknown update value is treated as none', () {
      expect(AppUpdateInfo.fromJson({..._optional, 'update': 'soon'}).kind, UpdateKind.none);
    });
  });

  group('UpdateDialog', () {
    Future<void> pump(WidgetTester tester, Map<String, Object?> json) =>
        tester.pumpWidget(MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: UpdateDialog(info: AppUpdateInfo.fromJson(json)),
          ),
        ));

    testWidgets('optional offers Update and Later with the notes', (tester) async {
      await pump(tester, _optional);
      expect(find.text('Update'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);
      expect(find.text('Faster checkout'), findsOneWidget);
      expect(find.text('Version 1.2.0'), findsOneWidget);
    });

    testWidgets('required has no Later and cannot be popped', (tester) async {
      await pump(tester, {..._optional, 'update': 'required', 'title': 'Update required'});
      expect(find.text('Update required'), findsOneWidget);
      expect(find.text('Later'), findsNothing);
      final scope = tester.widget<PopScope>(find.byType(PopScope));
      expect(scope.canPop, isFalse);
    });
  });
}
