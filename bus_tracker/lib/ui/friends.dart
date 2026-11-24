// 친구 시간표. 내 시간표를 QR·코드로 건네고(≡ 서랍 맨 아래), 친구 것을 찍거나 붙여넣어 이름과 함께 이 기기에 저장한다.
// 서버가 없어 받은 순간의 복사본이다 — 친구가 시간표를 고치면 같은 이름으로 다시 추가해 덮어쓴다.
// QR은 앱 안에서 찍는다: 휴대폰 기본 카메라로 찍으면 아이폰에선 홈 화면 앱이 아닌 사파리에 저장돼 버린다.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';
import 'timetable.dart';

const String _key = 'friends'; // 저장 형식: JSON {친구 이름: 공유 코드}
const String _prefix = 'JNUTT1:';
final RegExp _daysOk = RegExp(r'^[1-5]{1,5}$');

/// 공유 코드: 'JNUTT1:' + base64url(JSON [[과목, '13'(월·수), 시작 분, 끝 분], …]).
/// 저장 형식보다 짧게 줄여 QR이 덜 촘촘하다(찍기 쉽다). 글자만이라 메신저로 보내도 깨지지 않는다.
String shareCode(List<Lesson> ls) =>
    _prefix +
    base64Url.encode(
      utf8.encode(jsonEncode(<Object>[for (final Lesson l in ls) <Object>[l.title, l.days.join(), l.start, l.end]])),
    );

/// 코드를 수업 목록으로 되돌린다. 남이 준 글자라 모양을 하나하나 확인하고, 조금이라도 이상하면 null.
List<Lesson>? parseShareCode(String code) {
  final String s = code.trim();
  if (!s.startsWith(_prefix)) return null;
  try {
    final Object? rows = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(s.substring(_prefix.length)))));
    if (rows is! List<dynamic> || rows.isEmpty) return null;
    final List<Lesson> out = <Lesson>[];
    for (final dynamic r in rows) {
      if (r case [final String title, final String days, final int start, final int end]
          when title.trim().isNotEmpty && _daysOk.hasMatch(days) && start >= 0 && start < end && end <= 24 * 60) {
        out.add(Lesson(title: title, days: days.split('').map(int.parse).toSet().toList(), start: start, end: end));
      } else {
        return null;
      }
    }
    return out;
  } on FormatException {
    return null; // base64·JSON이 깨진 코드
  }
}

/// ≡ 서랍 맨 아래의 '내 시간표 QR'. 서랍을 열 때마다 새로 만들어져 방금 고친 시간표가 담긴다.
class MyQrCard extends StatefulWidget {
  const MyQrCard({super.key});

  @override
  State<MyQrCard> createState() => _MyQrCardState();
}

class _MyQrCardState extends State<MyQrCard> {
  String? _code; // 수업이 하나도 없으면 null

  @override
  void initState() {
    super.initState();
    loadLessons().then((List<Lesson> ls) {
      if (ls.isNotEmpty && mounted) setState(() => _code = shareCode(ls));
    });
  }

  @override
  Widget build(BuildContext context) {
    final String? code = _code;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text('내 시간표 QR', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            code == null
                ? '시간표에 수업을 넣으면 친구에게 보여 줄 QR이 여기에 생겨요.'
                : '친구가 홈 화면의 \'친구 추가\'에서 이 QR을 찍으면 내 시간표를 볼 수 있어요.',
            style: const TextStyle(fontSize: 14, color: AppColors.textSub, height: 1.45),
          ),
          if (code != null) ...<Widget>[
            const SizedBox(height: 8),
            AspectRatio(
              aspectRatio: 1,
              child: QrImageView(
                data: code,
                semanticsLabel: '내 시간표 QR 코드',
                // 수업이 아주 많아 QR 한 장에 안 들어갈 때.
                errorStateBuilder: (_, _) => const Center(
                  child: Text(
                    '수업이 많아 QR로 만들 수 없어요.\n아래 \'코드 복사\'로 보내 주세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: AppColors.textSub, height: 1.45),
                  ),
                ),
              ),
            ),
            Pressable(
              child: TextButton.icon(
                onPressed: () async {
                  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
                  await Clipboard.setData(ClipboardData(text: code));
                  messenger.showSnackBar(const SnackBar(content: Text('코드를 복사했어요. 메신저로 친구에게 보내 주세요.')));
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('코드 복사'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 홈 화면 시간표 아래의 친구 이름 줄. 이름을 누르면 그 친구의 시간표, '친구 추가'로 새 친구를 넣는다.
class FriendsRow extends StatefulWidget {
  const FriendsRow({super.key});

  @override
  State<FriendsRow> createState() => _FriendsRowState();
}

class _FriendsRowState extends State<FriendsRow> {
  Map<String, String> _friends = <String, String>{};

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((SharedPreferences p) {
      final String? s = p.getString(_key);
      if (s != null && mounted) {
        setState(() => _friends = Map<String, String>.from(jsonDecode(s) as Map<String, dynamic>));
      }
    });
  }

  Future<void> _save() async => (await SharedPreferences.getInstance()).setString(_key, jsonEncode(_friends));

  Future<void> _add() async {
    final (String, String)? added = await showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.card,
      builder: (_) => _AddFriendSheet(names: _friends.keys.toSet()),
    );
    if (added == null || !mounted) return;
    setState(() => _friends[added.$1] = added.$2);
    await _save();
  }

  Future<void> _open(String name) async {
    final bool? deleted = await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => _FriendPage(name: name, lessons: parseShareCode(_friends[name]!) ?? const <Lesson>[]),
      ),
    );
    if (deleted != true || !mounted) return;
    setState(() => _friends.remove(name));
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final String name in _friends.keys)
          Pressable(
            child: ActionChip(label: Text(name), onPressed: () => _open(name)),
          ),
        Pressable(
          child: ActionChip(
            avatar: const Icon(Icons.person_add_alt_1, size: 18, color: AppColors.primary),
            label: const Text('친구 추가'),
            onPressed: _add,
          ),
        ),
      ],
    );
  }
}

