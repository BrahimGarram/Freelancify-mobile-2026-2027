import 'package:flutter_test/flutter_test.dart';
import 'package:sae2_brahim/services/password_hasher.dart';

void main() {
  test('le hash ne contient pas le mot de passe en clair', () {
    final h = PasswordHasher.hash('secret123');
    expect(h, isNot(contains('secret123')));
    expect(PasswordHasher.isHashed(h), isTrue);
  });

  test('vérifie le bon mot de passe et refuse un mauvais', () {
    final h = PasswordHasher.hash('secret123');
    expect(PasswordHasher.verify('secret123', h), isTrue);
    expect(PasswordHasher.verify('Secret123', h), isFalse);
    expect(PasswordHasher.verify('', h), isFalse);
  });

  test('deux hash du même mot de passe sont différents (sel)', () {
    expect(PasswordHasher.hash('abc'), isNot(PasswordHasher.hash('abc')));
  });

  test('une valeur en clair ou mal formée est refusée', () {
    expect(PasswordHasher.isHashed('secret123'), isFalse);
    expect(PasswordHasher.verify('secret123', 'secret123'), isFalse);
    expect(PasswordHasher.verify('x', r'sha256$abc$s$h'), isFalse);
  });
}
