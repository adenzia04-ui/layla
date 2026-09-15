import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../domain/dua_catalogue.dart';
import '../domain/dua_pages.dart';

/// Shows the section as it is printed in the book.
///
/// The pages are images of the source rather than re-typed text. That is the
/// point: the Arabic is the book's own setting, fully vocalized, with its
/// transliteration, translation and references intact — nothing is
/// transcribed, so nothing can be transcribed wrongly.
class DuaPageScreen extends StatefulWidget {
  const DuaPageScreen({super.key, required this.section});

  final DuaSection section;

  @override
  State<DuaPageScreen> createState() => _DuaPageScreenState();
}

class _DuaPageScreenState extends State<DuaPageScreen> {
  late final PageRange _range =
      duaSectionPages[widget.section.number] ??
      (start: widget.section.page, end: widget.section.page);
  late final PageController _controller = PageController();
  late int _current = _range.start;

  int get _count => _range.end - _range.start + 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.midnight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(widget.section.title, style: AppType.titleSm),
            Text(
              _count == 1
                  ? 'Page $_current'
                  : 'Page $_current of ${_range.start}–${_range.end}',
              style: AppType.bodySm.copyWith(
                fontSize: 11,
                color: AppColors.mistFaint,
              ),
            ),
          ],
        ),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: _count,
        onPageChanged: (int i) => setState(() => _current = _range.start + i),
        itemBuilder: (BuildContext context, int i) {
          final int printed = _range.start + i;
          return InteractiveViewer(
            // The Arabic is small on a phone at full-page scale, so it has to
            // be zoomable — this is a page of a book, not a card.
            minScale: 1,
            maxScale: 4,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(Insets.md),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.md),
                  child: Image.asset(
                    'assets/duas/p$printed.jpg',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Text(
                      'Page $printed is not bundled.',
                      style: AppType.bodySm.copyWith(color: AppColors.mist),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: _count == 1
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: Insets.md),
                child: Text(
                  'Swipe for the rest of this section',
                  textAlign: TextAlign.center,
                  style: AppType.bodySm.copyWith(
                    fontSize: 11,
                    color: AppColors.mistFaint,
                  ),
                ),
              ),
            ),
    );
  }
}
