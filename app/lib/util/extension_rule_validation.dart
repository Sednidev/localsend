import 'package:localsend_app/model/persistence/extension_rule.dart';
import 'package:localsend_app/util/native/channel/extension_rule_saf.dart';
import 'package:logging/logging.dart';

final _logger = Logger('ExtensionRuleValidation');

/// Looks up the current state of the folder behind [uri].
///
/// Injectable so that the validation can be tested without Android.
typedef RuleFolderInfoLookup = Future<RuleFolderInfo> Function(String uri);

/// Checks whether the folders of [rules] are still accessible.
///
/// A rule whose folder was deleted or whose permission was revoked gets
/// `invalid = true`, so incoming files that match it fall back to the default
/// destination. A rule that becomes accessible again is marked valid. The
/// folder name is refreshed from the document provider while the folder is
/// accessible.
///
/// Rules are returned in the input order. When a lookup fails unexpectedly, the
/// affected rule is returned unchanged: a provider that is temporarily
/// unavailable must not invalidate the rule. The returned list is unmodifiable.
Future<List<ExtensionRule>> validateExtensionRuleFolders({
  required Iterable<ExtensionRule> rules,
  RuleFolderInfoLookup? lookUp,
}) async {
  final lookup = lookUp ?? _lookUpFolder;
  final validated = <ExtensionRule>[];

  for (final rule in rules) {
    validated.add(await _validateRule(rule, lookup));
  }

  return List.unmodifiable(validated);
}

Future<RuleFolderInfo> _lookUpFolder(String uri) => getRuleFolderInfo(uri: uri);

Future<ExtensionRule> _validateRule(ExtensionRule rule, RuleFolderInfoLookup lookUp) async {
  final RuleFolderInfo info;
  try {
    info = await lookUp(rule.folderUri);
  } catch (e) {
    _logger.warning('Could not check the folder of rule ${rule.id}', e);
    return rule;
  }

  if (!info.accessible) {
    return rule.invalid ? rule : rule.copyWith(invalid: true);
  }

  final providerName = info.providerName?.trim();
  final folderName = providerName == null || providerName.isEmpty ? rule.folderName : providerName;
  if (!rule.invalid && folderName == rule.folderName) {
    return rule;
  }
  return rule.copyWith(invalid: false, folderName: folderName);
}

/// Marks the rules that save into [folderUri] as invalid when that folder is
/// not accessible anymore.
///
/// Called when writing a received file into a rule folder failed: the file has
/// already been saved to the default folder at that point. Only rules that are
/// not invalid yet are checked, and a rule stays valid when its folder turns
/// out to be accessible, because the failure then had another cause.
///
/// Returns the rules to store and to report to the user; empty when nothing
/// changed.
Future<List<ExtensionRule>> markRulesForUnavailableFolder({
  required Iterable<ExtensionRule> rules,
  required String folderUri,
  RuleFolderInfoLookup? lookUp,
}) async {
  final affected = rules.where((rule) => rule.folderUri == folderUri && !rule.invalid).toList();
  if (affected.isEmpty) {
    return const [];
  }

  final validated = await validateExtensionRuleFolders(rules: affected, lookUp: lookUp);
  return validated.where((rule) => rule.invalid).toList();
}
