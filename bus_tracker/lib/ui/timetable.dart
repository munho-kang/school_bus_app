// 내 수업 시간표. 홈 화면에 월~금 일주일 표로 보여주고, 빈 곳의 '추가'나 수업 칸을 눌러 넣고·고치고·지운다.
// 이 기기(휴대폰 앱 또는 웹 브라우저)에만 저장된다 — 다른 사람에겐 보이지 않는다.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';

const String _key = 'timetable';
const String _week = '월화수목금';

/// 수업 하나. days는 1=월 … 5=금, 시각은 자정부터 센 분(10:30 → 630).
class Lesson {
  const Lesson({required this.title, required this.room, required this.days, required this.start, required this.end});

  final String title;
  final String room;
  final List<int> days;
  final int start;
  final int end;

  Map<String, Object> toJson() => <String, Object>{'title': title, 'room': room, 'days': days, 'start': start, 'end': end};

  factory Lesson.fromJson(Map<String, dynamic> j) => Lesson(
        title: j['title'] as String,
        room: j['room'] as String,
        days: List<int>.from(j['days'] as List<dynamic>),
        start: j['start'] as int,
        end: j['end'] as int,
      );
}

String encodeLessons(List<Lesson> ls) => jsonEncode(ls.map((Lesson l) => l.toJson()).toList());
List<Lesson> decodeLessons(String s) =>
    (jsonDecode(s) as List<dynamic>).map((dynamic j) => Lesson.fromJson(j as Map<String, dynamic>)).toList();

String hhmm(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

/// 표에 그릴 시간 범위(정시 단위). 가장 이른 수업의 시작 시(時)부터 가장 늦은 수업이 끝나는 시까지.
(int, int) hourRange(List<Lesson> ls) {
  int first = 24, last = 0;
  for (final Lesson l in ls) {
    if (l.start ~/ 60 < first) first = l.start ~/ 60;
    if ((l.end + 59) ~/ 60 > last) last = (l.end + 59) ~/ 60;
  }
  return (first, last);
}

// 과목 색(바탕, 글씨). 목록에 처음 나온 순서대로 돌아가며 준다 — 여섯 과목까지는 서로 다른 색.
const List<(Color, Color)> _palette = <(Color, Color)>[
  (Color(0xFFE3F6EE), Color(0xFF0A7A55)),
  (Color(0xFFE5EFFF), Color(0xFF0B4FC4)),
  (Color(0xFFFFF1DB), Color(0xFF8A5100)),
  (Color(0xFFF3E8FF), Color(0xFF6B2FB3)),
  (Color(0xFFFDECEE), Color(0xFFB0212C)),
  (Color(0xFFE2F4F8), Color(0xFF0B6377)),
];
int colorIndex(List<Lesson> ls, String title) =>
    ls.map((Lesson l) => l.title).toSet().toList().indexOf(title) % _palette.length;

/// 홈 화면의 시간표 카드. 저장된 수업을 불러와 그리고, 고치면 바로 저장한다.
class TimetableCard extends StatefulWidget {
  const TimetableCard({super.key, required this.now});

  final DateTime now;

  @override
  State<TimetableCard> createState() => _TimetableCardState();
}

class _TimetableCardState extends State<TimetableCard> {
  List<Lesson> _lessons = <Lesson>[];

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((SharedPreferences p) {
      final String? s = p.getString(_key);
      if (s != null && mounted) setState(() => _lessons = decodeLessons(s));
    });
  }

  Future<void> _edit([Lesson? old]) async {
    final Lesson? result = await showModalBottomSheet<Lesson>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.card,
      builder: (_) => _LessonSheet(old: old),
    );
    if (result == null) return;
    setState(() {
      final int i = old == null ? -1 : _lessons.indexOf(old);
      if (identical(result, _deleted)) {
        _lessons.removeAt(i);
      } else if (i >= 0) {
        _lessons[i] = result;
      } else {
        _lessons.add(result);
      }
    });
    (await SharedPreferences.getInstance()).setString(_key, encodeLessons(_lessons));
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const SizedBox(width: 4),
              const Text('내 시간표', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const Spacer(),
              Pressable(
                child: TextButton.icon(onPressed: _edit, icon: const Icon(Icons.add, size: 20), label: const Text('추가')),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_lessons.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                '아직 수업이 없어요.\n오른쪽 위 \'추가\'를 눌러 수업을 넣어 보세요.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textSub, height: 1.5),
              ),
            )
          else
            _Grid(lessons: _lessons, today: widget.now.weekday, onTap: _edit),
        ],
      ),
    );
  }
}

// 시트에서 '삭제'를 눌렀다는 표시로만 쓰는 값.
const Lesson _deleted = Lesson(title: '', room: '', days: <int>[], start: 0, end: 0);

/// 월~금 칸에 수업을 시간 비율대로 놓는다. 오늘 요일 머리글은 초록.
class _Grid extends StatelessWidget {
  const _Grid({required this.lessons, required this.today, required this.onTap});

