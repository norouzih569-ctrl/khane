import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import 'widgets.dart';

// ======================================================================
// فرم ثبت / ویرایش تراکنش
// ======================================================================

Future<void> openTransactionForm(
  BuildContext context, {
  TransactionItem? edit,
  bool income = false,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => TransactionFormPage(edit: edit, initialIncome: income),
    ),
  );
}

class TransactionFormPage extends StatefulWidget {
  final TransactionItem? edit;
  final bool initialIncome;
  const TransactionFormPage({super.key, this.edit, this.initialIncome = false});

  @override
  State<TransactionFormPage> createState() => _TransactionFormPageState();
}

class _TransactionFormPageState extends State<TransactionFormPage> {
  late bool _income;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late DateTime _date;
  int? _categoryId;
  int _necessity = 0; // 0 تعیین‌نشده، 1 ضروری، 2 غیرضروری

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    _necessity = e?.necessity ?? 0;
    _income = e?.isIncome ?? widget.initialIncome;
    _amount = TextEditingController(text: e == null ? '' : moneyText(e.amount));
    _note = TextEditingController(text: e?.note ?? '');
    _date = e?.date ?? dateOnly(DateTime.now());
    _categoryId = e?.categoryId;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final app = context.read<AppState>();
    final amount = parseMoney(_amount.text);
    if (amount <= 0) {
      messenger.showSnackBar(const SnackBar(content: Text('مبلغ را وارد کنید')));
      return;
    }
    if (_categoryId == null) {
      messenger
          .showSnackBar(const SnackBar(content: Text('یک دسته انتخاب کنید')));
      return;
    }
    final msg = await app.saveTransaction(
      TransactionItem(
        id: widget.edit?.id,
        isIncome: _income,
        amount: amount,
        categoryId: _categoryId,
        note: _note.text.trim(),
        date: _date,
        necessity: _income ? 0 : _necessity,
      ),
    );
    nav.pop();
    if (msg != null) {
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _delete() async {
    final nav = Navigator.of(context);
    final app = context.read<AppState>();
    final ok = await confirmDialog(context, 'این تراکنش حذف شود؟');
    if (!ok) return;
    await app.deleteTransaction(widget.edit!.id!);
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final cats = app.categoriesOf(_income);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.edit == null ? 'ثبت تراکنش' : 'ویرایش تراکنش'),
        actions: [
          if (widget.edit != null)
            IconButton(
              tooltip: 'حذف',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                label: Text('هزینه'),
                icon: Icon(Icons.arrow_upward),
              ),
              ButtonSegment(
                value: true,
                label: Text('درآمد'),
                icon: Icon(Icons.arrow_downward),
              ),
            ],
            selected: {_income},
            onSelectionChanged: (s) => setState(() {
              _income = s.first;
              _categoryId = null;
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amount,
            autofocus: widget.edit == null,
            keyboardType: TextInputType.number,
            inputFormatters: [MoneyInputFormatter()],
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              labelText: _income ? 'مبلغ درآمد (تومان)' : 'مبلغ هزینه (تومان)',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _income ? 'منبع درآمد' : 'دسته هزینه',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final c in cats)
                ChoiceChip(
                  avatar: Icon(iconOf(c.icon), size: 18, color: Color(c.color)),
                  label: Text(c.name),
                  selected: _categoryId == c.id,
                  onSelected: (_) => setState(() => _categoryId = c.id),
                ),
            ],
          ),
          if (!_income) ...[
            const SizedBox(height: 16),
            const Text(
              'نوع هزینه (اختیاری)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              emptySelectionAllowed: true,
              segments: const [
                ButtonSegment(value: 1, label: Text('ضروری')),
                ButtonSegment(value: 2, label: Text('غیرضروری')),
              ],
              selected: _necessity == 0 ? <int>{} : {_necessity},
              onSelectionChanged: (s) =>
                  setState(() => _necessity = s.isEmpty ? 0 : s.first),
            ),
          ],
          const SizedBox(height: 16),
          DateField(
            label: 'تاریخ',
            value: _date,
            onChanged: (d) => setState(() => _date = d),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            decoration: const InputDecoration(
              labelText: 'توضیح (اختیاری)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('ذخیره'),
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================================
// دیالوگ دسته (افزودن / ویرایش / حذف)
// ======================================================================

Future<void> showCategoryDialog(
  BuildContext context, {
  Category? edit,
  bool income = false,
}) async {
  final app = context.read<AppState>();
  final isIncome = edit?.isIncome ?? income;
  final name = TextEditingController(text: edit?.name ?? '');
  final budget = TextEditingController(text: moneyText(edit?.budget ?? 0));
  var icon = edit?.icon ?? 13;
  var color = edit?.color ?? kColors[4];

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: Text(edit == null
            ? (isIncome ? 'منبع درآمد جدید' : 'دسته هزینه جدید')
            : 'ویرایش دسته'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(
                  labelText: 'نام',
                  border: OutlineInputBorder(),
                ),
              ),
              if (!isIncome) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: budget,
                  keyboardType: TextInputType.number,
                  inputFormatters: [MoneyInputFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'سقف پیش‌فرض ماهانه (تومان)',
                    helperText: 'خالی = بدون سقف',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Text('رنگ'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in kColors)
                    GestureDetector(
                      onTap: () => setS(() => color = c),
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: Color(c),
                        child: color == c
                            ? const Icon(Icons.check,
                                size: 16, color: Colors.white)
                            : null,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('آیکون'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < kIcons.length; i++)
                    GestureDetector(
                      onTap: () => setS(() => icon = i),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: icon == i
                              ? Color(color).withValues(alpha: 0.2)
                              : null,
                          border: Border.all(
                            color: icon == i ? Color(color) : Colors.transparent,
                          ),
                        ),
                        child: Icon(kIcons[i], size: 22),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          if (edit != null)
            TextButton(
              onPressed: () async {
                final nav = Navigator.of(ctx);
                final ok = await confirmDialog(
                  ctx,
                  'دسته «${edit.name}» حذف شود؟ تراکنش‌های آن بدون دسته می‌مانند.',
                );
                if (ok) {
                  await app.deleteCategory(edit.id!);
                  nav.pop();
                }
              },
              child: const Text('حذف', style: TextStyle(color: kExpenseColor)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () async {
              final n = name.text.trim();
              if (n.isEmpty) return;
              final nav = Navigator.of(ctx);
              await app.saveCategory(
                Category(
                  id: edit?.id,
                  name: n,
                  icon: icon,
                  color: color,
                  isIncome: isIncome,
                  budget: isIncome ? 0 : parseMoney(budget.text),
                ),
              );
              nav.pop();
            },
            child: const Text('ذخیره'),
          ),
        ],
      ),
    ),
  );
}

// ======================================================================
// فرم قسط
// ======================================================================

Future<void> showInstallmentSheet(BuildContext context, {Installment? edit}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _InstallmentForm(edit: edit),
  );
}

const List<int> kRemindOptions = [0, 1, 2, 3, 5, 7];

String remindLabel(int d) => d == 0 ? 'همان روز' : '${toFa(d)} روز قبل';

class _InstallmentForm extends StatefulWidget {
  final Installment? edit;
  const _InstallmentForm({this.edit});

