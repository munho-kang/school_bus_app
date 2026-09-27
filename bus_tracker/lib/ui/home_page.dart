// 앱 첫 화면. 위는 정류장 LED 안내판(A·B 코스 정문 다음 출발, 누르면 실시간 지도), 아래는 포털·학사일정·공지사항·학식 메뉴 줄.
// 포털은 학교 포털을(웹에선 새 탭으로), 나머지는 각 화면을 띄운다.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/academic_schedule.dart';
import '../services/bus_service.dart';
import 'board.dart';
import 'map_view.dart';
import 'menu_page.dart';
import 'notice_page.dart';
import 'schedule_page.dart';
import 'surface_native.dart' if (dart.library.js_interop) 'surface_web.dart';

/// 안내판 오른쪽 문구. 2분 안이면 '곧 출발', 한 시간이 넘게 남은 그날 첫차는 '첫차'.
String waitText(String busId, DateTime now) {
  final String? t = nextDeparture(busId, now);
  if (t == null) return '운행 종료';
  final int mins = int.parse(t.substring(0, 2)) * 60 + int.parse(t.substring(3)) - (now.hour * 60 + now.minute);
  if (mins <= 2) return '곧 출발';
  if (mins < 60) return '$mins분 후';
  if (t == departures[busId]!.first) return '첫차';
  return mins % 60 == 0 ? '${mins ~/ 60}시간 후' : '${mins ~/ 60}시간 ${mins % 60}분 후';
}

/// 가장 가까운 남은 학사일정 한 줄('D-3 · 2학기 중간고사'). 올해 일정이 다 지났거나 해가 다르면 null.
String? nextScheduleText(DateTime today) {
  if (today.year != scheduleYear) return null;
  for (final (String start, String? end, String title) in academicSchedule) {
    final String? badge = scheduleBadge(start, end, today);
    if (badge != null) return '$badge · $title';
  }
  return null;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DateTime _now = DateTime.now();
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    // 안내판 시계와 '몇 분 후'를 갱신한다. 분이 바뀔 때만 다시 그린다.
    _tick = Timer.periodic(const Duration(seconds: 5), (_) {
      final DateTime n = DateTime.now();
      if (n.minute != _now.minute) setState(() => _now = n);
    });
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  // 폴링은 지도를 보는 동안에만 돈다. push가 끝나는 시점(뒤로가기)에 멈춘다.
  Future<void> _openMap() async {
    final BusService svc = context.read<BusService>()..start();
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MapView()));
    svc.stop();
  }

  void _push(Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        // 휴대폰에선 안내판을 맨 위에, 넓은 화면(웹)에선 가운데에.
        child: Align(
          alignment: MediaQuery.sizeOf(context).width < 600 ? Alignment.topCenter : Alignment.center,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            // 컴퓨터(웹)처럼 넓은 화면에서 안내판이 끝까지 늘어나지 않게 폭을 제한한다.
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _DepartureBoard(now: _now, onTap: _openMap),
                  const SizedBox(height: 28),
                  Material(
                    color: cs.surfaceContainerLowest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: cs.outlineVariant),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: <Widget>[
                        _MenuRow(
                          icon: Icons.school_outlined,
                          title: '포털 접속하기',
                          subtitle: 'jnuclass.jejunu.ac.kr',
                          external: true,
                          onTap: () => openPortal(context, 'https://jnuclass.jejunu.ac.kr/'),
                        ),
                        const Divider(indent: 64),
                        _MenuRow(
                          icon: Icons.event_note_outlined,
                          title: '학사일정',
                          subtitle: nextScheduleText(_now) ?? '$scheduleYear학년도 학사일정',
                          onTap: () => _push(const SchedulePage()),
                        ),
                        const Divider(indent: 64),
                        _MenuRow(
                          icon: Icons.campaign_outlined,
                          title: '공지사항',
                          subtitle: '학사 · 장학 · 행사 공지',
                          onTap: () => _push(const NoticePage()),
                        ),
                        const Divider(indent: 64),
                        _MenuRow(
                          icon: Icons.restaurant_outlined,
                          title: '학식 메뉴',
                          subtitle: '식당 5곳 · 이번 주 식단',
                          onTap: () => _push(const MenuPage()),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 정류장 안내판: 머리줄(정문 출발 · 현재 시각), 코스별 다음 출발, 맨 아래 지도 열기.
class _DepartureBoard extends StatelessWidget {
  const _DepartureBoard({required this.now, required this.onTap});

  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String clock = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return BoardFace(
      child: InkWell(
        onTap: onTap,
        splashColor: Board.amber.withAlpha(30),
        highlightColor: Board.amber.withAlpha(14),
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              child: Row(
                children: <Widget>[
                  Text('정문 출발', style: ledLabel(color: Board.amberDim)),
                  const Spacer(),
                  LedDigits(clock, dot: 2.4, color: Board.amberDim),
                ],
              ),
            ),
            const Divider(color: Board.seam, height: 1),
            _CourseRow(id: 'A', now: now),
            const Divider(color: Board.seam, height: 1, indent: 18, endIndent: 18),
            _CourseRow(id: 'B', now: now),
            const Divider(color: Board.seam, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
              child: Row(
                children: <Widget>[
                  Text('실시간 버스 보기', style: ledLabel()),
                  const Spacer(),
                  const Icon(Icons.map_outlined, color: Board.amber, size: 22),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right, color: Board.amber),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseRow extends StatelessWidget {
  const _CourseRow({required this.id, required this.now});

  final String id;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final String? t = nextDeparture(id, now);
    final String wait = waitText(id, now);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Row(
        children: <Widget>[
          CourseBadge(id, size: 34),
          const SizedBox(width: 16),
          LedDigits(t ?? '--:--', dot: 4.4, color: t == null ? Board.amberDim : Board.amber),
          const SizedBox(width: 12),
          // 좁은 휴대폰에서는 오른쪽 문구만 줄여 한 줄을 지킨다.
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                wait,
                style: ledLabel(size: 24, color: t == null ? Board.amberDim : (wait == '곧 출발' ? Board.red : Board.amber)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.title, required this.subtitle, required this.onTap, this.external = false});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool external;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: Board.face, borderRadius: BorderRadius.circular(6)),
              child: Icon(icon, color: Board.amber, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: cs.onSurface)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(external ? Icons.open_in_new : Icons.chevron_right, color: cs.onSurfaceVariant, size: external ? 18 : 24),
          ],
        ),
      ),
    );
  }
}
