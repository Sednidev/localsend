import 'package:localsend_app/model/persistence/extension_rule.dart';
import 'package:localsend_app/model/state/server/receive_session_state.dart';

/// A folder that at least one file of a receive session was saved to.
class ReceiveFolder {
  /// The folder to open: a file system path or, on Android, a SAF URI.
  final String path;

  /// Short label for the header.
  ///
  /// The path for the session destination folder, the folder name of the rule
  /// for a folder that an extension rule chose (that is what the settings
  /// screen shows as well).
  final String label;

  /// Whether an extension rule saved a file into this folder.
  final bool isRuleFolder;

  const ReceiveFolder({
    required this.path,
    required this.label,
    required this.isRuleFolder,
  });
}

/// Lists the folders that the files of [session] have actually been saved to.
///
/// The session-wide destination folder is only one possibility: a file that
/// matches an extension rule is saved into the folder of the rule instead, and
/// a file that was saved to the gallery has no folder at all. Files that are
/// not saved yet, failed, or went to the gallery are left out.
///
/// Returns the session destination folder when no folder is known yet, so the
/// header keeps its meaning while the transfer is still running.
List<ReceiveFolder> summarizeReceivedFolders({
  required ReceiveSessionState session,
  required List<ExtensionRule> rules,
}) {
  final folders = <String, ReceiveFolder>{};

  for (final file in session.files.values) {
    final path = file.path;
    if (path == null || file.savedToGallery) {
      continue;
    }

    final rule = _ruleOfFile(path, rules);
    if (rule == null) {
      // The file is where it would have gone without rules: the sub-directories
      // of a folder transfer are summarized by the destination folder itself.
      folders.putIfAbsent(
        session.destinationDirectory,
        () => ReceiveFolder(
          path: session.destinationDirectory,
          label: session.destinationDirectory,
          isRuleFolder: false,
        ),
      );
    } else {
      folders.putIfAbsent(
        rule.folderUri,
        () => ReceiveFolder(
          path: rule.folderUri,
          label: rule.folderName,
          isRuleFolder: true,
        ),
      );
    }
  }

  if (folders.isEmpty) {
    return [
      ReceiveFolder(
        path: session.destinationDirectory,
        label: session.destinationDirectory,
        isRuleFolder: false,
      ),
    ];
  }

  return List.unmodifiable(folders.values);
}

/// The rule whose folder contains [filePath], if any.
///
/// The server creates every file of a rule folder as a SAF document below the
/// tree URI of that folder, including the sub-directories of a folder transfer,
/// so the prefix identifies the folder. The session destination is never
/// mistaken for a rule folder: its tree URI is not followed by `/document/`
/// unless the file is directly inside it.
ExtensionRule? _ruleOfFile(String filePath, List<ExtensionRule> rules) {
  for (final rule in rules) {
    if (filePath.startsWith('${rule.folderUri}/document/')) {
      return rule;
    }
  }
  return null;
}
