import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sae2_brahim/screens/splash_screen.dart';
import 'package:sae2_brahim/theme/app_theme.dart';

Widget app(Future<String> chargement) => MaterialApp(
  theme: AppTheme.dark,
  home: SplashScreen<String>(
    chargement: chargement,
    suivant: (r) => Scaffold(body: Text('ouvert : $r')),
  ),
);

void main() {
  for (final largeur in [320.0, 432.0]) {
    testWidgets('anime le logo puis ouvre l\'app ($largeur dp)', (t) async {
      t.view.physicalSize = Size(largeur * 2, 1136);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);

      await t.pumpWidget(app(Future.value('moi')));
      // le logo est là dès la 1re image
      expect(find.text('F'), findsWidgets);
      // et centré : il doit se superposer exactement au logo natif Android
      final centre = t.getCenter(find.text('F').last);
      expect(centre.dx, closeTo(largeur / 2, 1));
      expect(centre.dy, closeTo(1136 / 2 / 2, 1));
      await t.pump(const Duration(milliseconds: 500));
      expect(
        find.text('ouvert : moi'),
        findsNothing,
      ); // l'animation n'est pas coupée

      await t.pump(const Duration(milliseconds: 1400));
      await t.pumpAndSettle();
      expect(find.text('freelance'), findsNothing); // l'écran a été remplacé
      expect(find.text('ouvert : moi'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('chargement long : le logo reste jusqu\'à la fin', (t) async {
    final chargement = Completer<String>();
    await t.pumpWidget(app(chargement.future));
    await t.pump();
    await t.pump(const Duration(seconds: 2));
    await t.pump(const Duration(seconds: 5));
    expect(find.text('ouvert : moi'), findsNothing);
    expect(find.text('freelance'), findsWidgets);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    chargement.complete('moi');
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle();
    expect(find.text('ouvert : moi'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
