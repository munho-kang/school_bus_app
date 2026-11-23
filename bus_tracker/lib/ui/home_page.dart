// 앱 첫 화면. 맨 위 제목 줄에 '제주대 캠퍼스' · 작은 버스 버튼 · ≡ 메뉴가 나란히 있고, 그 아래가 내 시간표(메인).
// 버스 버튼은 지도에서 별표한 정류장(없으면 정문)의 다음 도착 시각만 보여 주고, 누르면 실시간 지도로 간다.
// 화면 끝에서 더 아래로 내려도(휠·손가락) 버튼을 누른 것처럼 실시간 지도 화면으로 넘어간다.
// 포털·학사일정·공지사항·학식 바로가기는 오른쪽 위 ≡ 버튼으로 펼치는 서랍 안에 있다.
// 포털은 학교 포털을(웹에선 새 탭으로), 나머지는 각 화면을 띄운다.
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
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
  final ScrollController _scroll = ScrollController();
  double _pull = 0; // 화면 끝에서 손가락을 더 올린 거리.
  bool _inMap = false; // 지도 화면을 두 번 겹쳐 열지 않게.

  @override
  void initState() {
    super.initState();
    loadStarred();
    // 버스 버튼의 도착 시각을 갱신한다. 분이 바뀔 때만 다시 그린다.
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
    _scroll.dispose();
    super.dispose();
  }

  // 손가락: 화면 끝에 닿은 뒤 손가락을 80 넘게 더 올리면 지도로. (아이폰은 끝에서 화면이 덜 늘어나서, 늘어난 양 대신 손가락 이동 거리를 잰다.)
  bool _onScroll(ScrollNotification n) {
    final DragUpdateDetails? drag = switch (n) {
      ScrollUpdateNotification(:final DragUpdateDetails? dragDetails) => dragDetails,
      OverscrollNotification(:final DragUpdateDetails? dragDetails) => dragDetails,
      _ => null,
    };
    if (n is ScrollStartNotification) _pull = 0;
    if (drag != null && n.metrics.extentAfter == 0) _pull -= drag.delta.dy;
    if (_pull > 80) _openMap();
    return false;
  }

  // 휠·트랙패드: 이미 맨 아래인데 또 내리면 지도로. (끝에선 화면이 안 움직여 스크롤 알림이 없어 휠을 직접 본다.)
  void _onWheel(PointerSignalEvent e) {
    if (e is PointerScrollEvent && e.scrollDelta.dy > 0 && _scroll.hasClients && _scroll.position.extentAfter == 0) {
      _openMap();
    }
  }

  // 폴링은 지도를 보는 동안에만 돈다. push가 끝나는 시점(뒤로가기)에 멈춘다.
  Future<void> _openMap() async {
    if (_inMap) return;
    _inMap = true;
    _pull = 0;
    final BusService svc = context.read<BusService>()..start();
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MapView()));
    svc.stop();
    _inMap = false;
  }

  void _push(Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  // 서랍을 닫고 나서 이동한다(돌아왔을 때 서랍이 열려 있지 않게).
  void _fromDrawer(VoidCallback go) {
    Navigator.of(context).pop();
    go();
  }

  @override
  Widget build(BuildContext context) {
    const String week = '월화수목금토일';
    return Scaffold(
      // 오른쪽 위 ≡ 버튼을 누르면 오른쪽에서 펼쳐지는 바로가기 서랍.
      endDrawer: Drawer(
        backgroundColor: AppColors.bg,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: <Widget>[
                    _MenuRow(
                      icon: Icons.school_outlined,
                      title: '포털 접속하기',
                      subtitle: 'jnuclass.jejunu.ac.kr',
                      external: true,
                      onTap: () => _fromDrawer(() => openPortal(context, 'https://jnuclass.jejunu.ac.kr/')),
                    ),
                    const Divider(indent: 72, endIndent: 16),
                    _MenuRow(
                      icon: Icons.event_note_outlined,
                      title: '학사일정',
                      subtitle: nextScheduleText(_now) ?? '$scheduleYear학년도 학사일정',
                      onTap: () => _fromDrawer(() => _push(const SchedulePage())),
                    ),
                    const Divider(indent: 72, endIndent: 16),
                    _MenuRow(
                      icon: Icons.campaign_outlined,
                      title: '공지사항',
                      subtitle: '학사 · 장학 · 행사 공지',
                      onTap: () => _fromDrawer(() => _push(const NoticePage())),
                    ),
                    const Divider(indent: 72, endIndent: 16),
                    _MenuRow(
                      icon: Icons.restaurant_outlined,
                      title: '학식 메뉴',
                      subtitle: '식당 5곳 · 이번 주 식단',
                      onTap: () => _fromDrawer(() => _push(const MenuPage())),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        // 빈 곳까지 화면 전체가 스크롤을 받는다(지도에서 ← 누른 뒤 커서가 구석에 있어도 내리면 지도로).
        child: Listener(
          onPointerSignal: _onWheel,
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints box) => SingleChildScrollView(
                controller: _scroll,
                // 내용이 화면보다 짧아도 끌어내릴 수 있게(그래야 지도로 넘어간다).
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: math.max(0, box.maxHeight - 40)), // 40 = 위아래 여백
                  // 휴대폰에선 카드를 맨 위에, 넓은 화면(웹)에선 가운데에.
                  child: Align(
                    alignment: box.maxWidth < 600 ? Alignment.topCenter : Alignment.center,
                    // 컴퓨터(웹)처럼 넓은 화면에서 카드가 끝까지 늘어나지 않게 폭을 제한한다.
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Row(
                              children: <Widget>[
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      '${_now.month}월 ${_now.day}일 ${week[_now.weekday - 1]}요일',
                                      style: const TextStyle(fontSize: 15, color: AppColors.textSub),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      '제주대 캠퍼스',
                                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 6),
                                // 제목과 ≡ 사이 남는 자리에 버스 버튼. 폭 375부터 제 크기, 360에선 0.9배로 통째로 줄어든다.
                                // ponytail: 폭 340 아래나 큰 글씨 설정에선 버튼이 많이 작아진다. 문제가 되면 버튼을 제목 아랫줄로 내린다.
                                Expanded(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: _BusButton(now: _now, onTap: _openMap),
                                  ),
                                ),
                                Builder(
                                  builder: (BuildContext ctx) => Pressable(
                                    scale: 0.9,
                                    child: IconButton(
                                      icon: const Icon(Icons.menu, size: 28),
                                      tooltip: '메뉴',
                                      onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          TimetableCard(now: _now),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 제목 옆 작은 버스 버튼. 지도에서 별표한 정류장(여럿이면 마지막에 별표한 곳, 없으면 정문)의
/// 코스별 다음 도착 시각만 보여 주고, 누르면 실시간 지도로 간다.
/// 색이 상태를 말한다 — 오늘 더 올 버스가 없으면(운행 종료·주말·공휴일) 회색, 그 밖엔 초록.
class _BusButton extends StatelessWidget {
  const _BusButton({required this.now, required this.onTap});

  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final BusService svc = context.watch<BusService>();
    // 받은 지 오래된 위치는 믿지 않고 시간표대로 보여준다.
    final bool fresh = svc.isFresh(DateTime.now());
    final Map<String, Bus?> buses = <String, Bus?>{'A': fresh ? svc.busA : null, 'B': fresh ? svc.busB : null};
    return ValueListenableBuilder<List<String>>(
      valueListenable: starredStops,
      builder: (BuildContext context, List<String> stops, _) {
        final String? stop = stops.lastOrNull;
        // 정문은 버스가 늦게 떠나는 것까지 반영한 출발 시각, 별표 정류장은 시간표로 센 도착 시각.
        final Map<String, String?> times = <String, String?>{
          for (final String id in buses.keys)
            id: stop == null ? nextDeparture(id, now, buses[id]) : nextArrival(id, stop, now),
        };
        final bool off = times.values.every((String? t) => t == null);
        return Tooltip(
          message: '실시간 버스 보기',
          child: HeroCard(
            tone: off ? HeroTone.off : HeroTone.live,
            onTap: onTap,
            padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
            radius: const BorderRadius.all(Radius.circular(14)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      stop == null ? Icons.directions_bus_rounded : Icons.star_rounded,
                      size: 14,
                      color: stop == null ? Colors.white : const Color(0xFFFFD54F),
                    ),
                    const SizedBox(width: 3),
                    Text(stop ?? '정문', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    const Icon(Icons.chevron_right, size: 14),
                  ],
                ),
                const SizedBox(height: 4),
                if (off)
                  Text(noServiceText(now), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (final MapEntry<String, String?> e in times.entries) ...<Widget>[
                        if (e.key != times.keys.first) const SizedBox(width: 6),
                        CourseBadge(e.key, size: 15),
                        const SizedBox(width: 3),
                        Text(
                          e.value ?? '--:--',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: e.value == null ? Colors.white60 : Colors.white,
                            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.external = false,
  });

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
              Icon(
                external ? Icons.open_in_new : Icons.chevron_right,
                color: AppColors.textMuted,
                size: external ? 18 : 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
