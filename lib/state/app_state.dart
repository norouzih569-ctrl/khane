import 'dart:convert';

import 'package:crypto/crypto.dart';
// فقط ChangeNotifier: وگرنه نام «Category» با کلاس Category خود Flutter تداخل می‌کند
import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:shamsi_date/shamsi_date.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/db.dart';
import '../data/models.dart';
import '../services/notifications.dart';
import '../utils/format.dart';

const int _instBase = 100000;
const int _remBase = 200000;
const int _dailyId = 1;

/// اگر برنامه بیشتر از این مدت در پس‌زمینه بماند، دوباره قفل می‌شود
const Duration kLockDelay = Duration(seconds: 30);

class AppState extends ChangeNotifier {
  final AppDb _db = AppDb.instance;

  bool loading = true;
  int year = 1405;
  int month = 1;

  List<Category> categories = [];
  List<TransactionItem> txs = []; // تراکنش‌های ماه انتخاب‌شده
  List<Installment> installments = [];
  List<ReminderItem> reminders = [];
  List<Goal> goals = [];
  List<RecurringItem> recurrings = [];
  List<MonthTotals> history = []; // ۶ ماه اخیر تا ماه انتخاب‌شده

  /// سقف‌های ویژه‌ی ماه انتخاب‌شده (شناسه دسته -> مبلغ)؛ بر سقف پیش‌فرض دسته غلبه دارند
  Map<int, int> monthBudgets = {};

  // گزارش سالانه
  bool reportYearly = false;
  int reportYear = 1405;
  List<TransactionItem> yearTxs = [];

  bool gridView = false; // false: کارتی، true: شبکه‌ای

  // قفل برنامه (رمز ۴ رقمی؛ فقط هش با salt ذخیره می‌شود)
  String? _pinHash;
  String _pinSalt = '';
  bool locked = false;
  DateTime? _backgroundAt;
  bool get lockEnabled => _pinHash != null;
  bool dailyOn = false;
  int dailyHour = 21;
  int dailyMinute = 0;

  // ---------------------------------------------------------------- init
  Future<void> init() async {
    final j = Jalali.now();
    year = j.year;
    month = j.month;
    reportYear = j.year;
    try {
      final prefs = await SharedPreferences.getInstance();
      gridView = prefs.getBool('grid_view') ?? false;
      _pinHash = prefs.getString('pin_hash');
      _pinSalt = prefs.getString('pin_salt') ?? '';
      locked = _pinHash != null;
      dailyOn = prefs.getBool('daily_on') ?? false;
      dailyHour = prefs.getInt('daily_h') ?? 21;
      dailyMinute = prefs.getInt('daily_m') ?? 0;
    } catch (_) {}
    categories = await _db.categories();
    installments = await _db.installments();
    reminders = await _db.reminders();
    goals = await _db.goals();
    recurrings = await _db.recurrings();
    await _generateRecurring(); // ثبت تراکنش‌های تکراری سررسیده
    await _loadMonth();
    loading = false;
    notifyListeners();
    await _rescheduleAll();
  }

  Future<void> _loadMonth() async {
    txs = await _db.txsBetween(
      monthStart(year, month),
      nextMonthStart(year, month),
    );
    final list = <MonthTotals>[];
    for (var k = 5; k >= 0; k--) {
      final j = addJalaliMonths(Jalali(year, month, 1), -k);
      final t = await _db.totalsBetween(
        monthStart(j.year, j.month),
        nextMonthStart(j.year, j.month),
      );
      list.add(MonthTotals(j.year, j.month, t[0], t[1]));
    }
    history = list;
    monthBudgets = await _db.monthBudgets(ym);
    if (reportYearly) await _loadYear();
  }

  Future<void> _loadYear() async {
    yearTxs = await _db.txsBetween(
      monthStart(reportYear, 1),
      monthStart(reportYear + 1, 1),
    );
  }

  Future<void> setReportYearly(bool v) async {
    reportYearly = v;
    if (v) await _loadYear();
    notifyListeners();
  }

  Future<void> shiftReportYear(int delta) async {
    reportYear += delta;
    await _loadYear();
    notifyListeners();
  }

  /// رفتن به گزارش ماهانه‌ی یک ماه مشخص (از روی گزارش سالانه)
  Future<void> openMonth(int y, int m) async {
    year = y;
    month = m;
    reportYearly = false;
    await _loadMonth();
    notifyListeners();
  }

