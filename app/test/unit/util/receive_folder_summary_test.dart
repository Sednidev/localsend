import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_app/model/persistence/extension_rule.dart';
import 'package:localsend_app/model/state/server/receive_session_state.dart';
import 'package:localsend_app/model/state/server/receiving_file.dart';
import 'package:localsend_app/util/receive_folder_summary.dart';
import 'package:localsend_isolates/model/device.dart';
import 'package:localsend_isolates/model/dto/file_dto.dart';
import 'package:localsend_isolates/model/file_type.dart';
import 'package:localsend_isolates/model/session_status.dart';

const _destination = '/storage/emulated/0/Download';
const _destinationTreeUri = 'content://com.android.externalstorage.documents/tree/primary%3ADownload';
const _pdfUri = 'content://com.android.externalstorage.documents/tree/primary%3ADownload%2Fpdf';
const _imageUri = 'content://com.android.externalstorage.documents/tree/primary%3APictures%2Fls';

ExtensionRule _rule({
  String id = 'rule-1',
  String folderUri = _pdfUri,
  String folderName = 'pdf',
}) {
  return ExtensionRule(
    id: id,
    extensions: const ['pdf'],
    folderUri: folderUri,
    folderName: folderName,
  );
}

ReceivingFile _file({
  required String id,
  String? path,
  bool savedToGallery = false,
  String? errorMessage,
}) {
  return ReceivingFile(
    file: FileDto(
      id: id,
      fileName: 'file-$id.pdf',
      size: 1,
      fileType: FileType.pdf,
      hash: null,
      preview: null,
      metadata: null,
    ),
    token: null,
    desiredName: 'file-$id.pdf',
    path: path,
    savedToGallery: savedToGallery,
    errorMessage: errorMessage,
  );
}

ReceiveSessionState _session({
  required List<ReceivingFile> files,
  String destinationDirectory = _destination,
}) {
  return ReceiveSessionState(
    sessionId: 'session',
    status: SessionStatus.sending,
    sender: Device.empty,
    senderAlias: 'sender',
    files: {for (final file in files) file.file.id: file},
    startTime: null,
    endTime: null,
    destinationDirectory: destinationDirectory,
    cacheDirectory: '/cache',
    saveToGallery: false,
    createdDirectories: {},
  );
}

