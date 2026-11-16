import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_isolates/rust/frb_generated.dart';
import 'package:localsend_isolates/src/task/server/extension_rule_resolver.dart';
import 'package:localsend_isolates/src/task/server/file_saver.dart';

const _channel = MethodChannel('org.localsend.localsend_app/localsend');
const _pdfRoot = 'content://com.android.externalstorage.documents/tree/primary%3ADownload%2Fpdf';
const _photoRoot = 'content://com.android.externalstorage.documents/tree/primary%3APictures';
const _defaultDestination = '/storage/emulated/0/Download';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late Directory cacheDirectory;

  setUpAll(() {
    RustLib.initMock(api: _MockRustLibApi());
  });

  setUp(() {
    calls = [];
    cacheDirectory = Directory.systemTemp.createTempSync('file_saver_rule_folder_test');
    messenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      if (call.method == 'createFile') {
        final parentUri = call.arguments['parentUri'] as String;
        return {
          'uri': '$parentUri/document/received.pdf',
          'fd': 42,
        };
      }
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(_channel, null);
    if (cacheDirectory.existsSync()) {
      cacheDirectory.deleteSync(recursive: true);
    }
  });

  /// The arguments of the [method] calls, in order.
  List<Map<Object?, Object?>> argumentsOf(String method) =>
      calls.where((call) => call.method == method).map((call) => call.arguments as Map<Object?, Object?>).toList();

  group('folder transfer into a rule folder', () {
    test('recreates the relative directories inside the folder of the rule', () async {
      final target = await prepareFileSaveTarget(
        destinationDirectory: _pdfRoot,
        cacheDirectory: cacheDirectory.path,
        fileName: '2026/receipts/report.pdf',
        saveToGallery: false,
        createdDirectories: {},
        androidSdkInt: 33,
      );

      // The sub-directories of the transfer are created under the rule folder,
      // not under the default destination.
      final createdDirectories = argumentsOf('createDirectory');
      expect(createdDirectories.map((arguments) => arguments['directoryName']), ['2026', 'receipts']);
      expect(
        createdDirectories.every((arguments) => (arguments['documentUri'] as String).startsWith(_pdfRoot)),
        isTrue,
      );

      // The file is created in the deepest directory, again inside the rule folder.
      final createFile = argumentsOf('createFile').single;
      expect(createFile['fileName'], 'report.pdf');
      expect(createFile['parentUri'], '$_pdfRoot/document/primary%3ADownload%2Fpdf%2F2026%2Freceipts');

      expect(target.path, isNull);
      expect(target.fileDescriptor, 42);
      expect(target.displayPath, '$_pdfRoot/document/primary%3ADownload%2Fpdf%2F2026%2Freceipts/document/received.pdf');
    });

    test('creates the same relative directory in two rule folders', () async {
      final createdDirectories = <String>{};

      for (final root in [_pdfRoot, _photoRoot]) {
        await prepareFileSaveTarget(
          destinationDirectory: root,
          cacheDirectory: cacheDirectory.path,
          fileName: '2026/report.pdf',
          saveToGallery: false,
          createdDirectories: createdDirectories,
          androidSdkInt: 33,
        );
      }

      // One directory per root: the cache of a session is shared by all rules.
      final created = argumentsOf('createDirectory');
      expect(created, hasLength(2));
      expect(created.map((arguments) => arguments['documentUri']).toSet(), hasLength(2));
      expect(argumentsOf('createFile').map((arguments) => arguments['parentUri']).toSet(), hasLength(2));
    });
  });

  group('save to gallery', () {
    test('a matching media file is written into the rule folder without the cache', () async {
      final destination = resolveIncomingFileDestination(
        fileName: 'holiday/photo.jpg',
        destinationDirectory: _defaultDestination,
        saveToGallery: true,
        destinationByExtension: const {'jpg': _photoRoot},
      );

      final target = await prepareFileSaveTarget(
        destinationDirectory: destination.destinationDirectory,
        cacheDirectory: cacheDirectory.path,
        fileName: 'holiday/photo.jpg',
        saveToGallery: destination.saveToGallery,
        createdDirectories: {},
        androidSdkInt: 33,
      );

      expect(destination.saveToGallery, isFalse);
      // Written through SAF, so nothing is staged in the cache for the gallery.
      expect(target.path, isNull);
      expect(target.fileDescriptor, 42);
      expect(target.displayPath, startsWith(_photoRoot));
      expect(cacheDirectory.listSync(recursive: true), isEmpty);
      expect(argumentsOf('createFile'), hasLength(1));
    });

    test('a media file without a rule is still staged in the cache for the gallery', () async {
      final destination = resolveIncomingFileDestination(
        fileName: 'holiday/photo.jpg',
        destinationDirectory: _defaultDestination,
        saveToGallery: true,
        destinationByExtension: const {'pdf': _pdfRoot},
      );

      final target = await prepareFileSaveTarget(
        destinationDirectory: destination.destinationDirectory,
        cacheDirectory: cacheDirectory.path,
        fileName: 'holiday/photo.jpg',
        saveToGallery: destination.saveToGallery,
        createdDirectories: {},
        androidSdkInt: 33,
      );

      expect(destination.saveToGallery, isTrue);
      expect(target.path, '${cacheDirectory.path}/holiday/photo.jpg');
      expect(target.fileDescriptor, isNull);
      expect(argumentsOf('createFile'), isEmpty);
    });
  });
}

/// The sanitizer lives in the Rust library, which is not loaded in unit tests.
class _MockRustLibApi implements RustLibApi {
  @override
  String crateApiFilenameSanitizeFileName({required String name}) => name;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError('Not mocked: ${invocation.memberName}');
}
