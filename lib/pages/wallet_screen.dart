import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/section_header.dart';
import '../widgets/glass_container.dart';
import '../providers/expense_provider.dart';
import '../widgets/wallet/financial_analysis_card.dart';
import '../widgets/wallet/transaction_list.dart';
import '../widgets/wallet/add_expense_sheet.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    title: "Financial Analysis",
                    subtitle: "Monthly Spending",
                    action: _buildMonthSelector(),
                  ),
                  const SizedBox(height: 24),
                  FinancialAnalysisCard(provider: provider),
                  const SizedBox(height: 40),
                  const SectionHeader(
                    title: "Transactions",
                    subtitle: "History",
                  ),
                  const SizedBox(height: 16),
                  TransactionList(provider: provider),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 90),
        child: FloatingActionButton.extended(
          onPressed: () => _showAddExpenseSheet(context),
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add),
          label: const Text("Add Expense"),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.background,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        centerTitle: false,
        title: const Text("Wallet", style: AppTextStyles.h2),
      ),
      actions: [
        IconButton(
          onPressed: () => _showAddExpenseSheet(context),
          icon: const Icon(Icons.add_circle_outline, color: AppColors.secondary),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildMonthSelector() {
    return GestureDetector(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (date != null) {
          setState(() => _selectedDate = date);
        }
      },
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        borderRadius: 12,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(DateFormat('MMM yyyy').format(_selectedDate), style: AppTextStyles.bodyMd.copyWith(color: Colors.white)),
            const Icon(Icons.arrow_drop_down, color: Colors.white),
          ],
        ),
      ),
    );
  }

  void _showAddExpenseSheet(BuildContext context) {
    final provider = context.read<ExpenseProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddExpenseSheet(onAdd: provider.addExpense),
    );
  }
}
