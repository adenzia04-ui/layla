import CoreImage
import CoreML
import Flutter
import UIKit
import Vision

/// Classifies a photo on the device, so the app can tell a prayer mat from a
/// picture of the ceiling.
///
/// Apple's Vision framework, not a cloud API. The photo taken for Step 2 has
/// never left the phone — that is written into `ProofRepository` and told to
/// the user — and sending it to a server to be labelled would quietly reverse
/// that for no gain the user can see. Vision runs entirely on device, costs
/// nothing, and needs no account.
///
/// A caveat worth knowing before trusting the result: Vision's taxonomy has
/// 1303 classes and **not one of them is "rug" or "carpet"**. There is no
/// prayer-mat classifier here and none available for free. What this returns
/// is the raw label list; deciding what counts is Dart's job, and the honest
/// name for that decision is a sanity check, not recognition.
enum MatVisionBridge {
    static let channelName = "com.adenzia.layla/mat_vision"

    static func register(with controller: FlutterViewController) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: controller.binaryMessenger
        )
        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "classify":
                guard
                    let args = call.arguments as? [String: Any],
                    let path = args["path"] as? String
                else {
                    result(FlutterError(
                        code: "bad_args",
                        message: "classify needs a file path",
                        details: nil
                    ))
                    return
                }
                classify(path: path, result: result)
            case "classifyFrame":
                guard
                    let args = call.arguments as? [String: Any],
                    let bytes = args["bytes"] as? FlutterStandardTypedData,
                    let width = args["width"] as? Int,
                    let height = args["height"] as? Int,
                    let bytesPerRow = args["bytesPerRow"] as? Int
                else {
                    result(FlutterError(
                        code: "bad_args",
                        message: "classifyFrame needs bytes, width, height "
                            + "and bytesPerRow",
                        details: nil
                    ))
                    return
                }
                classifyFrame(
                    bgra: bytes.data,
                    width: width,
                    height: height,
                    bytesPerRow: bytesPerRow,
                    exifOrientation: (args["orientation"] as? Int) ?? 1,
                    result: result
                )
            case "downscale":
                guard
                    let args = call.arguments as? [String: Any],
                    let path = args["path"] as? String
                else {
                    result(FlutterError(
                        code: "bad_args",
                        message: "downscale needs a file path",
                        details: nil
                    ))
                    return
                }
                downscale(
                    path: path,
                    maxEdge: (args["maxEdge"] as? Int) ?? 640,
                    quality: (args["quality"] as? Double) ?? 0.7,
                    result: result
                )
            case "available":
                // Not "is there a bridge" but "can this build actually judge
                // a single frame". Without the zero-shot encoder or a trained
                // classifier there is only Vision's generic vocabulary, whose
                // most mat-like labels — 'floor', 'textile', 'room' — are true
                // of the whole room. A scanner leaning on those fires at a
                // doorway, so it must not run at all; the Dart side falls back
                // to a manual shutter when this is false.
                result((encoder != nil && prompts != nil) || trained != nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    /// The bundled prayer-mat classifier, if this build has one.
    ///
    /// Loaded once and kept: compiling a Core ML model is slow enough to be
    /// felt, and this runs the moment someone finishes photographing their mat.
    ///
    /// Absent by default. The model is trained from photos the user supplies —
    /// see `training/README.md` — so most builds fall back to Vision's generic
    /// labels, which can tell a floor from a face but cannot tell a prayer mat
    /// from a carpet.
    private static let trained: VNCoreMLModel? = {
        guard let url = Bundle.main.url(
            forResource: "PrayerMatClassifier", withExtension: "mlmodelc"
        ) else { return nil }
        do {
            return try VNCoreMLModel(for: MLModel(contentsOf: url))
        } catch {
            NSLog("Layla Pro: prayer-mat model present but unusable — \(error)")
            return nil
        }
    }()

    private static func trainedRequest() -> VNImageBasedRequest? {
        guard let model = trained else { return nil }
        let request = VNCoreMLRequest(model: model)
        // The photo is a whole scene, not a centred object.
        request.imageCropAndScaleOption = .scaleFill
        return request
    }

    // MARK: - Zero-shot mat check

    /// The CLIP image encoder and the prompt vectors baked at build time.
    ///
    /// Zero-shot, so it recognises prayer mats it was never shown — which is
    /// the whole point for a public app, where a classifier trained on one
    /// person's mats would reject everyone else's. Only the image encoder
    /// ships (22MB); the 85MB text encoder ran once on a Mac to turn the
    /// prompts into the numbers in mat_prompts.json.
    private struct Prompts {
        let vectors: [[Float]]
        /// The first `matCount` describe prayer mats; the rest describe
        /// carpets, floors and rooms.
        let matCount: Int
    }

    private static let encoder: MLModel? = {
        guard let url = Bundle.main.url(
            forResource: "MatEncoder", withExtension: "mlmodelc"
        ) else { return nil }
        return try? MLModel(contentsOf: url)
    }()

    private static let prompts: Prompts? = {
        guard
            let url = Bundle.main.url(forResource: "mat_prompts",
                                      withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let root = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any],
            let count = root["matPrompts"] as? Int,
            let list = root["prompts"] as? [[String: Any]]
        else { return nil }
        let vectors = list.compactMap { entry -> [Float]? in
            (entry["vector"] as? [Double])?.map { Float($0) }
        }
        guard vectors.count == list.count else { return nil }
        return Prompts(vectors: vectors, matCount: count)
    }()

    /// How much more the photo looks like a prayer mat than like a carpet.
    ///
    /// Positive means mat. Returned raw rather than as a yes/no, so the
    /// threshold lives in Dart next to its tests — it was tuned on measured
    /// data and will want revisiting as more photos arrive.
    private static func matMargin(_ cg: CGImage) -> Double? {
        guard let model = encoder, let prompts = prompts else { return nil }
        guard let buffer = pixelBuffer(from: cg, side: 256) else { return nil }
        guard
            let out = try? model.prediction(from: MLDictionaryFeatureProvider(
                dictionary: ["image": MLFeatureValue(pixelBuffer: buffer)])),
            let arr = out.featureValue(for: "final_emb_1")?.multiArrayValue
        else { return nil }

        var v = [Float](repeating: 0, count: arr.count)
        for i in 0..<arr.count { v[i] = arr[i].floatValue }
        let norm = sqrt(v.reduce(0) { $0 + $1 * $1 })
        guard norm > 0 else { return nil }
        v = v.map { $0 / norm }

        // Cosine similarity against every prompt; the answer is how far the
        // best mat description beats the best non-mat one. A margin, not an
        // absolute score, because CLIP's raw similarities drift with the image
        // and only their ordering is meaningful.
        let sims = prompts.vectors.map { p in
            zip(p, v).reduce(Float(0)) { $0 + $1.0 * $1.1 }
        }
        let bestMat = sims[0..<prompts.matCount].max() ?? 0
        let bestOther = sims[prompts.matCount...].max() ?? 0
        return Double(bestMat - bestOther)
    }

    private static func pixelBuffer(from cg: CGImage, side: Int)
        -> CVPixelBuffer? {
        var pb: CVPixelBuffer?
        CVPixelBufferCreate(nil, side, side, kCVPixelFormatType_32ARGB,
                            [kCVPixelBufferCGImageCompatibilityKey: true,
                             kCVPixelBufferCGBitmapContextCompatibilityKey: true]
                                as CFDictionary, &pb)
        guard let buffer = pb else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer), width: side,
            height: side, bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))
        return buffer
    }

    /// A smaller JPEG of the photo, for the one copy that leaves the phone.
    ///
    /// Claude is billed by the pixel — roughly (w × h) / 750 tokens — so the
    /// 1280px capture costs about 1,640 tokens where 640px costs 410. The
    /// question asked of it is "is this a prayer mat", which a 640px frame
    /// answers as well as a 1280px one.
    ///
    /// The capture itself is deliberately left alone. That photo is the
    /// person's own record of having prayed and it stays on their phone at
    /// full size; only the copy sent away is shrunk.
    private static func downscale(
        path: String,
        maxEdge: Int,
        quality: Double,
        result: @escaping FlutterResult
    ) {
        guard let image = UIImage(contentsOfFile: path) else {
            result(FlutterError(
                code: "unreadable",
                message: "could not read the photo",
                details: nil
            ))
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let longest = max(image.size.width, image.size.height)
            let scale = longest > CGFloat(maxEdge)
                ? CGFloat(maxEdge) / longest
                : 1
            let target = CGSize(
                width: (image.size.width * scale).rounded(),
                height: (image.size.height * scale).rounded()
            )

            // scale = 1 so a point is a pixel. The renderer defaults to the
            // screen's scale, which on any modern iPhone is 3 — that would
            // hand back a 1920px image and undo the whole exercise.
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = 1
            format.opaque = true

            // Drawn through UIImage rather than the CGImage, so an EXIF
            // rotation is baked in rather than lost.
            let shrunk = UIGraphicsImageRenderer(size: target, format: format)
                .image { _ in
                    image.draw(in: CGRect(origin: .zero, size: target))
                }

            guard let data = shrunk.jpegData(
                compressionQuality: CGFloat(quality)
            ) else {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "encode_failed",
                        message: "could not re-encode the photo",
                        details: nil
                    ))
                }
                return
            }
            DispatchQueue.main.async {
                result(FlutterStandardTypedData(bytes: data))
            }
        }
    }

    private static func classify(path: String, result: @escaping FlutterResult) {
        guard let image = UIImage(contentsOfFile: path),
              let cg = image.cgImage else {
            result(FlutterError(
                code: "unreadable",
                message: "could not read the photo",
                details: nil
            ))
            return
        }
        describe(cg, result: result)
    }

    // MARK: - Live frames

    /// Classifies one frame from the camera preview, which never becomes a
    /// file.
    ///
    /// The scanner looks at the picture roughly twice a second for thirty
    /// seconds. Routing that through `classify(path:)` would mean sixty JPEGs
    /// written to disk and sixty shutter sounds, because a still capture is
    /// the only way iOS hands back a file — and a scanner that clicks sixty
    /// times at 5am is not one anybody would hold up to their mat. A preview
    /// frame is silent and leaves nothing behind.
    private static func classifyFrame(
        bgra: Data,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        exifOrientation: Int,
        result: @escaping FlutterResult
    ) {
        guard let raw = image(
            fromBGRA: bgra,
            width: width,
            height: height,
            bytesPerRow: bytesPerRow
        ) else {
            result(FlutterError(
                code: "unreadable",
                message: "could not read the frame",
                details: nil
            ))
            return
        }

        // The buffer arrives in the sensor's own landscape orientation however
        // the phone is being held, and both checks care which way up it is:
        // Vision is reading a scene, and the zero-shot encoder squashes
        // whatever it is handed into a 256px square. Turning the frame upright
        // here is cheaper than teaching either of them to cope.
        let orientation = CGImagePropertyOrientation(
            rawValue: UInt32(exifOrientation)
        ) ?? .up
        describe(upright(raw, orientation: orientation) ?? raw, result: result)
    }

    /// Wraps a BGRA frame as a `CGImage` without copying the pixels.
    private static func image(
        fromBGRA bytes: Data,
        width: Int,
        height: Int,
        bytesPerRow: Int
    ) -> CGImage? {
        guard width > 0, height > 0, bytes.count >= bytesPerRow * height,
              let provider = CGDataProvider(data: bytes as CFData)
        else { return nil }

        // 32-bit little-endian with the alpha byte skipped is BGRA as it sits
        // in memory — the format `kCVPixelFormatType_32BGRA` delivers.
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(
                rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue
                    | CGBitmapInfo.byteOrder32Little.rawValue
            ),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    private static let ciContext = CIContext(options: nil)

    /// Turns a frame the right way up.
    ///
    /// Core Image rather than a hand-rolled transform on purpose: the rotation
    /// has to be right on a device nobody is watching, and `oriented(_:)` has
    /// exactly one way to be wrong where a CTM has four.
    private static func upright(
        _ cg: CGImage,
        orientation: CGImagePropertyOrientation
    ) -> CGImage? {
        if orientation == .up { return cg }
        let turned = CIImage(cgImage: cg).oriented(orientation)
        return ciContext.createCGImage(turned, from: turned.extent)
    }

    // MARK: - The check itself

    /// Runs both checks over an image and answers the channel.
    ///
    /// Shared by the still photo and the live frame so the scanner and the
    /// capture can never drift into judging the same mat differently.
    private static func describe(
        _ cg: CGImage,
        result: @escaping FlutterResult
    ) {
        // Off the main thread: classification takes long enough to drop frames,
        // and this runs while the confirmation screen is showing a spinner.
        DispatchQueue.global(qos: .userInitiated).async {
            let request = trainedRequest() ?? VNClassifyImageRequest()
            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            do {
                try handler.perform([request])
                let observations =
                    (request.results as? [VNClassificationObservation]) ?? []
                // Everything above a floor, sorted. Dart decides the rest, so
                // the rule lives in one place with the tests around it.
                var payload = observations
                    .filter { $0.confidence > 0.05 }
                    .sorted { $0.confidence > $1.confidence }
                    .prefix(40)
                    .map { ["label": $0.identifier,
                            "confidence": Double($0.confidence)] }
                // The zero-shot margin rides alongside the generic labels, so
                // a build without the encoder still answers with something.
                if let margin = matMargin(cg) {
                    payload.insert(["label": "clip_mat_margin",
                                    "confidence": margin], at: 0)
                }
                DispatchQueue.main.async { result(Array(payload)) }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "vision_failed",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            }
        }
    }
}
