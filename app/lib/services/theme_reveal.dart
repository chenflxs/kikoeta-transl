import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// 深浅色切换的圆形揭示（从触发点扩散到整个窗口）入口。
///
/// 参考社区通行做法（pub 上的 `animated_theme_switcher`、Android 12 的圆形揭示）：
/// 新外观由一个不断扩大的圆从触发点铺满窗口。区别在于这里**不重建第二棵控件树**——
/// 根组件先抓一张切换前的截图当作「旧外观」，真实界面只重建一次、立即变成新主题，
/// 动画每帧只是给这张贴图换一个圆形裁剪。文字、图标、控件的颜色都来自真实渲染，
/// 样式与静止时完全一致，也不会有双份 build / initState 的开销。
class ThemeReveal {
  ThemeReveal._();

  static final ThemeReveal instance = ThemeReveal._();

  /// 由根组件注册：切换主题并播放揭示动画
  Future<void> Function(String theme, Offset? globalOrigin)? _run;

  void bind(Future<void> Function(String theme, Offset? globalOrigin) run) {
    _run = run;
  }

  /// 从控件（如按钮）中心向四周扩散
  void fromWidget(BuildContext context, String theme) {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize
        ? box.localToGlobal(box.size.center(Offset.zero))
        : null;
    _dispatch(theme, origin);
  }

  /// 从窗口中心向四周扩散（设置页切换、跟随系统变化）
  void fromCenter(String theme) => _dispatch(theme, null);

  /// [origin] 为空时由根组件改用窗口中心
  void _dispatch(String theme, Offset? origin) => _run?.call(theme, origin);
}

/// 画出「切换前的截图」，但裁掉已经扩散到的圆形区域：
/// 圆内露出真实界面（新主题），圆外仍是旧外观。
/// 绘制直接挂在动画上（`repaint`），整个动画期间不触发任何 widget 重建。
class ThemeRevealPainter extends CustomPainter {
  ThemeRevealPainter({
    required this.image,
    required this.origin,
    required this.progress,
  }) : super(repaint: progress);

  final ui.Image image;

  /// 揭示中心（本组件局部坐标）
  final Offset origin;
  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    if (t >= 1) return; // 圆已盖住整个窗口，旧外观彻底撤掉
    final dst = Offset.zero & size;
    canvas.save();
    if (t > 0) {
      // 偶奇填充：矩形减去圆形 = 圆外区域
      final mask = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(dst)
        ..addOval(
          Rect.fromCircle(center: origin, radius: _maxRadius(size) * t),
        );
      canvas.clipPath(mask, doAntiAlias: true);
    }
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      dst,
      Paint()..filterQuality = FilterQuality.low,
    );
    canvas.restore();
  }

  /// 中心到四角的最远距离，保证圆最终能盖住整个窗口
  double _maxRadius(Size size) {
    final dx = math.max(origin.dx, size.width - origin.dx);
    final dy = math.max(origin.dy, size.height - origin.dy);
    return math.sqrt(dx * dx + dy * dy);
  }

  @override
  bool shouldRepaint(ThemeRevealPainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.origin != origin;
}
