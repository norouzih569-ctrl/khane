import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/backup.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import 'lock.dart';
import 'widgets.dart';

Future<void> openSettings(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
  );
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _pickTime(BuildContext context, AppState app) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: app.dailyHour, minute: app.dailyMinute),
    );
    if (t != null) {
      await app.setDaily(true, hour: t.hour, minute: t.minute);
    }
  }

  Future<void> _backup(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await BackupService.exportAndShare();
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('ساخت فایل پشتیبان انجام نشد')),
      );
    }
  }

  Future<void> _restore(BuildContext context, AppState app) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await BackupService.pickBackup();
      if (file == null) return;
      if (!context.mounted) return;
      final ok = await confirmDialog(
        context,
        'این پشتیبان شامل ${toFa(file.transactions)} تراکنش و ${toFa(file.categories)} دسته است. '
        'با بازیابی، همه‌ی اطلاعات فعلی برنامه حذف و با این فایل جایگزین می‌شود. ادامه می‌دهید؟',
        confirmText: 'بازیابی',
      );
      if (!ok) return;
      await BackupService.restore(app, file);
      messenger.showSnackBar(
        const SnackBar(content: Text('اطلاعات با موفقیت بازیابی شد')),
      );
    } on BackupException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('بازیابی انجام نشد')),
      );
    }
  }

  void _openPin(BuildContext context, PinMode mode) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => PinSetupPage(mode: mode)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final hh = toFa(app.dailyHour.toString().padLeft(2, '0'));
    final mm = toFa(app.dailyMinute.toString().padLeft(2, '0'));

    return Scaffold(
      appBar: AppBar(title: const Text('تنظیمات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: 'یادآوری',
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('یادآوری روزانه ثبت هزینه'),
                  value: app.dailyOn,
                  onChanged: (v) => app.setDaily(v),
                ),
                if (app.dailyOn)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule),
                    title: const Text('ساعت یادآوری'),
                    trailing: Text(
                      '$hh:$mm',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onTap: () => _pickTime(context, app),
                  ),
              ],
            ),
          ),
          SectionCard(
            title: 'امنیت',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('قفل برنامه با رمز ۴ رقمی'),
                  subtitle: const Text(
                    'بعد از ۳۰ ثانیه خروج از برنامه، دوباره رمز می‌خواهد',
                  ),
                  value: app.lockEnabled,
                  onChanged: (v) =>
                      _openPin(context, v ? PinMode.enable : PinMode.disable),
                ),
                if (app.lockEnabled)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.password),
                    title: const Text('تغییر رمز'),
                    onTap: () => _openPin(context, PinMode.change),
                  ),
                const SizedBox(height: 4),
                Text(
                  'این قفل جلوی باز کردن معمولی برنامه را می‌گیرد؛ اطلاعات داخل گوشی رمزنگاری نمی‌شود.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ],
            ),
          ),
          SectionCard(
            title: 'پشتیبان‌گیری',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'اطلاعات فقط روی همین گوشی است؛ پس هر چند وقت یک‌بار پشتیبان بگیرید '
                  'و فایل را جایی امن (مثلاً درایو یا تلگرام) نگه دارید. '
                  'با این فایل می‌توانید اطلاعات را روی گوشی جدید برگردانید.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).hintColor,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _backup(context),
                        icon: const Icon(Icons.upload_file),
                        label: const Text('تهیه پشتیبان'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _restore(context, app),
                        icon: const Icon(Icons.download),
                        label: const Text('بازیابی'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'رمز قفل برنامه در فایل پشتیبان ذخیره نمی‌شود.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'همه اطلاعات فقط روی همین گوشی ذخیره می‌شود. با حذف برنامه، اطلاعات هم پاک می‌شود.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
