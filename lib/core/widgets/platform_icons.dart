import 'dart:io';

import 'package:flutter/material.dart';

/// The two glyphs that are not the same shape on both phones.
///
/// Everything else in Layla Pro's icon set means the same thing everywhere.
/// These two do not: `ios_share` is Apple's box-with-an-arrow, which on an
/// Android phone is simply an icon nobody recognises, and
/// `arrow_back_ios_new` is Apple's thin chevron where Android's back arrow
/// has a shaft. Neither is broken — both are the small kind of wrong that
/// makes an app feel ported rather than built.
///
/// Under test `Platform` is neither, and the Android glyphs are the Material
/// ones, so a widget test renders the neutral pair.
IconData get kShareIcon =>
    Platform.isIOS ? Icons.ios_share_rounded : Icons.share_rounded;

IconData get kBackIcon => Platform.isIOS
    ? Icons.arrow_back_ios_new_rounded
    : Icons.arrow_back_rounded;
