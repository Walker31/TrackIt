import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackit/widgets/app_shortcuts.dart';

/// Single-key shortcuts must not fire while typing, and Ctrl+Enter must
/// save a form even from inside one of its text fields.
void main() {
  late List<String> calls;

  Widget shell({Widget? body}) => MaterialApp(
    home: AppShortcuts(
      onTab: (i) => calls.add('tab$i'),
      onNewExpense: () => calls.add('new'),
      child: Scaffold(body: body ?? const SizedBox()),
    ),
  );

  setUp(() => calls = []);

  testWidgets('number keys switch tabs and N adds an expense', (tester) async {
    await tester.pumpWidget(shell());
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);

    expect(calls, ['tab1', 'new']);
  });

  testWidgets('keys typed into a text field stay in the field', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(shell(body: TextField(controller: controller)));
    await tester.tap(find.byType(TextField));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);

    expect(calls, isEmpty);
  });

  testWidgets('Ctrl+Enter saves from inside a text field', (tester) async {
    var saved = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SaveShortcut(
            onSave: () => saved++,
            child: const TextField(textInputAction: TextInputAction.next),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(saved, 1);

    // Plain Enter is left to the field.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(saved, 1);
  });

  testWidgets('Ctrl+Enter is ignored while a dialog covers the form', (
    tester,
  ) async {
    var saved = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SaveShortcut(
            onSave: () => saved++,
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const AlertDialog(content: Text('Pick')),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(saved, 0);
  });
}
