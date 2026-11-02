import 'package:flutter/services.dart';

/// 系统动作原生通道（gunsmap/system，零第三方包）：
/// openUrl 用系统浏览器打开链接；installApk 用系统安装器安装已下载的 APK。
const _systemChannel = MethodChannel('gunsmap/system');

Future<bool> openSystemUrl(String url) async {
  try {
    return await _systemChannel.invokeMethod<bool>('openUrl', {'url': url}) ??
        false;
  } catch (_) {
    return false;
  }
}

/// 原生 cacheDir：下载目录以此为准，保证落在 FileProvider 的 cache-path 内。
Future<String?> getCacheDirPath() async {
  try {
    return await _systemChannel.invokeMethod<String>('getCacheDir');
  } catch (_) {
    return null;
  }
}

Future<bool> installDownloadedApk(String path) async {
  try {
    return await _systemChannel.invokeMethod<bool>('installApk', {'path': path}) ??
        false;
  } catch (_) {
    return false;
  }
}

/// 系统日历插入 intent（ACTION_INSERT + CalendarContract.Events）：
/// 跳到用户自己的日历 App 里由用户确认；无日历 App 接 intent 时
/// 返回 false，调用方显示可读提示。App 不追踪日历事件 ID。
Future<bool> addCalendarEvent({
  required String title,
  required int beginMs,
  required int endMs,
  required String description,
}) async {
  try {
    return await _systemChannel.invokeMethod<bool>('addCalendarEvent', {
          'title': title,
          'beginMs': beginMs,
          'endMs': endMs,
          'description': description,
        }) ??
        false;
  } catch (_) {
    return false;
  }
}

/// 系统闹钟 intent（ACTION_SET_ALARM）：跳到系统时钟 App 预填时间与文案，
/// 由用户确认；无时钟 App 接 intent 时返回 false，调用方显示可读提示。
Future<bool> setAlarmClock({
  required int hour,
  required int minute,
  required String message,
}) async {
  try {
    return await _systemChannel.invokeMethod<bool>('setAlarm', {
          'hour': hour,
          'minute': minute,
          'message': message,
        }) ??
        false;
  } catch (_) {
    return false;
  }
}

/// 打开应用设置页（ACTION_APPLICATION_DETAILS_SETTINGS）：定位被
/// 永久拒绝后由此入口让用户手动开权限；无设置应用接手时返回 false。
Future<bool> openAppSettings() async {
  try {
    return await _systemChannel.invokeMethod<bool>('openAppSettings') ??
        false;
  } catch (_) {
    return false;
  }
}

/// 视频附件系统播放（ACTION_VIEW + FileProvider）：文件不存在或无播放
/// 应用时返回 false，调用方显示可读提示，不闪退。
Future<bool> openVideoFile(String path) async {
  try {
    return await _systemChannel.invokeMethod<bool>('openVideo', {'path': path}) ??
        false;
  } catch (_) {
    return false;
  }
}
