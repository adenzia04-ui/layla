import CreateML
import Foundation

// Trains the prayer-mat classifier on this machine and writes a Core ML model
// into the iOS project. Apple's transfer learning, so a few dozen photos per
// class is enough — it is adapting a vision model, not learning sight.

let root = URL(fileURLWithPath: CommandLine.arguments[1])
let data = root.appendingPathComponent("training/prayer_mat")
let out = root.appendingPathComponent("ios/Runner/PrayerMatClassifier.mlmodel")

func photos(_ folder: String) -> [URL] {
    let dir = data.appendingPathComponent(folder)
    let all = (try? FileManager.default.contentsOfDirectory(
        at: dir, includingPropertiesForKeys: nil)) ?? []
    return all.filter {
        ["jpg", "jpeg", "png", "heic"].contains($0.pathExtension.lowercased())
    }
}

let mats = photos("mat")
let others = photos("not_mat")
print("  mat: \(mats.count) photos   not_mat: \(others.count) photos")

guard mats.count >= 20, others.count >= 20 else {
    print("""
      Not enough to train on. Create ML wants at least 20 per folder and
      really wants 60+. Add more photos and run this again — a model trained
      on a handful will look like it works and fail on your actual mat.
    """)
    exit(1)
}

// A lopsided set teaches the model to guess the bigger class and still score
// well, so say so rather than quietly training on it.
let ratio = Double(max(mats.count, others.count)) / Double(min(mats.count, others.count))
if ratio > 1.6 {
    print("""
      Warning: the folders are \(String(format: "%.1f", ratio))x apart. Even
      up the counts, or the model learns to answer with whichever class you
      gave it more of.
    """)
}

let job = try MLImageClassifier(
    trainingData: .labeledDirectories(at: data),
    parameters: MLImageClassifier.ModelParameters(
        validation: .split(strategy: .automatic),
        // Flips and rotations only. Someone photographing a mat holds the
        // phone at whatever angle; they do not recolour it.
        augmentation: [.flip, .rotation],
        algorithm: .transferLearning(
            featureExtractor: .scenePrint(revision: 2),
            classifier: .logisticRegressor
        )
    )
)

let train = (1.0 - job.trainingMetrics.classificationError) * 100
let valid = (1.0 - job.validationMetrics.classificationError) * 100
print(String(format: "  training accuracy %.1f%%   validation accuracy %.1f%%",
             train, valid))

// Validation is the honest number: training accuracy only says it memorised
// the photos it was shown.
if valid.isNaN {
    print("  No validation split was possible — too few photos. Add more.")
    exit(1)
}
if valid < 80 {
    print("""
      Validation accuracy is \(String(format: "%.1f", valid))%, which is too
      low to ship. It would reject real mats and accept the sofa. Usually this
      means not_mat/ is missing the near misses — plain carpet, a rug, bare
      floor. Nothing was written.
    """)
    exit(1)
}

try job.write(to: out, metadata: MLModelMetadata(
    author: "Layla",
    shortDescription: "Prayer mat vs not, for the Step 2 photo check.",
    version: "1.0"
))
print("  wrote \(out.path)")
