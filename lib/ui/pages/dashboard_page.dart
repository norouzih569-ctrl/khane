import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../utils/format.dart';
import '../forms.dart';
import '../widgets.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final income = app.totalIncome;
    final expense = app.totalExpense;
    final balance = app.balance;
    final allocated = app.totalAllocated;
    final recent = app.txs.take(5).toList();
    final upcoming = app.upcoming;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text('مانده این ماه'),
                const SizedBox(height: 4),
                Text(
                  fmtMoney(balance),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: balance < 0 ? kExpenseColor : null,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _MiniStat(
                        label: 'درآمد',
                        value: fmtMoney(income),
                        color: kIncomeColor,
                        icon: Icons.arrow_downward,
                      ),
                    ),
                    Expanded(
                      child: _MiniStat(
                        label: 'هزینه',
                        value: fmtMoney(expense),
                        color: kExpenseColor,
                        icon: Icons.arrow_upward,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => openTransactionForm(context, income: true),
                icon: const Icon(Icons.add),
                label: const Text('ثبت درآمد / حقوق'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => openTransactionForm(context),
                icon: const Icon(Icons.remove),
                label: const Text('ثبت هزینه'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (allocated > 0)
          SectionCard(
            title: 'بودجه هزینه‌ها',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BudgetBar(spent: expense, budget: allocated),
                const SizedBox(height: 8),
                Text(
                  expense <= allocated
                      ? '${fmtMoney(expense)} از ${fmtMoney(allocated)} مصرف شده؛ ${fmtMoney(allocated - expense)} باقی مانده'
                      : '${fmtMoney(expense - allocated)} بیشتر از بودجه خرج شده',
                  style: TextStyle(
                    color: expense > allocated ? kExpenseColor : null,
                  ),
                ),
                if (income > 0 && allocated > income)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'مجموع سقف‌ها از درآمد این ماه بیشتر است.',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
              ],
            ),
          ),
        if (upcoming.isNotEmpty)
          SectionCard(
            title: 'سررسیدهای نزدیک',
            child: Column(
              children: [
                for (final u in upcoming)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(
                      u.isInstallment
                          ? Icons.credit_card
                          : Icons.notifications_active_outlined,
                      color: daysUntil(u.due) < 0 ? kExpenseColor : null,
                    ),
                    title: Text(u.title),
                    subtitle: Text('${fmtDate(u.due)} • ${relativeDays(u.due)}'),
                    trailing: u.amount > 0 ? Text(fmtMoney(u.amount)) : null,
                  ),
              ],
            ),
          ),
        SectionCard(
          title: 'آخرین تراکنش‌ها',
          child: recent.isEmpty
              ? const EmptyHint(
                  'هنوز تراکنشی ثبت نشده.\nاول درآمد (مثلاً حقوق) را ثبت کنید.',
                )
              : Column(
                  children: [
                    for (final t in recent)
                      TransactionTile(
                        t,
                        onTap: () => openTransactionForm(context, edit: t),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
