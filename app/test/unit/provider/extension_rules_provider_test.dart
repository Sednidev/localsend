import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_app/model/persistence/extension_rule.dart';
import 'package:localsend_app/provider/extension_rules_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pdfUri = 'content://com.android.externalstorage.documents/tree/primary%3ADownload%2Fpdf';
const _docUri = 'content://com.android.externalstorage.documents/tree/primary%3ADownload%2Fdoc';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  Future<ExtensionRulesService> createService({List<String>? storedRules}) async {
    SharedPreferences.setMockInitialValues({
      extensionRulesKey: ?storedRules,
    });
    prefs = await SharedPreferences.getInstance();
    return ExtensionRulesService(prefs);
  }

  test('starts without rules', () async {
    final service = ReduxNotifier.test(redux: await createService());

    expect(service.state, isEmpty);
  });

  test('loads the stored rules', () async {
    final rule = _createRule('1', extensions: ['pdf']);
    final service = ReduxNotifier.test(redux: await createService(storedRules: [jsonEncode(rule.toJson())]));

    expect(service.state, [rule]);
  });

  test('skips unreadable rules but keeps the valid ones', () async {
    final rule = _createRule('1', extensions: ['pdf']);
    final service = ReduxNotifier.test(
      redux: await createService(
        storedRules: [
          jsonEncode(rule.toJson()),
          'not json',
          jsonEncode({'unexpected': 'shape'}),
        ],
      ),
    );

    expect(service.state, [rule]);
  });

  test('persists an added rule', () async {
    final service = ReduxNotifier.test(redux: await createService());
    final rule = _createRule('1', extensions: ['pdf']);

    await service.dispatchAsync(AddExtensionRuleAction(rule));

    expect(service.state, [rule]);
    expect(readExtensionRules(prefs), [rule]);
  });

  test('persists an updated rule', () async {
    final rule = _createRule('1', extensions: ['pdf']);
    final service = ReduxNotifier.test(redux: await createService(storedRules: [jsonEncode(rule.toJson())]));

    final updated = _createRule('1', extensions: ['pdf', 'doc'], folderUri: _docUri, folderName: 'doc');
    await service.dispatchAsync(UpdateExtensionRuleAction(updated));

    expect(service.state, [updated]);
    expect(readExtensionRules(prefs), [updated]);
  });

  test('ignores an update of an unknown rule', () async {
    final rule = _createRule('1', extensions: ['pdf']);
    final service = ReduxNotifier.test(redux: await createService(storedRules: [jsonEncode(rule.toJson())]));

    await service.dispatchAsync(UpdateExtensionRuleAction(_createRule('2', extensions: ['pdf'])));

    expect(service.state, [rule]);
    expect(readExtensionRules(prefs), [rule]);
  });

  test('persists a removed rule', () async {
    final rule = _createRule('1', extensions: ['pdf']);
    final other = _createRule('2', extensions: ['doc'], folderUri: _docUri, folderName: 'doc');
    final service = ReduxNotifier.test(
      redux: await createService(storedRules: [jsonEncode(rule.toJson()), jsonEncode(other.toJson())]),
    );

    await service.dispatchAsync(RemoveExtensionRuleAction('1'));

    expect(service.state, [other]);
    expect(readExtensionRules(prefs), [other]);
  });

  test('ignores the removal of an unknown rule', () async {
    final rule = _createRule('1', extensions: ['pdf']);
    final service = ReduxNotifier.test(redux: await createService(storedRules: [jsonEncode(rule.toJson())]));

    await service.dispatchAsync(RemoveExtensionRuleAction('2'));

    expect(service.state, [rule]);
    expect(readExtensionRules(prefs), [rule]);
  });
}

ExtensionRule _createRule(
  String id, {
  List<String> extensions = const ['pdf'],
  String folderUri = _pdfUri,
  String folderName = 'pdf',
}) {
  return ExtensionRule(
    id: id,
    extensions: extensions,
    folderUri: folderUri,
    folderName: folderName,
  );
}
