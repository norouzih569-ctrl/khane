import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:share_plus/share_plus.dart';

import '../data/db.dart';
import '../state/app_state.dart';

class BackupException implements Exception {
  final String message;
  const BackupException(this.message);

  @override
  String toString() => message;
}

/// یک فایل پشتیبانِ خوانده‌شده و اعتبارسنجی‌شده (هنوز اعمال نشده)
class BackupFile {
  final Map<String, dynamic> data;
  final int transactions;
  final int categories;
  const BackupFile(this.data, this.transactions, this.categories);
}

class BackupService {
  BackupService._();

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// از همه‌ی اطلاعات یک فایل JSON می‌سازد و پنجره‌ی اشتراک‌گذاری را باز می‌کند
  /// (ذخیره در فایل‌ها/درایو، فرستادن در تلگرام و ...)
  static Future<void> exportAndShare() async {
    final data = await AppDb.instance.exportAll();
    final dir = await getTemporaryDirectory();
    final j = Jalali.now();
    final name =
        'khane-budget-backup-${j.year}-${_two(j.month)}-${_two(j.day)}.json';
    final file = File(p.join(dir.path, name));
    await file.writeAsString(jsonEncode(data), flush: true);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: 'پشتیبان خرج خانه',
      text: 'نسخه پشتیبان برنامه خرج خانه',
    );
  }

  /// کاربر فایل را انتخاب می‌کند؛ فایل خوانده و بررسی می‌شود (اما هنوز چیزی تغییر نمی‌کند).
  /// null یعنی کاربر انصراف داد. فایل نامعتبر [BackupException] پرتاب می‌کند.
  static Future<BackupFile?> pickBackup() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    if (res == null || res.files.isEmpty) return null;
    final bytes = res.files.single.bytes;
    if (bytes == null) {
      throw const BackupException('خواندن فایل ممکن نشد');
    }

    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      throw const BackupException('این فایل، پشتیبان معتبر خرج خانه نیست');
    }
    if (decoded is! Map<String, dynamic> || decoded['app'] != 'khane_budget') {
      throw const BackupException('این فایل، پشتیبان معتبر خرج خانه نیست');
    }
    final v = decoded['version'];
    if (v is! int || v > kDbVersion) {
      throw const BackupException(
        'این پشتیبان با نسخه‌ی جدیدتری از برنامه ساخته شده؛ برنامه را به‌روز کنید',
      );
    }
    final Map<String, dynamic> map = decoded;
    int count(String key) {
      final v = map[key];
      return v is List ? v.length : 0;
    }

    return BackupFile(map, count('transactions'), count('categories'));
  }

  /// همه‌ی اطلاعات فعلی را با پشتیبان جایگزین می‌کند (همه‌یا‌هیچ) و برنامه را تازه می‌کند
  static Future<void> restore(AppState app, BackupFile file) async {
    try {
      await AppDb.instance.importAll(file.data);
    } on FormatException catch (e) {
      throw BackupException(e.message);
    } catch (_) {
      throw const BackupException(
        'فایل پشتیبان خراب است؛ چیزی تغییر نکرد',
      );
    }
    await app.reloadAll();
  }
}