  /// جستجو در همه‌ی ماه‌ها (توضیح، نام دسته یا مبلغ)
  Future<List<TransactionItem>> searchTransactions(String q) =>
      _db.searchTxs(q);

  Future<void> shiftMonth(int delta) async {
    final j = addJalaliMonths(Jalali(year, month, 1), delta);
    year = j.year;
    month = j.month;
    await _loadMonth();
    notifyListeners();
  }

  Future<void> goToToday() async {
    final j = Jalali.now();
    year = j.year;
    month = j.month;
    await _loadMonth();
    notifyListeners();
  }

  // ------------------------------------------------------------ computed
  bool get isCurrentMonth {
    final j = Jalali.now();
    return j.year == year && j.month == month;
  }

  int get totalIncome =>
      txs.where((t) => t.isIncome).fold(0, (a, t) => a + t.amount);
  int get totalExpense =>
      txs.where((t) => !t.isIncome).fold(0, (a, t) => a + t.amount);
  int get balance => totalIncome - totalExpense;

  int get ym => year * 100 + month;

  /// سقف مؤثر یک دسته در ماه انتخاب‌شده (۰ یعنی بدون سقف)
  int budgetOf(Category c) =>
      monthBudgets.containsKey(c.id) ? monthBudgets[c.id]! : c.budget;

  bool hasMonthOverride(Category c) => monthBudgets.containsKey(c.id);

  /// مجموع سقف‌های هزینه (تخصیص بودجه) در ماه انتخاب‌شده
  int get totalAllocated => categories
      .where((c) => !c.isIncome)
      .fold(0, (a, c) => a + budgetOf(c));

  /// جمع هزینه‌ها به تفکیک ضروری/غیرضروری: [تعیین‌نشده، ضروری، غیرضروری]
  List<int> get necessityTotals => necessityTotalsOf(txs);

  /// هزینه (یا درآمد) ماه به تفکیک دسته؛ کلید -1 یعنی بدون دسته
  Map<int, int> sumByCategory({required bool income}) {
    final m = <int, int>{};
    for (final t in txs) {
      if (t.isIncome != income) continue;
      final k = t.categoryId ?? -1;
      m[k] = (m[k] ?? 0) + t.amount;
    }
    return m;
  }

  List<Category> categoriesOf(bool income) =>
      categories.where((c) => c.isIncome == income).toList();

