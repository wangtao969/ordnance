import 'package:flutter/services.dart';

/// App 自建通知（gunsmap/notify，零第三方包）：行程提醒用。
/// 原生侧用 AlarmManager + BroadcastReceiver，到点由系统拉起通知，
/// 不依赖 App 存活。Android 13+ 需 POST_NOTIFICATIONS 运行时权限，
/// 未授权时原生返回 false，调用方给可读提示，不闪退。
/// 除 POST_NOTIFICATIONS 外不申请多余权限；精确闹钟不可用时
/// 原生回退到非精确闹钟，不声明 SCHEDULE_EXACT_ALARM。
const _notifyChannel = MethodChannel('gunsmap/notify');

/// 通知权限是否已授予（Android 13 以下直接视为已授予）。
Future<bool> ensureNotifyPermission() async {
  try {
    return await _notifyChannel.invokeMethod<bool>('ensurePermission') ??
        false;
  } catch (_) {
    return false;
  }
}

/// 在 timeMs 时刻发一条通知；id 由调用方给稳定值（取消用同一 id）。
Future<bool> scheduleTripNotification({
  required int id,
  required String title,
  required String body,
  required int timeMs,
}) async {
  try {
    return await _notifyChannel.invokeMethod<bool>('schedule', {
          'id': id,
          'title': title,
          'body': body,
          'timeMs': timeMs,
        }) ??
        false;
  } catch (_) {
    return false;
  }
}

/// 取消一条已设通知（也清掉通知栏里已弹出的同一条）。
Future<bool> cancelTripNotification(int id) async {
  try {
    return await _notifyChannel.invokeMethod<bool>('cancel', {'id': id}) ??
        false;
  } catch (_) {
    return false;
  }
}
