// 앱 전체의 모양(컬러 히어로). 연회색 바탕 + 흰 카드(모서리 18, 은은한 그림자) + 상태를 색으로 말하는 그라데이션 히어로.
// 참고: fall-detection 보호자 앱의 디자인(docs/superpowers/specs/2026-08-29-app-visual-redesign-design.md)을 버스 앱에 옮겼다.
// Pressable: 모든 버튼에 씌우는 눌림 애니메이션(살짝 줄었다가 튕기듯 돌아옴). 새 버튼을 만들면 꼭 감싼다.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class AppColors {
  static const Color bg = Color(0xFFF7F8FA); // 화면 바탕
  static const Color card = Color(0xFFFFFFFF);
  static const Color text = Color(0xFF191F28);
  static const Color textSub = Color(0xFF6B7684);
  static const Color textMuted = Color(0xFF8B95A1);
  static const Color hairline = Color(0xFFF2F4F6); // 구분선 · 옅은 칩 바탕
  static const Color border = Color(0xFFE5E8EB);

  static const Color primary = Color(0xFF0E9F6E);
  static const Color primaryLight = Color(0xFF14B98A);
  static const Color primaryTint = Color(0xFFE3F6EE);
  static const Color onPrimaryTint = Color(0xFF0A7A55);

  static const Color danger = Color(0xFFE5323F);
  static const Color dangerTint = Color(0xFFFDECEE);

  static const Color mutedStart = Color(0xFF6B7684);
  static const Color mutedEnd = Color(0xFF4E5968);

  // 코스 색은 지도 마커(assets/web/map.html)와 같아야 한다.
  static const Color courseA = Color(0xFF0066FF);
  static const Color courseB = Color(0xFF00CC66);
}

const List<BoxShadow> appShadow = <BoxShadow>[BoxShadow(color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 2))];

const String _font = 'Pretendard';

ThemeData buildTheme() {
  final ColorScheme cs = ColorScheme.fromSeed(seedColor: AppColors.primary).copyWith(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    primaryContainer: AppColors.primaryTint,
    onPrimaryContainer: AppColors.onPrimaryTint,
    surface: AppColors.bg,
    surfaceContainerLowest: AppColors.card,
    onSurface: AppColors.text,
    onSurfaceVariant: AppColors.textSub,
    outline: AppColors.border,
    outlineVariant: AppColors.hairline,
    error: AppColors.danger,
  );
  final ThemeData base = ThemeData(colorScheme: cs, fontFamily: _font);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    textTheme: base.textTheme.apply(bodyColor: AppColors.text, displayColor: AppColors.text),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: _font, fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.text),
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: AppColors.card,
        foregroundColor: AppColors.text,
        side: const BorderSide(color: AppColors.border),
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontFamily: _font, fontSize: 17, fontWeight: FontWeight.w700),
      ),
    ),
    chipTheme: const ChipThemeData(
      shape: StadiumBorder(side: BorderSide(color: AppColors.border)),
      showCheckmark: false,
      backgroundColor: AppColors.card,
      selectedColor: AppColors.primary,
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      labelStyle: TextStyle(fontFamily: _font, fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textSub),
      secondaryLabelStyle: TextStyle(fontFamily: _font, fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.hairline, thickness: 1, space: 1),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primary),
  );
}

/// 눌림 애니메이션. 누르는 동안 살짝 작아지고, 떼면 튕기듯 돌아온다. 아주 짧게 톡 쳐도 끝까지 한 번은 보인다.
/// Listener라 안의 버튼 동작(탭·스크롤)을 가로채지 않는다. 동작 줄이기 설정이면 움직이지 않는다.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.scale = 0.95});

  final Widget child;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
    reverseDuration: const Duration(milliseconds: 220),
  )..addStatusListener((AnimationStatus s) {
      if (s == AnimationStatus.completed && !_held) _c.reverse();
    });
  late final Animation<double> _scale = Tween<double>(begin: 1, end: widget.scale).animate(
    // 되돌아올 때 easeInBack: 끝에서 1을 살짝 넘었다가 자리를 잡는다(통 튀는 느낌).
    CurvedAnimation(parent: _c, curve: Curves.easeOut, reverseCurve: Curves.easeInBack),
  );
  bool _held = false;

  void _down(PointerDownEvent _) {
    if (MediaQuery.disableAnimationsOf(context)) return;
    _held = true;
    _c.forward();
  }

  void _up(PointerEvent _) {
    _held = false;
    if (_c.status == AnimationStatus.completed) _c.reverse();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _down,
      onPointerUp: _up,
      onPointerCancel: _up,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

/// 하위 화면 상단 바. 뒤로 가기와 오른쪽 버튼에도 눌림 애니메이션을 씌운다.
AppBar pageBar(String title, {List<Widget> actions = const <Widget>[]}) => AppBar(
      leading: const Pressable(child: BackButton()),
      title: Text(title),
      actions: <Widget>[for (final Widget a in actions) Pressable(child: a), const SizedBox(width: 4)],
    );

/// 흰 카드 — 모서리 18, 은은한 그림자. onTap이 있으면 잉크 효과 + 눌림 애니메이션.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.highlight = false});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool highlight; // 오늘·진행 중 — 초록 테두리

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(18);
    final Widget card = Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: radius,
        boxShadow: appShadow,
        border: highlight ? Border.all(color: AppColors.primary, width: 1.5) : null,
      ),
      // InkWell은 가장 가까운 Material에 그린다.
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      ),
    );
    return onTap == null ? card : Pressable(scale: 0.98, child: card);
  }
}

enum HeroTone { live, off }

const Map<HeroTone, List<Color>> _heroColors = <HeroTone, List<Color>>{
  HeroTone.live: <Color>[AppColors.primaryLight, AppColors.primary],
  HeroTone.off: <Color>[AppColors.mutedStart, AppColors.mutedEnd],
};

Widget _bubble(double size, double alpha) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: alpha)),
    );

/// 상태를 색으로 말하는 그라데이션 카드(운행 중 초록 · 운행 종료 회색). 안의 글씨·아이콘은 흰색.
class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.tone,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = const BorderRadius.all(Radius.circular(22)),
    this.onTap,
  });

  final HeroTone tone;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget body = Material(
      color: Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: _heroColors[tone]!),
        ),
        child: InkWell(
          onTap: onTap,
          splashColor: Colors.white.withValues(alpha: 0.16),
          highlightColor: Colors.white.withValues(alpha: 0.08),
          child: Stack(
            children: <Widget>[
              Positioned(right: -24, top: -24, child: _bubble(120, 0.12)),
              Positioned(right: 20, bottom: -40, child: _bubble(90, 0.08)),
              Padding(
                padding: padding,
                child: DefaultTextStyle.merge(
                  style: const TextStyle(color: Colors.white),
                  child: IconTheme.merge(data: const IconThemeData(color: Colors.white), child: child),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return onTap == null ? body : Pressable(scale: 0.97, child: body);
  }
}

/// 코스 번호판(A/B). 코스 색 바탕에 글자, 그라데이션 위에선 흰 테두리로 떼어 낸다.
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
        color: id == 'A' ? AppColors.courseA : AppColors.courseB,
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      // B 초록 바탕에 흰 글자는 대비가 모자라(2.1:1) 진한 글자로.
      child: Text(id,
          style: TextStyle(
              color: id == 'A' ? Colors.white : AppColors.text, fontWeight: FontWeight.w700, fontSize: size * 0.55, height: 1)),
    );
  }
}

/// 둥근 상태 칩('D-3', '진행 중', '오늘').
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.bg = AppColors.primaryTint, this.fg = AppColors.onPrimaryTint});

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}
