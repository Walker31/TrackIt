import 'package:flutter/material.dart';
import '../theme/app_text_styles.dart';

/// Plain, non-collapsing page title used at the top of each main tab.
class PageHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const PageHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              Expanded(child: Text(title, style: AppTextStyles.h1)),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
