import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_isolates/util/android_channel.dart';

const _channel = MethodChannel('org.localsend.localsend_app/localsend');
const _rootA = 'content://com.android.externalstorage.documents/tree/primary%3ADownload%2Fpdf';
const _rootB = 'content://com.android.externalstorage.documents/tree/primary%3ADownload%2Fdocs';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(_channel, null);
  });

  group('createMissingDirectoriesAndroid', () {
    test('creates each missing directory of the path', () async {
      await createMissingDirectoriesAndroid(
        parentUri: _rootA,
        fileName: '2026/receipts/report.pdf',
        createdDirectories: {},
      );

      expect(calls.map((call) => call.arguments['directoryName']), ['2026', 'receipts']);
    });

    test('does not create a directory twice for the same root', () async {
      final createdDirectories = <String>{};

      await createMissingDirectoriesAndroid(
        parentUri: _rootA,
        fileName: '2026/report.pdf',
        createdDirectories: createdDirectories,
      );
      await createMissingDirectoriesAndroid(
        parentUri: _rootA,
        fileName: '2026/other.pdf',
        createdDirectories: createdDirectories,
      );

      expect(calls, hasLength(1));
    });

    test('creates the same sub folder in a second root', () async {
      final createdDirectories = <String>{};

      // A session can write into several folders, one per extension rule. The
      // same relative sub folder in another root is a different directory.
      await createMissingDirectoriesAndroid(
        parentUri: _rootA,
        fileName: '2026/report.pdf',
        createdDirectories: createdDirectories,
      );
      await createMissingDirectoriesAndroid(
        parentUri: _rootB,
        fileName: '2026/report.pdf',
        createdDirectories: createdDirectories,
      );

      expect(calls, hasLength(2));
      expect(calls.map((call) => call.arguments['documentUri']).toSet(), hasLength(2));
    });

    test('does nothing for a file in the root directory', () async {
      await createMissingDirectoriesAndroid(
        parentUri: _rootA,
        fileName: 'report.pdf',
        createdDirectories: {},
      );

      expect(calls, isEmpty);
    });
  });
}
