// 학사일정 화면. 달력으로 보여주고(오늘은 초록 동그라미), 날짜를 누르면 그날 일정을 아래에 자세히 보여준다. 데이터는 data/academic_schedule.dart.
import 'package:flutter/material.dart';
import '../data/academic_schedule.dart';
import 'theme.dart';

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

/// 그날에 걸친 일정들. 하루짜리(마감일 등)를 앞에, 긴 기간은 뒤에 둔다.
List<(String, String?, String)> schedulesOn(DateTime day) {
  final DateTime d = _day(day);
  final List<(String, String?, String)> hits = academicSchedule
      .where(
        ((String, String?, String) e) => !d.isBefore(DateTime.parse(e.$1)) && !d.isAfter(DateTime.parse(e.$2 ?? e.$1)),
      )
      .toList();
  hits.sort((a, b) => (a.$2 == null ? 0 : 1) - (b.$2 == null ? 0 : 1)); // 안정 정렬이라 같은 종류끼리는 원래 순서
  return hits;
}

/// 달력 칸에 들어갈 짧은 이름. 학년도·학기·대학원 머리말을 떼어 낸다(전체 이름은 아래 상세에).
String shortTitle(String title) => title.replaceAll(RegExp(r'\(대학원\) |\d{4}학년도 |[12]학기 '), '');

