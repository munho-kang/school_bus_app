// 공지사항 화면. 맨 위 초록 머리 카드가 최근 3일 새 공지 개수를 말하고, 분류 버튼으로 거르고,
// 고정 공지는 접어 두고, '더 보기'로 다음 페이지를 붙인다. 각 줄은 왼쪽 날짜 칸 + 분류·새 글 딱지 + 제목.
// 제목을 누르면 학교 홈페이지 원문을 연다(앱은 앱 안에서, 웹은 새 탭).
import 'package:flutter/material.dart';
import '../services/notice_service.dart';
import 'theme.dart';
import 'surface_native.dart' if (dart.library.js_interop) 'surface_web.dart';

/// 오늘·어제·그제 올라온 글이면 새 글. 날짜를 못 읽으면 새 글이 아니다.
bool isNewNotice(String date, DateTime today) {
  final DateTime? d = DateTime.tryParse(date);
  if (d == null) return false;
  final int days = DateTime(today.year, today.month, today.day).difference(d).inDays;
  return days >= 0 && days < 3;
}

class NoticePage extends StatefulWidget {
  const NoticePage({super.key, this.load = fetchNotices, this.today});

  /// 공지 불러오기. 검사할 때 가짜로 바꿔 넣는다.
  final Future<List<Notice>> Function(int page, String? category) load;

  /// 검사용으로 오늘 날짜를 바꿔 넣을 수 있다. 비우면 실제 오늘.
  final DateTime? today;

  @override
  State<NoticePage> createState() => _NoticePageState();
}

