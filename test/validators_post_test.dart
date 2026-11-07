import 'package:flutter_test/flutter_test.dart';
import 'package:sae2_brahim/models/post.dart';
import 'package:sae2_brahim/models/post_options.dart';
import 'package:sae2_brahim/utils/validators.dart';

void main() {
  test('budget selon le type (fixe / horaire)', () {
    expect(Validators.budget('600', typeBudget: 'horaire'), isNotNull);
    expect(Validators.budget('500', typeBudget: 'horaire'), isNull);
    expect(Validators.budget('600', typeBudget: 'fixe'), isNull);
  });

  test('choix obligatoire', () {
    final v = Validators.choix(PostOptions.categories, 'Choisis');
    expect(v(null), 'Choisis');
    expect(v('inconnu'), isNotNull);
    expect(v('design'), isNull);
  });

  test('catégories : 1 à 3, sans doublon, dans la liste', () {
    expect(Validators.categories([]), isNotNull);
    expect(Validators.categories(null), isNotNull);
    expect(Validators.categories(['design']), isNull);
    expect(Validators.categories(['design', 'dev', 'video']), isNull);
    expect(
      Validators.categories(['design', 'dev', 'video', 'photo']),
      isNotNull,
    );
    expect(Validators.categories(['dev', 'dev']), isNotNull);
    expect(Validators.categories(['inconnu']), isNotNull);
  });

  test('lecture des catégories enregistrées', () {
    expect(Post.lireCategories('dev'), ['dev']); // ancien post
    expect(Post.lireCategories('dev,design'), ['dev', 'design']);
    expect(Post.lireCategories(''), ['autre']);
    expect(Post.lireCategories(null), ['autre']);
  });

  test('date limite : entre demain et dans 1 an', () {
    final today = DateTime(2026, 11, 7, 15, 30);
    String? v(DateTime? d) => Validators.dateLimite(d, aujourdHui: today);
    expect(v(null), isNotNull);
    expect(v(DateTime(2026, 11, 6)), isNotNull); // hier
    expect(v(DateTime(2026, 11, 7)), isNotNull); // aujourd'hui
    expect(v(DateTime(2026, 11, 8)), isNull); // demain
    expect(v(DateTime(2027, 11, 7)), isNull); // dans 365 jours
    expect(v(DateTime(2027, 11, 8)), isNotNull); // trop loin
  });

  test('ville obligatoire seulement sur place / hybride', () {
    expect(Validators.ville(null, 'distance'), isNull);
    expect(Validators.ville(null, 'sur_place'), isNotNull);
    expect(Validators.ville('Paris', 'hybride'), isNotNull);
    expect(Validators.ville('Sfax', 'hybride'), isNull);
  });

  test('compétences', () {
    expect(Validators.competence('', []), isNotNull);
    expect(Validators.competence('a', []), isNotNull);
    expect(Validators.competence('a' * 21, []), isNotNull);
    expect(Validators.competence('<script>', []), isNotNull);
    expect(Validators.competence('figma', ['Figma']), isNotNull); // doublon
    expect(
      Validators.competence('Logo', ['a1', 'b2', 'c3', 'd4', 'e5']),
      isNotNull,
    ); // déjà 5
    for (final ok in ['C#', 'Node.js', 'UI/UX', 'Montage vidéo', 'C++']) {
      expect(Validators.competence(ok, []), isNull, reason: ok);
    }
    expect(Validators.competences(['Figma', 'Logo']), isNull);
    expect(Validators.competences(['Figma', 'figma']), isNotNull);
    expect(Validators.competences(List.generate(6, (i) => 'C$i')), isNotNull);
  });
}
