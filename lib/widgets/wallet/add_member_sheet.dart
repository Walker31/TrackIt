import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../animated/animated_segmented_tabs.dart';
import '../glass_container.dart';
import '../app_button.dart';

/// Add someone to an event: by their TrackIt username, or (like Splitwise)
/// just by name for people without an account, who can be linked to one
/// later.
class AddMemberSheet extends StatefulWidget {
  final Future<void> Function(String name, {required bool guest}) onAdd;

  const AddMemberSheet({super.key, required this.onAdd});

  @override
  State<AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<AddMemberSheet> {
  final _controller = TextEditingController();
  bool _guest = false;
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(
        () => _error = _guest ? 'Enter their name.' : 'Enter a username.',
      );
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await widget.onAdd(name, guest: _guest);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _isSaving = false;
        _error = e.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

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
              const Text('Add member', style: AppTextStyles.h2),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                tooltip: 'Close',
              ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedSegmentedTabs(
            labels: const ['Has TrackIt', 'Just a name'],
            selectedIndex: _guest ? 1 : 0,
            onChanged: (i) => setState(() {
              _guest = i == 1;
              _error = null;
            }),
          ),
          const SizedBox(height: 12),
          Text(
            _guest
                ? "For people without TrackIt. You can split with them now "
                      'and link them to their account if they join later.'
                : 'Enter the username they signed up with.',
            style: AppTextStyles.bodySm.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: _guest
                ? TextCapitalization.words
                : TextCapitalization.none,
            autocorrect: false,
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              hintText: _guest ? 'Their name, e.g. Ravi' : 'Username',
              prefixIcon: Icon(
                _guest ? Icons.person_outline_rounded : Icons.alternate_email,
                size: 20,
              ),
              errorText: _error,
            ),
          ),
          const SizedBox(height: 28),
          AppButton(
            text: _guest ? 'Add by name' : 'Add member',
            isLoading: _isSaving,
            onPressed: _isSaving ? () {} : _save,
          ),
        ],
      ),
    );
  }
}
