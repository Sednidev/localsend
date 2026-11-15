import 'package:dart_mappable/dart_mappable.dart';
import 'package:uuid/uuid.dart';

part 'extension_rule.mapper.dart';

const _uuid = Uuid();

/// A custom rule that saves incoming files into another folder than the
/// default destination, based on the file extension.
///
/// The destination folder is identified by its Android SAF tree URI so that
/// the permission that the folder picker persisted stays attached to the rule.
///
/// Extensions are stored without the leading dot and in lower case, so `.PDF`
/// and `.pdf` are the same rule and one rule can group several extensions
/// (`doc` and `docx`).
@MappableClass()
class ExtensionRule with ExtensionRuleMappable {
  final String id;

  /// Normalized extensions (see [normalizeExtension]). Never empty.
  final List<String> extensions;

  /// SAF tree URI of the destination folder, e.g.
  /// `content://com.android.externalstorage.documents/tree/primary%3ADownload%2Fpdf`.
  final String folderUri;

  /// Human readable name of [folderUri], shown in the settings.
  final String folderName;

  /// True when [folderUri] is no longer accessible, e.g. because the folder was
  /// deleted or the permission was revoked. Files matching such a rule fall
  /// back to the default destination folder.
  final bool invalid;

  const ExtensionRule({
    required this.id,
    required this.extensions,
    required this.folderUri,
    required this.folderName,
    this.invalid = false,
  });

  /// Creates a new rule with a fresh id and normalized [extensions].
  factory ExtensionRule.fromValues({
    required Iterable<String> extensions,
    required String folderUri,
    required String folderName,
  }) {
    return ExtensionRule(
      id: _uuid.v4(),
      extensions: normalizeExtensions(extensions),
      folderUri: folderUri,
      folderName: folderName,
    );
  }

  static const fromJson = ExtensionRuleMapper.fromJson;
}

/// Turns user input into the stored extension format: trimmed, lower case and
/// without the leading dot. Returns `null` for input that contains no
/// extension at all.
String? normalizeExtension(String raw) {
  final extension = raw.trim().toLowerCase().replaceAll(RegExp(r'^\.+'), '');
  return extension.isEmpty ? null : extension;
}

/// Normalizes [raw] and removes duplicates while keeping the order.
List<String> normalizeExtensions(Iterable<String> raw) {
  final extensions = <String>[];
  for (final entry in raw) {
    final extension = normalizeExtension(entry);
    if (extension != null && !extensions.contains(extension)) {
      extensions.add(extension);
    }
  }
  return List.unmodifiable(extensions);
}

/// Parses user input like `pdf, .PNG docx` into normalized extensions.
List<String> parseExtensionInput(String raw) {
  return normalizeExtensions(raw.split(RegExp(r'[\s,;]+')));
}

extension ExtensionRulesExt on Iterable<ExtensionRule> {
  /// Maps extension -> folder URI, as expected by
  /// `resolveExtensionRuleDestination`.
  ///
  /// Invalid rules are skipped, so a file that matches one of them is saved to
  /// the default destination. If two rules claim the same extension, the first
  /// one wins.
  Map<String, String> toDestinationMap() {
    final destinations = <String, String>{};
    for (final rule in this) {
      if (rule.invalid) {
        continue;
      }
      for (final extension in rule.extensions) {
        destinations.putIfAbsent(extension, () => rule.folderUri);
      }
    }
    return destinations;
  }
}
