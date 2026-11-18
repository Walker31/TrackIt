import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Keyboard shortcuts for the main shell, for laptops and desktop browsers.
///
/// Single-key shortcuts step aside while a text field has focus, so typing
/// "n" in a description never opens a new expense. Sheets and dialogs are
/// separate routes, so these don't fire under them either.
class AppShortcuts extends StatelessWidget {
  final ValueChanged<int> onTab;
  final VoidCallback onNewExpense;
  final Widget child;

  const AppShortcuts({
    super.key,
    required this.onTab,
    required this.onNewExpense,
    required this.child,
  });

  static const _tabKeys = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
  ];

  /// What the help dialog lists, in order.
  static const help = [
    ('N', 'Add an expense'),
    ('1 – 4', 'Home, Wallet, Workout, Stats'),
    ('Ctrl + Enter', 'Save the open form'),
    ('Esc', 'Close a form or dialog'),
    ('?', 'Show these shortcuts'),
  ];

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        for (var i = 0; i < _tabKeys.length; i++)
          SingleActivator(_tabKeys[i]): _TabIntent(i),
        const SingleActivator(LogicalKeyboardKey.keyN):
            const _NewExpenseIntent(),
        const CharacterActivator('?'): const _HelpIntent(),
      },
      child: Actions(
        actions: {
          _TabIntent: _UnlessTyping<_TabIntent>((i) => onTab(i.index)),
          _NewExpenseIntent: _UnlessTyping<_NewExpenseIntent>(
            (_) => onNewExpense(),
          ),
          _HelpIntent: _UnlessTyping<_HelpIntent>(
            (_) => showShortcutHelp(context),
          ),
        },
        // Takes focus on start so shortcuts work before anything is clicked.
        child: Focus(autofocus: true, child: child),
      ),
    );
  }
}

/// Lists the keyboard shortcuts.
Future<void> showShortcutHelp(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Keyboard shortcuts'),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (keys, action) in AppShortcuts.help)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(child: Text(action, style: AppTextStyles.bodyMd)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.textTertiary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        keys,
                        style: AppTextStyles.bodySm.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    ),
  );
}

/// Saves a form with Ctrl+Enter (Cmd+Enter on a Mac), from anywhere in it.
///
/// A focused text field treats Ctrl+Enter as a plain Enter (submit, or move
/// to the next field) and never passes it up the focus tree, so this
/// listens to the keyboard directly, ahead of the fields, while its form is
/// the top route.
class SaveShortcut extends StatefulWidget {
  final VoidCallback onSave;
  final Widget child;

  const SaveShortcut({super.key, required this.onSave, required this.child});

  @override
  State<SaveShortcut> createState() => _SaveShortcutState();
}

class _SaveShortcutState extends State<SaveShortcut> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final enter =
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;
    final keyboard = HardwareKeyboard.instance;
    if (!enter || !(keyboard.isControlPressed || keyboard.isMetaPressed)) {
      return false;
    }
    // Not while a dialog (a date picker, a confirmation) sits above it.
    if (!mounted || ModalRoute.of(context)?.isCurrent == false) return false;
    widget.onSave();
    return true;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _TabIntent extends Intent {
  final int index;
  const _TabIntent(this.index);
}

class _NewExpenseIntent extends Intent {
  const _NewExpenseIntent();
}

class _HelpIntent extends Intent {
  const _HelpIntent();
}

/// Runs [onInvoke] unless a text field has focus; then the key is left for
/// the text field.
class _UnlessTyping<T extends Intent> extends CallbackAction<T> {
  _UnlessTyping(void Function(T intent) run)
    : super(
        onInvoke: (intent) {
          run(intent);
          return null;
        },
      );

  @override
  bool isEnabled(T intent) {
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused == null) return true;
    return focused.widget is! EditableText &&
        focused.findAncestorWidgetOfExactType<EditableText>() == null;
  }
}
