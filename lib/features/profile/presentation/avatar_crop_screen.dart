import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../domain/avatar_crop.dart';

/// Opens the circular crop editor over whatever is on screen and hands back
/// the two encoded JPEGs, or null if the person backed out.
///
/// Arrives the way the prayer-mat scanner does — a full-screen surface that
/// rises over the app rather than sliding in from the side — because both are
/// the same kind of moment: the app takes the whole screen for one task, and
/// gives it straight back.
Future<AvatarJpegs?> cropAvatar(
  BuildContext context, {
  required Uint8List source,
}) {
  return Navigator.of(context, rootNavigator: true).push<AvatarJpegs>(
    PageRouteBuilder<AvatarJpegs>(
      fullscreenDialog: true,
      opaque: true,
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (BuildContext _, Animation<double> a, Animation<double> b) =>
          AvatarCropScreen(source: source),
      transitionsBuilder:
          (
            BuildContext _,
            Animation<double> a,
            Animation<double> b,
            Widget child,
          ) {
            final CurvedAnimation curve = CurvedAnimation(
              parent: a,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curve,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.08),
                  end: Offset.zero,
                ).animate(curve),
                child: child,
              ),
            );
          },
    ),
  );
}

/// Choose what part of a picture becomes your face in Layla Pro.
///
/// The circle is not a preview of the crop, it *is* the crop: what shows
/// through the cutout is exactly what gets stored, at exactly the zoom it is
/// shown at. That is the whole reason the editor exists — the picker used to
/// shrink the whole photograph into a 256-pixel square, so a person standing
/// at the left of a group shot ended up as a group shot.
class AvatarCropScreen extends StatefulWidget {
  const AvatarCropScreen({super.key, required this.source});

  /// The file the picker handed back, undecoded.
  final Uint8List source;

  /// Room kept clear above the circle: the gap over Cancel, the Cancel row
  /// itself, the heading, and the line under it.
  ///
  /// Measured rather than estimated. Every number here was read off this
  /// screen laid out on the narrowest phone the app supports, where the line
  /// under the heading wraps to three: 8 above Cancel, a 48-point button row,
  /// a 22-point heading, [Insets.xs], 57 points of wrapped detail, and
  /// [Insets.md] of air before the circle.
  ///
  /// Public because `test/responsive_layout_test.dart` asserts that the
  /// circle really does clear the chrome on every phone at both ends of the
  /// text-scale clamp, and a reservation the test cannot see is a
  /// reservation that drifts from what is on screen — which is exactly what
  /// these two numbers had already done.
  static const double topChrome =
      Insets.sm + 48 + 22 + Insets.xs + 57 + Insets.md;

  /// Room kept clear below it: the fault line, the gap, the button and the
  /// page padding under it. The button is 56 because `filledButtonTheme` sets
  /// `minimumSize: Size.fromHeight(56)`, and the padding is [Insets.lg]
  /// because that is what the block below is actually built with.
  static const double bottomChrome = 19 + Insets.md + 56 + Insets.lg;

  @override
  State<AvatarCropScreen> createState() => _AvatarCropScreenState();
}

