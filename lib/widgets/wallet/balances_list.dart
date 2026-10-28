import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../models/expenses.dart';
import '../../utils/format.dart';
import '../app_card.dart';
import '../empty_state.dart';
import '../member_avatar.dart';
import '../animated/fade_slide_in.dart';
import '../../utils/simplify_debts.dart';

/// Each member's net position in the event, worded like Splitwise:
/// "Asha gets back ₹400", "Ravi owes ₹250", "You are settled up".
class BalancesList extends StatelessWidget {
  final List<MemberBalance> balances;
  final int currentMemberId;

  /// Members added by name, without an account; tapping one offers to
  /// link it to an account via [onLinkGuest].
  final Set<int> guestIds;
  final void Function(int memberId)? onLinkGuest;

  const BalancesList({
    super.key,
    required this.balances,
    required this.currentMemberId,
    this.guestIds = const {},
    this.onLinkGuest,
  });

  @override
  Widget build(BuildContext context) {
    if (balances.isEmpty) {
      return const EmptyState(
        icon: Icons.balance_rounded,
        title: 'Everyone is settled up',
        message: 'Balances appear once expenses are shared.',
      );
    }

    final plan = simplifyDebts(balances);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FadeSlideIn(
          child: AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < balances.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 70),
                  _row(balances[i]),
                ],
              ],
            ),
          ),
        ),
        if (plan.isNotEmpty) ...[
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'SIMPLEST WAY TO SETTLE · '
              '${plan.length} PAYMENT${plan.length == 1 ? '' : 'S'}',
              style: AppTextStyles.overline,
            ),
          ),
          FadeSlideIn(
            index: 1,
            child: AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < plan.length; i++) ...[
                    if (i > 0) const Divider(height: 1, indent: 16),
                    _paymentRow(plan[i]),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _name(int memberId) {
    if (memberId == currentMemberId) return 'You';
    return balances
            .where((b) => b.memberId == memberId)
            .firstOrNull
            ?.username ??
        'Someone';
  }

  /// "Asha → You  ₹300", tinted by whether it touches the viewer.
  Widget _paymentRow(SuggestedPayment p) {
    final mine = p.from == currentMemberId || p.to == currentMemberId;
    final color = p.to == currentMemberId
        ? AppColors.income
        : p.from == currentMemberId
        ? AppColors.outflow
        : AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                style: AppTextStyles.bodyLg.copyWith(
                  color: AppColors.textPrimary,
                ),
                children: [
                  TextSpan(
                    text: _name(p.from),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: p.from == currentMemberId ? ' pay ' : ' pays ',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  TextSpan(
                    text: _name(p.to),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          Text(
            formatRupees(p.amount),
            style: AppTextStyles.bodyLg.copyWith(
              fontWeight: mine ? FontWeight.w700 : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(MemberBalance b) {
    final isMe = b.memberId == currentMemberId;
    final name = isMe ? 'You' : b.username;
    final isSettled = b.balance.abs() < 0.01;
    final isOwed = b.balance > 0;

    final (verb, color) = isSettled
        ? (isMe ? ' are settled up' : ' is settled up', AppColors.textTertiary)
        : isOwed
        ? (isMe ? ' get back ' : ' gets back ', AppColors.income)
        : (isMe ? ' owe ' : ' owes ', AppColors.outflow);
    final guest = guestIds.contains(b.memberId);
    final canLink = guest && onLinkGuest != null;

    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          MemberAvatar(name: b.username),
          const SizedBox(width: 14),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: AppTextStyles.bodyLg.copyWith(
                  color: AppColors.textPrimary,
                ),
                children: [
                  TextSpan(
                    text: name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: verb,
                    style: TextStyle(
                      color: isSettled ? AppColors.textSecondary : color,
                    ),
                  ),
                  if (!isSettled)
                    TextSpan(
                      text: formatRupees(b.balance.abs()),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (guest) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: 'No TrackIt account. Tap to link one.',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'guest',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
    return canLink
        ? InkWell(onTap: () => onLinkGuest!(b.memberId), child: row)
        : row;
  }
}
