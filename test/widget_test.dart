import 'package:flutter_test/flutter_test.dart';

import 'package:eclinicpro_patient/app.dart';
import 'package:eclinicpro_patient/core/theme/app_assets.dart';

void main() {
  testWidgets('App starts at splash', (WidgetTester tester) async {
    await tester.pumpWidget(EClinicProApp());
    expect(AppAssets.logoOnDark, contains('logo_on_dark'));
    expect(find.textContaining('clinic'), findsOneWidget);
  });
}
