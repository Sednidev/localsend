import 'package:flutter/services.dart';
import 'package:localsend_isolates/util/content_uri_helper.dart';
import 'package:logging/logging.dart';

/// Channel of the Android host. Shared with the other Android-only helpers; it
/// must only be called on Android.
const _methodChannel = MethodChannel('org.localsend.localsend_app/localsend');

final _logger = Logger('ExtensionRuleSaf');

/// State of the folder behind a SAF tree URI, as reported by the system.
class RuleFolderInfo {
  /// The SAF tree URI of the folder.
  final String uri;

  /// Display name reported by the document provider. `null` when the provider
  /// does not report one or the folder is not accessible.
  final String? providerName;

  /// Display name for the settings: [providerName], a name derived from [uri],
  /// or [uri] itself. Never empty.
  final String name;

  /// Whether the folder still exists and the app still holds a permission for
  /// it. False when the folder was deleted or the permission was revoked.
  final bool accessible;

  const RuleFolderInfo({
    required this.uri,
    required this.providerName,
    required this.name,
    required this.accessible,
  });
}

/// Opens the system folder picker and returns the picked folder.
///
/// The native side takes the persistable permission, so the folder stays
/// usable after a restart. Returns `null` when the user cancels.
///
/// Android only, requires API 27+ (see `contentUriMinSdk`).
Future<RuleFolderInfo?> pickRuleFolder() async {
  final uri = await _pickRuleFolderUri();
  if (uri == null) {
    return null;
  }
  return getRuleFolderInfo(uri: uri);
}

Future<String?> _pickRuleFolderUri() async {
  try {
    return await _methodChannel.invokeMethod<String>('pickDirectoryPath');
  } on PlatformException catch (e) {
    // The host reports a cancelled picker as an error instead of a null result.
    if (e.code == 'CANCELED') {
      return null;
    }
    rethrow;
  }
}

/// Checks whether the folder behind [uri] can still be written to.
///
/// A folder that is gone or whose permission was revoked reports
/// [RuleFolderInfo.accessible] as false instead of failing.
Future<RuleFolderInfo> getRuleFolderInfo({required String uri}) async {
  final result = await _methodChannel.invokeMethod<Map>('getDirectoryInfo', {'uri': uri});
  final providerName = result?['name'] as String?;
  return RuleFolderInfo(
    uri: uri,
    providerName: providerName,
    name: ruleFolderDisplayName(uri: uri, providerName: providerName),
    accessible: result?['accessible'] == true,
  );
}

/// Drops the persisted permission of a folder that is no longer used, e.g.
/// because its rule was deleted. Best effort.
Future<void> releaseRuleFolderPermission({required String uri}) async {
  try {
    await _methodChannel.invokeMethod('releasePersistablePermission', {'uri': uri});
  } catch (e) {
    _logger.warning('Could not release the folder permission of $uri', e);
  }
}

/// Resolves the name to show for a rule folder: the name reported by the
/// provider, otherwise the last segment of the SAF tree URI, otherwise the URI.
String ruleFolderDisplayName({required String uri, String? providerName}) {
  final trimmed = providerName?.trim();
  if (trimmed != null && trimmed.isNotEmpty) {
    return trimmed;
  }

  final path = ContentUriHelper.getPathFromTreeUri(uri);
  final derived = path == null ? null : ContentUriHelper.getEntityNameFromPath(path);
  return derived ?? uri;
}
