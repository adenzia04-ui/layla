import 'package:flutter_test/flutter_test.dart';
import 'package:noor/features/prayer_lock/domain/mat_check.dart';

List<VisionLabel> labels(Map<String, double> m) => <VisionLabel>[
  for (final MapEntry<String, double> e in m.entries)
    VisionLabel(e.key, e.value),
];

void main() {
  test('fabric on a floor passes', () {
    expect(
      MatCheck.decide(
        labels(<String, double>{'textile': 0.62, 'pattern': 0.3}),
      ),
      MatVerdict.looksRight,
    );
  });

  test('a selfie is rejected', () {
    expect(
      MatCheck.decide(labels(<String, double>{'people': 0.91, 'face': 0.88})),
      MatVerdict.looksWrong,
    );
  });

  test('the sky is rejected', () {
    expect(
      MatCheck.decide(labels(<String, double>{'sky': 0.83, 'cloud': 0.7})),
      MatVerdict.looksWrong,
    );
  });

  test('a contradiction outranks a weak supporting label', () {
    // Someone photographing themselves on a mat: the person dominates, so the
    // photo is of the person.
    expect(
      MatCheck.decide(
        labels(<String, double>{'people': 0.80, 'textile': 0.14}),
      ),
      MatVerdict.looksWrong,
    );
  });

  test('nothing recognisable is unsure, not a failure', () {
    expect(
      MatCheck.decide(labels(<String, double>{'unknown_thing': 0.9})),
      MatVerdict.unsure,
    );
    expect(MatCheck.decide(<VisionLabel>[]), MatVerdict.unsure);
  });

  test('a faint supporting label is not enough on its own', () {
    expect(
      MatCheck.decide(labels(<String, double>{'textile': 0.03})),
      MatVerdict.unsure,
    );
  });

  group('the zero-shot margin', () {
    // Numbers from the measurement on 53 mats and 22 carpets.
    test('a typical prayer mat passes', () {
      expect(
        MatCheck.decide(labels(<String, double>{'clip_mat_margin': 0.053})),
        MatVerdict.looksRight,
      );
    });

    test('the weakest mat in the measured set still passes', () {
      // -0.0258 was the lowest-scoring real prayer mat. The threshold sits
      // below it on purpose.
      expect(
        MatCheck.decide(labels(<String, double>{'clip_mat_margin': -0.0258})),
        MatVerdict.looksRight,
      );
    });

    test('a typical carpet is rejected', () {
      expect(
        MatCheck.decide(labels(<String, double>{'clip_mat_margin': -0.069})),
        MatVerdict.looksWrong,
      );
    });

    test('it answers before the generic vocabulary', () {
      // Vision also reports 'textile' for a carpet, which the fallback would
      // happily accept. The measured signal has to win.
      expect(
        MatCheck.decide(
          labels(<String, double>{'clip_mat_margin': -0.12, 'textile': 0.8}),
        ),
        MatVerdict.looksWrong,
      );
    });

    test('without the encoder it falls back to the generic labels', () {
      expect(
        MatCheck.decide(labels(<String, double>{'textile': 0.62})),
        MatVerdict.looksRight,
      );
    });
  });

  group('when to ask Claude', () {
    // The band was measured: outside it, all 64 photos were judged correctly
    // on device. Inside it the two groups interleave.
    test('a confident mat is settled on the phone', () {
      expect(MatCheck.needsSecondOpinion(0.053), isFalse);
      expect(MatCheck.needsSecondOpinion(0.136), isFalse);
    });

    test('a confident carpet is settled on the phone', () {
      expect(MatCheck.needsSecondOpinion(-0.069), isFalse);
      expect(MatCheck.needsSecondOpinion(-0.131), isFalse);
    });

    test('the overlap is escalated', () {
      // -0.0258 was a real prayer mat, +0.0016 the best-scoring carpet. Both
      // sit where the margin has stopped meaning anything.
      expect(MatCheck.needsSecondOpinion(-0.0258), isTrue);
      expect(MatCheck.needsSecondOpinion(0.0016), isTrue);
      expect(MatCheck.needsSecondOpinion(-0.02), isTrue);
    });

    test('no margin means no encoder, so there is nothing to escalate on', () {
      expect(MatCheck.needsSecondOpinion(null), isFalse);
    });

    test('the margin is read back out of the label list', () {
      expect(
        MatCheck.marginOf(labels(<String, double>{'clip_mat_margin': -0.02})),
        -0.02,
      );
      expect(
        MatCheck.marginOf(labels(<String, double>{'textile': 0.6})),
        isNull,
      );
    });
  });

  group('the trained classifier, when it is bundled', () {
    test('a confident mat passes', () {
      expect(
        MatCheck.decide(labels(<String, double>{'mat': 0.94})),
        MatVerdict.looksRight,
      );
    });

    test('a confident not_mat is rejected — and this is the trap', () {
      // _matches splits on underscores, so 'not_mat' yields ['not', 'mat'] and
      // 'mat' is in the accept list. Handled before the vocabulary, the model
      // saying "definitely not a prayer mat" would have read as a pass.
      expect(
        MatCheck.decide(labels(<String, double>{'not_mat': 0.97})),
        MatVerdict.looksWrong,
      );
    });

    test('a hesitant model does not block anyone', () {
      expect(
        MatCheck.decide(labels(<String, double>{'not_mat': 0.51})),
        MatVerdict.unsure,
      );
    });

    test('it outranks the generic labels shipped alongside it', () {
      expect(
        MatCheck.decide(
          labels(<String, double>{'not_mat': 0.88, 'textile': 0.7}),
        ),
        MatVerdict.looksWrong,
      );
    });
  });

  group('substring matching would have been a disaster', () {
    // Vision really does ship these identifiers. 'rug' sits inside 'arugula'
    // and 'rugby'; 'mat' inside 'matches', 'matzo' and 'material'. A contains()
    // check would let a salad confirm a prayer.
    test('arugula is not a rug', () {
      expect(
        MatCheck.decide(labels(<String, double>{'arugula': 0.95})),
        isNot(MatVerdict.looksRight),
      );
    });

    test('rugby is not a rug', () {
      expect(
        MatCheck.decide(labels(<String, double>{'rugby': 0.95})),
        isNot(MatVerdict.looksRight),
      );
    });

    test('matzo is not a mat', () {
      expect(
        MatCheck.decide(labels(<String, double>{'matzo': 0.95})),
        isNot(MatVerdict.looksRight),
      );
    });

    test('but a compound label still matches on its parts', () {
      expect(
        MatCheck.decide(labels(<String, double>{'prayer_mat': 0.5})),
        MatVerdict.looksRight,
      );
    });
  });

  group('a live frame is held to a stricter standard than a photo', () {
    test('a near-zero scene passes as a photo but not as a frame', () {
      // The exact complaint that prompted the split: a bag, a desk, a doorway
      // is neither mat nor carpet, so the margin lands near zero — miles above
      // the photo threshold of -0.045.
      final List<VisionLabel> nothingInParticular = labels(<String, double>{
        'clip_mat_margin': 0.0,
      });
      expect(MatCheck.decide(nothingInParticular), MatVerdict.looksRight);
      expect(MatCheck.decideFrame(nothingInParticular), MatVerdict.looksWrong);
    });

    test('a mat that scores well still passes', () {
      // +0.053 was the median of the 53 measured mats.
      expect(
        MatCheck.decideFrame(
          labels(<String, double>{'clip_mat_margin': 0.053}),
        ),
        MatVerdict.looksRight,
      );
    });

    test('the best measured carpet is rejected', () {
      // The 22 carpets topped out at +0.002.
      expect(
        MatCheck.decideFrame(
          labels(<String, double>{'clip_mat_margin': 0.002}),
        ),
        MatVerdict.looksWrong,
      );
    });

    test('a confident contradiction is rejected whatever the margin says', () {
      // decide() returns on the margin before it ever reads these, which is
      // how a screen could score near zero and confirm a prayer.
      final List<VisionLabel> aTelevision = labels(<String, double>{
        'clip_mat_margin': 0.9,
        'television': 0.88,
      });
      expect(MatCheck.decide(aTelevision), MatVerdict.looksRight);
      expect(MatCheck.decideFrame(aTelevision), MatVerdict.looksWrong);
    });

    test('generic labels alone never fire the scanner', () {
      // 'floor' and 'textile' are true of an entire room.
      expect(
        MatCheck.decideFrame(
          labels(<String, double>{'floor': 0.9, 'textile': 0.8}),
        ),
        MatVerdict.unsure,
      );
    });

    test('an empty label list is not a mat', () {
      expect(MatCheck.decideFrame(<VisionLabel>[]), MatVerdict.unsure);
    });

    test('the trained classifier needs more confidence per frame', () {
      // 0.7 is enough for a photo, not for one frame of sixty.
      expect(
        MatCheck.decide(labels(<String, double>{'mat': 0.7})),
        MatVerdict.looksRight,
      );
      expect(
        MatCheck.decideFrame(labels(<String, double>{'mat': 0.7})),
        MatVerdict.unsure,
      );
      expect(
        MatCheck.decideFrame(labels(<String, double>{'mat': 0.9})),
        MatVerdict.looksRight,
      );
    });
  });
}
