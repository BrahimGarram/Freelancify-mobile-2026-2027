import 'package:flutter_test/flutter_test.dart';
import 'package:sae2_brahim/utils/validators.dart';

void main() {
  test('username', () {
    expect(Validators.username(''), isNotNull);
    expect(Validators.username('ab'), isNotNull);
    expect(Validators.username('a' * 21), isNotNull);
    expect(Validators.username('mon nom'), isNotNull);
    expect(Validators.username('fady.dev'), isNull);
    expect(Validators.username('éloïse_92'), isNull);
  });

  test('email', () {
    for (final bad in [
      '',
      'abc',
      'a@b',
      'a@b.c',
      'a b@c.com',
      'a..b@c.com',
      'a@b..com',
    ]) {
      expect(Validators.email(bad), isNotNull, reason: bad);
    }
    expect(Validators.email('toi@exemple.com'), isNull);
    expect(Validators.email(' prenom.nom+tag@mail.co.uk '), isNull);
  });

  test('mot de passe', () {
    expect(Validators.password('court1'), isNotNull);
    expect(Validators.password('seulementlettres'), isNotNull);
    expect(Validators.password('12345678'), isNotNull);
    expect(Validators.password('avec espace1'), isNotNull);
    expect(Validators.password('motdepasse1'), isNull);
    expect(Validators.passwordLogin('x'), isNull);
    expect(Validators.passwordLogin(''), isNotNull);
  });

  test('confirmation', () {
    final v = Validators.confirmation(() => 'motdepasse1');
    expect(v(''), isNotNull);
    expect(v('autre'), isNotNull);
    expect(v('motdepasse1'), isNull);
  });

  test('budget', () {
    for (final bad in ['', 'abc', '0', '-5', '1.234', '1,2,3', '2000000']) {
      expect(Validators.budget(bad), isNotNull, reason: bad);
    }
    expect(Validators.budget('150'), isNull);
    expect(Validators.budget('150,50'), isNull);
    expect(Validators.lireBudget('150,5'), 150.5);
  });

  test('titre, description, message', () {
    expect(Validators.titre('Logo'), isNotNull);
    expect(Validators.titre('Logo pro'), isNull);
    expect(Validators.titre('a' * 81), isNotNull);
    expect(Validators.description('trop court'), isNotNull);
    expect(Validators.description('Une description assez longue.'), isNull);
    expect(Validators.message('   '), isNotNull);
    expect(Validators.message('a' * 501), isNotNull);
  });
}
