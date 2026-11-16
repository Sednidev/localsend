import 'package:flutter/material.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/persistence/extension_rule.dart';
import 'package:routerino/routerino.dart';

/// Asks before deleting an extension rule.
class ExtensionRuleDeleteDialog extends StatelessWidget {
  final ExtensionRule rule;

  const ExtensionRuleDeleteDialog(this.rule);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(t.dialogs.extensionRuleDeleteDialog.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.dialogs.extensionRuleDeleteDialog.content),
          const SizedBox(height: 10),
          Text(
            '${rule.extensions.map((extension) => '.$extension').join(', ')}\n${rule.folderName}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: Text(t.general.cancel),
        ),
        FilledButton(
          onPressed: () => context.pop(true),
          child: Text(t.general.delete),
        ),
      ],
    );
  }
}
