// 앱 전체의 모양(정류장 LED 안내판). 검은 안내판 면 + 호박색 LED 글자, 나머지는 금속 테두리 같은 회색 바탕.
// LedDigits: 시각·숫자를 둥근 LED 점으로 그린다. ledLabel: 안내판 위 한글 문구(갈무리 픽셀 글꼴).
//
// 디자인 계약
// THESIS: 첫 화면이 곧 정류장 도착정보 안내기(BIS). 흰 바탕 파란 버튼 목록·카드 격자를 거부한다.
// OWN-WORLD: 검은 아크릴 면(#0B0D0F)에 호박색 LED(#FFB000), 곧 출발만 빨강. 코스 번호판 A #0066FF·B #00CC66.
//   바탕은 안내판 금속 틀 같은 회색(밝게 #E8EBEE / 어둡게 #121518). 모서리 4~10, 그림자 대신 1px 이음선.
// STORY: 학생은 앱을 열자마자 A·B 다음 출발과 남은 시간을 읽고, 판을 눌러 지도로 가거나 아래 줄에서 포털·일정·공지·학식으로 간다.
// FIRST VIEWPORT: 위 안내판(머리줄 '정문 출발' + LED 시계, A·B 줄에 LED 시각 + 'n분 후', 끝줄 '실시간 버스 보기'), 그 아래 흰 판에 메뉴 네 줄.
// FORM: 정류장 LED 안내판, 내 후보 1순위(IMPECCABLE'S PICK), seed c7d7629f. 판은 Hero로 지도 상단 패널이 된다. 값이 바뀌면 LED가 왼쪽부터 켜진다.
// FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class Board {
  static const Color face = Color(0xFF0B0D0F); // 검은 아크릴 안내판 면
  static const Color seam = Color(0xFF23282D); // 안내판 안의 구분선
  static const Color amber = Color(0xFFFFB000); // 켜진 LED
  static const Color amberDim = Color(0xFFB88A2E); // 덜 중요한 LED 문구
  static const Color red = Color(0xFFFF5A4A); // 곧 출발
  static const Color courseA = Color(0xFF0066FF);
  static const Color courseB = Color(0xFF00CC66);
}

// ponytail: 갈무리 글꼴은 아래 글자만 담아 17KB로 줄였다. 안내판 문구에 새 한글을 쓰면 그 글자는 기본 글꼴로 나온다.
// 글자를 추가하려면 --text에 넣어 다시 만든다:
// pyftsubset Galmuri11-Bold.ttf --text="정문출발곧분후운행종료실시간버스보기학사일정공지항식메뉴제주대교포털코진중오늘첫차다음·→" --unicodes="U+0020-007E" --output-file=assets/fonts/Galmuri11-Bold.ttf
/// 안내판 위 문구. 픽셀 글꼴이라 12의 배수 크기에서 가장 또렷하다.
TextStyle ledLabel({double size = 12, Color color = Board.amber}) =>
    TextStyle(fontFamily: 'Galmuri', fontSize: size, height: 1.2, color: color, letterSpacing: 0);

ThemeData buildTheme(Brightness brightness) {
  final bool dark = brightness == Brightness.dark;
  final ColorScheme cs = ColorScheme.fromSeed(seedColor: Board.amber, brightness: brightness).copyWith(
    surface: dark ? const Color(0xFF121518) : const Color(0xFFE8EBEE),
    surfaceContainerLowest: dark ? const Color(0xFF181C20) : Colors.white,
    surfaceContainerLow: dark ? const Color(0xFF1C2024) : const Color(0xFFF4F5F7),
    surfaceContainer: dark ? const Color(0xFF22272C) : const Color(0xFFEDEFF2),
    primaryContainer: Board.amber,
    onPrimaryContainer: const Color(0xFF1A1200),
    outlineVariant: dark ? const Color(0xFF2E343A) : const Color(0xFFD3D8DD),
  );
  final RoundedRectangleBorder plate = RoundedRectangleBorder(borderRadius: BorderRadius.circular(6));
  return ThemeData(
    colorScheme: cs,
    scaffoldBackgroundColor: cs.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: Board.face,
      foregroundColor: Board.amber,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: ledLabel(size: 24),
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: cs.surfaceContainerLowest,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: cs.outlineVariant)),
    ),
    chipTheme: ChipThemeData(
      shape: plate.copyWith(side: BorderSide(color: cs.outlineVariant)),
      showCheckmark: false,
      selectedColor: Board.amber,
      backgroundColor: cs.surfaceContainerLowest,
      labelStyle: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600),
      secondaryLabelStyle: const TextStyle(color: Color(0xFF1A1200), fontWeight: FontWeight.w700),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(shape: plate, minimumSize: const Size(0, 48))),
    dividerTheme: DividerThemeData(color: cs.outlineVariant, thickness: 1, space: 1),
    expansionTileTheme: const ExpansionTileThemeData(shape: Border(), collapsedShape: Border()),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Board.amber),
  );
}

/// 검은 안내판 면. 홈 안내판과 지도 상단 패널이 같은 Hero로 이어져, 누르면 판이 그대로 지도 위로 옮겨 간다.
class BoardFace extends StatelessWidget {
  const BoardFace({super.key, required this.child, this.radius = const BorderRadius.all(Radius.circular(10))});