  final List<Lesson> lessons;
  final int today;
  final void Function(Lesson) onTap;

  static const double _hourH = 52;
  static const double _labelW = 22;
  static const double _headH = 24;

  @override
  Widget build(BuildContext context) {
    final (int first, int last) = hourRange(lessons);
    return LayoutBuilder(builder: (BuildContext context, BoxConstraints c) {
      final double colW = (c.maxWidth - _labelW) / 5;
      double y(int minute) => _headH + (minute - first * 60) / 60 * _hourH;
      return SizedBox(
        height: _headH + (last - first) * _hourH,
        child: Stack(
          children: <Widget>[
            for (int d = 1; d <= 5; d++)
              Positioned(
                left: _labelW + (d - 1) * colW,
                width: colW,
                top: 0,
                height: _headH,
                child: Center(
                  child: Text(
                    _week[d - 1],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: d == today ? AppColors.primary : AppColors.textSub,
                    ),
                  ),
                ),
              ),
            for (int h = first; h < last; h++) ...<Widget>[
              Positioned(left: _labelW, right: 0, top: y(h * 60), child: const Divider()),
              Positioned(
                left: 0,
                top: y(h * 60) + 3,
                child: Text('$h', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ),
            ],
            for (final Lesson l in lessons)
              for (final int d in l.days)
                Positioned(
                  left: _labelW + (d - 1) * colW + 1.5,
                  width: colW - 3,
                  top: y(l.start) + 1.5,
                  height: y(l.end) - y(l.start) - 3,
                  child: _Block(lesson: l, colors: _palette[colorIndex(lessons, l.title)], onTap: () => onTap(l)),
                ),
          ],
        ),
      );
    });
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.lesson, required this.colors, required this.onTap});

  final Lesson lesson;
  final (Color, Color) colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = colors;
    return Pressable(
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  lesson.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg, height: 1.25),
                ),
                if (lesson.room.isNotEmpty)
                  Text(
                    lesson.room,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10.5, color: fg.withValues(alpha: 0.8)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 수업 넣기·고치기 시트. 저장하면 새 Lesson을, 삭제하면 _deleted를 돌려준다.
class _LessonSheet extends StatefulWidget {
  const _LessonSheet({this.old});

  final Lesson? old;

  @override
  State<_LessonSheet> createState() => _LessonSheetState();
}

class _LessonSheetState extends State<_LessonSheet> {
  late final TextEditingController _title = TextEditingController(text: widget.old?.title);
  late final TextEditingController _room = TextEditingController(text: widget.old?.room);
  late final Set<int> _days = <int>{...?widget.old?.days};
  late int _start = widget.old?.start ?? 9 * 60;
  late int _end = widget.old?.end ?? 10 * 60 + 15;

  @override
  void dispose() {
    _title.dispose();
    _room.dispose();
    super.dispose();
  }

  String? get _problem {
    if (_title.text.trim().isEmpty) return '과목 이름을 적어 주세요.';
    if (_days.isEmpty) return '요일을 하나 이상 골라 주세요.';
    if (_end <= _start) return '끝나는 시각이 시작보다 늦어야 해요.';
    return null;
  }

  Future<void> _pick(bool isStart) async {
    final int m = isStart ? _start : _end;
    final TimeOfDay? t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60));
    if (t == null) return;
    setState(() => isStart ? _start = t.hour * 60 + t.minute : _end = t.hour * 60 + t.minute);
  }

  @override
  Widget build(BuildContext context) {
    final String? problem = _problem;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(widget.old == null ? '수업 추가' : '수업 고치기', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: '과목', border: OutlineInputBorder()),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _room,
            decoration: const InputDecoration(labelText: '강의실 (선택)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: <Widget>[
              for (int d = 1; d <= 5; d++)
                Pressable(
                  child: FilterChip(
                    label: Text(_week[d - 1]),
                    selected: _days.contains(d),
                    onSelected: (bool on) => setState(() => on ? _days.add(d) : _days.remove(d)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(child: Pressable(child: OutlinedButton(onPressed: () => _pick(true), child: Text(hhmm(_start))))),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('~')),
              Expanded(child: Pressable(child: OutlinedButton(onPressed: () => _pick(false), child: Text(hhmm(_end))))),
            ],
          ),
          const SizedBox(height: 12),
          if (problem != null)
            Text(problem, style: const TextStyle(fontSize: 13, color: AppColors.textSub), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              if (widget.old != null) ...<Widget>[
                Pressable(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, _deleted),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                    child: const Text('삭제'),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Pressable(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    onPressed: problem != null
                        ? null
                        : () => Navigator.pop(
                              context,
                              Lesson(
                                title: _title.text.trim(),
                                room: _room.text.trim(),
                                days: (_days.toList()..sort()),
                                start: _start,
                                end: _end,
                              ),
                            ),
                    child: const Text('저장'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
