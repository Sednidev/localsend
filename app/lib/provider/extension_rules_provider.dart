import 'dart:convert';

import 'package:localsend_app/model/persistence/extension_rule.dart';
import 'package:logging/logging.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _logger = Logger('ExtensionRules');

/// Key of the extension rules in the SharedPreferences store.
const extensionRulesKey = 'ls_extension_rules';

/// This provider stores the "extension -> destination folder" rules of the
/// receiver. It automatically saves the list to the device's storage.
///
/// The rules have their own key instead of going through `PersistenceService`
/// so that the shared persistence layer stays untouched. They are stored in
/// the same SharedPreferences store as the other settings, one JSON string per
/// rule, so that a single corrupted entry does not lose the other rules.
final extensionRulesProvider = ReduxProvider<ExtensionRulesService, List<ExtensionRule>>((ref) {
  throw Exception('extensionRulesProvider not initialized');
});

class ExtensionRulesService extends ReduxNotifier<List<ExtensionRule>> {
  final SharedPreferences _prefs;

  ExtensionRulesService(this._prefs);

  @override
  List<ExtensionRule> init() => readExtensionRules(_prefs);

  Future<void> _persist(List<ExtensionRule> rules) => writeExtensionRules(_prefs, rules);
}

/// Reads the stored rules. Entries that cannot be decoded are skipped instead
/// of failing the whole list.
List<ExtensionRule> readExtensionRules(SharedPreferences prefs) {
  final rules = <ExtensionRule>[];
  for (final raw in prefs.getStringList(extensionRulesKey) ?? const <String>[]) {
    try {
      rules.add(ExtensionRule.fromJson(jsonDecode(raw) as Map<String, dynamic>));
    } catch (e) {
      _logger.warning('Skipping unreadable extension rule: $raw', e);
    }
  }
  return List.unmodifiable(rules);
}

Future<void> writeExtensionRules(SharedPreferences prefs, List<ExtensionRule> rules) {
  return prefs.setStringList(extensionRulesKey, [for (final rule in rules) jsonEncode(rule.toJson())]);
}

/// Adds a rule.
class AddExtensionRuleAction extends AsyncReduxAction<ExtensionRulesService, List<ExtensionRule>> {
  final ExtensionRule rule;

  AddExtensionRuleAction(this.rule);

  @override
  Future<List<ExtensionRule>> reduce() async {
    final updated = List<ExtensionRule>.unmodifiable([...state, rule]);
    await notifier._persist(updated);
    return updated;
  }
}

/// Replaces the rule with the same id.
class UpdateExtensionRuleAction extends AsyncReduxAction<ExtensionRulesService, List<ExtensionRule>> {
  final ExtensionRule rule;

  UpdateExtensionRuleAction(this.rule);

  @override
  Future<List<ExtensionRule>> reduce() async {
    final index = state.indexWhere((e) => e.id == rule.id);
    if (index == -1) {
      // Unknown rule
      return state;
    }
    final updated = List<ExtensionRule>.unmodifiable(
      <ExtensionRule>[
        ...state,
      ]..replaceRange(index, index + 1, [rule]),
    );
    await notifier._persist(updated);
    return updated;
  }
}

/// Removes the rule with the given id.
class RemoveExtensionRuleAction extends AsyncReduxAction<ExtensionRulesService, List<ExtensionRule>> {
  final String id;

  RemoveExtensionRuleAction(this.id);

  @override
  Future<List<ExtensionRule>> reduce() async {
    final index = state.indexWhere((e) => e.id == id);
    if (index == -1) {
      // Unknown rule
      return state;
    }
    final updated = List<ExtensionRule>.unmodifiable(
      <ExtensionRule>[
        ...state,
      ]..removeAt(index),
    );
    await notifier._persist(updated);
    return updated;
  }
}
