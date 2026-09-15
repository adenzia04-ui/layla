import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../data/mat_vision.dart';
import '../domain/mat_check.dart';

/// Opens the scanner and returns the photo that passed, or null if the person
/// backed out.
///
/// The file comes straight from the camera's temporary directory, so the
/// caller must copy it somewhere permanent — `ProofRepository.save` does.
Future<XFile?> scanForPrayerMat(BuildContext context, {String? prayerLabel}) {
  // Slides up over the app like a sheet, the way a camera should arrive.
  return Navigator.of(context, rootNavigator: true).push<XFile>(
    PageRouteBuilder<XFile>(
      fullscreenDialog: true,
      opaque: true,
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (BuildContext _, Animation<double> a, Animation<double> b) =>
          MatScannerScreen(prayerLabel: prayerLabel),
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

/// Step 2, as a viewfinder rather than a camera roll.
///
/// The old Step 2 handed the whole job to the system camera: a shutter button,
/// a "Use Photo" confirmation, and no idea what was in the frame until it came
/// back. This looks at the live preview instead and takes the photo itself the
/// moment it sees a prayer mat, which is both less to do at 5am and a harder
/// thing to fake — you have to actually be pointing a camera at a mat, not
/// choosing a picture of one.
///
/// Thirty seconds is the whole scan. It is not a punishment: nothing is lost
/// when it runs out, the person just scans again. What the clock buys is the
/// difference between "hold the phone over your mat" and "leave the camera
/// open indefinitely", and a deadline is what makes the first one feel like a
/// task with an end.
class MatScannerScreen extends ConsumerStatefulWidget {
  const MatScannerScreen({super.key, this.prayerLabel});

  /// Named in the note beneath the instructions, when known.
  final String? prayerLabel;

  @override
  ConsumerState<MatScannerScreen> createState() => _MatScannerScreenState();
}

enum _Phase {
  /// Opening the camera.
  starting,

  /// Live, looking at frames.
  scanning,

  /// A mat was seen; taking the photo that will be kept.
  found,

  /// The thirty seconds ran out.
  timedOut,

  /// This device cannot judge frames, so the person frames and taps.
  manual,

  /// The camera would not open at all.
  broken,

  /// Torn down — the scan loop checks this before touching anything.
  done,
}

class _MatScannerScreenState extends ConsumerState<MatScannerScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  /// How long the person has to get their mat in frame.
  static const int _window = 30;

  /// Roughly twice a second. Fast enough that sweeping the phone over a mat
  /// catches it, slow enough that the classifier is never the bottleneck.
  static const Duration _between = Duration(milliseconds: 420);

  /// Consecutive passing frames before the photo is taken.
  ///
  /// One is not enough. Swinging the camera across a room puts all sorts of
  /// things in frame for a fifth of a second, and a single lucky frame would
  /// confirm a prayer from a doorway. Two in a row means the phone was
  /// actually held over the mat.
  static const int _runNeeded = 2;

  CameraController? _camera;
  CameraDescription? _lens;

  _Phase _phase = _Phase.starting;
  int _left = _window;
  int _run = 0;
  bool _torch = false;
  bool _busy = false;
  String? _fault;

  Timer? _countdown;
  DateTime? _lastLook;

  /// The arrival: the card rises and the chrome fades in after it.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 640),
  )..forward();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_open());
  }

  @override
  void dispose() {
    _intro.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _countdown?.cancel();
    // Read by the frame callback and the loop, both of which can still be in
    // flight; set before the controller goes so neither touches a dead camera.
    _phase = _Phase.done;
    final CameraController? cam = _camera;
    _camera = null;
    unawaited(_shutDown(cam));
    super.dispose();
  }

  /// Leaving Layla Pro mid-scan ends the scan.
  ///
  /// iOS suspends the capture session when the app goes to the background, and
  /// a preview that resumes frozen is worse than no preview — the person would
  /// hold a still image over their mat waiting for something that can never
  /// happen. Coming back to the confirmation screen with a "Scan" button is
  /// honest about where they are.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.paused) return;
    if (!mounted || _phase == _Phase.done) return;
    Navigator.of(context).pop();
  }

  Future<void> _shutDown(CameraController? cam) async {
    if (cam == null) return;
    try {
      if (cam.value.isStreamingImages) await cam.stopImageStream();
      if (cam.value.flashMode == FlashMode.torch) {
        await cam.setFlashMode(FlashMode.off);
      }
    } on CameraException catch (e) {
      debugPrint('Layla Pro: scanner would not settle (${e.code})');
    }
    await cam.dispose();
  }

  // ── Opening ────────────────────────────────────────────────────────────

  Future<void> _open() async {
    try {
      final List<CameraDescription> lenses = await availableCameras();
      if (lenses.isEmpty) return _breakDown('This device has no camera.');

      final CameraDescription lens = lenses.firstWhere(
        (CameraDescription c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => lenses.first,
      );

      // 720p. High enough that the kept photo is a real record of the mat, low
      // enough that a frame crossing to the classifier twice a second is not
      // a burden.
      final CameraController cam = CameraController(
        lens,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.bgra8888,
      );
      await cam.initialize();
      // Left off rather than automatic: an auto flash firing into a dark room
      // at Fajr is startling, and the torch button is right there.
      await cam.setFlashMode(FlashMode.off);

      if (!mounted) {
        await _shutDown(cam);
        return;
      }
      setState(() {
        _camera = cam;
        _lens = lens;
      });

      // Nothing to scan *with* on a platform that cannot classify: every frame
      // would come back unsure, which would either never trigger or trigger on
      // the ceiling. Hand those people a shutter button instead of a scanner
      // that quietly does nothing.
      if (!await ref.read(matVisionProvider).canScan()) {
        if (mounted) setState(() => _phase = _Phase.manual);
        return;
      }
      if (mounted) _beginScan();
    } on CameraException catch (e) {
      _breakDown(
        e.code == 'CameraAccessDenied'
            ? 'Layla Pro needs the camera to scan your prayer mat.'
            : 'The camera would not open (${e.code}).',
      );
    } on Object catch (e) {
      debugPrint('Layla Pro: scanner failed to open ($e)');
      _breakDown('The camera would not open.');
    }
  }

  void _breakDown(String why) {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.broken;
      _fault = why;
    });
  }

  // ── Scanning ───────────────────────────────────────────────────────────

  void _beginScan() {
    setState(() {
      _phase = _Phase.scanning;
      _left = _window;
      _run = 0;
    });
    _lastLook = null;
    _countdown?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted || _phase != _Phase.scanning) return t.cancel();
      if (_left > 1) return setState(() => _left--);
      t.cancel();
      _ranOut();
    });

    final CameraController? cam = _camera;
    if (cam == null || cam.value.isStreamingImages) return;
    unawaited(
      cam.startImageStream(_onFrame).catchError((Object e) {
        debugPrint('Layla Pro: preview stream would not start ($e)');
        // No stream means no auto-detection, but the camera itself is fine.
        if (mounted) setState(() => _phase = _Phase.manual);
      }),
    );
  }

  /// The latest frame off the preview, kept so the photo can be that frame
  /// rather than a second capture with the system shutter.
  CameraImage? _latest;

  void _onFrame(CameraImage image) {
    _latest = image;
    if (_phase != _Phase.scanning || _busy) return;
    final DateTime now = DateTime.now();
    if (_lastLook != null && now.difference(_lastLook!) < _between) return;
    _lastLook = now;
    _busy = true;
    unawaited(_judge(image).whenComplete(() => _busy = false));
  }

  Future<void> _judge(CameraImage image) async {
    if (image.planes.isEmpty) return;
    final Plane plane = image.planes.first;
    final MatVerdict seen = await ref
        .read(matVisionProvider)
        .inspectFrame(
          MatFrame(
            bytes: plane.bytes,
            width: image.width,
            height: image.height,
            bytesPerRow: plane.bytesPerRow,
            sensorOrientation: _lens?.sensorOrientation ?? 0,
          ),
        );
    if (!mounted || _phase != _Phase.scanning) return;

    // Anything but a pass breaks the run. The count is what "hold steady"
    // actually means, so it has to reset the moment the mat leaves the frame.
    if (seen != MatVerdict.looksRight) {
      if (_run != 0) setState(() => _run = 0);
      return;
    }
    if (_run + 1 < _runNeeded) {
      setState(() => _run++);
      return;
    }
    await _keep();
  }

  /// Two good frames in a row: stop looking and take the photo that is kept.
  ///
  /// A still, not the frame that passed. The frame is raw preview data that
  /// would have to be encoded to become a file, and the still is sharper,
  /// properly exposed, and the thing the person will see if they ever look
  /// back at how they confirmed this prayer.
  /// The camera plugin's `takePicture` plays the system shutter and cannot be
  /// silenced. The preview stream has already handed over a full frame, so
  /// the photo is that frame, written out by us, turned upright for the
  /// sensor. A soft chime marks the moment instead of a shutter clack.
  Future<XFile?> _keepFrame(CameraController cam) async {
    final CameraImage? img = _latest;
    if (img == null || img.planes.isEmpty) return null;
    try {
      final Plane plane = img.planes.first;
      final Completer<ui.Image> raw = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        plane.bytes,
        img.width,
        img.height,
        ui.PixelFormat.bgra8888,
        raw.complete,
        rowBytes: plane.bytesPerRow,
      );
      final ui.Image decoded = await raw.future;
      final int turn = cam.description.sensorOrientation % 360;
      final bool sideways = turn == 90 || turn == 270;
      final ui.PictureRecorder rec = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(rec);
      final double w = sideways ? img.height.toDouble() : img.width.toDouble();
      final double h = sideways ? img.width.toDouble() : img.height.toDouble();
      canvas.translate(w / 2, h / 2);
      canvas.rotate(turn * 3.141592653589793 / 180);
      canvas.translate(-img.width / 2, -img.height / 2);
      canvas.drawImage(decoded, ui.Offset.zero, ui.Paint());
      final ui.Image upright = await rec.endRecording().toImage(
        w.toInt(),
        h.toInt(),
      );
      final ByteData? png = await upright.toByteData(
        format: ui.ImageByteFormat.png,
      );
      decoded.dispose();
      upright.dispose();
      if (png == null) return null;
      final Directory dir = await getTemporaryDirectory();
      final File file = File(
        '${dir.path}/mat-${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(png.buffer.asUint8List(), flush: true);
      return XFile(file.path, mimeType: 'image/png');
    } catch (e) {
      debugPrint('Layla Pro: could not keep the preview frame ($e)');
      return null;
    }
  }

  Future<void> _chime() async {
    try {
      final AudioPlayer player = AudioPlayer();
      await player.setAsset('assets/sounds/scan.wav');
      await player.setVolume(0.9);
      unawaited(player.play().whenComplete(player.dispose));
    } catch (e) {
      debugPrint('Layla Pro: chime failed ($e)');
    }
  }

  Future<void> _keep() async {
    final CameraController? cam = _camera;
    if (cam == null) return;

    setState(() => _phase = _Phase.found);
    _countdown?.cancel();
    unawaited(HapticFeedback.mediumImpact());

    try {
      // Keep the frame the scanner judged, before the stream stops.
      final XFile? kept = await _keepFrame(cam);
      unawaited(_chime());
      if (cam.value.isStreamingImages) await cam.stopImageStream();
      // Long enough to read "Prayer mat found" and see the frame go green.
      // Without it the screen simply vanishes and nothing explains why.
      await Future<void>.delayed(const Duration(milliseconds: 420));
      final XFile shot = kept ?? await cam.takePicture();
      if (!mounted) return;
      // Closed before `dispose` runs, so a notification arriving in the gap
      // between popping and being torn down cannot pop a second route.
      _phase = _Phase.done;
      Navigator.of(context).pop(shot);
    } on CameraException catch (e) {
      debugPrint('Layla Pro: scanner could not keep the photo (${e.code})');
      if (mounted) _breakDown('The photo could not be taken (${e.code}).');
    }
  }

  void _ranOut() {
    if (!mounted) return;
    unawaited(_stopStream());
    setState(() {
      _phase = _Phase.timedOut;
      _run = 0;
    });
  }

  Future<void> _stopStream() async {
    final CameraController? cam = _camera;
    if (cam == null || !cam.value.isStreamingImages) return;
    try {
      await cam.stopImageStream();
    } on CameraException catch (e) {
      debugPrint('Layla Pro: preview stream would not stop (${e.code})');
    }
  }

  // ── Manual capture ─────────────────────────────────────────────────────

  Future<void> _shoot() async {
    final CameraController? cam = _camera;
    if (cam == null || _busy) return;
    setState(() => _busy = true);
    try {
      final XFile? kept = await _keepFrame(cam);
      unawaited(_chime());
      await _stopStream();
      final XFile shot = kept ?? await cam.takePicture();
      if (!mounted) return;
      _phase = _Phase.done;
      Navigator.of(context).pop(shot);
    } on CameraException catch (e) {
      debugPrint('Layla Pro: manual capture failed (${e.code})');
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleTorch() async {
    final CameraController? cam = _camera;
    if (cam == null || !cam.value.isInitialized) return;
    final bool next = !_torch;
    try {
      await cam.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      if (mounted) setState(() => _torch = next);
    } on CameraException catch (e) {
      debugPrint('Layla Pro: torch unavailable (${e.code})');
    }
  }

  // ── Painting ───────────────────────────────────────────────────────────

  Color get _tone => switch (_phase) {
    _Phase.scanning => _run > 0 ? AppColors.pulseSoft : AppColors.pulse,
    _Phase.found => AppColors.emerald,
    _Phase.timedOut => AppColors.rose,
    _Phase.broken => AppColors.rose,
    _ => AppColors.mistFaint,
  };

  String get _status => switch (_phase) {
    _Phase.starting => 'Opening the camera…',
    _Phase.scanning => _run > 0 ? 'Hold steady…' : 'Looking for your mat…',
    _Phase.found => 'Prayer mat found.',
    _Phase.timedOut => 'Time ran out. Scan again, or use ⋯ to take the photo.',
    _Phase.manual => 'Frame your mat, then use ⋯ to take the photo.',
    _Phase.broken => _fault ?? 'The camera would not open.',
    _ => '',
  };

  @override
  Widget build(BuildContext context) {
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final Size screen = MediaQuery.sizeOf(context);
    final String prayer = widget.prayerLabel ?? 'This prayer';
    // Black above, the camera below: the card starts above the middle of the
    // screen and runs to the bottom, with its own controls inside it.
    final double cardTop = screen.height * 0.24;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: <Widget>[
          // ── Top bar: torch, the clock, close ─────────────────────────
          Positioned(
            top: safe.top + Insets.xs,
            left: Insets.page,
            right: Insets.page,
            child: _Enter(
              intro: _intro,
              from: 0.0,
              child: Row(
                children: <Widget>[
                  _TorchButton(on: _torch, onPressed: _toggleTorch),
                  const Spacer(),
                  _Clock(
                    seconds: _left,
                    total: _window,
                    live: _phase == _Phase.scanning,
                  ),
                  const Spacer(),
                  _RoundButton(
                    icon: Icons.close_rounded,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),

          // ── The camera, as a card that rises into place ──────────────
          Positioned(
            top: cardTop,
            left: 12,
            right: 12,
            bottom: safe.bottom > 0 ? safe.bottom - 8 : 12,
            child: AnimatedBuilder(
              animation: _intro,
              builder: (BuildContext context, Widget? child) {
                final double t = Curves.easeOutCubic.transform(_intro.value);
                return Transform.translate(
                  offset: Offset(0, (1 - t) * 90),
                  child: Transform.scale(
                    scale: 0.94 + 0.06 * t,
                    alignment: Alignment.bottomCenter,
                    child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
                  ),
                );
              },
              child: _CameraCard(
                preview: _preview,
                tone: _tone,
                status: _status,
                found: _phase == _Phase.found,
                scanning: _phase == _Phase.scanning,
                title: 'Scan your prayer mat',
                detail:
                    'Hold your phone over the mat. Layla Pro takes the photo '
                    'itself.',
                note:
                    '$prayer stays unconfirmed, and does not count toward '
                    'your streak, until the mat is scanned.',
                bottom: _controls(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The live preview, covering its box rather than letterboxed inside it,
  /// so the brackets never lie about what the camera can see.
  Widget _preview(BoxConstraints box) {
    final CameraController? cam = _camera;
    if (cam == null || !cam.value.isInitialized) {
      return const ColoredBox(color: Color(0xFF0A0F1A));
    }
    final double screen = box.maxWidth / box.maxHeight;
    double scale = cam.value.aspectRatio * screen;
    if (scale < 1) scale = 1 / scale;
    return ClipRect(
      child: Transform.scale(
        scale: scale,
        child: Center(child: CameraPreview(cam)),
      ),
    );
  }

  /// Back on the left, more on the right, inside the card. There is no
  /// shutter: the scanner takes the photo. The "more" menu holds the ways
  /// out when it cannot — scanning again, or taking the photo by hand.
  Widget _controls() {
    return Row(
      children: <Widget>[
        _RoundButton(
          icon: Icons.arrow_back_ios_new_rounded,
          dark: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
        const Spacer(),
        if (_phase == _Phase.timedOut || _phase == _Phase.broken)
          _Pill(
            label: _phase == _Phase.broken ? 'Close' : 'Scan again',
            icon: _phase == _Phase.broken
                ? Icons.close_rounded
                : Icons.refresh_rounded,
            onPressed: _phase == _Phase.broken
                ? () => Navigator.of(context).pop()
                : _beginScan,
          ),
        const Spacer(),
        _RoundButton(
          icon: Icons.more_horiz_rounded,
          dark: true,
          onPressed: _phase == _Phase.found || _busy ? null : _more,
        ),
      ],
    );
  }

  Future<void> _more() async {
    final bool canShoot =
        _phase == _Phase.scanning ||
        _phase == _Phase.manual ||
        _phase == _Phase.timedOut;
    final String? pick = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.navy,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
      ),
      builder: (BuildContext context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: Insets.sm),
            if (canShoot)
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_outlined,
                  color: AppColors.cream,
                ),
                title: Text('Take the photo myself', style: AppType.titleSm),
                subtitle: Text(
                  'If the scanner cannot see your mat.',
                  style: AppType.bodySm.copyWith(color: AppColors.mist),
                ),
                onTap: () => Navigator.of(context).pop('shoot'),
              ),
            if (_phase == _Phase.timedOut || _phase == _Phase.manual)
              ListTile(
                leading: const Icon(
                  Icons.refresh_rounded,
                  color: AppColors.cream,
                ),
                title: Text('Scan again', style: AppType.titleSm),
                onTap: () => Navigator.of(context).pop('again'),
              ),
            ListTile(
              leading: Icon(
                _torch
                    ? Icons.flashlight_off_rounded
                    : Icons.flashlight_on_rounded,
                color: AppColors.cream,
              ),
              title: Text(
                _torch ? 'Torch off' : 'Torch on',
                style: AppType.titleSm,
              ),
              onTap: () => Navigator.of(context).pop('torch'),
            ),
            const SizedBox(height: Insets.sm),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (pick) {
      case 'shoot':
        await _shoot();
      case 'again':
        _beginScan();
      case 'torch':
        await _toggleTorch();
    }
  }
}

// ── Chrome ───────────────────────────────────────────────────────────────

/// Fades and lifts a piece of chrome in, a little after the piece before it.
class _Enter extends StatelessWidget {
  const _Enter({required this.intro, required this.from, required this.child});

  final Animation<double> intro;
  final double from;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: intro,
      builder: (BuildContext context, Widget? child) {
        final double t = Curves.easeOutCubic.transform(
          ((intro.value - from) / (1 - from)).clamp(0.0, 1.0),
        );
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 14),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// The preview in a rounded card: rounded corner brackets inside it, the
/// instructions written over the top of the picture, the status under them,
/// and the buttons along the bottom. A green edge the moment it finds the mat.
class _CameraCard extends StatelessWidget {
  const _CameraCard({
    required this.preview,
    required this.tone,
    required this.status,
    required this.found,
    required this.scanning,
    required this.title,
    required this.detail,
    required this.note,
    required this.bottom,
  });

  final Widget Function(BoxConstraints) preview;
  final Color tone;
  final String status;
  final bool found;
  final bool scanning;
  final String title;
  final String detail;
  final String note;
  final Widget bottom;

  @override
  Widget build(BuildContext context) {
    const double radius = 34;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: found
              ? AppColors.emerald.withValues(alpha: 0.9)
              : Colors.white.withValues(alpha: 0.08),
          width: found ? 2 : 1,
        ),
        boxShadow: found
            ? <BoxShadow>[
                BoxShadow(
                  color: AppColors.emerald.withValues(alpha: 0.35),
                  blurRadius: 40,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 1),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints box) {
            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                preview(box),
                // A dark band at the top, so the words read over any room.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: <double>[0, 0.42, 1],
                      colors: <Color>[
                        Color(0xB3000000),
                        Color(0x00000000),
                        Color(0x99000000),
                      ],
                    ),
                  ),
                ),
                // Words at the top, buttons at the bottom, and the brackets
                // frame whatever is left between them.
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Insets.xl,
                    Insets.xl,
                    Insets.xl,
                    Insets.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        title,
                        style: AppType.displaySm.copyWith(
                          color: AppColors.cream,
                        ),
                      ),
                      const SizedBox(height: Insets.xs),
                      Text(
                        detail,
                        style: AppType.bodySm.copyWith(
                          color: Colors.white.withValues(alpha: 0.82),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: Insets.md),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 240),
                          child: Container(
                            key: ValueKey<String>(status),
                            padding: const EdgeInsets.symmetric(
                              horizontal: Insets.md,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: tone.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                _Dot(color: tone, pulse: scanning),
                                const SizedBox(width: Insets.sm),
                                Flexible(
                                  child: Text(
                                    status,
                                    style: AppType.bodySm.copyWith(
                                      color: AppColors.cream,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: CustomPaint(
                          painter: _BracketsPainter(
                            tone: found
                                ? AppColors.emerald
                                : tone == AppColors.rose
                                ? AppColors.rose
                                : AppColors.navyLine,
                            glow: found ? AppColors.emerald : AppColors.pulse,
                          ),
                        ),
                      ),
                      Text(
                        note,
                        textAlign: TextAlign.center,
                        style: AppType.bodySm.copyWith(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: Insets.md),
                      bottom,
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.pulse});

  final Color color;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withValues(alpha: pulse ? 0.7 : 0.3),
            blurRadius: 8,
          ),
        ],
      ),
    );
  }
}

/// Four rounded corner brackets, inset from the card's edge. Still: nothing
/// sweeps across the picture.
class _BracketsPainter extends CustomPainter {
  const _BracketsPainter({required this.tone, required this.glow});

  /// The stroke: Layla Pro's navy, the blue of the Home sky.
  final Color tone;

  /// A faint halo under the stroke, so navy still reads over a bright mat.
  final Color glow;

  @override
  void paint(Canvas canvas, Size size) {
    const double inset = 8;
    const double arm = 34;
    const double bend = 18;
    final Rect r = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );
    final Paint halo = Paint()
      ..color = glow.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    final Paint p = Paint()
      ..color = tone
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    for (final (Offset c, double sx, double sy) in <(Offset, double, double)>[
      (r.topLeft, 1, 1),
      (r.topRight, -1, 1),
      (r.bottomRight, -1, -1),
      (r.bottomLeft, 1, -1),
    ]) {
      // From the end of one arm, round the corner, to the end of the other.
      final Path path = Path()
        ..moveTo(c.dx + arm * sx, c.dy)
        ..lineTo(c.dx + bend * sx, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + bend * sy)
        ..lineTo(c.dx, c.dy + arm * sy);
      canvas.drawPath(path, halo);
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(_BracketsPainter old) =>
      old.tone != tone || old.glow != glow;
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.onPressed,
    this.on = false,
    this.dark = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final bool on;

  /// Over the picture: a darker, larger disc that reads against a lit room.
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: on
          ? AppColors.gold
          : dark
          ? Colors.black.withValues(alpha: 0.55)
          : Colors.white.withValues(alpha: 0.10),
      shape: dark
          ? CircleBorder(
              side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
            )
          : const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        onPressed: onPressed,
        iconSize: dark ? 22 : 20,
        padding: EdgeInsets.all(dark ? 14 : 8),
        color: on ? AppColors.midnight : Colors.white,
        icon: Icon(icon),
      ),
    );
  }
}

/// A small labelled pill for the one action a phase needs.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.gold,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.lg,
            vertical: 12,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 18, color: AppColors.midnight),
              const SizedBox(width: Insets.sm),
              Text(
                label,
                style: AppType.titleSm.copyWith(color: AppColors.midnight),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The thirty seconds, as a pill with a thin ring emptying around a clock
/// glyph. Amber under ten seconds, when it stops being information and
/// starts being a prompt.
class _Clock extends StatelessWidget {
  const _Clock({
    required this.seconds,
    required this.total,
    required this.live,
  });

  final int seconds;
  final int total;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final int m = seconds ~/ 60;
    final String s = (seconds % 60).toString().padLeft(2, '0');
    final Color tone = !live
        ? AppColors.mistFaint
        : seconds <= 10
        ? AppColors.amber
        : AppColors.cream;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 240),
      opacity: live ? 1 : 0.55,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 6, Insets.lg, 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 18,
              height: 18,
              child: CustomPaint(
                painter: _RingPainter(fraction: seconds / total, tone: tone),
              ),
            ),
            const SizedBox(width: Insets.sm),
            Text(
              '$m:$s',
              style: AppType.titleMd.copyWith(
                color: tone,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.fraction, required this.tone});

  final double fraction;
  final Color tone;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect r = (Offset.zero & size).deflate(1.5);
    canvas.drawArc(
      r,
      0,
      6.283185307179586,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = tone.withValues(alpha: 0.25),
    );
    canvas.drawArc(
      r,
      -1.5707963267948966,
      6.283185307179586 * fraction.clamp(0.0, 1.0),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = tone,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.tone != tone;
}

class _TorchButton extends StatelessWidget {
  const _TorchButton({required this.on, required this.onPressed});

  final bool on;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _RoundButton(
      icon: on ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
      on: on,
      onPressed: onPressed,
    );
  }
}
