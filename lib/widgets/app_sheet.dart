import 'package:flutter/material.dart';

/// Wider than this, sheets open as a centred dialog instead of sliding up
/// from the bottom edge: on a desktop window a full-width bottom sheet
/// sends the eye to the bottom of the screen and pushes fields below the
/// fold.
const double kSheetAsDialogWidth = 840;

/// Opens [builder]'s sheet the way that suits the window: a bottom sheet
/// on phones and narrow windows, a centred dialog on wide ones. Sheets
/// built on [GlassContainer] with `sheet: true` adapt their corners on
/// their own (see [SheetPresentation]).
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double maxDialogWidth = 560,
}) {
  final wide = MediaQuery.sizeOf(context).width >= kSheetAsDialogWidth;
  if (!wide) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          SheetPresentation(asDialog: false, child: Builder(builder: builder)),
    );
  }
  return showDialog<T>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxDialogWidth),
        child: SheetPresentation(
          asDialog: true,
          child: Builder(builder: builder),
        ),
      ),
    ),
  );
}

/// Tells a sheet whether it is showing as a dialog, so it can round all
/// four corners and drop its drag handle.
class SheetPresentation extends InheritedWidget {
  final bool asDialog;

  const SheetPresentation({
    super.key,
    required this.asDialog,
    required super.child,
  });

  static bool isDialog(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<SheetPresentation>()
          ?.asDialog ??
      false;

  @override
  bool updateShouldNotify(SheetPresentation oldWidget) =>
      asDialog != oldWidget.asDialog;
}
