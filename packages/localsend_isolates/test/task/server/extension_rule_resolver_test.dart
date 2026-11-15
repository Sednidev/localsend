import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_isolates/src/task/server/extension_rule_resolver.dart';

const _pdfUri = 'content://com.android.externalstorage.documents/tree/primary%3ADownload%2Fpdf';
const _docUri = 'content://com.android.externalstorage.documents/tree/primary%3ADownload%2Fdoc';

void main() {
  group('resolveExtensionRuleDestination', () {
    test('returns null when there are no rules', () {
      expect(
        resolveExtensionRuleDestination(
          fileName: 'file.pdf',
          destinationByExtension: const {},
        ),
        isNull,
      );
    });

    test('matches the extension of the file name', () {
      expect(
        resolveExtensionRuleDestination(
          fileName: 'file.pdf',
          destinationByExtension: const {'pdf': _pdfUri},
        ),
        _pdfUri,
      );
    });

    test('matches regardless of the case of the file name', () {
      expect(
        resolveExtensionRuleDestination(
          fileName: 'REPORT.PDF',
          destinationByExtension: const {'pdf': _pdfUri},
        ),
        _pdfUri,
      );
      expect(
        resolveExtensionRuleDestination(
          fileName: 'Report.Pdf',
          destinationByExtension: const {'pdf': _pdfUri},
        ),
        _pdfUri,
      );
    });

    test('matches a grouped rule that lists several extensions', () {
      const destinations = {'doc': _docUri, 'docx': _docUri};

      for (final fileName in ['letter.doc', 'letter.docx', 'LETTER.DOCX']) {
        expect(
          resolveExtensionRuleDestination(fileName: fileName, destinationByExtension: destinations),
          _docUri,
          reason: fileName,
        );
      }
    });

    test('uses the base name for a file inside a relative directory', () {
      expect(
        resolveExtensionRuleDestination(
          fileName: 'photos/holiday/file.jpg',
          destinationByExtension: const {'jpg': _pdfUri},
        ),
        _pdfUri,
      );
      expect(
        resolveExtensionRuleDestination(
          fileName: r'photos\holiday\file.jpg',
          destinationByExtension: const {'jpg': _pdfUri},
        ),
        _pdfUri,
      );
      expect(
        resolveExtensionRuleDestination(
          // A dot in a directory name must not be mistaken for the extension.
          fileName: 'photos.v2/file',
          destinationByExtension: const {'v2/file': _pdfUri, 'jpg': _docUri},
        ),
        isNull,
      );
    });

    test('returns null for a file without an extension', () {
      expect(
        resolveExtensionRuleDestination(
          fileName: 'README',
          destinationByExtension: const {'pdf': _pdfUri},
        ),
        isNull,
      );
      expect(
        resolveExtensionRuleDestination(
          fileName: 'archive.',
          destinationByExtension: const {'pdf': _pdfUri},
        ),
        isNull,
      );
    });

    test('returns null for an extension that has no rule', () {
      expect(
        resolveExtensionRuleDestination(
          fileName: 'file.zip',
          destinationByExtension: const {'pdf': _pdfUri},
        ),
        isNull,
      );
    });

    test('returns null for an empty file name', () {
      expect(
        resolveExtensionRuleDestination(
          fileName: '',
          destinationByExtension: const {'pdf': _pdfUri},
        ),
        isNull,
      );
    });

    test('matches only the last extension of a multi-dot name', () {
      const destinations = {'gz': _pdfUri, 'tar.gz': _docUri};

      expect(
        resolveExtensionRuleDestination(fileName: 'backup.tar.gz', destinationByExtension: destinations),
        _pdfUri,
      );
    });
  });
}
