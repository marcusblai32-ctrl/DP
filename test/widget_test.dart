import 'package:dp_scolaire/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('DP Scolaire application widget can be constructed', () {
    expect(const SchoolApp(), isA<SchoolApp>());
  });

  testWidgets('dashboard renders on a small phone screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SchoolApp());
    await tester.pumpAndSettle();

    expect(find.text('Bon retour !'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard renders on a wide desktop window', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SchoolApp());
    await tester.pumpAndSettle();

    expect(find.text('Bon retour !'), findsOneWidget);
    expect(find.text('Préparation des cours'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