/// 친구 시간표 화면(보기 전용). 지우면 true를 돌려준다.
class _FriendPage extends StatelessWidget {
  const _FriendPage({required this.name, required this.lessons});

  final String name;
  final List<Lesson> lessons;

  Future<void> _delete(BuildContext context) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        title: Text('$name의 시간표를 지울까요?'),
        content: const Text('다시 보려면 친구의 QR을 다시 찍어야 해요.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('지우기'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: pageBar(
        '$name의 시간표',
        actions: <Widget>[
          IconButton(icon: const Icon(Icons.delete_outline), tooltip: '친구 지우기', onPressed: () => _delete(context)),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: AppCard(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
              child: TimetableGrid(lessons: lessons, now: DateTime.now()),
            ),
          ),
        ),
      ),
    );
  }
}

/// 친구 추가 시트. QR을 찍거나 코드를 붙여넣고 이름을 적어 저장하면 (이름, 코드)를 돌려준다.
class _AddFriendSheet extends StatefulWidget {
  const _AddFriendSheet({required this.names});

  final Set<String> names; // 이미 있는 친구 이름 — 같은 이름이면 덮어쓴다고 알려 준다.

  @override
  State<_AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends State<_AddFriendSheet> {
  final TextEditingController _code = TextEditingController();
  final TextEditingController _name = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final String? code = await Navigator.of(context).push(MaterialPageRoute<String>(builder: (_) => const _ScanPage()));
    if (code != null && mounted) setState(() => _code.text = code);
  }

  @override
  Widget build(BuildContext context) {
    final List<Lesson>? lessons = parseShareCode(_code.text);
    final String name = _name.text.trim();
    final String? problem = _code.text.trim().isEmpty
        ? '친구의 QR을 찍거나, 친구가 보낸 코드를 붙여넣어 주세요.'
        : lessons == null
        ? '코드가 올바르지 않아요. 다시 찍거나 다시 복사해 주세요.'
        : name.isEmpty
        ? '친구 이름을 적어 주세요.'
        : null;
    final String? note = problem ?? (widget.names.contains(name) ? '같은 이름의 친구가 있어요. 저장하면 새 시간표로 바뀌어요.' : null);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text('친구 추가', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Pressable(
            child: OutlinedButton.icon(
              onPressed: _scan,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('친구 QR 찍기'),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _code,
            decoration: InputDecoration(
              labelText: '또는 코드 붙여넣기',
              helperText: lessons == null ? null : '수업 ${lessons.length}개를 읽었어요.',
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            maxLength: 10,
            decoration: const InputDecoration(labelText: '친구 이름', border: OutlineInputBorder(), counterText: ''),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          if (note != null)
            Text(note, style: const TextStyle(fontSize: 13, color: AppColors.textSub), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Pressable(
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              onPressed: problem != null ? null : () => Navigator.pop(context, (name, _code.text.trim())),
              child: const Text('저장'),
            ),
          ),
        ],
      ),
    );
  }
}

/// 카메라로 친구의 QR을 찍는 화면. 시간표 코드가 담긴 QR을 처음 읽으면 그 코드를 돌려주며 닫힌다(다른 QR은 무시).
class _ScanPage extends StatefulWidget {
  const _ScanPage();

  @override
  State<_ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<_ScanPage> {
  bool _done = false; // 카메라가 같은 QR을 연달아 알려 줘도 한 번만 닫는다.

  void _onDetect(BarcodeCapture capture) {
    for (final Barcode b in capture.barcodes) {
      final String? v = b.rawValue;
      if (!_done && v != null && parseShareCode(v) != null) {
        _done = true;
        Navigator.pop(context, v);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: pageBar('친구 QR 찍기'),
      body: Column(
        children: <Widget>[
          Expanded(
            child: MobileScanner(
              onDetect: _onDetect,
              errorBuilder: (_, _) => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    '카메라를 쓸 수 없어요.\n카메라 사용을 허용하거나, 뒤로 가서 코드를 붙여넣어 주세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: AppColors.textSub, height: 1.5),
                  ),
                ),
              ),
            ),
          ),
          const SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '친구 휴대폰에서 ≡ 목록 맨 아래의 QR을 비춰 주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: AppColors.textSub),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