class _AvatarCropScreenState extends State<AvatarCropScreen>
    with SingleTickerProviderStateMixin {
  final TransformationController _view = TransformationController();

  ui.Image? _picture;

  /// The viewport the transform was last set up for. The editor is the whole
  /// screen, so this changes on rotation and on nothing else.
  Size? _laidOut;

  /// The circle as last laid out. Kept rather than worked out again wherever
  /// it is needed: the crop that gets stored and the constraint that keeps the
  /// circle full have to be measuring the same circle the person was looking
  /// at, and two derivations from MediaQuery is two chances for them not to
  /// be.
  double _circle = 0;

  /// Guards [_settle] against the change it makes itself.
  bool _settling = false;

  /// Whether the opening transform has actually been applied — see [_adopt].
  bool _framed = false;

  /// True while the crop is being cut and encoded.
  bool _busy = false;

  /// A plain sentence when the picture cannot be read or encoded.
  String? _fault;

  /// The arrival: the picture fades up and the chrome follows it.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  )..forward();

  /// The picture arrives first and the chrome follows it, the same staggered
  /// entrance the mat scanner makes.
  late final CurvedAnimation _pictureIn = CurvedAnimation(
    parent: _intro,
    curve: Curves.easeOut,
  );
  late final CurvedAnimation _chromeIn = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.35, 1, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    _view.addListener(_settle);
    unawaited(_decode());
  }

  @override
  void dispose() {
    _view.removeListener(_settle);
    _view.dispose();
    _pictureIn.dispose();
    _chromeIn.dispose();
    _intro.dispose();
    _picture?.dispose();
    super.dispose();
  }

  /// Decodes the source once, for its pixels and for its size.
  ///
  /// Flutter's decoder, not `package:image`'s: this one is what actually
  /// paints, so the picture the person frames and the size the maths uses can
  /// never disagree. It also honours the EXIF orientation tag, which is why
  /// the encoder bakes that in before it cuts.
  Future<void> _decode() async {
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(widget.source);
      final ui.FrameInfo frame = await codec.getNextFrame();
      codec.dispose();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() => _picture = frame.image);
    } on Object catch (error) {
      debugPrint('Layla Pro: chosen picture would not decode ($error)');
      if (mounted) {
        setState(
          () => _fault =
              'That picture could not be opened. Please choose another one.',
        );
      }
    }
  }

  /// The circle, sized to whichever of the two directions runs out first.
  double _diameter(Size viewport, EdgeInsets safe, double textScale) =>
      AvatarCrop.diameterFor(
        viewport: viewport,
        safe: safe,
        topChrome: AvatarCropScreen.topChrome,
        bottomChrome: AvatarCropScreen.bottomChrome,
        textScale: textScale,
      );

  Size get _sourceSize {
    final ui.Image? picture = _picture;
    if (picture == null) return Size.zero;
    return Size(picture.width.toDouble(), picture.height.toDouble());
  }

  /// Sets the opening transform the first time a viewport is known, and again
  /// if the screen ever changes shape underneath it.
  ///
  /// Keyed on the circle as well as on the viewport. They usually move
  /// together, but not always: the diameter comes from the safe-area insets
  /// too, so an Android system bar appearing or an in-call banner arriving can
  /// grow the circle while the screen stays exactly the same size. Keyed on
  /// the viewport alone, the circle would grow against a transform settled for
  /// the smaller one and nothing would correct it — [_settle] only runs when
  /// the person moves the picture, and they have not touched it. The circle
  /// would show scrim at its edge, and "Use photo" would then cut a rectangle
  /// rather than a square.
  void _adopt(Size viewport, double diameter) {
    if (_picture == null || (_laidOut == viewport && _circle == diameter)) {
      return;
    }
    _laidOut = viewport;
    _circle = diameter;
    // After the frame: this is called from `build`, and a transformation
    // controller is a Listenable that half the subtree is already listening
    // to.
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted || _laidOut != viewport || _circle != diameter) return;
      _settling = true;
      _view.value = AvatarCrop.initialTransform(
        source: _sourceSize,
        viewport: viewport,
        diameter: diameter,
      );
      _settling = false;
      // Only now is the picture where the person is meant to find it. Until
      // this runs the InteractiveViewer is at the identity, which paints the
      // photograph letterboxed in the whole screen — a strip of picture with
      // black above and below it, inside a circle that is supposed to be
      // full. One frame of that is usually hidden under the opening fade, but
      // a slow decode of a 1600-pixel source lands after the fade is over and
      // shows it at full strength.
      if (!_framed) setState(() => _framed = true);
    });
  }

  /// Pulls the picture back whenever a drag has opened a gap in the circle.
  void _settle() {
    if (_settling || !mounted) return;
    final Size? viewport = _laidOut;
    if (viewport == null || _picture == null) return;

    final Matrix4 fixed = AvatarCrop.constrain(
      source: _sourceSize,
      viewport: viewport,
      diameter: _circle,
      transform: _view.value,
    );
    if (fixed == _view.value) return;
    _settling = true;
    _view.value = fixed;
    _settling = false;
  }

  /// Cuts what the circle is looking at and encodes it, then closes with it.
  Future<void> _use() async {
    final Size? viewport = _laidOut;
    if (_busy || _picture == null || viewport == null) return;

    setState(() {
      _busy = true;
      _fault = null;
    });
    unawaited(HapticFeedback.selectionClick());

    try {
      final Rect crop = AvatarCrop.rectFor(
        source: _sourceSize,
        viewport: viewport,
        diameter: _circle,
        transform: _view.value,
      );
      final AvatarJpegs jpegs = await encodeAvatarCropOffThread(
        AvatarCropOrder(source: widget.source, crop: crop),
      );
      // Still mounted is not enough. A route that is already on its way out
      // stays in the tree for the whole of its 320ms reverse transition, and
      // the encode usually finishes inside that window — so `mounted` is true
      // for a screen that is halfway gone. Popping then does not close this
      // route, which Navigator no longer counts as present: it closes the one
      // underneath, taking the profile screen with it.
      if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
      Navigator.of(context).pop(jpegs);
    } on AvatarCropFailure catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _fault = error.message;
        });
      }
    } on Object catch (error) {
      debugPrint('Layla Pro: avatar crop failed ($error)');
      if (mounted) {
        setState(() {
          _busy = false;
          _fault = 'That picture could not be saved. Please try another one.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    // What the chrome above and below the circle will actually measure — see
    // AvatarCrop.diameterFor.
    final double textScale = MediaQuery.textScalerOf(context).scale(1);

    // Back is refused for exactly as long as Cancel is. Android's back button
    // and its predictive-back gesture reach this screen too, and neither goes
    // anywhere near the Cancel button that is already disabled — so without
    // this, backing out while the crop is encoding leaves a pop landing on a
    // route that is already closing.
    return PopScope<AvatarJpegs?>(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints box) {
            final Size viewport = Size(box.maxWidth, box.maxHeight);
            final double diameter = _diameter(viewport, safe, textScale);
            _adopt(viewport, diameter);

            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                // Nothing is drawn until the picture is framed: a gold ring
                // around a circle of black, while the decode is still running or
                // after it has failed, would read as the app having lost the
                // photograph.
                if (_picture != null && _framed) ...<Widget>[
                  _backdrop(),
                  _editor(viewport, diameter),
                  // The scrim and the ring are painting, not a target: every
                  // touch belongs to the picture underneath them.
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _CutoutPainter(diameter: diameter),
                      size: viewport,
                    ),
                  ),
                ],
                _chrome(safe),
              ],
            );
          },
        ),
      ),
    );
  }

  /// The same picture again, blurred, filling the screen behind the editor.
  ///
  /// The picture the person moves is contained rather than cover-fitted — that
  /// is what lets them zoom out far enough to use its whole short side — and a
  /// contained picture leaves bands of nothing above and below it. Empty, they
  /// read as a seam across the screen: the scrim darkens the photograph to
  /// almost black, so a band of true black beside it looks like a rendering
  /// fault rather than like the end of a picture.
  ///
  /// Blurred rather than merely repeated, because a sharp copy at a second
  /// framing puts a hard edge across the screen wherever the two disagree.
  /// Out of focus there is no edge to find, and the picture reads as floating
  /// over a soft version of itself.
  ///
  /// Never seen through the circle, whatever it is doing: the editor above is
  /// held to covering the circle at every moment.
  Widget _backdrop() => FadeTransition(
    opacity: _pictureIn,
    child: ImageFiltered(
      // Clamped, not the default: a decal blur fades to transparent at the
      // edges of the screen, which would put back the very band of black this
      // exists to fill.
      imageFilter: ui.ImageFilter.blur(
        sigmaX: 28,
        sigmaY: 28,
        tileMode: TileMode.clamp,
      ),
      child: RawImage(
        image: _picture,
        fit: BoxFit.cover,
        // Ground, not content. It is under a scrim at a tenth of its own
        // brightness and then blurred past recognition; a careful resample of
        // it would be paying for pixels nobody can see.
        filterQuality: FilterQuality.low,
      ),
    ),
  );

  /// The picture, under the fingers.
  Widget _editor(Size viewport, double diameter) {
    final Size source = _sourceSize;
    return FadeTransition(
      opacity: _pictureIn,
      child: InteractiveViewer(
        transformationController: _view,
        minScale: AvatarCrop.minScale(
          source: source,
          viewport: viewport,
          diameter: diameter,
        ),
        maxScale: AvatarCrop.maxScale(
          source: source,
          viewport: viewport,
          diameter: diameter,
        ),
        // Nothing to clip to: the editor is the whole screen, and the scrim
        // above it is what hides everything outside the circle.
        clipBehavior: Clip.none,
        // Its own boundary logic would keep the letterboxed *box* over the
        // screen, which says nothing about whether the picture is over the
        // circle. `_settle` does that job instead — see AvatarCrop.constrain.
        boundaryMargin: const EdgeInsets.all(double.infinity),
        child: RawImage(
          image: _picture,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }

  /// Cancel and the heading above, the button below.
  ///
  /// The heading is the whole reason this screen reads as Layla Pro rather
  /// than as the system photo cropper it otherwise resembles — a circle, a
  /// scrim and two buttons are what every cropper on the phone looks like. It
  /// is the same pairing the mat scanner opens with: what you are being asked
  /// to do, and one line saying what it is for.
  Widget _chrome(EdgeInsets safe) {
    final String? fault = _fault;
    return FadeTransition(
      opacity: _chromeIn,
      child: Column(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(
              Insets.md,
              safe.top + Insets.sm,
              Insets.md,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.cream,
                      textStyle: AppType.titleSm,
                      // Insets.sm horizontally, not the md the vertical uses:
                      // that puts the word "Cancel" at Insets.page from the
                      // edge of the screen, in line with the heading under it
                      // and with the button at the far end of the screen.
                      padding: const EdgeInsets.symmetric(
                        horizontal: Insets.sm,
                        vertical: Insets.md,
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Frame your picture',
                        style: AppType.displaySm.copyWith(
                          color: AppColors.cream,
                        ),
                      ),
                      const SizedBox(height: Insets.xs),
                      Text(
                        'Pinch and drag until the circle holds what you want. '
                        'That is your picture on Layla Pro, and on your '
                        "friends' lists.",
                        style: AppType.bodySm.copyWith(color: AppColors.mist),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: EdgeInsets.fromLTRB(
              Insets.page,
              0,
              Insets.page,
              safe.bottom + Insets.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // The fault slot, and nothing else. Kept in the layout even
                // when there is nothing to say, because a line that appears
                // out of nothing would push the button down the screen at the
                // exact moment somebody is reaching for it.
                Visibility(
                  visible: fault != null,
                  maintainSize: true,
                  maintainState: true,
                  maintainAnimation: true,
                  child: Text(
                    fault ?? '',
                    textAlign: TextAlign.center,
                    style: AppType.bodySm.copyWith(color: AppColors.rose),
                  ),
                ),
                const SizedBox(height: Insets.md),
                PrimaryButton(
                  label: 'Use photo',
                  busy: _busy,
                  onPressed: _picture == null ? null : _use,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Everything but the circle, darkened, with a gold rim around what is left.
///
/// The hole is cut with an even-odd path rather than by drawing four
/// rectangles around a circle, which is the difference between a clean
/// anti-aliased edge and four seams meeting at the corners of the cutout.
class _CutoutPainter extends CustomPainter {
  const _CutoutPainter({required this.diameter});

  final double diameter;

  /// Midnight rather than black, at the strength where a face outside the
  /// circle is still readable as context but never competes with the one
  /// inside it.
  static const Color _scrim = Color(0xE6060D1B);

  @override
  void paint(Canvas canvas, Size size) {
    final Offset centre = Offset(size.width / 2, size.height / 2);
    final Rect circle = Rect.fromCircle(center: centre, radius: diameter / 2);

    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addOval(circle),
      Paint()..color = _scrim,
    );

    // The rim the picture is about to get, so the crop reads as an avatar
    // rather than as a viewfinder.
    //
    // Scaled with the circle rather than copied from `AvatarCircle`, which
    // wears 1.5 points around 44 to 64. The same number around a 350-point
    // circle is not the same line — it is six times thinner relative to what
    // it encloses, and it reads as a thread. This keeps the proportion.
    //
    // Drawn inside the circle, because a stroke is centred on its path: half
    // of it would otherwise sit outside the region the crop actually keeps,
    // and the preview's rim and the saved picture's rim would land on
    // different pixels.
    final double stroke = math.max(1.5, diameter / 140);
    canvas.drawCircle(
      centre,
      diameter / 2 - stroke / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = AppColors.gold,
    );
  }

  @override
  bool shouldRepaint(_CutoutPainter old) => old.diameter != diameter;
}
