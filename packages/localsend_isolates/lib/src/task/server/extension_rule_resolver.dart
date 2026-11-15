import 'package:localsend_isolates/util/file_path_helper.dart';

/// Decides which folder an incoming file is saved to.
///
/// [destinationByExtension] maps a file extension to the Android SAF tree URI
/// of a folder, e.g. `{'pdf': 'content://…/tree/primary%3ADownload%2Fpdf'}`.
/// The keys are stored without the leading dot and in lower case, so `.PDF`
/// and `.pdf` match the same rule. A single rule can group several extensions
/// by contributing one entry per extension to the map.
///
/// Folders that are no longer accessible are not part of the map, so a file
/// matching such a rule falls back to the default destination as well.
///
/// Returns `null` when no rule matches the file name. The caller then uses the
/// default destination folder.
String? resolveExtensionRuleDestination({
  required String fileName,
  required Map<String, String> destinationByExtension,
}) {
  if (destinationByExtension.isEmpty) {
    return null;
  }

  // The sender may put the file into a relative directory (`folder/file.pdf`),
  // so only the base name carries the extension.
  final extension = fileName.fileName.extension;
  if (extension.isEmpty) {
    return null;
  }

  return destinationByExtension[extension];
}
