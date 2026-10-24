import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../state/app_state.dart';
import '../../utils/format.dart';
import '../forms.dart';
import '../widgets.dart';

class BudgetPage extends StatelessWidget {
  const BudgetPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final income = app.totalIncome;
    final allocated = app.totalAllocated;
    final free = income - allocated;
    final spent = app.sumByCategory(income: false);
    final earned = app.sumByCategory(income: true);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        SectionCard(
          title: 'طرح بودجه ${fmtMonthYear(app.year, app.month)}',
          child: Column(
            children: [
              KeyValueRow('درآمد ثبت‌شده', fmtMoney(income),
                  valueColor: kIncomeColor),
              KeyValueRow('مجموع سقف دسته‌ها', fmtMoney(allocated)),
              const Divider(),
              KeyValueRow(
                free >= 0 ? 'مانده برای تخصیص' : 'تخصیص بیش از درآمد',
                fmtMoney(free.abs()),
                valueColor: free >= 0 ? kIncomeColor : kExpenseColor,
                bold: true,
              ),
              const SizedBox(height: 8),
              const Text(
                'روی هر دسته بزنید تا سقفش را تعیین کنید؛ یا برای همه‌ی ماه‌ها '
                'یا فقط برای همین ماه (مثلاً در ماه مسافرت سقف بیشتری بگذارید).',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'دسته‌های هزینه',
          trailing: TextButton.icon(
            onPressed: () => showCategoryDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('دسته جدید'),
          ),
          child: app.gridView
              ? GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    mainAxisExtent: 156,
                  ),
                  itemCount: app.categoriesOf(false).length,
                  itemBuilder: (ctx, i) {
                    final c = app.categoriesOf(false)[i];
                    return _CategoryGridCard(
                      cat: c,
                      spent: spent[c.id] ?? 0,
                      budget: app.budgetOf(c),
                      special: app.hasMonthOverride(c),
                    );
                  },
                )
              : Column(
                  children: [
                    for (final c in app.categoriesOf(false))
                      _ExpenseCategoryRow(
                        cat: c,
                        spent: spent[c.id] ?? 0,
                        budget: app.budgetOf(c),
                        special: app.hasMonthOverride(c),
                      ),
                  ],
                ),
        ),
        SectionCard(
          title: 'منابع درآمد',
          trailing: TextButton.icon(
            onPressed: () => showCategoryDialog(context, income: true),
            icon: const Icon(Icons.add),
            label: const Text('منبع جدید'),
          ),
          child: Column(
            children: [
              for (final c in app.categoriesOf(true))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CatAvatar(c),
                  title: Text(c.name),
                  subtitle: Text('این ماه: ${fmtMoney(earned[c.id] ?? 0)}'),
                  onTap: () => showCategoryDialog(context, edit: c),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExpenseCategoryRow extends StatelessWidget {
  final Category cat;
  final int spent;
  final int budget; // سقف مؤثر این ماه
  final bool special; // سقف ویژه‌ی همین ماه است
  const _ExpenseCategoryRow({
    required this.cat,
    required this.spent,
    required this.budget,
    required this.special,
  });

  @override
  Widget build(BuildContext context) {
    final hasBudget = budget > 0;
    final over = hasBudget && spent > budget;
    return InkWell(
      onTap: () => showBudgetDialog(context, cat),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CatAvatar(cat),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          cat.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (special)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 6),
                          child: Icon(
                            Icons.push_pin,
                            size: 14,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      Text(
                        hasBudget ? 'سقف: ${fmtNum(budget)}' : 'بدون سقف',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  if (hasBudget) ...[
                    const SizedBox(height: 6),
                    BudgetBar(spent: spent, budget: budget),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    hasBudget
                        ? (over
                            ? 'خرج‌شده ${fmtNum(spent)} — ${fmtNum(spent - budget)} بیشتر از سقف'
                            : 'خرج‌شده ${fmtNum(spent)} — باقی‌مانده ${fmtNum(budget - spent)}')
                        : 'خرج‌شده ${fmtNum(spent)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: over ? kExpenseColor : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// کارت شبکه‌ای یک دسته: حلقه‌ی پیشرفت دور آیکون + مصرف و باقی‌مانده
class _CategoryGridCard extends StatelessWidget {
  final Category cat;
  final int spent;
  final int budget;
  final bool special;
  const _CategoryGridCard({
    required this.cat,
    required this.spent,
    required this.budget,
    required this.special,
  });

  @override
  Widget build(BuildContext context) {
    final hasBudget = budget > 0;
    final over = hasBudget && spent > budget;
    final ratio = hasBudget ? (spent / budget).clamp(0.0, 1.0) : 0.0;
    final color = budgetColor(spent, budget);
    final hint = Theme.of(context).hintColor;

    final status = !hasBudget
        ? 'بدون سقف'
        : (over
            ? '${fmtNum(spent - budget)} بیش از سقف'
            : '${fmtNum(budget - spent)} باقی‌مانده');

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showBudgetDialog(context, cat),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: CircularProgressIndicator(
                        value: ratio,
                        strokeWidth: 4,
                        color: color,
                        backgroundColor: color.withValues(alpha: 0.15),
                      ),
                    ),
                    CatAvatar(cat, radius: 16),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (special)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 4),
                      child: Icon(
                        Icons.push_pin,
                        size: 12,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  Flexible(
                    child: Text(
                      cat.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  hasBudget
                      ? '${fmtNum(spent)} از ${fmtNum(budget)}'
                      : 'خرج‌شده ${fmtNum(spent)}',
                  style: TextStyle(fontSize: 11, color: hint),
                ),
              ),
              const Spacer(),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: over ? kExpenseColor : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