  Category? categoryById(int? id) {
    if (id == null) return null;
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  Category? _categoryByName(String name) {
    for (final c in categories) {
      if (!c.isIncome && c.name == name) return c;
    }
    return null;
  }

  List<UpcomingItem> get upcoming {
    final limit = dateOnly(DateTime.now()).add(const Duration(days: 14));
    final list = <UpcomingItem>[];
    for (final i in installments) {
      if (i.finished) continue;
      if (dateOnly(i.nextDue).isAfter(limit)) continue;
      list.add(UpcomingItem(i.title, i.amount, i.nextDue, true));
    }
    for (final r in reminders) {
      if (r.done) continue;
      if (dateOnly(r.due).isAfter(limit)) continue;
      list.add(UpcomingItem(r.title, r.amount, r.due, false));
    }
    list.sort((a, b) => a.due.compareTo(b.due));
    return list;
  }

  // -------------------------------------------------------- categories
  Future<void> saveCategory(Category c) async {
    if (c.id == null) {
      await _db.insertCategory(c);
    } else {
      await _db.updateCategory(c);
    }
    categories = await _db.categories();
    notifyListeners();
  }

  Future<void> deleteCategory(int id) async {
    await _db.deleteCategory(id);
    categories = await _db.categories();
    recurrings = await _db.recurrings();
    await _loadMonth();
    notifyListeners();
  }

  /// تعیین سقف یک دسته. اگر [thisMonthOnly] درست باشد فقط برای ماه انتخاب‌شده،
  /// وگرنه سقف پیش‌فرض همه‌ی ماه‌هاست (و استثنای همین ماه برداشته می‌شود).
  Future<void> setBudget(
    Category c,
    int amount, {
    required bool thisMonthOnly,
  }) async {
    if (c.id == null) return;
    if (thisMonthOnly) {
      await _db.setMonthBudget(c.id!, ym, amount);
    } else {
      await _db.updateCategory(c.copyWith(budget: amount));
      await _db.clearMonthBudget(c.id!, ym);
    }
    categories = await _db.categories();
    monthBudgets = await _db.monthBudgets(ym);
    notifyListeners();
  }

  /// حذف سقف ویژه‌ی این ماه (برمی‌گردد به سقف پیش‌فرض دسته)
  Future<void> clearMonthBudget(Category c) async {
    if (c.id == null) return;
    await _db.clearMonthBudget(c.id!, ym);
    monthBudgets = await _db.monthBudgets(ym);
    notifyListeners();
  }

  // ------------------------------------------------------ transactions
  /// ذخیره‌ی تراکنش. اگر هزینه از سقف دسته عبور کرده باشد، پیام هشدار برمی‌گرداند.
  Future<String?> saveTransaction(TransactionItem t) async {
    if (t.id == null) {
      await _db.insertTx(t);
    } else {
      await _db.updateTx(t);
    }
    await _loadMonth();
    notifyListeners();

    if (t.isIncome) return null;
    final cat = categoryById(t.categoryId);
    if (cat == null) return null;

    // سقف مربوط به ماهِ خودِ تراکنش (ویژه‌ی همان ماه یا پیش‌فرض دسته)
    final j = Jalali.fromDateTime(t.date);
    final override = await _db.monthBudgetFor(cat.id!, j.year * 100 + j.month);
    final budget = override ?? cat.budget;
    if (budget <= 0) return null;

    final spent = await _db.spentInCategory(
      cat.id!,
      monthStart(j.year, j.month),
      nextMonthStart(j.year, j.month),
    );
    String? msg;
    if (spent > budget) {
      msg =
          'بودجه «${cat.name}» به اندازه ${fmtMoney(spent - budget)} از سقف گذشت';
    } else if (spent >= budget * 0.9) {
      msg =
          'بیش از ۹۰٪ بودجه «${cat.name}» مصرف شده؛ ${fmtMoney(budget - spent)} باقی مانده';
    }
    if (msg != null) {
      await Notif.showNow(2, 'هشدار بودجه', msg);
    }
    return msg;
  }

  Future<void> deleteTransaction(int id) async {
    // ابتدا از لیست حذف می‌کنیم تا ویجت Dismissible همان لحظه از درخت خارج شود
    txs = txs.where((t) => t.id != id).toList();
    notifyListeners();
    await _db.deleteTx(id);
    await _loadMonth();
    notifyListeners();
  }

  // ------------------------------------------------------- installments
  DateTime _notifyTime(DateTime due, int daysBefore) {
    final d = dateOnly(due).subtract(Duration(days: daysBefore));
    return DateTime(d.year, d.month, d.day, 9, 0);
  }

  Future<void> _scheduleInstallment(Installment i) async {
    final id = _instBase + i.id!;
    await Notif.cancel(id);
    if (i.finished) return;
    final when = i.remindDays == 0
        ? 'امروز'
        : '${toFa(i.remindDays)} روز دیگر';
    await Notif.scheduleOnce(
      id,
      'سررسید قسط',
      '${i.title} — ${fmtMoney(i.amount)} — $when سررسید می‌شود',
      _notifyTime(i.nextDue, i.remindDays),
    );
  }

  Future<void> _reloadInstallments() async {
    installments = await _db.installments();
    notifyListeners();
  }

  Future<void> saveInstallment(Installment i) async {
    int id;
    if (i.id == null) {
      id = await _db.insertInstallment(i);
    } else {
      await _db.updateInstallment(i);
      id = i.id!;
    }
    await _reloadInstallments();
    for (final x in installments) {
      if (x.id == id) await _scheduleInstallment(x);
    }
  }

  Future<void> deleteInstallment(int id) async {
    await _db.deleteInstallment(id);
    await Notif.cancel(_instBase + id);
    await _reloadInstallments();
  }

  /// ثبت پرداخت یک قسط: هزینه ثبت می‌شود و سررسید به ماه بعد می‌رود
  Future<void> payInstallment(Installment i) async {
    final cat = _categoryByName('اقساط');
    final number = i.paidCount + 1;
    await _db.insertTx(
      TransactionItem(
        isIncome: false,
        amount: i.amount,
        categoryId: cat?.id,
        note: '${i.title} (قسط ${toFa(number)} از ${toFa(i.totalCount)})',
        date: dateOnly(DateTime.now()),
      ),
    );
    final done = number >= i.totalCount;
    await _db.updateInstallment(
      i.copyWith(
        paidCount: number,
        nextDue: done ? i.nextDue : addMonthsDt(i.nextDue, 1),
      ),
    );
    await _loadMonth();
    await _reloadInstallments();
    for (final x in installments) {
      if (x.id == i.id) await _scheduleInstallment(x);
    }
  }

  // ---------------------------------------------------------- reminders
  Future<void> _scheduleReminder(ReminderItem r) async {
    final id = _remBase + r.id!;
    await Notif.cancel(id);
    if (r.done) return;
    final when =
        r.remindDays == 0 ? 'امروز' : '${toFa(r.remindDays)} روز دیگر';
    final amount = r.amount > 0 ? ' — ${fmtMoney(r.amount)}' : '';
    await Notif.scheduleOnce(
      id,
      'یادآوری',
      '${r.title}$amount — $when موعد است',
      _notifyTime(r.due, r.remindDays),
    );
  }

  Future<void> _reloadReminders() async {
    reminders = await _db.reminders();
    notifyListeners();
  }

  Future<void> saveReminder(ReminderItem r) async {
    int id;
    if (r.id == null) {
      id = await _db.insertReminder(r);
    } else {
      await _db.updateReminder(r);
      id = r.id!;
    }
    await _reloadReminders();
    for (final x in reminders) {
      if (x.id == id) await _scheduleReminder(x);
    }
  }

  Future<void> deleteReminder(int id) async {
    await _db.deleteReminder(id);
    await Notif.cancel(_remBase + id);
    await _reloadReminders();
  }

  /// انجام‌شد؛ اگر ماهانه باشد موعد به ماه بعد می‌رود
  Future<void> completeReminder(ReminderItem r) async {
    final updated = r.monthly
        ? r.copyWith(due: addMonthsDt(r.due, 1))
        : r.copyWith(done: true);
    await _db.updateReminder(updated);
    await _reloadReminders();
    for (final x in reminders) {
      if (x.id == r.id) await _scheduleReminder(x);
    }
  }

  Future<void> reopenReminder(ReminderItem r) async {
    await _db.updateReminder(r.copyWith(done: false));
    await _reloadReminders();
    for (final x in reminders) {
      if (x.id == r.id) await _scheduleReminder(x);
    }
  }

  // -------------------------------------------------------------- goals
  Future<void> saveGoal(Goal g) async {
    if (g.id == null) {
      await _db.insertGoal(g);
    } else {
      await _db.updateGoal(g);
    }
    goals = await _db.goals();
    notifyListeners();
  }

  Future<void> deleteGoal(int id) async {
    await _db.deleteGoal(id);
    goals = await _db.goals();
    notifyListeners();
  }

  /// افزودن ([delta] مثبت) یا برداشت ([delta] منفی) از پس‌انداز یک هدف
  Future<void> addToGoal(Goal g, int delta) async {
    final s = g.saved + delta;
    await _db.updateGoal(g.copyWith(saved: s < 0 ? 0 : s));
    goals = await _db.goals();
    notifyListeners();
  }

  // ---------------------------------------------------------- recurring
  DateTime _nextMonthly(DateTime d, int day) {
    final j = Jalali.fromDateTime(d);
    final t = addJalaliMonths(Jalali(j.year, j.month, 1), 1);
    final len = t.monthLength;
    return Jalali(t.year, t.month, day > len ? len : day).toDateTime();
  }

  /// تراکنش‌های تکراریِ سررسیده را ثبت می‌کند. اگر چیزی ثبت شود true برمی‌گرداند.
  Future<bool> _generateRecurring() async {
    final today = dateOnly(DateTime.now());
    var changed = false;
    for (final r in recurrings) {
      if (!r.active) continue;
      var next = dateOnly(r.nextDate);
      var n = 0;
      while (!next.isAfter(today) && n < 120) {
        await _db.insertTx(
          TransactionItem(
            isIncome: r.isIncome,
            amount: r.amount,
            categoryId: r.categoryId,
            note: r.note,
            date: next,
            necessity: r.necessity,
          ),
        );
        next = _nextMonthly(next, r.day);
        n++;
      }
      if (n > 0) {
        await _db.updateRecurring(r.copyWith(nextDate: next));
        changed = true;
      }
    }
    if (changed) recurrings = await _db.recurrings();
    return changed;
  }

  /// بررسی دوباره (مثلاً وقتی برنامه از پس‌زمینه برمی‌گردد)
  Future<void> runRecurring() async {
    if (await _generateRecurring()) {
      await _loadMonth();
      notifyListeners();
    }
  }

  Future<void> saveRecurring(RecurringItem r) async {
    if (r.id == null) {
      await _db.insertRecurring(r);
    } else {
      await _db.updateRecurring(r);
    }
    recurrings = await _db.recurrings();
    await _generateRecurring();
    await _loadMonth();
    notifyListeners();
  }

  Future<void> deleteRecurring(int id) async {
    await _db.deleteRecurring(id);
    recurrings = await _db.recurrings();
    notifyListeners();
  }

  /// توقف/ادامه. هنگام ادامه، ماه‌های سپری‌شده‌ی دوران توقف ثبت نمی‌شوند.
  Future<void> toggleRecurring(RecurringItem r) async {
    var next = dateOnly(r.nextDate);
    if (!r.active) {
      final today = dateOnly(DateTime.now());
      while (next.isBefore(today)) {
        next = _nextMonthly(next, r.day);
      }
    }
    await _db.updateRecurring(r.copyWith(active: !r.active, nextDate: next));
    recurrings = await _db.recurrings();
    await _generateRecurring();
    await _loadMonth();
    notifyListeners();
  }

  // ------------------------------------------------------------ settings
  // ------------------------------------------------------------ app lock
  String _hashPin(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  bool verifyPin(String pin) =>
      _pinHash != null && _hashPin(pin, _pinSalt) == _pinHash;

  /// رمز را ذخیره می‌کند؛ اگر ذخیره‌سازی ممکن نشد false برمی‌گرداند (و قفلی فعال نمی‌شود)
  Future<bool> setPin(String pin) async {
    final salt = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final hash = _hashPin(pin, salt);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pin_salt', salt);
      await prefs.setString('pin_hash', hash);
    } catch (_) {
      return false;
    }
    _pinSalt = salt;
    _pinHash = hash;
    notifyListeners();
    return true;
  }

  Future<void> clearPin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pin_hash');
      await prefs.remove('pin_salt');
    } catch (_) {}
    _pinHash = null;
    _pinSalt = '';
    locked = false;
    notifyListeners();
  }

  void unlock() {
    locked = false;
    notifyListeners();
  }

  void onBackground() => _backgroundAt = DateTime.now();

  /// وقتی برنامه از پس‌زمینه برمی‌گردد: قفل (در صورت طولانی بودن غیبت) و ثبت تراکنش‌های تکراری
  Future<void> onResume() async {
    final at = _backgroundAt;
    _backgroundAt = null;
    if (lockEnabled && at != null && DateTime.now().difference(at) > kLockDelay) {
      locked = true;
      notifyListeners();
    }
    await runRecurring();
  }

  /// بعد از بازیابی پشتیبان: همه‌چیز دوباره از دیتابیس خوانده و یادآورها از نو تنظیم می‌شوند
  Future<void> reloadAll() async {
    categories = await _db.categories();
    installments = await _db.installments();
    reminders = await _db.reminders();
    goals = await _db.goals();
    recurrings = await _db.recurrings();
    await _generateRecurring();
    await _loadMonth();
    notifyListeners();
    await Notif.cancelAll();
    await _rescheduleAll();
  }

  /// جابه‌جایی بین نمایش کارتی (لیستی) و شبکه‌ای
  Future<void> setGridView(bool v) async {
    gridView = v;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('grid_view', v);
    } catch (_) {}
  }

  Future<void> setDaily(bool on, {int? hour, int? minute}) async {
    dailyOn = on;
    if (hour != null) dailyHour = hour;
    if (minute != null) dailyMinute = minute;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('daily_on', dailyOn);
      await prefs.setInt('daily_h', dailyHour);
      await prefs.setInt('daily_m', dailyMinute);
    } catch (_) {}
    notifyListeners();
    await _scheduleDaily();
  }

  Future<void> _scheduleDaily() async {
    await Notif.cancel(_dailyId);
    if (!dailyOn) return;
    await Notif.scheduleDaily(
      _dailyId,
      'ثبت هزینه‌های امروز',
      'هزینه‌ها و درآمدهای امروز را در برنامه ثبت کنید.',
      dailyHour,
      dailyMinute,
    );
  }

  Future<void> _rescheduleAll() async {
    for (final i in installments) {
      await _scheduleInstallment(i);
    }
    for (final r in reminders) {
      await _scheduleReminder(r);
    }
    await _scheduleDaily();
  }
}
