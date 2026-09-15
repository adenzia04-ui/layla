import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/prefs_service.dart';
import '../domain/journey_answers.dart';

final NotifierProvider<JourneyController, JourneyAnswers> journeyProvider =
    NotifierProvider<JourneyController, JourneyAnswers>(JourneyController.new);

/// Holds the first-run answers and writes each one as it is given.
///
/// Saved on every step rather than once at the end. Someone who abandons the
/// journey halfway and comes back should not be asked their name again, and a
/// crash on step nine should not throw away the first eight.
class JourneyController extends Notifier<JourneyAnswers> {
  @override
  JourneyAnswers build() =>
      JourneyAnswers.decode(ref.watch(prefsProvider).journeyAnswers);

  void _write(JourneyAnswers next) {
    state = next;
    // Not awaited: the journey should never wait on a disk write to advance,
    // and SharedPreferences serialises writes itself.
    ref.read(prefsProvider).setJourneyAnswers(next.encode());
  }

  void setName(String value) => _write(state.copyWith(name: value.trim()));
  void setGender(String value) => _write(state.copyWith(gender: value));
  void setAvatar(String value) => _write(state.copyWith(avatar: value));
  void setAge(int value) => _write(state.copyWith(age: value));
  void setRevert(bool value) => _write(state.copyWith(revert: value));
  void setPrayersADay(int value) => _write(state.copyWith(prayersADay: value));
  void setStrugglesOnTime(bool v) => _write(state.copyWith(strugglesOnTime: v));
  void setForgetsAfterDelaying(bool v) =>
      _write(state.copyWith(forgetsAfterDelaying: v));
  void setStrugglesWithFajr(bool v) =>
      _write(state.copyWith(strugglesWithFajr: v));
  void setPhoneHours(int value) =>
      _write(state.copyWith(phoneHoursADay: value));
  void setWantsMatScan(bool v) => _write(state.copyWith(wantsMatScan: v));
  void setWantsAppPause(bool v) => _write(state.copyWith(wantsAppPause: v));
  void setRemindersAllowed(bool v) =>
      _write(state.copyWith(remindersAllowed: v));
  void setPledged(bool v) => _write(state.copyWith(pledged: v));
}
