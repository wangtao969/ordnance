import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// 液态玻璃折射底（v2，对标酷安底栏的做法），供 App 真实底部导航用。
///
/// 原理：不用矩阵放大冒充折射，而是走 Impeller 的 [ui.ImageFilter.shader]，
/// 片元着色器直接采样底栏后方的实时画面，按圆角 SDF 的法线做边缘折射位移
/// + 红蓝错位色散 + 边缘高光。着色器在 shaders/liquid_glass.frag。
///
/// 用法：把它包在导航条内容外面，只换底的渲染方式，内容本身（图标、
/// 选中药丸、渐变底色、边框、阴影）一律由 child 自己画，不动。
/// 着色器在不支持的后端（非 Impeller）加载会失败，自动退回原来的
/// 毛玻璃 blur，加载完成前也先显示毛玻璃，绝不崩、不出白条。
class LiquidGlassBackdrop extends StatefulWidget {
  const LiquidGlassBackdrop({
    super.key,
    required this.child,
    this.radius = 34,
    this.refraction = 14.0,
    this.chroma = 0.35,
    this.tint = 0.16,
    this.fallbackSigma = 40.0,
  });

  final Widget child;

  /// 药丸圆角半径 px，需与外层 ClipRRect 一致，着色器用它算 SDF 法线。
  final double radius;

  /// 边缘折射位移 px（与演示页一致）。
  final double refraction;

  /// 红蓝错位色散系数（与演示页一致）。
  final double chroma;

  /// 白色 veil 量：2.2.5 从 0.08 加到 0.16，导航条更实、更糊。
  final double tint;

  /// 着色器不可用时的毛玻璃 blur：2.2.5 从 28 加到 40。
  final double fallbackSigma;

  @override
  State<LiquidGlassBackdrop> createState() => _LiquidGlassBackdropState();
}

class _LiquidGlassBackdropState extends State<LiquidGlassBackdrop> {
  ui.FragmentProgram? _program;

  @override
  void initState() {
    super.initState();
    ui.FragmentProgram.fromAsset('shaders/liquid_glass.frag').then(
      (program) {
        if (mounted) setState(() => _program = program);
      },
      onError: (_) {
        // 着色器不可用：保持毛玻璃退路，不抛错。
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_program != null) {
      final shader = _program!.fragmentShader();
      // 引擎自动占位：u_size 占 float 索引 0、1；自定义 uniform 从 2 开始，
      // 顺序与 liquid_glass.frag 声明一致：radius、refraction、chroma、tint。
      shader.setFloat(2, widget.radius);
      shader.setFloat(3, widget.refraction);
      shader.setFloat(4, widget.chroma);
      shader.setFloat(5, widget.tint);
      return BackdropFilter(
        filter: ui.ImageFilter.shader(shader),
        child: widget.child,
      );
    }
    return BackdropFilter(
      filter: ui.ImageFilter.blur(
          sigmaX: widget.fallbackSigma, sigmaY: widget.fallbackSigma),
      child: widget.child,
    );
  }
}
