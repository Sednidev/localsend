import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_app/util/native/channel/extension_rule_saf.dart';

const _channel = MethodChannel('org.localsend.localsend_app/localsend');

const _treeUri = 'content://com.android.externalstorage.documents/tree/primary%3ADownload%2Fpdf';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;

  /// Answers the channel calls of the native side.
  void mockHost({
    Object? Function(MethodCall call)? handler,
  }) {
    messenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      return handler?.call(call);
    });
  }

  setUp(() {
    calls = [];
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(_channel, null);
  });

  group('pickRuleFolder', () {
    test('returns the picked folder', () async {
      mockHost(
        handler: (call) => switch (call.method) {
          'pickDirectoryPath' => _treeUri,
          'getDirectoryInfo' => {'accessible': true, 'name': 'pdf'},
          _ => null,
        },
      );

      final info = await pickRuleFolder();

      expect(info, isNotNull);
      expect(info!.uri, _treeUri);
      expect(info.name, 'pdf');
      expect(info.providerName, 'pdf');
      expect(info.accessible, isTrue);
      expect(calls.map((c) => c.method), ['pickDirectoryPath', 'getDirectoryInfo']);
      expect(calls.last.arguments, {'uri': _treeUri});
    });

    test('returns null when the picker is cancelled', () async {
      mockHost(
        handler: (call) => throw PlatformException(code: 'CANCELED'),
      );

      expect(await pickRuleFolder(), isNull);
      expect(calls.map((c) => c.method), ['pickDirectoryPath']);
    });

    test('rethrows other picker errors', () async {
      mockHost(
        handler: (call) => throw PlatformException(code: 'ACTIVITY_NOT_FOUND'),
      );

      await expectLater(pickRuleFolder(), throwsA(isA<PlatformException>()));
    });

    test('reports the folder as inaccessible when no info is returned', () async {
      mockHost(
        handler: (call) => call.method == 'pickDirectoryPath' ? _treeUri : null,
      );

      final info = await pickRuleFolder();

      expect(info, isNotNull);
      expect(info!.accessible, isFalse);
      expect(info.providerName, isNull);
      expect(info.name, 'pdf');
    });
  });

  group('getRuleFolderInfo', () {
    test('reads the accessible state and the name of the provider', () async {
      mockHost(handler: (call) => {'accessible': true, 'name': 'Invoices'});

      final info = await getRuleFolderInfo(uri: _treeUri);

      expect(info.uri, _treeUri);
      expect(info.providerName, 'Invoices');
      expect(info.name, 'Invoices');
      expect(info.accessible, isTrue);
      expect(calls.single.method, 'getDirectoryInfo');
      expect(calls.single.arguments, {'uri': _treeUri});
    });

    test('reports a deleted folder as inaccessible', () async {
      mockHost(handler: (call) => {'accessible': false, 'name': null});

      final info = await getRuleFolderInfo(uri: _treeUri);

      expect(info.accessible, isFalse);
      expect(info.providerName, isNull);
      expect(info.name, 'pdf');
    });

    test('handles a host that returns no map at all', () async {
      mockHost();

      final info = await getRuleFolderInfo(uri: _treeUri);

      expect(info.accessible, isFalse);
      expect(info.providerName, isNull);
      expect(info.name, 'pdf');
    });
  });

  group('releaseRuleFolderPermission', () {
    test('drops the permission of the folder', () async {
      mockHost();

      await releaseRuleFolderPermission(uri: _treeUri);

      expect(calls.single.method, 'releasePersistablePermission');
      expect(calls.single.arguments, {'uri': _treeUri});
    });

    test('does not fail when the host does not know the folder', () async {
      mockHost(
        handler: (call) => throw PlatformException(code: 'PERMISSION_NOT_FOUND'),
      );

      await expectLater(releaseRuleFolderPermission(uri: _treeUri), completes);
    });
  });

  group('ruleFolderDisplayName', () {
    test('prefers the name reported by the provider', () {
      expect(ruleFolderDisplayName(uri: _treeUri, providerName: '  Invoices '), 'Invoices');
    });

    test('derives the name from the tree uri', () {
      expect(ruleFolderDisplayName(uri: _treeUri), 'pdf');
    });

    test('handles an encoded folder name in the tree uri', () {
      expect(
        ruleFolderDisplayName(uri: 'content://com.android.externalstorage.documents/tree/primary%3ADownload%2FMy%20PDFs'),
        'My PDFs',
      );
    });

    test('falls back to the uri itself', () {
      expect(ruleFolderDisplayName(uri: 'content://com.example.documents'), 'content://com.example.documents');
    });

    test('ignores a blank provider name', () {
      expect(ruleFolderDisplayName(uri: _treeUri, providerName: '   '), 'pdf');
    });
  });
}