  final Widget child;
  final BorderRadius radius;

  static Widget _shuttle(BuildContext _, Animation<double> _, HeroFlightDirection _, BuildContext _, BuildContext _) =>
      const DecoratedBox(decoration: BoxDecoration(color: Board.face));

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'board',
      flightShuttleBuilder: _shuttle,
      child: Material(
        color: Board.face,
        // 어두운 테마 바탕과 섞이지 않게 1px 이음선 테두리.
        shape: RoundedRectangleBorder(borderRadius: radius, side: const BorderSide(color: Board.seam)),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

/// 노선 번호판(A/B). 정류장 안내기의 색 번호판처럼 코스 색 바탕에 흰 글자.
class CourseBadge extends StatelessWidget {
  const CourseBadge(this.id, {super.key, this.size = 28});

  final String id;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: id == 'A' ? Board.courseA : Board.courseB,
        borderRadius: BorderRadius.circular(4),
      ),
      // B 초록 바탕에 흰 글자는 대비가 모자라(2.1:1) 검은 글자로.
      child: Text(id,
          style: TextStyle(
              color: id == 'A' ? Colors.white : Board.face, fontWeight: FontWeight.w800, fontSize: size * 0.6, height: 1)),
    );
  }
}

// 5×7 LED 점 글자. '1'은 켜진 점.
const Map<String, List<String>> _glyphs = <String, List<String>>{
  '0': <String>['01110', '10001', '10001', '10001', '10001', '10001', '01110'],
  '1': <String>['00100', '01100', '00100', '00100', '00100', '00100', '01110'],
  '2': <String>['01110', '10001', '00001', '00010', '00100', '01000', '11111'],
  '3': <String>['11111', '00010', '00100', '00010', '00001', '10001', '01110'],
  '4': <String>['00010', '00110', '01010', '10010', '11111', '00010', '00010'],
  '5': <String>['11111', '10000', '11110', '00001', '00001', '10001', '01110'],
  '6': <String>['00110', '01000', '10000', '11110', '10001', '10001', '01110'],
  '7': <String>['11111', '00001', '00010', '00100', '01000', '01000', '01000'],
  '8': <String>['01110', '10001', '10001', '01110', '10001', '10001', '01110'],
  '9': <String>['01110', '10001', '10001', '01111', '00001', '00010', '01100'],
  ':': <String>['0', '0', '1', '0', '1', '0', '0'],
  '-': <String>['000', '000', '000', '111', '000', '000', '000'],
  ' ': <String>['00', '00', '00', '00', '00', '00', '00'],
};

/// 시각·숫자를 LED 점으로 그린다. 값이 바뀌면 왼쪽부터 한 열씩 켜진다(동작 줄이기 설정이면 바로).
class LedDigits extends StatefulWidget {
  const LedDigits(this.text, {super.key, this.dot = 4, this.color = Board.amber});

  final String text;
  final double dot; // 점 하나의 지름
  final Color color;

  @override
  State<LedDigits> createState() => _LedDigitsState();
}

class _LedDigitsState extends State<LedDigits> with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _play();
  }

  @override
  void didUpdateWidget(LedDigits old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _play();
  }

  void _play() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _sweep.value = 1;
    } else {
      _sweep.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _LedPainter p = _LedPainter(widget.text, widget.dot, widget.color, _sweep);
    return Semantics(
      label: widget.text,
      excludeSemantics: true,
      child: CustomPaint(size: p.size, painter: p),
    );
  }
}

class _LedPainter extends CustomPainter {
  _LedPainter(this.text, this.dot, this.color, this.sweep) : super(repaint: sweep);

  final String text;
  final double dot;
  final Color color;
  final Animation<double> sweep;

  double get _pitch => dot * 1.4;
  List<List<String>> get _cells => <List<String>>[for (final String c in text.split('')) _glyphs[c] ?? _glyphs[' ']!];
  int get _cols => _cells.fold(0, (int n, List<String> g) => n + g.first.length + 1) - 1;
  Size get size => Size(_cols * _pitch, 7 * _pitch);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint off = Paint()..color = color.withAlpha(22);
    final Paint on = Paint()..color = color;
    final Paint glow = Paint()
      ..color = color.withAlpha(90)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, dot * 0.6);
    final double lit = sweep.value * _cols;
    // 글자 사이 빈 열까지 꺼진 점을 깔아 한 장의 LED 판처럼 보이게 한다.
    final List<String> gap = List<String>.filled(7, '0');
    final List<List<String>> cols = <List<String>>[
      for (final (int i, List<String> g) in _cells.indexed) ...<List<String>>[
        if (i > 0) gap,
        for (int c = 0; c < g.first.length; c++) <String>[for (final String row in g) row[c]],
      ],
    ];
    for (final (int x, List<String> col) in cols.indexed) {
      for (int r = 0; r < 7; r++) {
        final Offset o = Offset((x + 0.5) * _pitch, (r + 0.5) * _pitch);
        if (col[r] == '1' && x < lit) {
          canvas.drawCircle(o, dot * 0.7, glow);
          canvas.drawCircle(o, dot / 2, on);
        } else {
          canvas.drawCircle(o, dot / 2, off);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_LedPainter old) => old.text != text || old.dot != dot || old.color != color;
}