void main() {
  group('summarizeReceivedFolders', () {
    test('shows the session destination while nothing is saved', () {
      final folders = summarizeReceivedFolders(
        session: _session(files: [_file(id: '1')]),
        rules: [_rule()],
      );

      expect(folders.single.path, _destination);
      expect(folders.single.label, _destination);
      expect(folders.single.isRuleFolder, isFalse);
    });

    test('shows the session destination for a file without a rule', () {
      final folders = summarizeReceivedFolders(
        session: _session(
          files: [_file(id: '1', path: '$_destination/file-1.pdf')],
        ),
        rules: const [],
      );

      expect(folders.single.path, _destination);
      expect(folders.single.isRuleFolder, isFalse);
    });

    test('shows the folder of the rule that saved the file', () {
      final folders = summarizeReceivedFolders(
        session: _session(
          files: [_file(id: '1', path: '$_pdfUri/document/primary%3ADownload%2Fpdf/file-1.pdf')],
        ),
        rules: [_rule()],
      );

      expect(folders.single.path, _pdfUri);
      expect(folders.single.label, 'pdf');
      expect(folders.single.isRuleFolder, isTrue);
    });

    test('lists the destination and the rule folder when both were used', () {
      final folders = summarizeReceivedFolders(
        session: _session(
          files: [
            _file(id: '1', path: '$_destination/file-1.pdf'),
            _file(id: '2', path: '$_pdfUri/document/primary%3ADownload%2Fpdf/file-2.pdf'),
          ],
        ),
        rules: [_rule()],
      );

      expect(folders.map((folder) => folder.path), [_destination, _pdfUri]);
      expect(folders.map((folder) => folder.isRuleFolder), [isFalse, isTrue]);
    });

    test('summarizes the sub-directories of a folder transfer by their folder', () {
      final folders = summarizeReceivedFolders(
        session: _session(
          files: [
            _file(id: '1', path: '$_pdfUri/document/primary%3ADownload%2Fpdf%2Ftrip%2F2026/file-1.pdf'),
            _file(id: '2', path: '$_pdfUri/document/primary%3ADownload%2Fpdf%2Ftrip%2F2026/file-2.pdf'),
          ],
        ),
        rules: [_rule()],
      );

      expect(folders, hasLength(1));
      expect(folders.single.path, _pdfUri);
    });

    test('keeps one entry per folder for a rule with several extensions', () {
      final folders = summarizeReceivedFolders(
        session: _session(
          files: [
            _file(id: '1', path: '$_pdfUri/document/primary%3ADownload%2Fpdf/file-1.pdf'),
            _file(id: '2', path: '$_pdfUri/document/primary%3ADownload%2Fpdf/file-2.pdf'),
          ],
        ),
        rules: [_rule()],
      );

      expect(folders, hasLength(1));
      expect(folders.single.path, _pdfUri);
    });

    test('does not confuse the destination tree with a rule folder below it', () {
      final folders = summarizeReceivedFolders(
        session: _session(
          destinationDirectory: _destinationTreeUri,
          files: [
            _file(id: '1', path: '$_destinationTreeUri/document/primary%3ADownload/file-1.pdf'),
            _file(id: '2', path: '$_pdfUri/document/primary%3ADownload%2Fpdf/file-2.pdf'),
          ],
        ),
        rules: [_rule()],
      );

      expect(folders.map((folder) => folder.path), [_destinationTreeUri, _pdfUri]);
    });

    test('lists every rule folder that was used', () {
      final folders = summarizeReceivedFolders(
        session: _session(
          files: [
            _file(id: '1', path: '$_pdfUri/document/primary%3ADownload%2Fpdf/file-1.pdf'),
            _file(id: '2', path: '$_imageUri/document/primary%3APictures%2Fls/file-2.pdf'),
          ],
        ),
        rules: [
          _rule(),
          _rule(id: 'rule-2', folderUri: _imageUri, folderName: 'Images'),
        ],
      );

      expect(folders.map((folder) => folder.label), ['pdf', 'Images']);
    });

    test('ignores files that went to the gallery', () {
      final folders = summarizeReceivedFolders(
        session: _session(
          files: [
            _file(id: '1', savedToGallery: true),
            _file(id: '2', path: '$_pdfUri/document/primary%3ADownload%2Fpdf/file-2.pdf'),
          ],
        ),
        rules: [_rule()],
      );

      expect(folders.single.path, _pdfUri);
    });

    test('falls back to the destination when every file went to the gallery', () {
      final folders = summarizeReceivedFolders(
        session: _session(files: [_file(id: '1', savedToGallery: true)]),
        rules: [_rule()],
      );

      expect(folders.single.path, _destination);
      expect(folders.single.isRuleFolder, isFalse);
    });

    test('ignores failed files', () {
      final folders = summarizeReceivedFolders(
        session: _session(
          files: [
            _file(id: '1', path: null, errorMessage: 'failed'),
            _file(id: '2', path: '$_pdfUri/document/primary%3ADownload%2Fpdf/file-2.pdf'),
          ],
        ),
        rules: [_rule()],
      );

      expect(folders.single.path, _pdfUri);
    });

    test('shows the destination when the rule was deleted during the session', () {
      final folders = summarizeReceivedFolders(
        session: _session(
          files: [_file(id: '1', path: '$_pdfUri/document/primary%3ADownload%2Fpdf/file-1.pdf')],
        ),
        rules: const [],
      );

      expect(folders.single.path, _destination);
      expect(folders.single.isRuleFolder, isFalse);
    });
  });
}