  @override
  State<_InstallmentForm> createState() => _InstallmentFormState();
}

class _InstallmentFormState extends State<_InstallmentForm> {
  late final TextEditingController _title;
  late final TextEditingController _amount;
  late final TextEditingController _total;
  late final TextEditingController _paid;
  late DateTime _due;
  late int _remind;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    _title = TextEditingController(text: e?.title ?? '');
    _amount = TextEditingController(text: e == null ? '' : moneyText(e.amount));
    _total = TextEditingController(text: e == null ? '' : toFa(e.totalCount));
    _paid = TextEditingController(text: toFa(e?.paidCount ?? 0));
    _due = e?.nextDue ?? addMonthsDt(dateOnly(DateTime.now()), 1);
    _remind = e?.remindDays ?? 2;
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _total.dispose();
    _paid.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final app = context.read<AppState>();
    final amount = parseMoney(_amount.text);
    final total = parseMoney(_total.text);
    final paid = parseMoney(_paid.text);
    if (_title.text.trim().isEmpty || amount <= 0 || total <= 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('عنوان، مبلغ هر قسط و تعداد اقساط را وارد کنید')),
      );
      return;
    }
    await app.saveInstallment(
      Installment(
        id: widget.edit?.id,
        title: _title.text.trim(),
        amount: amount,
        totalCount: total,
        paidCount: paid > total ? total : paid,
        nextDue: _due,
        remindDays: _remind,
      ),
    );
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.edit == null ? 'قسط جدید' : 'ویرایش قسط',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'عنوان (مثلاً وام خودرو)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [MoneyInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'مبلغ هر قسط (تومان)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _total,
                    keyboardType: TextInputType.number,
                    inputFormatters: [MoneyInputFormatter()],
                    decoration: const InputDecoration(
                      labelText: 'تعداد کل اقساط',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _paid,
                    keyboardType: TextInputType.number,
                    inputFormatters: [MoneyInputFormatter()],
                    decoration: const InputDecoration(
                      labelText: 'تا الان پرداخت‌شده',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DateField(
              label: 'سررسید قسط بعدی',
              value: _due,
              onChanged: (d) => setState(() => _due = d),
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'یادآوری',
                border: OutlineInputBorder(),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  isDense: true,
                  isExpanded: true,
                  value: _remind,
                  items: [
                    for (final d in kRemindOptions)
                      DropdownMenuItem(value: d, child: Text(remindLabel(d))),
                  ],
                  onChanged: (v) => setState(() => _remind = v ?? _remind),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('ذخیره'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================================
// فرم یادآور
// ======================================================================

Future<void> showReminderSheet(BuildContext context, {ReminderItem? edit}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _ReminderForm(edit: edit),
  );
}

class _ReminderForm extends StatefulWidget {
  final ReminderItem? edit;
  const _ReminderForm({this.edit});

  @override
  State<_ReminderForm> createState() => _ReminderFormState();
}

class _ReminderFormState extends State<_ReminderForm> {
  late final TextEditingController _title;
  late final TextEditingController _amount;
  late DateTime _due;
  late bool _monthly;
  late int _remind;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    _title = TextEditingController(text: e?.title ?? '');
    _amount = TextEditingController(text: e == null ? '' : moneyText(e.amount));
    _due = e?.due ?? dateOnly(DateTime.now()).add(const Duration(days: 7));
    _monthly = e?.monthly ?? false;
    _remind = e?.remindDays ?? 1;
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final app = context.read<AppState>();
    if (_title.text.trim().isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('عنوان را وارد کنید')));
      return;
    }
    await app.saveReminder(
      ReminderItem(
        id: widget.edit?.id,
        title: _title.text.trim(),
        amount: parseMoney(_amount.text),
        due: _due,
        monthly: _monthly,
        done: false,
        remindDays: _remind,
      ),
    );
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.edit == null ? 'یادآور جدید' : 'ویرایش یادآور',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'عنوان (مثلاً قبض برق، اجاره خانه)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [MoneyInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'مبلغ (اختیاری، تومان)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DateField(
              label: 'موعد',
              value: _due,
              onChanged: (d) => setState(() => _due = d),
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'یادآوری',
                border: OutlineInputBorder(),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  isDense: true,
                  isExpanded: true,
                  value: _remind,
                  items: [
                    for (final d in kRemindOptions)
                      DropdownMenuItem(value: d, child: Text(remindLabel(d))),
                  ],
                  onChanged: (v) => setState(() => _remind = v ?? _remind),
                ),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('هر ماه تکرار شود'),
              value: _monthly,
              onChanged: (v) => setState(() => _monthly = v),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('ذخیره'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================================
// دیالوگ سقف بودجه‌ی یک دسته (برای همه‌ی ماه‌ها یا فقط ماه انتخاب‌شده)
// ======================================================================

Future<void> showBudgetDialog(BuildContext context, Category cat) async {
  final app = context.read<AppState>();
  final controller = TextEditingController(text: moneyText(app.budgetOf(cat)));
  final hasOverride = app.hasMonthOverride(cat);
  final monthLabel = fmtMonthYear(app.year, app.month);
  final defaultText =
      cat.budget > 0 ? fmtMoney(cat.budget) : 'بدون سقف';

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('سقف «${cat.name}»'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [MoneyInputFormatter()],
            decoration: const InputDecoration(
              labelText: 'سقف (تومان)',
              helperText: 'خالی = بدون سقف',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            hasOverride
                ? 'برای $monthLabel سقف ویژه تعیین شده است. سقف پیش‌فرض بقیه‌ی ماه‌ها: $defaultText'
                : 'سقف فعلی برای همه‌ی ماه‌هاست ($defaultText). می‌توانید فقط برای $monthLabel سقف دیگری بگذارید.',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            showCategoryDialog(context, edit: cat);
          },
          child: const Text('ویرایش دسته'),
        ),
        if (hasOverride)
          TextButton(
            onPressed: () async {
              final nav = Navigator.of(ctx);
              await app.clearMonthBudget(cat);
              nav.pop();
            },
            child: const Text('حذف سقف این ماه'),
          ),
        FilledButton.tonal(
          onPressed: () async {
            final nav = Navigator.of(ctx);
            await app.setBudget(
              cat,
              parseMoney(controller.text),
              thisMonthOnly: true,
            );
            nav.pop();
          },
          child: Text('فقط $monthLabel'),
        ),
        FilledButton(
          onPressed: () async {
            final nav = Navigator.of(ctx);
            await app.setBudget(
              cat,
              parseMoney(controller.text),
              thisMonthOnly: false,
            );
            nav.pop();
          },
          child: const Text('همه ماه‌ها'),
        ),
      ],
    ),
  );
}

