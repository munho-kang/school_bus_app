// 앱 첫 화면. 위는 내 시간표(메인), 그 아래 작은 그라데이션 히어로 카드(A·B 코스 정문 다음 출발, 누르면 실시간 지도), 맨 아래는 포털·학사일정·공지사항·학식 바로가기 카드.
// 포털은 학교 포털을(웹에선 새 탭으로), 나머지는 각 화면을 띄운다.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/academic_schedule.dart';
import '../models/bus.dart';
import '../services/bus_service.dart';
import 'theme.dart';
import 'map_view.dart';
import 'menu_page.dart';
import 'notice_page.dart';
import 'schedule_page.dart';
import 'timetable.dart';
import 'surface_native.dart' if (dart.library.js_interop) 'surface_web.dart';

/// 다음 정문 출발까지 남은 분. 오늘 막차가 지났으면 null.
/// 버스가 정문에서 늦게 떠나는 중이면 음수.
int? minutesLeft(String busId, DateTime now, [Bus? bus]) {
  final String? t = nextDeparture(busId, now, bus);
  return t == null ? null : minutesUntil(t, now);
}

/// 코스 줄 오른쪽 문구. 한 시간이 넘게 남은 그날 첫차는 '첫차'. (5분 안이면 앞에 '곧 출발' 칩이 붙는다.)
String waitText(String busId, DateTime now, [Bus? bus]) {
  final int? mins = minutesLeft(busId, now, bus);
  if (mins == null) return '운행 종료';
  if (mins < 0) return '${-mins}분 지연';
  if (mins < 60) return '$mins분 후';
  if (nextDeparture(busId, now) == departures[busId]!.first) return '첫차';
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
    // 카드 시계와 '몇 분 후'를 갱신한다. 분이 바뀔 때만 다시 그린다.
    // 출발 시각 전후 몇 분 동안만 실제 위치를 받아, 버스가 정문을 떠났는지 확인한다.
    _tick = Timer.periodic(const Duration(seconds: 5), (_) {
      final DateTime n = DateTime.now();
      if (departingNow(n)) context.read<BusService>().fetchNow();
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
    const String week = '월화수목금토일';
    return Scaffold(
      body: SafeArea(
        // 휴대폰에선 카드를 맨 위에, 넓은 화면(웹)에선 가운데에.
        child: Align(
          alignment: MediaQuery.sizeOf(context).width < 600 ? Alignment.topCenter : Alignment.center,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            // 컴퓨터(웹)처럼 넓은 화면에서 카드가 끝까지 늘어나지 않게 폭을 제한한다.
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${_now.month}월 ${_now.day}일 ${week[_now.weekday - 1]}요일',
                          style: const TextStyle(fontSize: 15, color: AppColors.textSub),
                        ),
                        const SizedBox(height: 4),
                        const Text('제주대 캠퍼스', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TimetableCard(now: _now),
                  const SizedBox(height: 16),
                  _DepartureHero(now: _now, onTap: _openMap),
                  const SizedBox(height: 16),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: <Widget>[
                        _MenuRow(
                          icon: Icons.school_outlined,
                          title: '포털 접속하기',
                          subtitle: 'jnuclass.jejunu.ac.kr',
                          external: true,
                          onTap: () => openPortal(context, 'https://jnuclass.jejunu.ac.kr/'),
                        ),
                        const Divider(indent: 72, endIndent: 16),
                        _MenuRow(
                          icon: Icons.event_note_outlined,
                          title: '학사일정',
                          subtitle: nextScheduleText(_now) ?? '$scheduleYear학년도 학사일정',
                          onTap: () => _push(const SchedulePage()),
                        ),
                        const Divider(indent: 72, endIndent: 16),
                        _MenuRow(
                          icon: Icons.campaign_outlined,
                          title: '공지사항',
                          subtitle: '학사 · 장학 · 행사 공지',
                          onTap: () => _push(const NoticePage()),
                        ),
                        const Divider(indent: 72, endIndent: 16),
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

/// 정문 출발 카드: 머리줄(정문 출발 · 현재 시각), 코스별 다음 출발, 맨 아래 지도 열기.
/// 색이 상태를 말한다 — 둘 다 운행 종료면 회색, 그 밖엔 초록.
class _DepartureHero extends StatelessWidget {
  const _DepartureHero({required this.now, required this.onTap});

  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String clock = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final BusService svc = context.watch<BusService>();
    final List<String> waits = <String>[waitText('A', now, svc.busA), waitText('B', now, svc.busB)];
    final HeroTone tone = waits.every((String w) => w == '운행 종료') ? HeroTone.off : HeroTone.live;
    const TextStyle head = TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white70);
    return HeroCard(
      tone: tone,
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.directions_bus_rounded, size: 18, color: Colors.white70),
              const SizedBox(width: 6),
              const Text('정문 출발', style: head),
              const Spacer(),
              Text(clock, style: head.copyWith(fontFeatures: const <FontFeature>[FontFeature.tabularFigures()])),
            ],
          ),
          const SizedBox(height: 10),
          _CourseRow(id: 'A', now: now, bus: svc.busA, wait: waits[0]),
          const SizedBox(height: 6),
          _CourseRow(id: 'B', now: now, bus: svc.busB, wait: waits[1]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(14)),
            child: const Row(
              children: <Widget>[
                Text('실시간 버스 보기', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                Spacer(),
                Icon(Icons.map_outlined, size: 20),
                SizedBox(width: 2),
                Icon(Icons.chevron_right),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseRow extends StatelessWidget {
  const _CourseRow({required this.id, required this.now, required this.bus, required this.wait});

  final String id;
  final DateTime now;
  final Bus? bus;
  final String wait;

  @override
  Widget build(BuildContext context) {
    final String? t = nextDeparture(id, now, bus);
    final int? mins = minutesLeft(id, now, bus);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: <Widget>[
          CourseBadge(id, size: 26),
          const SizedBox(width: 12),
          Text(
            t ?? '--:--',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: t == null ? Colors.white60 : Colors.white,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 12),
          // 좁은 휴대폰에서는 오른쪽 문구만 줄여 한 줄을 지킨다.
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              // 5분 안이면 앞에 흰 바탕 빨간 글씨 '곧 출발' 칩.
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (mins != null && mins <= 5) ...<Widget>[
                    const Pill('곧 출발', bg: Colors.white, fg: AppColors.danger),
                    const SizedBox(width: 8),
                  ],
                  Text(wait, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ],
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
    return Pressable(
      scale: 0.97,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: AppColors.primaryTint, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, color: AppColors.textSub),
                    ),
                  ],
                ),
              ),
              Icon(external ? Icons.open_in_new : Icons.chevron_right, color: AppColors.textMuted, size: external ? 18 : 24),
            ],
          ),
        ),
      ),
    );
  }
}
