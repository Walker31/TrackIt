import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../glass_container.dart';
import '../app_button.dart';
import '../../models/expenses.dart';

class AddExpenseSheet extends StatefulWidget {
  final Function(Expense) onAdd;
  const AddExpenseSheet({super.key, required this.onAdd});

  @override
  State<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<AddExpenseSheet> {
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  ExpenseCategory _selectedCategory = ExpenseCategory.food;

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
              const Text("Add Expense", style: AppTextStyles.h2),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            style: AppTextStyles.h1.copyWith(color: AppColors.expense),
            decoration: const InputDecoration(
              prefixText: "₹",
              hintText: "0.00",
              border: InputBorder.none,
            ),
          ),
          const SizedBox(height: 24),
          Text("Category", style: AppTextStyles.label),
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: ExpenseCategory.values.length,
              itemBuilder: (context, index) {
                final cat = ExpenseCategory.values[index];
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(cat.displayName),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                    selectedColor: cat.color.withValues(alpha: 0.2),
                    labelStyle: TextStyle(color: isSelected ? cat.color : Colors.white70),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _descController,
            decoration: InputDecoration(
              hintText: "Description (optional)",
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 32),
          AppButton(
            text: "Save Expense",
            color: AppColors.expense,
            onPressed: () {
              if (_amountController.text.isNotEmpty) {
                final amount = double.tryParse(_amountController.text) ?? 0;
                widget.onAdd(Expense(
                  amount: amount,
                  category: _selectedCategory,
                  description: _descController.text,
                  timestamp: DateTime.now(),
                ));
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }
}