// ======================================================================
// هدف پس‌انداز
// ======================================================================

Future<void> showGoalSheet(BuildContext context, {Goal? edit}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _GoalForm(edit: edit),
  );
}

class _GoalForm extends StatefulWidget {
  final Goal? edit;
  const _GoalForm({this.edit});

  @override
  State<_GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends State<_GoalForm> {
  late final TextEditingController _title;
  late final TextEditingController _target;
  late final TextEditingController _saved;
  late bool _hasDue;
  late DateTime _due;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    _title = TextEditingController(text: e?.title ?? '');
    _target = TextEditingController(text: e == null ? '' : moneyText(e.target));
    _saved = TextEditingController();
    _hasDue = e?.due != null;
    _due = e?.due ?? addMonthsDt(dateOnly(DateTime.now()), 6);
  }

  @override
  void dispose() {
    _title.dispose();
    _target.dispose();
    _saved.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final app = context.read<AppState>();
    final target = parseMoney(_target.text);
    if (_title.text.trim().isEmpty || target <= 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('عنوان و مبلغ هدف را وارد کنید')),
      );
      return;
    }
    await app.saveGoal(
      Goal(
        id: widget.edit?.id,
        title: _title.text.trim(),
        target: target,
        saved: widget.edit?.saved ?? parseMoney(_saved.text),
        due: _hasDue ? _due : null,
      ),
    );
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.edit == null ? 'هدف پس‌انداز جدید' : 'ویرایش هدف',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'عنوان (مثلاً خرید یخچال)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _target,
              keyboardType: TextInputType.number,
              inputFormatters: [MoneyInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'مبلغ هدف (تومان)',
                border: OutlineInputBorder(),
              ),
            ),
            if (widget.edit == null) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _saved,
                keyboardType: TextInputType.number,
                inputFormatters: [MoneyInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'تا الان چقدر جمع کرده‌اید؟ (اختیاری)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('تاریخ هدف دارم'),
              value: _hasDue,
              onChanged: (v) => setState(() => _hasDue = v),
            ),
            if (_hasDue)
              DateField(
                label: 'می‌خواهم تا این تاریخ جمع شود',
                value: _due,
                onChanged: (d) => setState(() => _due = d),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('ذخیره'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// افزودن به پس‌انداز یک هدف یا برداشت از آن
Future<void> showGoalAmountDialog(
  BuildContext context,
  Goal g, {
  required bool add,
}) async {
  final app = context.read<AppState>();
  final controller = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(add ? 'افزودن به «${g.title}»' : 'برداشت از «${g.title}»'),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [MoneyInputFormatter()],
        decoration: InputDecoration(
          labelText: 'مبلغ (تومان)',
          helperText: add ? null : 'حداکثر ${fmtMoney(g.saved)}',
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('انصراف'),
        ),
        FilledButton(
          onPressed: () async {
            final amount = parseMoney(controller.text);
            if (amount <= 0) return;
            final nav = Navigator.of(ctx);
            await app.addToGoal(g, add ? amount : -amount);
            nav.pop();
          },
          child: Text(add ? 'افزودن' : 'برداشت'),
        ),
      ],
    ),
  );
}

