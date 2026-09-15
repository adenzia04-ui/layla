import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Loads the refraction shader once, for whoever wants it.
///
/// Returns null if it cannot be loaded or the device is not on Impeller —
/// `ImageFilter.shader` throws on the Skia backend. Callers fall back to the
/// painted glass, which looks fine; a tab bar must never depend on a shader.
class LiquidGlassShader {
  static ui.FragmentProgram? _program;
  static bool _tried = false;

  static Future<void> load() async {
    if (_tried) return;
    _tried = true;
    try {
      _program = await ui.FragmentProgram.fromAsset(
        'shaders/liquid_glass.frag',
      );
    } on Object catch (error) {
      debugPrint('Layla Pro: liquid glass shader unavailable — $error');
    }
  }

  static bool get ready => _program != null;

  /// The filter for a lens whose on-screen rectangle is [lensPx], in device
  /// pixels from the top-left of the screen.
  ///
  /// The image a backdrop filter is handed is the whole screen at device
  /// resolution, with fragment coordinates in the same space — so that is
  /// the space the lens must be described in. [strength] is how far the rim
  /// bends light, as a share of the lens's height. Returns null when the
  /// shader is unavailable, or when the platform rejects it.
  static ui.ImageFilter? filter({
    required Rect lensPx,
    double strength = 0.22,
    double light = 1,
  }) {
    final ui.FragmentProgram? program = _program;
    if (program == null) return null;
    try {
      // uSize (floats 0 and 1) is filled in by the engine.
      final ui.FragmentShader shader = program.fragmentShader()
        ..setFloat(2, lensPx.center.dx)
        ..setFloat(3, lensPx.center.dy)
        ..setFloat(4, lensPx.width / 2)
        ..setFloat(5, lensPx.height / 2)
        ..setFloat(6, lensPx.height / 2)
        ..setFloat(7, strength * lensPx.height)
        ..setFloat(8, light);
      return ui.ImageFilter.shader(shader);
    } on Object catch (error) {
      debugPrint('Layla Pro: liquid glass filter failed — $error');
      return null;
    }
  }
}

/// A pane of refracting glass the size of its box.
///
/// Measures its own rectangle on screen while painting — through every
/// transform above it, so a lens mid-swell is still described exactly — and
/// hands that to the shader in device pixels. Asking a parent where it was
/// went wrong once; asking nobody cannot. Paints nothing when the shader is
/// unavailable, so whatever is layered over it carries the look alone.
class RefractingGlass extends SingleChildRenderObjectWidget {
  const RefractingGlass({
    super.key,
    this.strength = 0.30,
    this.light = 1,
    super.child,
  });

  /// How much light sits on the glass, 0 to 1.
  final double light;

  /// How far the rim bends light, as a share of the pane's height.
  final double strength;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderRefractingGlass(
        dpr: MediaQuery.devicePixelRatioOf(context),
        strength: strength,
        light: light,
      );

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderRefractingGlass)
      ..dpr = MediaQuery.devicePixelRatioOf(context)
      ..strength = strength
      ..light = light;
  }
}

class _RenderRefractingGlass extends RenderProxyBox {
  _RenderRefractingGlass({
    required double dpr,
    required double strength,
    required double light,
  }) : _dpr = dpr,
       _strength = strength,
       _light = light;

  double _light;
  double get light => _light;
  set light(double value) {
    if (value == _light) return;
    _light = value;
    markNeedsPaint();
  }

  double _dpr;
  double get dpr => _dpr;
  set dpr(double value) {
    if (value == _dpr) return;
    _dpr = value;
    markNeedsPaint();
  }

  double _strength;
  double get strength => _strength;
  set strength(double value) {
    if (value == _strength) return;
    _strength = value;
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => LiquidGlassShader.ready;

  @override
  void paint(PaintingContext context, Offset offset) {
    final Rect onScreen = Rect.fromPoints(
      localToGlobal(Offset.zero),
      localToGlobal(Offset(size.width, size.height)),
    );
    final ui.ImageFilter? filter = LiquidGlassShader.filter(
      lensPx: Rect.fromLTRB(
        onScreen.left * dpr,
        onScreen.top * dpr,
        onScreen.right * dpr,
        onScreen.bottom * dpr,
      ),
      strength: strength,
      light: light,
    );
    if (filter == null) {
      super.paint(context, offset);
      return;
    }
    final BackdropFilterLayer glass =
        (layer as BackdropFilterLayer?) ?? BackdropFilterLayer();
    glass.filter = filter;
    layer = glass;
    context.pushLayer(glass, super.paint, offset);
  }
}
