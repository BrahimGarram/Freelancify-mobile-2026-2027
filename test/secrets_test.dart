import 'package:flutter_test/flutter_test.dart';
import 'package:sae2_brahim/services/secrets.dart';

void main() {
  test(
    'une valeur --dart-define est prioritaire, les exemples sont ignorés',
    () {
      expect(Secrets.lire('X', 'depuis-define'), 'depuis-define');
      expect(Secrets.lire('ABSENTE', '', defaut: 'd'), 'd');
    },
  );
}