class _NoticePageState extends State<NoticePage> {
  String? _category;
  int _page = 1;
  List<Notice> _pinned = <Notice>[];
  final List<Notice> _items = <Notice>[];
  bool _loading = false;
  bool _failed = false;
  bool _hasMore = true;
  bool _pinnedOpen = false;
  int _request = 0; // 분류를 빨리 바꿀 때 늦게 도착한 이전 응답을 버리기 위한 번호
  late final DateTime _today = widget.today ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final int req = ++_request;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final List<Notice> got = await widget.load(_page, _category);
      if (!mounted || req != _request) return;
      final List<Notice> fresh = got.where((Notice n) => !n.pinned).toList();
      setState(() {
        // 고정 공지는 모든 페이지에 똑같이 붙어 나오므로 첫 페이지 것만 쓴다.
        if (_page == 1) _pinned = got.where((Notice n) => n.pinned).toList();
        _items.addAll(fresh);
        _hasMore = fresh.isNotEmpty;
        _loading = false;
      });
    } catch (e) {
      debugPrint('notice load error: $e');
      if (!mounted || req != _request) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  void _selectCategory(String? code) {
    if (code == _category) return;
    _category = code;
    _page = 1;
    _pinned = <Notice>[];
    _items.clear();
    _load();
  }

  void _more() {
    _page++;
    _load();
  }

  // 목록 맨 아래: 불러오는 중 / 실패(같은 페이지 다시 시도) / 더 보기.
  Widget _footer() {
    if (_loading) {
      return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
    }
    if (_failed) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: <Widget>[
            const Text('공지를 불러오지 못했어요. 인터넷 연결을 확인해 주세요.', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Pressable(child: OutlinedButton(onPressed: _load, child: const Text('다시 시도'))),
          ],
        ),
      );
    }
    if (_items.isEmpty && _pinned.isEmpty) {
      return const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('공지가 없어요.')));
    }
    if (!_hasMore) return const SizedBox(height: 24);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(child: Pressable(child: OutlinedButton(onPressed: _more, child: const Text('더 보기')))),
    );
  }

  // 머리 카드: 최근 3일 새 공지 개수와 가장 최근 글 제목. 새 글이 없으면 회색.
  Widget _hero() {
    final List<Notice> fresh = _items.where((Notice n) => isNewNotice(n.date, _today)).toList();
    return HeroCard(
      tone: fresh.isEmpty ? HeroTone.off : HeroTone.live,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.campaign_rounded, size: 18, color: Colors.white70),
              SizedBox(width: 6),
              Text('최근 3일 새 공지', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            fresh.isEmpty ? '없어요' : '${fresh.length}개',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          if (fresh.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              fresh.length == 1 ? fresh.first.title : '${fresh.first.title} 외 ${fresh.length - 1}건',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }

  // 고정 공지 묶음: 연한 초록 머리줄을 누르면 부드럽게 펼쳐지고 접힌다.
  Widget _pinnedCard() {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          Pressable(
            scale: 0.97,
            child: Material(
              color: AppColors.primaryTint,
              child: InkWell(
                onTap: () => setState(() => _pinnedOpen = !_pinnedOpen),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.push_pin_rounded, size: 20, color: AppColors.onPrimaryTint),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '고정 공지 ${_pinned.length}개',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.onPrimaryTint),
                        ),
                      ),
                      AnimatedRotation(
                        turns: _pinnedOpen ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(Icons.expand_more, color: AppColors.onPrimaryTint),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _pinnedOpen
                ? Column(
                    children: <Widget>[
                      for (final (int i, Notice n) in _pinned.indexed) ...<Widget>[
                        if (i > 0) const Divider(indent: 16, endIndent: 16),
                        _NoticeTile(n, isNew: isNewNotice(n.date, _today)),
                      ],
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: pageBar('공지사항'),
      body: Center(
        // 넓은 화면(웹)에서 목록이 끝까지 늘어나지 않게 폭을 제한한다.
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: <Widget>[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Row(
                  children: <Widget>[
                    for (final MapEntry<String, String?> c in noticeCategories.entries)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Pressable(
                          child: ChoiceChip(
                            label: Text(c.key),
                            selected: c.value == _category,
                            onSelected: (_) => _selectCategory(c.value),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  children: <Widget>[
                    if (_items.isNotEmpty) ...<Widget>[_hero(), const SizedBox(height: 16)],
                    if (_pinned.isNotEmpty) ...<Widget>[_pinnedCard(), const SizedBox(height: 12)],
                    if (_items.isNotEmpty)
                      AppCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: <Widget>[
                            for (final (int i, Notice n) in _items.indexed) ...<Widget>[
                              if (i > 0) const Divider(indent: 16, endIndent: 16),
                              _NoticeTile(n, isNew: isNewNotice(n.date, _today)),
                            ],
                          ],
                        ),
                      ),
                    _footer(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoticeTile extends StatelessWidget {
  const _NoticeTile(this.n, {required this.isNew});

  final Notice n;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.98,
      child: InkWell(
        onTap: () => openPortal(context, n.url, title: '공지사항'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _DateBox(n.date, isNew: isNew),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (n.category.isNotEmpty || isNew)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Wrap(
                          spacing: 6,
                          children: <Widget>[
                            if (n.category.isNotEmpty) _Tag(n.category, bg: AppColors.primaryTint, fg: AppColors.onPrimaryTint),
                            if (isNew) const _Tag('새 글', bg: AppColors.primary, fg: Colors.white),
                          ],
                        ),
                      ),
                    Text(
                      n.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.35),
                    ),
                    if (n.writer.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(n.writer, style: const TextStyle(fontSize: 13, color: AppColors.textSub)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 왼쪽 날짜 칸: 큰 일(日) + 작은 월. 새 글은 연한 초록, 나머지는 옅은 회색. 날짜를 못 읽으면 글자 그대로.
class _DateBox extends StatelessWidget {
  const _DateBox(this.date, {required this.isNew});

  final String date;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final DateTime? d = DateTime.tryParse(date);
    final Color fg = isNew ? AppColors.onPrimaryTint : AppColors.text;
    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isNew ? AppColors.primaryTint : AppColors.hairline,
        borderRadius: BorderRadius.circular(14),
      ),
      child: d == null
          ? Text(date, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: fg))
          : Column(
              children: <Widget>[
                Text(
                  '${d.day}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    color: fg,
                    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                  ),
                ),
                Text('${d.month}월', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
              ],
            ),
    );
  }
}

/// 공지 줄의 작은 딱지(분류 · 새 글). Pill보다 한 단계 작다.
class _Tag extends StatelessWidget {
  const _Tag(this.label, {required this.bg, required this.fg});

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}
