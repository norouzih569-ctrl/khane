import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../data/models.dart';
import '../../state/app_state.dart';
import '../../utils/format.dart';
import '../widgets.dart';

class ReportPage extends StatelessWidget {
  const ReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: false,
              label: Text('ماهانه'),
              icon: Icon(Icons.calendar_view_month),
            ),
            ButtonSegment(
              value: true,
              label: Text('سالانه'),
              icon: Icon(Icons.calendar_today),
            ),
          ],
          selected: {app.reportYearly},
          onSelectionChanged: (s) => app.setReportYearly(s.first),
        ),
        const SizedBox(height: 12),
        if (app.reportYearly)
          ..._yearlyChildren(context, app)
        else
          ..._monthlyChildren(context, app),
      ],
    );
  }
}

// ======================================================================
// گزارش ماهانه
// ======================================================================

List<Widget> _monthlyChildren(BuildContext context, AppState app) {
  final income = app.totalIncome;
  final expense = app.totalExpense;
  final balance = app.balance;

  final days = app.isCurrentMonth
      ? math.max(
          1,
          DateTime.now().difference(monthStart(app.year, app.month)).inDays + 1,
        )
      : monthLengthOf(app.year, app.month);
  final avgDaily = expense ~/ days;
  final saveRate = income > 0 ? (balance * 100 / income).round() : null;

  final spent = app.sumByCategory(income: false);
  final budgeted =
      app.categoriesOf(false).where((c) => app.budgetOf(c) > 0).toList();
  final top = app.txs.where((t) => !t.isIncome).toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));

  return [
    SectionCard(
      title: 'خلاصه ${fmtMonthYear(app.year, app.month)}',
      child: Column(
        children: [
          KeyValueRow('کل درآمد', fmtMoney(income), valueColor: kIncomeColor),
          KeyValueRow('کل هزینه', fmtMoney(expense), valueColor: kExpenseColor),
          const Divider(),
          KeyValueRow(
            balance >= 0 ? 'پس‌انداز ماه' : 'کسری ماه',
            fmtMoney(balance.abs()),
            valueColor: balance >= 0 ? kIncomeColor : kExpenseColor,
            bold: true,
          ),
          if (saveRate != null)
            KeyValueRow('درصد پس‌انداز از درآمد', '${toFa(saveRate)}٪'),
          KeyValueRow('میانگین هزینه روزانه', fmtMoney(avgDaily)),
        ],
      ),
    ),
    _categoryCard(app, app.txs, income: false, title: 'هزینه به تفکیک دسته'),
    if (expense > 0)
      SectionCard(
        title: 'ضروری و غیرضروری',
        child: _NecessityBody(necessityTotalsOf(app.txs)),
      ),
    SectionCard(title: 'روند ۶ ماه اخیر', child: _TrendChart(app.history)),
    if (budgeted.isNotEmpty)
      SectionCard(
        title: 'بودجه در برابر خرج واقعی',
        child: Column(
          children: [
            for (final c in budgeted)
              _BudgetCompareRow(c, spent[c.id] ?? 0, app.budgetOf(c)),
          ],
        ),
      ),
    if (app.txs.any((t) => t.isIncome))
      _categoryCard(app, app.txs, income: true, title: 'درآمد به تفکیک منبع'),
    if (top.isNotEmpty)
      SectionCard(
        title: 'بزرگ‌ترین هزینه‌های ماه',
        child: Column(
          children: [for (final t in top.take(5)) TransactionTile(t)],
        ),
      ),
  ];
}

// ======================================================================
// گزارش سالانه
// ======================================================================

