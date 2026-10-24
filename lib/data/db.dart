import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../utils/format.dart';
import 'models.dart';

const int kDbVersion = 2;

/// جدول‌هایی که در پشتیبان ذخیره می‌شوند (ترتیب مهم نیست چون کلید خارجی نداریم)
const List<String> kBackupTables = [
  'categories',
  'transactions',
  'installments',
  'reminders',
  'month_budgets',
  'goals',
  'recurring',
];

class AppDb {
  AppDb._();
  static final AppDb instance = AppDb._();

  Database? _db;

  Future<Database> get db async => _db ??= await _open();

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), 'khane_budget.db');
    return openDatabase(
      path,
      version: kDbVersion,
      onCreate: _create,
      onUpgrade: _upgrade,
    );
  }

  Future<void> _createExtraTables(Database d) async {
    await d.execute('''
      CREATE TABLE month_budgets(
        category_id INTEGER NOT NULL,
        ym INTEGER NOT NULL,
        amount INTEGER NOT NULL,
        PRIMARY KEY (category_id, ym)
      )''');
    await d.execute('''
      CREATE TABLE goals(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        target INTEGER NOT NULL,
        saved INTEGER NOT NULL DEFAULT 0,
        due INTEGER
      )''');
    await d.execute('''
      CREATE TABLE recurring(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        is_income INTEGER NOT NULL,
        amount INTEGER NOT NULL,
        category_id INTEGER,
        note TEXT,
        day INTEGER NOT NULL,
        next_date INTEGER NOT NULL,
        necessity INTEGER NOT NULL DEFAULT 0,
        active INTEGER NOT NULL DEFAULT 1
      )''');
  }

  Future<void> _upgrade(Database d, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await d.execute(
        'ALTER TABLE transactions ADD COLUMN necessity INTEGER NOT NULL DEFAULT 0',
      );
      await _createExtraTables(d);
    }
  }

  Future<void> _create(Database d, int version) async {
    await d.execute('''
      CREATE TABLE categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon INTEGER NOT NULL,
        color INTEGER NOT NULL,
        is_income INTEGER NOT NULL,
        budget INTEGER NOT NULL DEFAULT 0
      )''');
    await d.execute('''
      CREATE TABLE transactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        is_income INTEGER NOT NULL,
        amount INTEGER NOT NULL,
        category_id INTEGER,
        note TEXT,
        date INTEGER NOT NULL,
        necessity INTEGER NOT NULL DEFAULT 0
      )''');
    await d.execute('CREATE INDEX idx_tx_date ON transactions(date)');
    await d.execute('''
      CREATE TABLE installments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        amount INTEGER NOT NULL,
        total_count INTEGER NOT NULL,
        paid_count INTEGER NOT NULL DEFAULT 0,
        next_due INTEGER NOT NULL,
        remind_days INTEGER NOT NULL DEFAULT 2
      )''');
    await d.execute('''
      CREATE TABLE reminders(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        amount INTEGER NOT NULL DEFAULT 0,
        due INTEGER NOT NULL,
        monthly INTEGER NOT NULL DEFAULT 0,
        done INTEGER NOT NULL DEFAULT 0,
        remind_days INTEGER NOT NULL DEFAULT 1
      )''');
    await _createExtraTables(d);

    // دسته‌های پیش‌فرض (قابل ویرایش و حذف) — رنگ‌ها عمداً متفاوت‌اند تا نمودار دایره‌ای خوانا باشد
    const expenses = [
      ['گوشت و مرغ', 0, 0xFFE53935],
      ['برنج و حبوبات', 1, 0xFFFB8C00],
      ['نان و لبنیات', 2, 0xFF6D4C41],
      ['میوه و سبزی', 3, 0xFF43A047],
      ['پزشکی و دارو', 4, 0xFFD81B60],
      ['اقساط', 5, 0xFF3949AB],
      ['قبوض', 6, 0xFFFDD835],
      ['اجاره / مسکن', 7, 0xFF00897B],
      ['حمل‌ونقل', 8, 0xFF039BE5],
      ['مسافرت', 9, 0xFF00ACC1],
      ['تفریح', 10, 0xFF8E24AA],
      ['پوشاک', 11, 0xFFFF7043],
      ['آموزش', 12, 0xFF7CB342],
      ['سایر', 13, 0xFF546E7A],
    ];
    for (final e in expenses) {
      await d.insert(
        'categories',
        Category(
          name: e[0] as String,
          icon: e[1] as int,
          color: e[2] as int,
          isIncome: false,
        ).toMap(),
      );
    }
    const incomes = [
      ['حقوق', 14, 0xFF43A047],
      ['سایر درآمدها', 15, 0xFF00897B],
    ];
    for (final e in incomes) {
      await d.insert(
        'categories',
        Category(
          name: e[0] as String,
          icon: e[1] as int,
          color: e[2] as int,
          isIncome: true,
        ).toMap(),
      );
    }
  }

  // ---------- دسته‌ها ----------
  Future<List<Category>> categories() async {
    final d = await db;
    final rows = await d.query('categories', orderBy: 'id');
    return rows.map(Category.fromMap).toList();
  }

  Future<int> insertCategory(Category c) async =>
      (await db).insert('categories', c.toMap());

  Future<void> updateCategory(Category c) async => (await db)
      .update('categories', c.toMap(), where: 'id = ?', whereArgs: [c.id]);

  Future<void> deleteCategory(int id) async {
    final d = await db;
    await d.transaction((txn) async {
      await txn.update(
        'transactions',
        {'category_id': null},
        where: 'category_id = ?',
        whereArgs: [id],
      );
      await txn.update(
        'recurring',
        {'category_id': null},
        where: 'category_id = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'month_budgets',
        where: 'category_id = ?',
        whereArgs: [id],
      );
      await txn.delete('categories', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ---------- سقف بودجه‌ی ویژه‌ی هر ماه ----------
  Future<Map<int, int>> monthBudgets(int ym) async {
    final rows = await (await db)
        .query('month_budgets', where: 'ym = ?', whereArgs: [ym]);
    return {
      for (final r in rows) r['category_id'] as int: r['amount'] as int,
    };
  }

  Future<int?> monthBudgetFor(int categoryId, int ym) async {
    final rows = await (await db).query(
      'month_budgets',
      where: 'category_id = ? AND ym = ?',
      whereArgs: [categoryId, ym],
    );
    if (rows.isEmpty) return null;
    return rows.first['amount'] as int;
  }

  Future<void> setMonthBudget(int categoryId, int ym, int amount) async =>
      (await db).insert(
        'month_budgets',
        {'category_id': categoryId, 'ym': ym, 'amount': amount},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<void> clearMonthBudget(int categoryId, int ym) async =>
      (await db).delete(
        'month_budgets',
        where: 'category_id = ? AND ym = ?',
        whereArgs: [categoryId, ym],
      );

  // ---------- تراکنش‌ها ----------
  Future<List<TransactionItem>> txsBetween(DateTime s, DateTime e) async {
    final d = await db;
    final rows = await d.query(
      'transactions',
      where: 'date >= ? AND date < ?',
      whereArgs: [s.millisecondsSinceEpoch, e.millisecondsSinceEpoch],
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(TransactionItem.fromMap).toList();
  }

  /// جستجو در همه‌ی ماه‌ها: توضیح، نام دسته یا مبلغ دقیق
  Future<List<TransactionItem>> searchTxs(String q) async {
    final text = q
        .trim()
        .replaceAll('ي', 'ی')
        .replaceAll('ك', 'ک')
        .replaceAll('%', '')
        .replaceAll('_', '');
    if (text.isEmpty) return [];
    final digits = toEn(text).replaceAll(RegExp(r'[,،\s]'), '');
    final isNum = RegExp(r'^\d+$').hasMatch(digits);
    final like = '%$text%';
    final d = await db;
    final rows = await d.rawQuery(
      'SELECT t.* FROM transactions t '
      'LEFT JOIN categories c ON c.id = t.category_id '
      'WHERE t.note LIKE ? OR c.name LIKE ?${isNum ? ' OR t.amount = ?' : ''} '
      'ORDER BY t.date DESC, t.id DESC LIMIT 300',
      [like, like, if (isNum) int.parse(digits.length > 13 ? '0' : digits)],
    );
    return rows.map(TransactionItem.fromMap).toList();
  }

  Future<int> insertTx(TransactionItem t) async =>
      (await db).insert('transactions', t.toMap());

  Future<void> updateTx(TransactionItem t) async => (await db)
      .update('transactions', t.toMap(), where: 'id = ?', whereArgs: [t.id]);

  Future<void> deleteTx(int id) async =>
      (await db).delete('transactions', where: 'id = ?', whereArgs: [id]);

  /// [درآمد، هزینه]
  Future<List<int>> totalsBetween(DateTime s, DateTime e) async {
    final d = await db;
    final rows = await d.rawQuery(
      'SELECT is_income AS t, COALESCE(SUM(amount), 0) AS s '
      'FROM transactions WHERE date >= ? AND date < ? GROUP BY is_income',
      [s.millisecondsSinceEpoch, e.millisecondsSinceEpoch],
    );
    var inc = 0;
    var exp = 0;
    for (final r in rows) {
      final v = (r['s'] as num).toInt();
      if ((r['t'] as int) == 1) {
        inc = v;
      } else {
        exp = v;
      }
    }
    return [inc, exp];
  }

  Future<int> spentInCategory(int categoryId, DateTime s, DateTime e) async {
    final d = await db;
    final rows = await d.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS s FROM transactions '
      'WHERE is_income = 0 AND category_id = ? AND date >= ? AND date < ?',
      [categoryId, s.millisecondsSinceEpoch, e.millisecondsSinceEpoch],
    );
    return (rows.first['s'] as num).toInt();
  }

  // ---------- اقساط ----------
  Future<List<Installment>> installments() async {
    final rows = await (await db).query('installments', orderBy: 'next_due');
    return rows.map(Installment.fromMap).toList();
  }

  Future<int> insertInstallment(Installment i) async =>
      (await db).insert('installments', i.toMap());

  Future<void> updateInstallment(Installment i) async => (await db)
      .update('installments', i.toMap(), where: 'id = ?', whereArgs: [i.id]);

  Future<void> deleteInstallment(int id) async =>
      (await db).delete('installments', where: 'id = ?', whereArgs: [id]);

  // ---------- یادآورها ----------
  Future<List<ReminderItem>> reminders() async {
    final rows = await (await db).query('reminders', orderBy: 'due');
    return rows.map(ReminderItem.fromMap).toList();
  }

  Future<int> insertReminder(ReminderItem r) async =>
      (await db).insert('reminders', r.toMap());

  Future<void> updateReminder(ReminderItem r) async => (await db)
      .update('reminders', r.toMap(), where: 'id = ?', whereArgs: [r.id]);

  Future<void> deleteReminder(int id) async =>
      (await db).delete('reminders', where: 'id = ?', whereArgs: [id]);

  // ---------- اهداف پس‌انداز ----------
  Future<List<Goal>> goals() async {
    final rows = await (await db).query('goals', orderBy: 'id');
    return rows.map(Goal.fromMap).toList();
  }

  Future<int> insertGoal(Goal g) async =>
      (await db).insert('goals', g.toMap());

  Future<void> updateGoal(Goal g) async =>
      (await db).update('goals', g.toMap(), where: 'id = ?', whereArgs: [g.id]);

  Future<void> deleteGoal(int id) async =>
      (await db).delete('goals', where: 'id = ?', whereArgs: [id]);

  // ---------- تراکنش‌های تکراری ----------
  Future<List<RecurringItem>> recurrings() async {
    final rows = await (await db).query('recurring', orderBy: 'id');
    return rows.map(RecurringItem.fromMap).toList();
  }

  Future<int> insertRecurring(RecurringItem r) async =>
      (await db).insert('recurring', r.toMap());

  Future<void> updateRecurring(RecurringItem r) async => (await db)
      .update('recurring', r.toMap(), where: 'id = ?', whereArgs: [r.id]);

  Future<void> deleteRecurring(int id) async =>
      (await db).delete('recurring', where: 'id = ?', whereArgs: [id]);

  // ---------- پشتیبان‌گیری ----------
  Future<Map<String, Object?>> exportAll() async {
    final d = await db;
    final data = <String, Object?>{
      'app': 'khane_budget',
      'version': kDbVersion,
      'exported_at': DateTime.now().toIso8601String(),
    };
    for (final t in kBackupTables) {
      data[t] = await d.query(t);
    }
    return data;
  }

  /// همه‌ی اطلاعات فعلی را با محتوای پشتیبان جایگزین می‌کند (همه‌یا‌هیچ).
  /// در صورت نامعتبر بودن فایل، Exception پرتاب می‌شود و چیزی تغییر نمی‌کند.
  Future<void> importAll(Map<String, dynamic> data) async {
    if (data['app'] != 'khane_budget') {
      throw const FormatException('این فایل پشتیبان این برنامه نیست');
    }
    final v = data['version'];
    if (v is! int || v > kDbVersion) {
      throw const FormatException('نسخه‌ی فایل پشتیبان پشتیبانی نمی‌شود');
    }
    final d = await db;
    await d.transaction((txn) async {
      for (final t in kBackupTables) {
        await txn.delete(t);
        final rows = (data[t] as List?) ?? const [];
        for (final r in rows) {
          await txn.insert(t, Map<String, Object?>.from(r as Map));
        }
      }
    });
  }
}
