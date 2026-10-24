#!/usr/bin/env python3
"""
بعد از `flutter create` اجرا می‌شود و تنظیمات اندروید موردنیاز برنامه را اضافه می‌کند:
  * مجوزها و receiverهای اعلان (یادآوری‌ها)
  * فعال‌سازی core library desugaring (لازم برای flutter_local_notifications)
  * نام فارسی برنامه و آیکون

چند بار اجرا شدنش مشکلی ایجاد نمی‌کند (idempotent).
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "android/app/src/main/AndroidManifest.xml"
GRADLE_KTS = ROOT / "android/app/build.gradle.kts"
GRADLE_GROOVY = ROOT / "android/app/build.gradle"
DESUGAR = "com.android.tools:desugar_jdk_libs:2.1.4"
APP_LABEL = "خرج خانه"


def patch_manifest() -> None:
    s = MANIFEST.read_text(encoding="utf-8")

    perms = [
        "android.permission.POST_NOTIFICATIONS",
        "android.permission.RECEIVE_BOOT_COMPLETED",
        "android.permission.VIBRATE",
    ]
    add = "".join(
        f'<uses-permission android:name="{p}"/>\n    ' for p in perms if p not in s
    )
    if add:
        s = s.replace("<application", add + "<application", 1)

    if "ScheduledNotificationReceiver" not in s:
        receivers = """
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
    """
        s = s.replace("</application>", receivers + "</application>", 1)

    s = re.sub(r'android:label="[^"]*"', f'android:label="{APP_LABEL}"', s, count=1)
    MANIFEST.write_text(s, encoding="utf-8")
    print("manifest patched")


def patch_gradle() -> None:
    if GRADLE_KTS.exists():
        s = GRADLE_KTS.read_text(encoding="utf-8")
        if "isCoreLibraryDesugaringEnabled" not in s:
            s, n = re.subn(
                r"(compileOptions\s*\{)",
                r"\1\n        isCoreLibraryDesugaringEnabled = true",
                s,
                count=1,
            )
            if n == 0:
                sys.exit("compileOptions block not found in build.gradle.kts")
        if "desugar_jdk_libs" not in s:
            s += f'\n\ndependencies {{\n    coreLibraryDesugaring("{DESUGAR}")\n}}\n'
        GRADLE_KTS.write_text(s, encoding="utf-8")
    elif GRADLE_GROOVY.exists():
        s = GRADLE_GROOVY.read_text(encoding="utf-8")
        if "coreLibraryDesugaringEnabled" not in s:
            s, n = re.subn(
                r"(compileOptions\s*\{)",
                r"\1\n        coreLibraryDesugaringEnabled true",
                s,
                count=1,
            )
            if n == 0:
                sys.exit("compileOptions block not found in build.gradle")
        if "desugar_jdk_libs" not in s:
            s += f"\n\ndependencies {{\n    coreLibraryDesugaring '{DESUGAR}'\n}}\n"
        GRADLE_GROOVY.write_text(s, encoding="utf-8")
    else:
        sys.exit("android/app/build.gradle(.kts) not found")
    print("gradle patched")


def patch_icon() -> None:
    try:
        from PIL import Image
    except ImportError:
        print("Pillow not installed; default launcher icon kept")
        return
    src = ROOT / "assets/icon/icon.png"
    if not src.exists():
        return
    sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    img = Image.open(src).convert("RGBA")
    for folder, px in sizes.items():
        d = ROOT / "android/app/src/main/res" / folder
        if d.exists():
            img.resize((px, px), Image.LANCZOS).save(d / "ic_launcher.png")
    print("icon patched")


if __name__ == "__main__":
    patch_manifest()
    patch_gradle()
    patch_icon()
