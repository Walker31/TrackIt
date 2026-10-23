import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../glass_container.dart';
import '../app_button.dart';

class AddMemberSheet extends StatefulWidget {
  final Future<void> Function(String username) onAdd;

  const AddMemberSheet({super.key, required this.onAdd});

  @override
  State<AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<AddMemberSheet> {
  final _usernameController = TextEditingController();
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
      borderRadius: 32,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Add Member", style: AppTextStyles.h2),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "They must already have a TrackIt account.",
            style: AppTextStyles.bodySm.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _usernameController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: "Username",
              errorText: _error,
            ),
          ),
          const SizedBox(height: 32),
          AppButton(
            text: _isSaving ? "Adding..." : "Add Member",
            onPressed: _isSaving
                ? () {}
                : () async {
                    final username = _usernameController.text.trim();
                    if (username.isEmpty) return;
                    setState(() {
                      _isSaving = true;
                      _error = null;
                    });
                    try {
                      await widget.onAdd(username);
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      setState(() {
                        _isSaving = false;
                        _error = e.toString().replaceFirst('StateError: ', '');
                      });
                    }
                  },
          ),
        ],
      ),
    );
  }
}