// 달은 '연도×12 + (월-1)' 정수 하나로 다룬다. 앞뒤 달 이동이 +1/-1로 끝난다.
int _mi(DateTime d) => d.year * 12 + d.month - 1;
final int _firstMonth = _mi(DateTime(scheduleYear));
final int _lastMonth = academicSchedule
    .map(((String, String?, String) e) => _mi(DateTime.parse(e.$2 ?? e.$1)))
    .reduce((int a, int b) => a > b ? a : b);

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key, this.today});

  /// 검사용으로 오늘 날짜를 바꿔 넣을 수 있다. 비우면 실제 오늘.
  final DateTime? today;

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  late final DateTime _today = _day(widget.today ?? DateTime.now());
  late int _month = _mi(_today).clamp(_firstMonth, _lastMonth);
  late DateTime _selected = _defaultDay(_month);

  // 달을 넘기면 그 달에 오늘이 있으면 오늘, 없으면 1일을 고른다.
  DateTime _defaultDay(int m) => _mi(_today) == m ? _today : DateTime(m ~/ 12, m % 12 + 1);

  void _go(int delta) {
    final int m = _month + delta;
    if (m < _firstMonth || m > _lastMonth) return;
    setState(() {
      _month = m;
      _selected = _defaultDay(m);
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<(String, String?, String)> items = schedulesOn(_selected);
    const String w = '월화수목금토일';
    return Scaffold(
      appBar: pageBar('$scheduleYear 학사일정'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Center(
          // 넓은 화면(웹)에서 달력이 끝까지 늘어나지 않게 폭을 제한한다.
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                AppCard(padding: const EdgeInsets.fromLTRB(6, 6, 6, 10), child: _calendar(context)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
                  child: Text(
                    '${_selected.month}월 ${_selected.day}일 ${w[_selected.weekday - 1]}요일',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 4, 4, 8),
                    child: Text('학사일정이 없는 날이에요', style: TextStyle(fontSize: 15, color: AppColors.textSub)),
                  ),
                for (final (String start, String? end, String title) in items)
                  _ScheduleTile(
                    date: scheduleDateText(start, end),
                    title: title,
                    badge: scheduleBadge(start, end, _today),
                  ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    '출처: 제주대학교 홈페이지 학사일정',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _arrow(IconData icon, String tip, int delta) {
    final int m = _month + delta;
    final bool ok = m >= _firstMonth && m <= _lastMonth;
    return Pressable(
      scale: 0.9,
      child: IconButton(icon: Icon(icon), tooltip: tip, onPressed: ok ? () => _go(delta) : null),
    );
  }

  Widget _calendar(BuildContext context) {
    final DateTime first = DateTime(_month ~/ 12, _month % 12 + 1);
    final int blanks = first.weekday % 7; // 일요일 시작
    final int days = DateTime(first.year, first.month + 1, 0).day;
    final List<Widget> weeks = <Widget>[];
    for (int i = 0; i < blanks + days; i += 7) {
      weeks.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (int j = i; j < i + 7; j++)
                Expanded(
                  child: j < blanks || j >= blanks + days
                      ? const SizedBox()
                      : _cell(DateTime(first.year, first.month, j - blanks + 1)),
                ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            _arrow(Icons.chevron_left, '이전 달', -1),
            Expanded(
              child: Text(
                '${first.year}년 ${first.month}월',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
            _arrow(Icons.chevron_right, '다음 달', 1),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: <Widget>[
            for (final String d in '일월화수목금토'.split(''))
              Expanded(
                child: Text(
                  d,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        // 옆으로 밀어도 달이 넘어간다.
        GestureDetector(
          onHorizontalDragEnd: (DragEndDetails d) {
            final double v = d.primaryVelocity ?? 0;
            if (v.abs() > 200) _go(v < 0 ? 1 : -1);
          },
          child: AnimatedSwitcher(
            duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 200),
            child: Column(key: ValueKey<int>(_month), children: weeks),
          ),
        ),
      ],
    );
  }

  Widget _cell(DateTime day) {
    final List<(String, String?, String)> items = schedulesOn(day);
    // 이름은 시작하는 날에만 쓴다(긴 기간이 매일 반복되면 달력이 빽빽해진다). 이어지는 날은 회색 줄로만.
    final String ymd = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final List<(String, String?, String)> starts = items.where(((String, String?, String) e) => e.$1 == ymd).toList();
    final bool running = starts.length < items.length;
    final bool isToday = day == _today;
    final bool isSelected = day == _selected;
    // 칸이 좁아 이름은 최대 2개. 넘치면 1개 + '+n'.
    final int shown = starts.length <= 2 ? starts.length : 1;
    return Pressable(
      scale: 0.92,
      child: Material(
        // 고른 날은 초록 테두리(칸 안 초록 이름표가 묻히지 않게 바탕은 그대로).
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: isSelected ? const BorderSide(color: AppColors.primary, width: 1.5) : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _selected = day),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 68),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(2, 4, 2, 4),
              child: Column(
                children: <Widget>[
                  // 오늘은 초록 동그라미.
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: isToday ? const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle) : null,
                    child: Text(
                      '${day.day}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isToday || isSelected ? FontWeight.w700 : FontWeight.w400,
                        color: isToday ? Colors.white : AppColors.text,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  for (final (String _, String? end, String title) in starts.take(shown)) _label(title, end == null),
                  if (starts.length > shown)
                    Text(
                      '+${starts.length - shown}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSub),
                    ),
                  if (running)
                    Container(
                      width: double.infinity,
                      height: 3,
                      margin: const EdgeInsets.only(top: 2),
                      decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 하루짜리 일정은 초록, 여러 날 이어지는 기간은 회색.
  Widget _label(String title, bool oneDay) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 2),
    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
    decoration: BoxDecoration(
      color: oneDay ? AppColors.primaryTint : AppColors.hairline,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      shortTitle(title),
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.clip,
      style: TextStyle(fontSize: 10, color: oneDay ? AppColors.onPrimaryTint : AppColors.textSub),
    ),
  );
}

class _ScheduleTile extends StatelessWidget {
  const _ScheduleTile({required this.date, required this.title, required this.badge});

  final String date;
  final String title;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final bool past = badge == null;
    final bool ongoing = badge == '진행 중';

    // 지난 일정은 흐리게(투명도) 하지 않고 카드만 빼서, 글자 대비는 지키면서 한 단계 물러나 보이게 한다.
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: past
          ? null
          : BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(18),
              boxShadow: appShadow,
              border: ongoing ? Border.all(color: AppColors.primary, width: 1.5) : null,
            ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSub,
                    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: past ? AppColors.textSub : AppColors.text,
                  ),
                ),
              ],
            ),
          ),
          // 진행 중·D-day는 진한 칩, 남은 날짜는 옅은 칩.
          if (badge != null)
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: ongoing || badge == 'D-day' ? Pill(badge!, bg: AppColors.primary, fg: Colors.white) : Pill(badge!),
            ),
        ],
      ),
    );
  }
}
