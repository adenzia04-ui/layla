import 'dart:ui' as ui;

import 'package:flutter/material.dart';

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
      _program =
          await ui.FragmentProgram.fromAsset('shaders/liquid_glass.frag');
    } on Object catch (error) {
      debugPrint('Layla: liquid glass shader unavailable — $error');
    }
  }

  static bool get ready => _program != null;

  /// Builds the filter for one lens position. Returns null when the shader is
  /// unavailable, or when the platform rejects it.
  static ui.ImageFilter? filter({
    required Size area,
    required Rect lens,
    required double radius,
    required double strength,
  }) {
    final ui.FragmentProgram? program = _program;
    if (program == null) return null;
    try {
      final ui.FragmentShader shader = program.fragmentShader()
        ..setFloat(0, area.width)
        ..setFloat(1, area.height)
        ..setFloat(2, lens.center.dx)
        ..setFloat(3, lens.center.dy)
        ..setFloat(4, lens.width / 2)
        ..setFloat(5, lens.height / 2)
        ..setFloat(6, radius)
        ..setFloat(7, strength);
      return ui.ImageFilter.shader(shader);
    } on Object catch (error) {
      debugPrint('Layla: liquid glass filter failed — $error');
      return null;
    }
  }
}
