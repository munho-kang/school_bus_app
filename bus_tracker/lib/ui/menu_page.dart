// 학식 메뉴 화면. 식당 버튼으로 고르고, 이번 주 식단을 날짜별 카드로 보여 주며 오늘 카드를 강조해 그리로 스크롤한다.
// 운영시간·가격은 오른쪽 위 버튼으로 학교 홈페이지 원문에서 본다.
import 'package:flutter/material.dart';
import '../services/menu_service.dart';
import 'theme.dart';
import 'surface_native.dart' if (dart.library.js_interop) 'surface_web.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key, this.load = fetchMenu, this.today});

  /// 식단 불러오기. 검사할 때 가짜로 바꿔 넣는다.
  final Future<List<MenuDay>> Function(String place) load;

  /// 검사용으로 오늘 날짜를 바꿔 넣을 수 있다. 비우면 실제 오늘.
  final DateTime? today;

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  String _place = cafeterias.values.first;
  List<MenuDay>? _days; // null이면 불러오는 중
  bool _failed = false;
  int _request = 0; // 식당을 빨리 바꿀 때 늦게 도착한 이전 응답을 버리기 위한 번호
  final GlobalKey _todayKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final int req = ++_request;
    setState(() {
      _days = null;
      _failed = false;
    });
    try {
      final List<MenuDay> got = await widget.load(_place);
      if (!mounted || req != _request) return;
      setState(() => _days = got);
      // 그려진 직후 오늘 카드가 보이도록 스크롤한다.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final BuildContext? c = _todayKey.currentContext;
        if (c != null) Scrollable.ensureVisible(c);
      });
    } catch (e) {
      debugPrint('menu load error: $e');
      if (!mounted || req != _request) return;
      setState(() => _failed = true);
    }
  }

  void _select(String place) {
    if (place == _place) return;
    _place = place;
    _load();
  }

  Widget _body() {
    if (_failed) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: <Widget>[
            const Text('식단을 불러오지 못했어요. 인터넷 연결을 확인해 주세요.', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Pressable(child: OutlinedButton(onPressed: _load, child: const Text('다시 시도'))),
          ],
        ),
      );
    }
    final List<MenuDay>? days = _days;
    if (days == null) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
    if (days.isEmpty) return const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('식단이 아직 올라오지 않았어요.')));
    final DateTime today = widget.today ?? DateTime.now();
    return Column(
      children: <Widget>[
        for (final MenuDay d in days)
          if (isMenuToday(d.label, today)) _DayCard(d, today: true, key: _todayKey) else _DayCard(d, today: false),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: pageBar(
        '학식 메뉴',
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: '홈페이지에서 보기(운영시간·가격)',
            onPressed: () => openPortal(context, menuPageUrl(_place), title: '학식 메뉴'),
          ),
        ],
      ),
      body: Center(
        // 넓은 화면(웹)에서 카드가 끝까지 늘어나지 않게 폭을 제한한다.
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: <Widget>[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Row(
                  children: <Widget>[
                    for (final MapEntry<String, String> c in cafeterias.entries)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Pressable(
                          child: ChoiceChip(
                            label: Text(c.key),
                            selected: c.value == _place,
                            onSelected: (_) => _select(c.value),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // 카드가 5~7장뿐이라 한 번에 다 그린다(오늘 카드로 스크롤하려면 그려져 있어야 함).
              Expanded(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), child: _body())),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard(this.day, {required this.today, super.key});

  final MenuDay day;
  final bool today;

  @override
  Widget build(BuildContext context) {
    // 날짜가 있는 식단은 메뉴를 한 줄로 잇고, 고정 메뉴 안내문은 줄을 그대로 둔다.
    final String sep = RegExp(r'^\d').hasMatch(day.label) ? ' · ' : '\n';
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: AppCard(
        highlight: today,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(day.label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                if (today) ...<Widget>[
                  const SizedBox(width: 8),
                  const Pill('오늘', bg: AppColors.primary, fg: Colors.white),
                ],
              ],
            ),
            for (final (String name, List<String> items) in day.meals)
              if (items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (name.isNotEmpty)
                        Text(name, style: const TextStyle(color: AppColors.onPrimaryTint, fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(items.join(sep), style: const TextStyle(fontSize: 15, height: 1.45)),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
