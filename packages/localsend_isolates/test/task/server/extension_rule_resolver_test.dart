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

  group('resolveIncomingFileDestination', () {
    test('keeps the default destination without a matching rule', () {
      final destination = resolveIncomingFileDestination(
        fileName: 'file.pdf',
        destinationDirectory: '/default',
        saveToGallery: false,
        destinationByExtension: const {},
      );

      expect(destination.destinationDirectory, '/default');
      expect(destination.saveToGallery, isFalse);
      expect(destination.ruleFolderUri, isNull);
    });

    test('keeps the gallery setting without a matching rule', () {
      final destination = resolveIncomingFileDestination(
        fileName: 'photo.jpg',
        destinationDirectory: '/default',
        saveToGallery: true,
        destinationByExtension: const {'pdf': _pdfUri},
      );

      expect(destination.destinationDirectory, '/default');
      expect(destination.saveToGallery, isTrue);
    });

    test('uses the folder of the matching rule', () {
      final destination = resolveIncomingFileDestination(
        fileName: 'folder/Report.PDF',
        destinationDirectory: '/default',
        saveToGallery: false,
        destinationByExtension: const {'pdf': _pdfUri},
      );

      expect(destination.destinationDirectory, _pdfUri);
      expect(destination.ruleFolderUri, _pdfUri);
    });

    test('the rule folder wins over the gallery', () {
      final destination = resolveIncomingFileDestination(
        fileName: 'photo.JPG',
        destinationDirectory: '/default',
        saveToGallery: true,
        destinationByExtension: const {'jpg': _pdfUri},
      );

      expect(destination.destinationDirectory, _pdfUri);
      expect(destination.saveToGallery, isFalse);
      expect(destination.ruleFolderUri, _pdfUri);
    });
  });

  group('withoutUnavailableRuleFolders', () {
    test('returns the same map when no folder failed', () {
      const destinations = {'pdf': _pdfUri};

      final result = withoutUnavailableRuleFolders(destinationByExtension: destinations, unavailableFolders: const {});

      expect(result, destinations);
    });

    test('drops every extension of the failed folder', () {
      const destinations = {'doc': _docUri, 'docx': _docUri, 'pdf': _pdfUri};

      final result = withoutUnavailableRuleFolders(destinationByExtension: destinations, unavailableFolders: {_docUri});

      expect(result, {'pdf': _pdfUri});
    });

    test('keeps folders that did not fail', () {
      const destinations = {'pdf': _pdfUri, 'doc': _docUri};

      final result = withoutUnavailableRuleFolders(destinationByExtension: destinations, unavailableFolders: {'content://other'});

      expect(result, destinations);
    });
  });
}
