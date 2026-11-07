import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sae2_brahim/models/user.dart';
import 'package:sae2_brahim/screens/client/publier_post.dart';
import 'package:sae2_brahim/theme/app_theme.dart';

Future<void> ouvrir(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: PublierPostScreen(
        user: User(
          id: 1,
          username: 'c',
          email: 'c@t.com',
          password: '',
          role: 'client',
        ),
      ),
    ),
  );
}

Future<void> toucher(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pump();
}

void main() {
  testWidgets("formulaire vide : les erreurs obligatoires s'affichent", (
    tester,
  ) async {
    await ouvrir(tester);
    await toucher(tester, find.text('Publier le post'));

    expect(find.text('Donne un titre à ton post'), findsOneWidget);
    expect(find.text('Choisis au moins une catégorie'), findsOneWidget);
    expect(find.text('Décris le travail demandé'), findsOneWidget);
    expect(find.text('Entre un budget'), findsOneWidget);
    expect(find.text('Choisis une date limite'), findsOneWidget);
    expect(
      find.text('Corrige les champs en rouge avant de publier'),
      findsOneWidget,
    );
  });

  testWidgets('plusieurs catégories, 3 au maximum', (tester) async {
    await ouvrir(tester);
    expect(find.text('0/3'), findsOneWidget);
    for (final c in ['Design', 'Vidéo', 'Photo']) {
      await toucher(tester, find.text(c));
    }
    expect(find.text('3/3'), findsOneWidget);
    expect(find.text('Choisis au moins une catégorie'), findsNothing);

    // la 4e est ignorée
    await toucher(tester, find.text('Marketing'));
    expect(find.text('3/3'), findsOneWidget);

    // on en retire une, puis on peut en choisir une autre
    await toucher(tester, find.text('Vidéo'));
    expect(find.text('2/3'), findsOneWidget);
    await toucher(tester, find.text('Marketing'));
    expect(find.text('3/3'), findsOneWidget);
  });

  testWidgets('la ville apparaît seulement pour « Sur place »', (tester) async {
    await ouvrir(tester);
    expect(find.text('Ville'), findsNothing);

    await toucher(tester, find.text('Sur place'));
    expect(find.text('Ville'), findsOneWidget);

    await toucher(tester, find.text('Publier le post'));
    expect(find.text('Choisis la ville'), findsOneWidget);
  });

  testWidgets('le libellé du budget suit le type', (tester) async {
    await ouvrir(tester);
    expect(find.text('Budget total'), findsOneWidget);
    await toucher(tester, find.text('Par heure'));
    expect(find.text('Taux horaire'), findsOneWidget);
    expect(find.text('DT/h'), findsOneWidget);
  });

  testWidgets('ajout et refus de compétences', (tester) async {
    await ouvrir(tester);
    final champ = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          w.decoration?.hintText == 'Ex : Figma, Flutter, Montage…',
    );
    await tester.ensureVisible(champ);

    await tester.enterText(champ, 'Figma');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.widgetWithText(InputChip, 'Figma'), findsOneWidget);

    await tester.enterText(champ, 'figma');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text('Compétence déjà ajoutée'), findsOneWidget);
  });
}