List<Widget> _yearlyChildren(BuildContext context, AppState app) {
  final txs = app.yearTxs;

  // هر ماه: [درآمد، هزینه]
  final months = List.generate(12, (_) => [0, 0]);
  for (final t in txs) {
    final m = Jalali.fromDateTime(t.date).month;
    months[m - 1][t.isIncome ? 0 : 1] += t.amount;
  }
  final income = months.fold(0, (a, m) => a + m[0]);
  final expense = months.fold(0, (a, m) => a + m[1]);
  final balance = income - expense;
  final saveRate = income > 0 ? (balance * 100 / income).round() : null;

  final active = [
    for (var i = 0; i < 12; i++)
      if (months[i][0] > 0 || months[i][1] > 0) i,
  ];
  final avgExpense = active.isEmpty ? 0 : expense ~/ active.length;

  int? maxIdx;
  int? minIdx;
  for (final i in active) {
    if (months[i][1] <= 0) continue;
    if (maxIdx == null || months[i][1] > months[maxIdx][1]) maxIdx = i;
    if (minIdx == null || months[i][1] < months[minIdx][1]) minIdx = i;
  }
  final maxExpense = months.fold(0, (a, m) => math.max(a, m[1]));

  final top = txs.where((t) => !t.isIncome).toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));

  final switcher = Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      IconButton(
        tooltip: 'سال قبل',
        onPressed: () => app.shiftReportYear(-1),
        icon: const Icon(Icons.chevron_right),
      ),
      Text(
        'سال ${toFa(app.reportYear)}',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      IconButton(
        tooltip: 'سال بعد',
        onPressed: () => app.shiftReportYear(1),
        icon: const Icon(Icons.chevron_left),
      ),
    ],
  );

  if (txs.isEmpty) {
    return [
      switcher,
      const SectionCard(
        child: EmptyHint('برای این سال تراکنشی ثبت نشده'),
      ),
    ];
  }

  return [
    switcher,
    SectionCard(
      title: 'خلاصه سال ${toFa(app.reportYear)}',
      child: Column(
        children: [
          KeyValueRow('کل درآمد', fmtMoney(income), valueColor: kIncomeColor),
          KeyValueRow('کل هزینه', fmtMoney(expense), valueColor: kExpenseColor),
          const Divider(),
          KeyValueRow(
            balance >= 0 ? 'پس‌انداز سال' : 'کسری سال',
            fmtMoney(balance.abs()),
            valueColor: balance >= 0 ? kIncomeColor : kExpenseColor,
            bold: true,
          ),
          if (saveRate != null)
            KeyValueRow('درصد پس‌انداز از درآمد', '${toFa(saveRate)}٪'),
          KeyValueRow('میانگین هزینه ماهانه', fmtMoney(avgExpense)),
          if (maxIdx != null)
            KeyValueRow(
              'پرهزینه‌ترین ماه',
              '${kJalaliMonths[maxIdx]} (${fmtNum(months[maxIdx][1])})',
            ),
          if (minIdx != null && minIdx != maxIdx)
            KeyValueRow(
              'کم‌هزینه‌ترین ماه',
              '${kJalaliMonths[minIdx]} (${fmtNum(months[minIdx][1])})',
            ),
        ],
      ),
    ),
    _categoryCard(app, txs, income: false, title: 'هزینه به تفکیک دسته'),
    if (expense > 0)
      SectionCard(
        title: 'ضروری و غیرضروری',
        child: _NecessityBody(necessityTotalsOf(txs)),
      ),
    SectionCard(
      title: 'ماه‌به‌ماه (برای دیدن گزارش ماه، رویش بزنید)',
      child: Column(
        children: [
          for (var i = 0; i < 12; i++)
            _MonthRow(
              name: kJalaliMonths[i],
              income: months[i][0],
              expense: months[i][1],
              maxExpense: maxExpense,
              onTap: () => app.openMonth(app.reportYear, i + 1),
            ),
        ],
      ),
    ),
    if (txs.any((t) => t.isIncome))
      _categoryCard(app, txs, income: true, title: 'درآمد به تفکیک منبع'),
    if (top.isNotEmpty)
      SectionCard(
        title: 'بزرگ‌ترین هزینه‌های سال',
        child: Column(
          children: [for (final t in top.take(5)) TransactionTile(t)],
        ),
      ),
  ];
}

// ======================================================================
// اجزای مشترک
// ======================================================================

Color _catColor(AppState app, int id) {
  final c = app.categoryById(id == -1 ? null : id);
  return c == null ? Colors.grey : Color(c.color);
}

/// کارت «به تفکیک دسته» با نمودار دایره‌ای و فهرست سهم هر دسته
Widget _categoryCard(
  AppState app,
  List<TransactionItem> txs, {
  required bool income,
  required String title,
}) {
  final sums = sumByCategoryOf(txs, income: income).entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final total = sums.fold(0, (a, e) => a + e.value);

  return SectionCard(
    title: title,
    child: sums.isEmpty
        ? EmptyHint(
            income ? 'درآمدی ثبت نشده' : 'هزینه‌ای ثبت نشده',
            icon: Icons.pie_chart_outline,
          )
        : Column(
            children: [
              Center(
                child: DonutChart(
                  slices: [
                    for (final e in sums)
                      DonutSlice(e.value.toDouble(), _catColor(app, e.key)),
                  ],
                  centerLabel: income ? 'جمع درآمد' : 'جمع هزینه',
                  centerValue: fmtCompact(total),
                ),
              ),
              const SizedBox(height: 12),
              for (final e in sums) _ShareRow(app, e.key, e.value, total),
            ],
          ),
  );
}

class _ShareRow extends StatelessWidget {
  final AppState app;
  final int catId;
  final int amount;
  final int total;
  const _ShareRow(this.app, this.catId, this.amount, this.total);

  @override
  Widget build(BuildContext context) {
    final cat = app.categoryById(catId == -1 ? null : catId);
    final pct = total == 0 ? 0.0 : amount / total;
    final color = cat == null ? Colors.grey : Color(cat.color);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                cat == null ? Icons.help_outline : iconOf(cat.icon),
                size: 18,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(cat?.name ?? 'بدون دسته')),
              Text('${fmtNum(amount)}  (${toFa((pct * 100).round())}٪)'),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
            color: color,
            backgroundColor: color.withValues(alpha: 0.12),
          ),
        ],
      ),
    );
  }
}

