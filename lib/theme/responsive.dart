import 'package:flutter/material.dart';

/// Window size classes, following Material's breakpoints.
enum WindowSize {
  /// Phones: bottom navigation, single column.
  compact,

  /// Tablets / small windows: side rail, single centred column.
  medium,

  /// Desktop / large web windows: side rail with labels, two columns.
  expanded;

  static WindowSize of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 600) return compact;
    if (width < 1024) return medium;
    return expanded;
  }

  bool get usesBottomNav => this == compact;
}

class Responsive {
  Responsive._();

  /// Height the floating bottom bar covers on phones. Scrollable pages add
  /// this to their bottom padding; it is zero when navigation is on the side.
  static double navInset(BuildContext context) =>
      WindowSize.of(context).usesBottomNav ? 90 : 0;

  /// Bottom padding for a tab page's scroll content. Pages with a floating
  /// action button pass [hasFab] so their last item can scroll clear of it.
  static double pageBottomPadding(
    BuildContext context, {
    bool hasFab = false,
  }) => navInset(context) + (hasFab ? 96 : 30);

  /// Side padding that centres a full-width scroll view's content at
  /// [maxWidth], so it still scrolls from anywhere in the window.
  static double centeringPadding(
    BuildContext context, {
    double maxWidth = 760,
    double min = 20,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    return ((width - maxWidth) / 2).clamp(min, double.infinity);
  }

  /// Widest a page's content should get before it is centred.
  static double maxContentWidth(BuildContext context) =>
      switch (WindowSize.of(context)) {
        WindowSize.compact => double.infinity,
        WindowSize.medium => 760,
        WindowSize.expanded => 1180,
      };
}

/// Two columns side by side on wide windows, stacked otherwise.
class ResponsiveColumns extends StatelessWidget {
  final List<Widget> left;
  final List<Widget> right;
  final double gap;

  /// Proportions of the two columns on wide windows.
  final int leftFlex;
  final int rightFlex;

  const ResponsiveColumns({
    super.key,
    required this.left,
    required this.right,
    this.gap = 28,
    this.leftFlex = 1,
    this.rightFlex = 1,
  });

  @override
  Widget build(BuildContext context) {
    if (WindowSize.of(context) != WindowSize.expanded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...left,
          SizedBox(height: gap),
          ...right,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: leftFlex,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: left,
          ),
        ),
        SizedBox(width: gap),
        Expanded(
          flex: rightFlex,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: right,
          ),
        ),
      ],
    );
  }
}

/// Centres [child] and caps its width, for standalone pages (settings,
/// group details) pushed outside the tab shell.
class CenteredContent extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const CenteredContent({super.key, required this.child, this.maxWidth = 760});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
