import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_app/model/persistence/extension_rule.dart';
import 'package:localsend_app/util/extension_rule_validation.dart';
import 'package:localsend_app/util/native/channel/extension_rule_saf.dart';

const _uri = 'content://com.android.externalstorage.documents/tree/primary%3ADownload%2Fpdf';

ExtensionRule _rule({
  String id = 'rule-1',
  String folderUri = _uri,
  String folderName = 'pdf',
  bool invalid = false,
}) {
  return ExtensionRule(
    id: id,
    extensions: const ['pdf'],
    folderUri: folderUri,
    folderName: folderName,
    invalid: invalid,
  );
}

RuleFolderInfo _info({required bool accessible, String? providerName, String uri = _uri}) {
  return RuleFolderInfo(
    uri: uri,
    providerName: providerName,
    name: providerName ?? 'derived',
    accessible: accessible,
  );
}

void main() {
  group('validateExtensionRuleFolders', () {
    test('keeps accessible rules valid', () async {
      final rule = _rule();

      final result = await validateExtensionRuleFolders(
        rules: [rule],
        lookUp: (_) async => _info(accessible: true, providerName: 'pdf'),
      );

      expect(result.single.invalid, isFalse);
      expect(result.single.folderName, 'pdf');
    });

    test('marks a deleted folder as invalid and keeps its name', () async {
      final rule = _rule();

      final result = await validateExtensionRuleFolders(
        rules: [rule],
        lookUp: (_) async => _info(accessible: false),
      );

      expect(result.single.invalid, isTrue);
      expect(result.single.folderName, 'pdf');
      expect(result.single.folderUri, _uri);
    });

    test('marks a rule valid again when the folder is accessible again', () async {
      final rule = _rule(invalid: true);

      final result = await validateExtensionRuleFolders(
        rules: [rule],
        lookUp: (_) async => _info(accessible: true, providerName: 'pdf'),
      );

      expect(result.single.invalid, isFalse);
    });

    test('refreshes the folder name from the provider', () async {
      final rule = _rule(folderName: 'Renamed');

      final result = await validateExtensionRuleFolders(
        rules: [rule],
        lookUp: (_) async => _info(accessible: true, providerName: 'Invoices'),
      );

      expect(result.single.folderName, 'Invoices');
    });

    test('keeps the stored name when the provider does not report one', () async {
      final rule = _rule(folderName: 'My PDFs');

      final result = await validateExtensionRuleFolders(
        rules: [rule],
        lookUp: (_) async => _info(accessible: true),
      );

      expect(result.single.folderName, 'My PDFs');
    });

    test('keeps the rules that failed unexpectedly unchanged', () async {
      final rule = _rule(folderName: 'My PDFs');

      final result = await validateExtensionRuleFolders(
        rules: [rule],
        lookUp: (_) async => throw Exception('provider unavailable'),
      );

      expect(result.single.invalid, isFalse);
      expect(result.single.folderName, 'My PDFs');
      expect(result.single, rule);
    });

    test('returns the rules in the input order', () async {
      final rules = [
        _rule(id: 'first', folderUri: 'uri-1'),
        _rule(id: 'second', folderUri: 'uri-2'),
      ];

      final result = await validateExtensionRuleFolders(
        rules: rules,
        lookUp: (uri) async => _info(accessible: uri == 'uri-1', providerName: uri),
      );

      expect(result.map((rule) => rule.id), ['first', 'second']);
      expect(result.map((rule) => rule.invalid), [false, true]);
    });

    test('does not replace unchanged rules', () async {
      final rule = _rule();

      final result = await validateExtensionRuleFolders(
        rules: [rule],
        lookUp: (_) async => _info(accessible: true, providerName: 'pdf'),
      );

      expect(identical(result.single, rule), isTrue);
    });

    test('returns an empty list for no rules', () async {
      final result = await validateExtensionRuleFolders(rules: const []);

      expect(result, isEmpty);
    });
  });
}