/// یک ردیف ماه در گزارش سالانه
class _MonthRow extends StatelessWidget {
  final String name;
  final int income;
  final int expense;
  final int maxExpense;
  final VoidCallback onTap;
  const _MonthRow({
    required this.name,
    required this.income,
    required this.expense,
    required this.maxExpense,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final balance = income - expense;
    final empty = income == 0 && expense == 0;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (empty)
                  Text(
                    'بدون تراکنش',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).hintColor,
                    ),
                  )
                else
                  Text(
                    '${balance >= 0 ? '+' : '−'}${fmtNum(balance.abs())}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: balance >= 0 ? kIncomeColor : kExpenseColor,
                    ),
                  ),
              ],
            ),
            if (!empty) ...[
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: maxExpense == 0
                    ? 0
                    : (expense / maxExpense).clamp(0.0, 1.0),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
                color: kExpenseColor,
                backgroundColor: kExpenseColor.withValues(alpha: 0.12),
              ),
              const SizedBox(height: 2),
              Text(
                'هزینه ${fmtNum(expense)} • درآمد ${fmtNum(income)}',
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BudgetCompareRow extends StatelessWidget {
  final Category cat;
  final int spent;
  final int budget; // سقف مؤثر ماه انتخاب‌شده
  const _BudgetCompareRow(this.cat, this.spent, this.budget);

  @override
  Widget build(BuildContext context) {
    final diff = budget - spent;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(cat.name)),
              Text(
                diff >= 0
                    ? '${fmtNum(diff)} باقی‌مانده'
                    : '${fmtNum(-diff)} بیش از سقف',
                style: TextStyle(
                  color: diff >= 0 ? kIncomeColor : kExpenseColor,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          BudgetBar(spent: spent, budget: budget),
          const SizedBox(height: 2),
          Text(
            '${fmtNum(spent)} از ${fmtNum(budget)}',
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  final List<MonthTotals> data;
  const _TrendChart(this.data);

  @override
  Widget build(BuildContext context) {
    var maxV = 0;
    for (final m in data) {
      maxV = math.max(maxV, math.max(m.income, m.expense));
    }
    if (maxV == 0) {
      return const EmptyHint('هنوز داده‌ای برای نمودار نیست',
          icon: Icons.bar_chart);
    }
    const chartH = 120.0;
    Widget bar(int v, Color c) => Container(
          width: 12,
          height: math.max(2.0, chartH * v / maxV),
          decoration: BoxDecoration(
            color: c,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          ),
        );

    return Column(
      children: [
        SizedBox(
          height: chartH + 36,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final m in data)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          bar(m.income, kIncomeColor),
                          const SizedBox(width: 3),
                          bar(m.expense, kExpenseColor),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        kJalaliMonths[m.month - 1],
                        style: const TextStyle(fontSize: 11),
                      ),
                      Text(
                        fmtCompact(m.expense),
                        style: TextStyle(
                          fontSize: 9,
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.square, size: 12, color: kIncomeColor),
            SizedBox(width: 4),
            Text('درآمد', style: TextStyle(fontSize: 12)),
            SizedBox(width: 16),
            Icon(Icons.square, size: 12, color: kExpenseColor),
            SizedBox(width: 4),
            Text('هزینه (عدد زیر ماه)', style: TextStyle(fontSize: 12)),
          ],
        ),
      ],
    );
  }
}

/// جمع هزینه‌ها به تفکیک ضروری / غیرضروری / تعیین‌نشده
class _NecessityBody extends StatelessWidget {
  /// [تعیین‌نشده، ضروری، غیرضروری]
  final List<int> totals;
  const _NecessityBody(this.totals);

  @override
  Widget build(BuildContext context) {
    final sum = totals.fold(0, (a, b) => a + b);
    // ترتیب نمایش: ضروری، غیرضروری، تعیین‌نشده
    const order = [1, 2, 0];
    final colors = {
      1: kIncomeColor,
      2: Colors.orange.shade800,
      0: Colors.blueGrey,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final k in order)
          if (totals[k] > 0 || k != 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(kNecessityLabels[k])),
                      Text(
                        '${fmtNum(totals[k])}  (${toFa(sum == 0 ? 0 : (totals[k] * 100 / sum).round())}٪)',
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: sum == 0 ? 0 : (totals[k] / sum).clamp(0.0, 1.0),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                    color: colors[k],
                    backgroundColor: colors[k]!.withValues(alpha: 0.12),
                  ),
                ],
              ),
            ),
        if (totals[0] > 0)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'برای دقیق‌تر شدن گزارش، موقع ثبت هزینه، نوعش را (ضروری یا غیرضروری) انتخاب کنید.',
              style: TextStyle(fontSize: 12),
            ),
          ),
      ],
    );
  }
}
