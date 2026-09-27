// 공지사항 화면. 분류 버튼으로 거르고, 고정 공지는 접어 두고, '더 보기'로 다음 페이지를 붙인다.
// 제목을 누르면 학교 홈페이지 원문을 연다(앱은 앱 안에서, 웹은 새 탭).
import 'package:flutter/material.dart';
import '../services/notice_service.dart';
import 'surface_native.dart' if (dart.library.js_interop) 'surface_web.dart';

class NoticePage extends StatefulWidget {
  const NoticePage({super.key, this.load = fetchNotices});

  /// 공지 불러오기. 검사할 때 가짜로 바꿔 넣는다.
  final Future<List<Notice>> Function(int page, String? category) load;

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
  int _request = 0; // 분류를 빨리 바꿀 때 늦게 도착한 이전 응답을 버리기 위한 번호

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
            OutlinedButton(onPressed: _load, child: const Text('다시 시도')),
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
      child: Center(child: OutlinedButton(onPressed: _more, child: const Text('더 보기'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('공지사항')),
      body: Center(
        // 넓은 화면(웹)에서 목록이 끝까지 늘어나지 않게 폭을 제한한다.
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: <Widget>[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: <Widget>[
                    for (final MapEntry<String, String?> c in noticeCategories.entries)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(c.key),
                          selected: c.value == _category,
                          onSelected: (_) => _selectCategory(c.value),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  children: <Widget>[
                    if (_pinned.isNotEmpty)
                      ExpansionTile(
                        leading: const Icon(Icons.push_pin_outlined),
                        title: Text('고정 공지 ${_pinned.length}개'),
                        children: <Widget>[for (final Notice n in _pinned) _NoticeTile(n)],
                      ),
                    for (final Notice n in _items) ...<Widget>[_NoticeTile(n), const Divider(indent: 16, endIndent: 16)],
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
  const _NoticeTile(this.n);

  final Notice n;

  @override
  Widget build(BuildContext context) {
    final String date = n.date.length == 10 ? n.date.substring(5).replaceAll('-', '.') : n.date;
    return ListTile(
      title: Text(n.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        <String>[n.category, n.writer, date].where((String s) => s.isNotEmpty).join(' · '),
        style: const TextStyle(fontFeatures: <FontFeature>[FontFeature.tabularFigures()]),
      ),
      onTap: () => openPortal(context, n.url, title: '공지사항'),
    );
  }
}
