import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../glass_container.dart';
import '../app_button.dart';

const List<String> _groupIcons = [
  '💰',
  '✈️',
  '🏠',
  '🎉',
  '🍽️',
  '🎬',
  '🏖️',
  '🎓',
];

class CreateGroupSheet extends StatefulWidget {
  final Future<void> Function(String name, String icon) onCreate;

  const CreateGroupSheet({super.key, required this.onCreate});

  @override
  State<CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<CreateGroupSheet> {
  final _nameController = TextEditingController();
  String _selectedIcon = _groupIcons.first;
  bool _isSaving = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 24,
        right: 24,
      ),
      borderRadius: 24,
      sheet: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("New event", style: AppTextStyles.h2),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text("Icon", style: AppTextStyles.fieldLabel),
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _groupIcons.length,
              itemBuilder: (context, index) {
                final icon = _groupIcons[index];
                final isSelected = _selectedIcon == icon;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  // A fixed square tile: chips squeezed the emoji glyphs
                  // and clipped them (notably on web).
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedIcon = icon),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 50,
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.14)
                            : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Text(icon, style: const TextStyle(fontSize: 24)),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(hintText: "e.g. Goa Trip 2026"),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: AppTextStyles.bodySm.copyWith(color: AppColors.expense),
            ),
          ],
          const SizedBox(height: 32),
          AppButton(
            text: "Create event",
            isLoading: _isSaving,
            onPressed: _isSaving
                ? () {}
                : () async {
                    final name = _nameController.text.trim();
                    if (name.isEmpty) {
                      setState(() => _error = 'Give your event a name.');
                      return;
                    }
                    setState(() => _isSaving = true);
                    await widget.onCreate(name, _selectedIcon);
                    if (context.mounted) Navigator.pop(context);
                  },
          ),
        ],
      ),
    );
  }
}
