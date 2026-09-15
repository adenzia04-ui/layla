# Training the prayer-mat classifier

Apple's Create ML, run locally. Nothing is uploaded, nothing is paid for, and
no account is involved. The result is a Core ML model bundled into the app and
run through the Vision bridge that already exists.

## What to put here

    training/prayer_mat/
      mat/       photos of prayer mats
      not_mat/   photos of everything else

**mat/** — prayer mats, laid out as you would pray on them. Vary it: different
mats in the house, different rooms, different times of day, close up and from
standing height, straight on and at an angle. If the app should accept a mat
in dim light before Fajr, dim photos have to be in here.

**not_mat/** — the things it must *reject*, and this matters more than it
sounds. A classifier trained on mats against random internet pictures learns
"indoor floor" and passes your living-room carpet. So this folder wants the
near misses: plain carpet, a rug that is not a prayer mat, bare floor, a
towel, a bedsheet, a sofa, walls, the ceiling.

Roughly **60–150 per folder**, and keep the two counts close — a lopsided set
teaches the model to guess the bigger class. Ordinary phone photos are right;
they are what it will see in use.

## Then

    dart run tool/train_mat_model.dart

It trains, prints the accuracy, and writes the model into the iOS project. If
the numbers are poor it says so rather than shipping a model that guesses.
