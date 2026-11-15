import 'package:localsend_app/model/persistence/extension_rule.dart';
import 'package:test/test.dart';

const _pdfUri = 'content://com.android.externalstorage.documents/tree/primary%3ADownload%2Fpdf';
const _docUri = 'content://com.android.externalstorage.documents/tree/primary%3ADownload%2Fdoc';

void main() {
  group('normalizeExtension', () {
    test('lowercases and removes the leading dot', () {
      expect(normalizeExtension('.PDF'), 'pdf');
      expect(normalizeExtension('docx'), 'docx');
      expect(normalizeExtension('  .Tar.Gz '), 'tar.gz');
      expect(normalizeExtension('..pdf'), 'pdf');
    });

    test('returns null when there is no extension', () {
      expect(normalizeExtension(''), isNull);
      expect(normalizeExtension('   '), isNull);
      expect(normalizeExtension('.'), isNull);
    });
  });

  group('normalizeExtensions', () {
    test('normalizes and removes duplicates while keeping the order', () {
      expect(normalizeExtensions(['PDF', '.pdf', ' Doc ', 'docx', '']), ['pdf', 'doc', 'docx']);
    });
  });

  group('parseExtensionInput', () {
    test('splits on commas, semicolons and whitespace', () {
      expect(parseExtensionInput('pdf, .PNG;docx  doc'), ['pdf', 'png', 'docx', 'doc']);
    });

    test('returns an empty list for empty input', () {
      expect(parseExtensionInput(''), isEmpty);
      expect(parseExtensionInput(' , ; '), isEmpty);
    });
  });

  group('toDestinationMap', () {
    test('maps every extension of every rule to its folder', () {
      final rules = [
        ExtensionRule(id: '1', extensions: const ['pdf'], folderUri: _pdfUri, folderName: 'pdf'),
        ExtensionRule(id: '2', extensions: const ['doc', 'docx'], folderUri: _docUri, folderName: 'doc'),
      ];

      expect(rules.toDestinationMap(), {'pdf': _pdfUri, 'doc': _docUri, 'docx': _docUri});
    });

    test('skips invalid rules', () {
      final rules = [
        ExtensionRule(id: '1', extensions: const ['pdf'], folderUri: _pdfUri, folderName: 'pdf', invalid: true),
        ExtensionRule(id: '2', extensions: const ['doc'], folderUri: _docUri, folderName: 'doc'),
      ];

      expect(rules.toDestinationMap(), {'doc': _docUri});
    });

    test('keeps the first rule when two rules claim the same extension', () {
      final rules = [
        ExtensionRule(id: '1', extensions: const ['pdf'], folderUri: _pdfUri, folderName: 'pdf'),
        ExtensionRule(id: '2', extensions: const ['pdf'], folderUri: _docUri, folderName: 'doc'),
      ];

      expect(rules.toDestinationMap(), {'pdf': _pdfUri});
    });

    test('is empty without rules', () {
      expect(<ExtensionRule>[].toDestinationMap(), isEmpty);
    });
  });

  group('ExtensionRule', () {
    test('fromValues generates an id and normalizes the extensions', () {
      final rule = ExtensionRule.fromValues(extensions: ['.PDF', 'pdf'], folderUri: _pdfUri, folderName: 'pdf');

      expect(rule.id, isNotEmpty);
      expect(rule.extensions, ['pdf']);
      expect(rule.invalid, isFalse);
    });

    test('generates a different id per rule', () {
      final first = ExtensionRule.fromValues(extensions: ['pdf'], folderUri: _pdfUri, folderName: 'pdf');
      final second = ExtensionRule.fromValues(extensions: ['pdf'], folderUri: _pdfUri, folderName: 'pdf');

      expect(first.id, isNot(second.id));
    });

    test('survives a serialize/deserialize round trip', () {
      final rule = ExtensionRule(
        id: '1',
        extensions: const ['pdf', 'doc'],
        folderUri: _pdfUri,
        folderName: 'pdf',
        invalid: true,
      );

      final restored = ExtensionRule.fromJson(rule.toJson());

      expect(restored.id, '1');
      expect(restored.extensions, ['pdf', 'doc']);
      expect(restored.folderUri, _pdfUri);
      expect(restored.folderName, 'pdf');
      expect(restored.invalid, isTrue);
    });
  });
}