// ======================================================================
// تراکنش تکراری ماهانه
// ======================================================================

Future<void> showRecurringSheet(BuildContext context, {RecurringItem? edit}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _RecurringForm(edit: edit),
  );
}

class _RecurringForm extends StatefulWidget {
  final RecurringItem? edit;
  const _RecurringForm({this.edit});

  @override
  State<_RecurringForm> createState() => _RecurringFormState();
}

class _RecurringFormState extends State<_RecurringForm> {
  late bool _income;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late DateTime _start;
  bool _dateChanged = false;
  int? _categoryId;
  int _necessity = 0;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    _income = e?.isIncome ?? false;
    _amount = TextEditingController(text: e == null ? '' : moneyText(e.amount));
    _note = TextEditingController(text: e?.note ?? '');
    _start = e?.nextDate ?? dateOnly(DateTime.now());
    _categoryId = e?.categoryId;
    _necessity = e?.necessity ?? 0;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final app = context.read<AppState>();
    final amount = parseMoney(_amount.text);
    if (amount <= 0) {
      messenger.showSnackBar(const SnackBar(content: Text('مبلغ را وارد کنید')));
      return;
    }
    if (_categoryId == null) {
      messenger
          .showSnackBar(const SnackBar(content: Text('یک دسته انتخاب کنید')));
      return;
    }
    final e = widget.edit;
    // اگر تاریخ دست‌نخورده باشد، «روز ماه» اصلی حفظ می‌شود (مثلاً ۳۱ در ماه‌های ۳۰ روزه)
    final day = (e != null && !_dateChanged)
        ? e.day
        : Jalali.fromDateTime(_start).day;
    await app.saveRecurring(
      RecurringItem(
        id: e?.id,
        isIncome: _income,
        amount: amount,
        categoryId: _categoryId,
        note: _note.text.trim(),
        day: day,
        nextDate: _start,
        necessity: _income ? 0 : _necessity,
        active: e?.active ?? true,
      ),
    );
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final cats = app.categoriesOf(_income);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                widget.edit == null
                    ? 'تراکنش تکراری جدید'
                    : 'ویرایش تراکنش تکراری',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('هزینه')),
                ButtonSegment(value: true, label: Text('درآمد')),
              ],
              selected: {_income},
              onSelectionChanged: (s) => setState(() {
                _income = s.first;
                _categoryId = null;
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [MoneyInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'مبلغ (تومان)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final c in cats)
                  ChoiceChip(
                    avatar:
                        Icon(iconOf(c.icon), size: 18, color: Color(c.color)),
                    label: Text(c.name),
                    selected: _categoryId == c.id,
                    onSelected: (_) => setState(() => _categoryId = c.id),
                  ),
              ],
            ),
            if (!_income) ...[
              const SizedBox(height: 12),
              SegmentedButton<int>(
                emptySelectionAllowed: true,
                segments: const [
                  ButtonSegment(value: 1, label: Text('ضروری')),
                  ButtonSegment(value: 2, label: Text('غیرضروری')),
                ],
                selected: _necessity == 0 ? <int>{} : {_necessity},
                onSelectionChanged: (s) =>
                    setState(() => _necessity = s.isEmpty ? 0 : s.first),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              decoration: const InputDecoration(
                labelText: 'توضیح (اختیاری، مثلاً اجاره خانه)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DateField(
              label: widget.edit == null
                  ? 'اولین تاریخ ثبت'
                  : 'تاریخ ثبت بعدی',
              value: _start,
              onChanged: (d) => setState(() {
                _start = d;
                _dateChanged = true;
              }),
            ),
            const SizedBox(height: 6),
            const Text(
              'از این تاریخ، هر ماه در همین روز خودکار ثبت می‌شود. '
              'اگر تاریخ امروز یا گذشته باشد، ماه‌های سپری‌شده هم همین حالا ثبت می‌شوند.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('ذخیره'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
