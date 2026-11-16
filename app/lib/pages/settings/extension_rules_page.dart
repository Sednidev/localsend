import 'package:flutter/material.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/persistence/extension_rule.dart';
import 'package:localsend_app/provider/extension_rules_provider.dart';
import 'package:localsend_app/util/extension_rule_validation.dart';
import 'package:localsend_app/util/native/channel/extension_rule_saf.dart';
import 'package:localsend_app/widget/dialogs/extension_rule_delete_dialog.dart';
import 'package:localsend_app/widget/dialogs/extension_rule_dialog.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// Lists the "extension -> folder" rules, with add, edit and delete.
///
/// Android only: it is opened from the settings and the folder picker needs the
/// Android channel. Every rule is shown with its destination folder and, when
/// the folder was deleted or its permission was revoked, with a warning.
class ExtensionRulesPage extends StatefulWidget {
  const ExtensionRulesPage({super.key});

  @override
  State<ExtensionRulesPage> createState() => _ExtensionRulesPageState();
}

class _ExtensionRulesPageState extends State<ExtensionRulesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _revalidateFolders());
  }

  /// Refreshes the stored rules: a folder that is gone or no longer permitted
  /// marks its rule as invalid, and names are taken from the document provider.
  Future<void> _revalidateFolders() async {
    final rules = context.read(extensionRulesProvider);
    if (rules.isEmpty) {
      return;
    }

    final dispatcher = context.redux(extensionRulesProvider);
    final validated = await validateExtensionRuleFolders(rules: rules);
    if (!mounted) {
      return;
    }

    for (var i = 0; i < validated.length; i++) {
      if (validated[i] != rules[i]) {
        await dispatcher.dispatchAsync(UpdateExtensionRuleAction(validated[i]));
      }
    }
  }

  Future<void> _openEditor({ExtensionRule? rule}) async {
    await showDialog<bool>(
      context: context,
      builder: (_) => ExtensionRuleDialog(rule: rule),
    );
    if (mounted) {
      await _revalidateFolders();
    }
  }

  Future<void> _deleteRule(ExtensionRule rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ExtensionRuleDeleteDialog(rule),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    await context.redux(extensionRulesProvider).dispatchAsync(RemoveExtensionRuleAction(rule.id));
    await releaseRuleFolderPermission(uri: rule.folderUri);
  }

  @override
  Widget build(BuildContext context) {
    final rules = context.watch(extensionRulesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.extensionRulesPage.title),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: Text(t.extensionRulesPage.add),
      ),
      body: ResponsiveListView(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
        children: [
          Text(t.extensionRulesPage.info, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          if (rules.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 100),
              child: Center(child: Text(t.extensionRulesPage.empty, style: Theme.of(context).textTheme.headlineMedium)),
            )
          else
            ...rules.map(
              (rule) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RuleCard(
                  rule: rule,
                  onTap: () => _openEditor(rule: rule),
                  onDelete: () => _deleteRule(rule),
                ),
              ),
            ),
          // Keep the last rule reachable above the floating action button.
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  final ExtensionRule rule;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _RuleCard({
    required this.rule,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(left: 15, right: 5, top: 12, bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (rule.invalid) ...[
                          Icon(Icons.warning_amber_rounded, size: 20, color: theme.colorScheme.warning),
                          const SizedBox(width: 5),
                        ],
                        Expanded(
                          child: Text(
                            rule.folderName,
                            style: theme.textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rule.extensions.map((extension) => '.$extension').join(', '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (rule.invalid)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          t.extensionRulesPage.invalid,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.warning),
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<_RuleAction>(
                onSelected: (action) {
                  switch (action) {
                    case _RuleAction.edit:
                      onTap();
                      break;
                    case _RuleAction.delete:
                      onDelete();
                      break;
                  }
                },
                itemBuilder: (context) => _RuleAction.values
                    .map(
                      (action) => PopupMenuItem<_RuleAction>(
                        value: action,
                        child: Text(action.label),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _RuleAction {
  edit,
  delete;

  String get label {
    return switch (this) {
      _RuleAction.edit => t.general.edit,
      _RuleAction.delete => t.general.delete,
    };
  }
}
