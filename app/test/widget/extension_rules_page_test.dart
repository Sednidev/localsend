import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/persistence/extension_rule.dart';
import 'package:localsend_app/pages/settings/extension_rules_page.dart';
import 'package:localsend_app/provider/extension_rules_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _channel = MethodChannel('org.localsend.localsend_app/localsend');
const _uri = 'content://com.android.externalstorage.documents/tree/primary%3ADownload%2Fpdf';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late bool folderAccessible;
  late String? providerName;

  ExtensionRule createRule({
    String id = 'rule-1',
    List<String> extensions = const ['pdf'],
    String folderUri = _uri,
    String folderName = 'pdf',
    bool invalid = false,
  }) {
    return ExtensionRule(
      id: id,
      extensions: extensions,
      folderUri: folderUri,
      folderName: folderName,
      invalid: invalid,
    );
  }

  setUp(() {
    calls = [];
    folderAccessible = true;
    providerName = 'pdf';
    messenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'pickDirectoryPath' => _uri,
        'getDirectoryInfo' => {'accessible': folderAccessible, 'name': providerName},
        'releasePersistablePermission' => null,
        _ => null,
      };
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(_channel, null);
  });

  Future<SharedPreferences> pumpPage(WidgetTester tester, {List<ExtensionRule> rules = const []}) async {
    SharedPreferences.setMockInitialValues({
      extensionRulesKey: [for (final rule in rules) jsonEncode(rule.toJson())],
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      RefenaScope(
        overrides: [
          extensionRulesProvider.overrideWithNotifier((ref) => ExtensionRulesService(prefs)),
        ],
        child: const MaterialApp(home: ExtensionRulesPage()),
      ),
    );
    await tester.pumpAndSettle();
    return prefs;
  }

  testWidgets('shows the empty state', (tester) async {
    await pumpPage(tester);

    expect(find.text(t.extensionRulesPage.empty), findsOneWidget);
    expect(find.text(t.extensionRulesPage.add), findsOneWidget);
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('lists the rules with their extensions', (tester) async {
    await pumpPage(
      tester,
      rules: [
        createRule(extensions: ['pdf', 'docx']),
      ],
    );

    expect(find.text('pdf'), findsOneWidget);
    expect(find.text('.pdf, .docx'), findsOneWidget);
    expect(find.text(t.extensionRulesPage.invalid), findsNothing);
    expect(find.text(t.extensionRulesPage.empty), findsNothing);
  });

  testWidgets('marks a rule whose folder is gone as invalid', (tester) async {
    folderAccessible = false;
    providerName = null;
    final prefs = await pumpPage(tester, rules: [createRule()]);

    expect(find.text(t.extensionRulesPage.invalid), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(readExtensionRules(prefs).single.invalid, isTrue);
  });

  testWidgets('refreshes the folder name from the provider', (tester) async {
    providerName = 'Invoices';
    final prefs = await pumpPage(tester, rules: [createRule(folderName: 'Old name')]);

    expect(find.text('Invoices'), findsOneWidget);
    expect(find.text('Old name'), findsNothing);
    expect(readExtensionRules(prefs).single.folderName, 'Invoices');
  });

  testWidgets('adds a rule with a picked folder', (tester) async {
    final prefs = await pumpPage(tester);

    await tester.tap(find.text(t.extensionRulesPage.add));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'PDF, docx');
    await tester.tap(find.text(t.dialogs.extensionRuleDialog.chooseFolder));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.general.confirm));
    await tester.pumpAndSettle();

    expect(find.byType(TextFormField), findsNothing);
    final stored = readExtensionRules(prefs);
    expect(stored, hasLength(1));
    expect(stored.single.extensions, ['pdf', 'docx']);
    expect(stored.single.folderUri, _uri);
    expect(stored.single.folderName, 'pdf');
    expect(stored.single.invalid, isFalse);
    expect(find.text('.pdf, .docx'), findsOneWidget);
  });

  testWidgets('does not save without a folder', (tester) async {
    final prefs = await pumpPage(tester);

    await tester.tap(find.text(t.extensionRulesPage.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'pdf');
    await tester.tap(find.text(t.general.confirm));
    await tester.pumpAndSettle();

    expect(find.text(t.dialogs.extensionRuleDialog.noFolderError), findsOneWidget);
    expect(readExtensionRules(prefs), isEmpty);
  });

  testWidgets('does not save without an extension', (tester) async {
    final prefs = await pumpPage(tester);

    await tester.tap(find.text(t.extensionRulesPage.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.dialogs.extensionRuleDialog.chooseFolder));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.general.confirm));
    await tester.pumpAndSettle();

    expect(find.text(t.dialogs.extensionRuleDialog.noExtensions), findsOneWidget);
    expect(readExtensionRules(prefs), isEmpty);
  });

  testWidgets('rejects extensions that another rule already uses', (tester) async {
    final prefs = await pumpPage(tester, rules: [createRule()]);

    await tester.tap(find.text(t.extensionRulesPage.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '.PDF');
    await tester.tap(find.text(t.dialogs.extensionRuleDialog.chooseFolder));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.general.confirm));
    await tester.pumpAndSettle();

    expect(find.text(t.dialogs.extensionRuleDialog.duplicateExtensions(extensions: '.pdf')), findsOneWidget);
    expect(readExtensionRules(prefs), hasLength(1));
  });

  testWidgets('edits a rule', (tester) async {
    final prefs = await pumpPage(tester, rules: [createRule()]);

    await tester.tap(find.text('.pdf'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'png');
    await tester.tap(find.text(t.dialogs.extensionRuleDialog.changeFolder));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.general.confirm));
    await tester.pumpAndSettle();

    final stored = readExtensionRules(prefs);
    expect(stored, hasLength(1));
    expect(stored.single.id, 'rule-1');
    expect(stored.single.extensions, ['png']);
  });

  testWidgets('deletes a rule and releases its folder permission', (tester) async {
    final prefs = await pumpPage(tester, rules: [createRule()]);

    await tester.tap(find.byWidgetPredicate((widget) => widget is PopupMenuButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.general.delete));
    await tester.pumpAndSettle();

    expect(find.text(t.dialogs.extensionRuleDeleteDialog.title), findsOneWidget);
    await tester.tap(find.text(t.general.delete).last);
    await tester.pumpAndSettle();

    expect(readExtensionRules(prefs), isEmpty);
    expect(find.text(t.extensionRulesPage.empty), findsOneWidget);
    expect(calls.where((call) => call.method == 'releasePersistablePermission'), hasLength(1));
  });
}
