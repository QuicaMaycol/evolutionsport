import 'package:test/test.dart';
import 'package:evolutionsport/utils/material_utils.dart';

void main() {
  group('isDuplicateMaterial', () {
    test('detects duplicates in list', () {
      final list = ['Balón', 'Conos', 'Balón'];
      expect(isDuplicateMaterial(list, 'Balón'), isTrue);
    });

    test('ignores excluded index', () {
      final list = ['Balón', 'Conos', 'Balón'];
      // Excluir índice 0, debe detectar duplicado en índice 2
      expect(isDuplicateMaterial(list, 'Balón', excludeIndex: 0), isFalse);
      expect(isDuplicateMaterial(list, 'Balón', excludeIndex: 1), isTrue);
    });

    test('ignores spaces around', () {
      final list = ['Balón', 'Conos'];
      expect(isDuplicateMaterial(list, ' Balón '), isTrue);
    });
  });
}
