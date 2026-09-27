// 학사일정 화면. 월별로 묶어 보여주고, 열면 이번 달로 이동한다. 데이터는 data/academic_schedule.dart.
import 'package:flutter/material.dart';
import '../data/academic_schedule.dart';
import 'board.dart';

DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

/// 일정 옆에 붙일 표시. 진행 중이면 '진행 중', 앞으로 남았으면 'D-n', 지났으면 null.
String? scheduleBadge(String start, String? end, DateTime today) {
  final DateTime now = _day(today);
  final DateTime s = DateTime.parse(start);
  final DateTime e = DateTime.parse(end ?? start);
  if (now.isAfter(e)) return null;
  if (end != null && !now.isBefore(s)) return '진행 중';
  final int d = s.difference(now).inDays;
  return d == 0 ? 'D-day' : 'D-$d';
}

String _md(String ymd) {
  final DateTime d = DateTime.parse(ymd);
  const String w = '월화수목금토일';
  return '${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}(${w[d.weekday - 1]})';
}

/// '09.29(화)' 또는 '12.28(월) ~ 01.18(월)'.
String scheduleDateText(String start, String? end) => end == null ? _md(start) : '${_md(start)} ~ ${_md(end)}';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key, this.today});

  /// 검사용으로 오늘 날짜를 바꿔 넣을 수 있다. 비우면 실제 오늘.
  final DateTime? today;

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  final GlobalKey _firstLive = GlobalKey();

  @override
  void initState() {
    super.initState();
    // 화면이 그려진 직후 아직 안 끝난 첫 일정(진행 중이거나 다가오는 일정)이 맨 위에 오도록 스크롤한다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? c = _firstLive.currentContext;
      if (c != null) Scrollable.ensureVisible(c, alignment: 0.1); // 위에 달 제목이 보이도록 살짝 아래에
    });
  }

  @override
  Widget build(BuildContext context) {
    final DateTime today = widget.today ?? DateTime.now();
    final ColorScheme cs = Theme.of(context).colorScheme;

    final List<Widget> children = <Widget>[];
    bool keyed = today.year != scheduleYear;
    for (int m = 1; m <= 12; m++) {
      final Iterable<(String, String?, String)> items = academicSchedule.where(
        ((String, String?, String) e) => DateTime.parse(e.$1).month == m,
      );
      if (items.isEmpty) continue;
      final bool isNow = today.year == scheduleYear && today.month == m;
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
          child: Text(
            '$m월',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: isNow ? cs.primary : null),
          ),
        ),
      );
      for (final (String start, String? end, String title) in items) {
        final String? badge = scheduleBadge(start, end, today);
        final bool first = !keyed && badge != null;
        if (first) keyed = true;
        children.add(
          _ScheduleTile(key: first ? _firstLive : null, date: scheduleDateText(start, end), title: title, badge: badge),
        );
      }
    }
    children.add(
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          '출처: 제주대학교 홈페이지 학사일정',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: cs.outline),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('$scheduleYear 학사일정')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Center(
          // 넓은 화면(웹)에서 목록이 끝까지 늘어나지 않게 폭을 제한한다.
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ),
      ),
    );
  }
}

class _ScheduleTile extends StatelessWidget {
  const _ScheduleTile({super.key, required this.date, required this.title, required this.badge});

  final String date;
  final String title;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool past = badge == null;
    final bool ongoing = badge == '진행 중';

    // 지난 일정은 흐리게(투명도) 하지 않고 판·테두리만 빼서, 글자 대비는 지키면서 한 단계 물러나 보이게 한다.
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: past
          ? null
          : BoxDecoration(
              color: cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ongoing ? Board.amber : cs.outlineVariant, width: ongoing ? 1.5 : 1),
            ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurfaceVariant,
                    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: past ? cs.onSurfaceVariant : cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
          // 남은 날짜는 작은 안내판 조각에 LED 문구로.
          if (badge != null)
            Container(
              margin: const EdgeInsets.only(left: 10),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(color: Board.face, borderRadius: BorderRadius.circular(4)),
              child: Text(badge!, style: ledLabel()),
            ),
        ],
      ),
    );
  }
}
