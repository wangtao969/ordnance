import 'package:flutter/material.dart';
import '../widgets/app_toast.dart';
import 'package:flutter/services.dart';
import '../i18n.dart';
import '../widgets/app_top_bar.dart';

/// 意见反馈：应用内填写 + 联系邮箱。
/// 暂未接后端：反馈只保存在本机当次有效，提交后可以一键复制，
/// 复制出来的文本直接发到聊天里或用邮箱发出去；联系邮箱填你
/// 自己的邮箱，方便回复你。
class FeedbackItem {
final String type;
final String content;
final String email;
final String time;
FeedbackItem({
required this.type,
required this.content,
required this.email,
required this.time,
});

String get shareText {
final mail = email.isEmpty? '未留邮箱': email;
return '类型：$type\n内容：$content\n联系邮箱：$mail\n时间：$time';
}
}

class FeedbackScreen extends StatefulWidget {
const FeedbackScreen({super.key});

@override
State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
static const _types = ['功能建议', '内容纠错', '闪退报错', '其他'];
String _type = _types.first;
final _contentCtrl = TextEditingController();
final _emailCtrl = TextEditingController(text: 'Toryphoto77@gmail.com');
final _submitted = <FeedbackItem>[];

@override
void dispose() {
_contentCtrl.dispose();
_emailCtrl.dispose();
super.dispose();
}

String _now() {
final n = DateTime.now();
final hm = '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
if (localeNotifier.value == localeEn) return '${n.month}/${n.day} $hm';
return '${n.month}月${n.day}日 $hm';
}

/// 点邮箱行直接跳转手机邮箱应用：走 gunsmap/mailto 原生通道，
/// 拉 ACTION_SENDTO + mailto 意图；没装邮箱应用时复制邮箱地址。
static const _mailChannel = MethodChannel('gunsmap/mailto');

Future<void> _openMailApp() async {
bool opened = false;
try {
opened = await _mailChannel.invokeMethod<bool>('openMail', {
'email': 'Toryphoto77@gmail.com',
'subject': "Ordnance 反馈",
'body': _contentCtrl.text.trim(),
}) ??
false;
} catch (_) {
opened = false;
}
if (!mounted) return;
if (!opened) {
await Clipboard.setData(
const ClipboardData(text: 'Toryphoto77@gmail.com'));
showAppToast(context, tr('no_mail_app'));
}
}

void _submit() {
final content = _contentCtrl.text.trim();
if (content.isEmpty) {
showAppToast(context, tr('feedback_empty'));
return;
}
setState(() {
_submitted.insert(
0,
FeedbackItem(
type: _type,
content: content,
email: _emailCtrl.text.trim(),
time: _now(),
));
_contentCtrl.clear();
});
showAppToast(context, tr('feedback_saved'));
}


String _typeLabel(String t) {
switch (t) {
case '功能建议':
return tr('feedback_type_feature');
case '内容纠错':
return tr('feedback_type_content');
case '闪退报错':
return tr('feedback_type_crash');
default:
return tr('feedback_type_other');
}
}

@override
Widget build(BuildContext context) {
final dark = Theme.of(context).brightness == Brightness.dark;
final grey = dark? const Color(0xFF8A8578): const Color(0xFF9A917F);
return Scaffold(
appBar: SubPageAppBar(title: tr('feedback')),
body: ListView(
padding: const EdgeInsets.all(16),
children: [
Text(tr('feedback'),
style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
const SizedBox(height: 4),
Text(tr('feedback_note'),
style: TextStyle(color: grey, fontSize: 12)),
const SizedBox(height: 16),
Card(
child: ListTile(
leading: const Icon(Icons.mail_outlined),
title: Text(tr('feedback_mail')),
subtitle: Text(tr('feedback_mail_sub')),
trailing: const Icon(Icons.open_in_new, size: 18),
onTap: _openMailApp,
),
),
const SizedBox(height: 16),
Text(tr('feedback_type'),
style: TextStyle(fontWeight: FontWeight.bold)),
const SizedBox(height: 8),
Wrap(
spacing: 8,
children: _types
.map((t) => ChoiceChip(
label: Text(_typeLabel(t)),
selected: _type == t,
onSelected: (_) => setState(() => _type = t),
))
.toList(),
),
const SizedBox(height: 16),
TextField(
controller: _contentCtrl,
maxLines: 6,
decoration: InputDecoration(
labelText: tr('feedback_content_label'),
hintText: tr('feedback_content_hint'),
border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
),
),
const SizedBox(height: 12),
TextField(
controller: _emailCtrl,
keyboardType: TextInputType.emailAddress,
decoration: InputDecoration(
labelText: tr('feedback_email_label'),
hintText: tr('feedback_email_hint'),
border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
),
),
const SizedBox(height: 16),
ElevatedButton(
onPressed: _submit,
child: Text(tr('feedback_submit')),
),
if (_submitted.isNotEmpty)...[
const SizedBox(height: 24),
Text(tr('feedback_submitted'),
style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
const SizedBox(height: 8),
..._submitted.map((f) => Card(
margin: const EdgeInsets.only(bottom: 10),
child: Padding(
padding: const EdgeInsets.all(14),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
children: [
Chip(label: Text(_typeLabel(f.type))),
const SizedBox(width: 8),
Text(f.time,
style: TextStyle(color: grey, fontSize: 12)),
const Spacer(),
TextButton.icon(
onPressed: () async {
await Clipboard.setData(
ClipboardData(text: f.shareText));
if (!context.mounted) return;
showAppToast(context, tr('feedback_copied'));
},
icon: const Icon(Icons.copy, size: 16),
label: Text(tr('copy')),
),
],
),
const SizedBox(height: 4),
Text(f.content),
if (f.email.isNotEmpty)...[
const SizedBox(height: 4),
Text('${tr('feedback_email_prefix')}${f.email}',
style: TextStyle(color: grey, fontSize: 12)),
],
],
),
),
)),
],
],
),
);
}
}
