import 'package:flutter/material.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/persistence/extension_rule.dart';
import 'package:localsend_app/provider/extension_rules_provider.dart';
import 'package:localsend_app/util/native/channel/extension_rule_saf.dart';
import 'package:logging/logging.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

final _logger = Logger('ExtensionRuleDialog');

/// A dialog to add or edit an extension rule.
///
/// The destination folder is picked with the system folder picker, so the rule
/// is always saved with a folder the app is allowed to write to.
class ExtensionRuleDialog extends StatefulWidget {
  final ExtensionRule? rule;

  const ExtensionRuleDialog({this.rule});

  @override
  State<ExtensionRuleDialog> createState() => _ExtensionRuleDialogState();
}

class _ExtensionRuleDialogState extends State<ExtensionRuleDialog> {
  late final TextEditingController _extensionsController;

  String? _folderUri;
  String? _folderName;
  bool _folderInvalid = false;
  String? _extensionsError;
  String? _folderError;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    _extensionsController = TextEditingController(text: widget.rule?.extensions.map((extension) => '.$extension').join(', ') ?? '');
    _folderUri = widget.rule?.folderUri;
    _folderName = widget.rule?.folderName;
    _folderInvalid = widget.rule?.invalid ?? false;
  }

  @override
  void dispose() {
    _extensionsController.dispose();
    super.dispose();
  }

  Future<void> _pickFolder() async {
    setState(() {
      _picking = true;
      _folderError = null;
    });

    try {
      final info = await pickRuleFolder();
      if (!mounted) {
        return;
      }
      if (info != null) {
        setState(() {
          _folderUri = info.uri;
          _folderName = info.name;
          _folderInvalid = !info.accessible;
          _folderError = info.accessible ? null : t.dialogs.extensionRuleDialog.folderUnavailable;
        });
      }
    } catch (e) {
      _logger.warning('Could not pick a folder', e);
      if (mounted) {
        setState(() {
          _folderError = t.dialogs.extensionRuleDialog.pickFailed;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _picking = false;
        });
      }
    }
  }

  List<String> _duplicateExtensions(List<String> extensions, List<ExtensionRule> rules) {
    final otherRules = rules.where((rule) => rule.id != widget.rule?.id);
    final used = <String>{for (final rule in otherRules) ...rule.extensions};
    return extensions.where(used.contains).toList();
  }

  Future<void> _save() async {
    final rules = context.read(extensionRulesProvider);
    final dispatcher = context.redux(extensionRulesProvider);
    final extensions = parseExtensionInput(_extensionsController.text);
    if (extensions.isEmpty) {
      setState(() {
        _extensionsError = t.dialogs.extensionRuleDialog.noExtensions;
      });
      return;
    }
    setState(() {
      _extensionsError = null;
    });

    final folderUri = _folderUri;
    if (folderUri == null) {
      setState(() {
        _folderError = t.dialogs.extensionRuleDialog.noFolderError;
      });
      return;
    }
    if (_folderInvalid) {
      setState(() {
        _folderError = t.dialogs.extensionRuleDialog.folderUnavailable;
      });
      return;
    }

    final duplicates = _duplicateExtensions(extensions, rules);
    if (duplicates.isNotEmpty) {
      setState(() {
        _extensionsError = t.dialogs.extensionRuleDialog.duplicateExtensions(extensions: duplicates.map((e) => '.$e').join(', '));
      });
      return;
    }

    final folderName = _folderName ?? ruleFolderDisplayName(uri: folderUri);
    final existingRule = widget.rule;
    if (existingRule == null) {
      await dispatcher.dispatchAsync(
        AddExtensionRuleAction(
          ExtensionRule.fromValues(
            extensions: extensions,
            folderUri: folderUri,
            folderName: folderName,
          ),
        ),
      );
    } else {
      await dispatcher.dispatchAsync(
        UpdateExtensionRuleAction(
          existingRule.copyWith(
            extensions: extensions,
            folderUri: folderUri,
            folderName: folderName,
            invalid: false,
          ),
        ),
      );

      if (existingRule.folderUri != folderUri) {
        // The old folder is not needed by this rule anymore.
        await releaseRuleFolderPermission(uri: existingRule.folderUri);
      }
    }

    if (mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.rule != null;
    return AlertDialog(
      title: Text(isEdit ? t.dialogs.extensionRuleDialog.titleEdit : t.dialogs.extensionRuleDialog.titleAdd),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.dialogs.extensionRuleDialog.extensions),
            const SizedBox(height: 5),
            TextFormField(
              controller: _extensionsController,
              autofocus: !isEdit,
              decoration: InputDecoration(
                hintText: t.dialogs.extensionRuleDialog.extensionsHint,
                errorText: _extensionsError,
              ),
              textInputAction: TextInputAction.done,
              onChanged: (_) {
                if (_extensionsError != null) {
                  setState(() {
                    _extensionsError = null;
                  });
                }
              },
            ),
            const SizedBox(height: 5),
            Text(
              t.dialogs.extensionRuleDialog.extensionsHelp,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Text(t.dialogs.extensionRuleDialog.folder),
            const SizedBox(height: 5),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _folderName ?? t.dialogs.extensionRuleDialog.noFolder,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _folderInvalid ? Theme.of(context).colorScheme.warning : null),
                  ),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: _picking ? null : _pickFolder,
                  child: Text(_folderUri == null ? t.dialogs.extensionRuleDialog.chooseFolder : t.dialogs.extensionRuleDialog.changeFolder),
                ),
              ],
            ),
            if (_folderError != null)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  _folderError!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.warning),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: Text(t.general.cancel),
        ),
        FilledButton(
          onPressed: _picking ? null : _save,
          child: Text(t.general.confirm),
        ),
      ],
    );
  }
}
