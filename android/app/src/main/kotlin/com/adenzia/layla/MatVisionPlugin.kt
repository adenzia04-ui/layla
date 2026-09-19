package com.adenzia.layla

import android.app.Activity
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.util.Log
import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.nio.FloatBuffer
import org.json.JSONObject
import kotlin.math.max
import kotlin.math.sqrt

/**
 * The prayer-mat check, on Android.
 *
 * The iPhone has judged mat photos since the feature shipped; Android never
 * has. `MatVision.canScan` asks this channel whether the phone can judge a
 * frame, Android had no implementation, and so the answer was always no — the
 * scanner opened, never fired on its own, and fell back to a manual shutter.
 * Reported, reasonably, as "the camera does not scan by itself".
 *
 * Same model, same maths, same numbers. iOS runs Apple's MobileCLIP-S0 image
 * encoder through CoreML; this runs the same encoder through ONNX Runtime, and
 * both score against the identical prompt vectors in `mat_prompts.json`, which
 * were produced once on a Mac by the text encoder that never ships. So the
 * margin a photo scores here is the margin it would score on an iPhone, and
 * the thresholds in `MatCheck` — tuned on 53 mats and 22 carpets — mean the
 * same thing on both.
 *
 * Zero-shot on purpose: it recognises mats it was never shown, which is what a
 * public app needs. A classifier trained on one person's mats would reject
 * everyone else's.
 */
object MatVisionPlugin {

    private const val TAG = "LaylaMatVision"
    private const val CHANNEL = "com.adenzia.layla/mat_vision"

    /** What the encoder wants, and what iOS hands it. */
    private const val SIDE = 256

    /** The label the Dart side reads the margin out of. */
    private const val MARGIN_LABEL = "clip_mat_margin"

    private var env: OrtEnvironment? = null
    private var session: OrtSession? = null
    private var matVectors: List<FloatArray> = emptyList()
    private var otherVectors: List<FloatArray> = emptyList()
    private var loadFailed = false

    fun register(activity: Activity, engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result -> handle(activity, call, result) }
    }

    private fun handle(
        activity: Activity,
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        when (call.method) {
            "available" -> result.success(load(activity))

            "classify" -> {
                val path = call.argument<String>("path")
                if (path == null || !load(activity)) {
                    result.success(emptyList<Map<String, Any?>>())
                    return
                }
                result.success(labelsFor(decodeFile(path)))
            }

            "classifyFrame" -> {
                if (!load(activity)) {
                    result.success(emptyList<Map<String, Any?>>())
                    return
                }
                result.success(labelsFor(decodeFrame(call)))
            }

            else -> result.notImplemented()
        }
    }

    /**
     * Opens the encoder once, and never tries again if it will not open.
     *
     * A failure here is not an error the person should see. It means the
     * scanner falls back to the manual shutter, which is the behaviour Android
     * had all along.
     */
    @Synchronized
    private fun load(activity: Activity): Boolean {
        if (session != null) return true
        if (loadFailed) return false
        return try {
            val bytes = activity.assets.open("mat_encoder.onnx").use { it.readBytes() }
            val environment = OrtEnvironment.getEnvironment()
            val opts = OrtSession.SessionOptions().apply {
                // One thread. This runs twice a second behind a live preview;
                // taking every core would cost more in dropped frames than it
                // buys in latency.
                setIntraOpNumThreads(1)
                setOptimizationLevel(OrtSession.SessionOptions.OptLevel.ALL_OPT)
            }
            session = environment.createSession(bytes, opts)
            env = environment
            readPrompts(activity)
            matVectors.isNotEmpty() && otherVectors.isNotEmpty()
        } catch (error: Throwable) {
            Log.w(TAG, "encoder would not load", error)
            loadFailed = true
            session = null
            false
        }
    }

    /**
     * The prompt vectors, and which of them describe a prayer mat.
     *
     * The same file the iPhone reads. `matPrompts` is how many of the list
     * describe mats; everything after that describes carpets, floors and
     * rooms, and the margin is how far the best of the first beats the best of
     * the rest.
     */
    private fun readPrompts(activity: Activity) {
        val raw = activity.assets.open("mat_prompts.json").use {
            it.readBytes().toString(Charsets.UTF_8)
        }
        val root = JSONObject(raw)
        val matCount = root.getInt("matPrompts")
        val list = root.getJSONArray("prompts")
        val all = ArrayList<FloatArray>(list.length())
        for (i in 0 until list.length()) {
            val vec = list.getJSONObject(i).getJSONArray("vector")
            val v = FloatArray(vec.length())
            for (j in 0 until vec.length()) v[j] = vec.getDouble(j).toFloat()
            all.add(v)
        }
        matVectors = all.take(matCount)
        otherVectors = all.drop(matCount)
    }

    /**
     * One label, carrying the margin, or nothing.
     *
     * Deliberately not a verdict. The threshold lives in Dart beside its
     * tests, where it was tuned on measured photos and will want revisiting as
     * more arrive; a number crossing the bridge keeps both platforms answering
     * to the same one.
     */
    private fun labelsFor(bitmap: Bitmap?): List<Map<String, Any?>> {
        if (bitmap == null) return emptyList()
        val margin = try {
            margin(bitmap)
        } catch (error: Throwable) {
            Log.w(TAG, "could not score the frame", error)
            null
        } finally {
            bitmap.recycle()
        }
        return if (margin == null) {
            emptyList()
        } else {
            listOf(mapOf("label" to MARGIN_LABEL, "confidence" to margin))
        }
    }

    private fun margin(bitmap: Bitmap): Double? {
        val ort = env ?: return null
        val run = session ?: return null

        val scaled = Bitmap.createScaledBitmap(bitmap, SIDE, SIDE, true)
        val input = FloatBuffer.allocate(3 * SIDE * SIDE)
        val pixels = IntArray(SIDE * SIDE)
        scaled.getPixels(pixels, 0, SIDE, 0, 0, SIDE, SIDE)
        if (scaled !== bitmap) scaled.recycle()

        // NCHW, and 0..1 rather than the usual CLIP mean/std: MobileCLIP's own
        // preprocessing does not normalise, and the CoreML build has the same
        // scaling baked in, so both phones feed the encoder the same numbers.
        val plane = SIDE * SIDE
        for (i in pixels.indices) {
            val p = pixels[i]
            input.put(i, ((p shr 16) and 0xFF) / 255f)
            input.put(plane + i, ((p shr 8) and 0xFF) / 255f)
            input.put(2 * plane + i, (p and 0xFF) / 255f)
        }

        // Read from the session rather than hardcoded: this is an export, and
        // a renamed input is the kind of thing that changes between them.
        val inputName = run.inputNames.first()
        val outputName = run.outputNames.first()

        val shape = longArrayOf(1, 3, SIDE.toLong(), SIDE.toLong())
        OnnxTensor.createTensor(ort, input, shape).use { tensor ->
            run.run(mapOf(inputName to tensor)).use { out ->
                val value = out.get(outputName).orElse(null) ?: return null
                @Suppress("UNCHECKED_CAST")
                val embedding = (value.value as? Array<FloatArray>)?.firstOrNull()
                    ?: return null
                return marginOf(embedding)
            }
        }
    }

    /**
     * Cosine similarity against every prompt, and the gap between the best mat
     * and the best not-a-mat.
     *
     * A margin rather than an absolute score, because CLIP's raw similarities
     * drift with the image and only their ordering means anything.
     */
    private fun marginOf(embedding: FloatArray): Double? {
        var norm = 0f
        for (x in embedding) norm += x * x
        norm = sqrt(norm)
        if (norm <= 0f) return null
        val unit = FloatArray(embedding.size) { embedding[it] / norm }

        fun best(vectors: List<FloatArray>): Float {
            var top = -Float.MAX_VALUE
            for (v in vectors) {
                if (v.size != unit.size) continue
                var dot = 0f
                for (i in unit.indices) dot += v[i] * unit[i]
                top = max(top, dot)
            }
            return top
        }

        val mat = best(matVectors)
        val other = best(otherVectors)
        if (mat == -Float.MAX_VALUE || other == -Float.MAX_VALUE) return null
        return (mat - other).toDouble()
    }

    private fun decodeFile(path: String): Bitmap? = try {
        BitmapFactory.decodeFile(path)
    } catch (error: Throwable) {
        Log.w(TAG, "could not read $path", error)
        null
    }

    /**
     * One live preview frame, as the camera plugin hands it over.
     *
     * Two shapes arrive. iOS sends a single BGRA plane; Android's camera gives
     * YUV420 in three, and the luminance plane on its own is a greyscale
     * picture — enough to see shape, blind to the colour that separates a
     * prayer mat from the floor it is lying on. So the chroma planes come
     * across too when they exist, and this puts them back together.
     */
    private fun decodeFrame(call: MethodCall): Bitmap? {
        val y = call.argument<ByteArray>("y") ?: return null
        val width = call.argument<Int>("width") ?: return null
        val height = call.argument<Int>("height") ?: return null
        val yRowStride = call.argument<Int>("yRowStride") ?: width
        val rotation = call.argument<Int>("rotation") ?: 0

        val u = call.argument<ByteArray>("u")
        val v = call.argument<ByteArray>("v")
        val uvRowStride = call.argument<Int>("uvRowStride") ?: 0
        val uvPixelStride = call.argument<Int>("uvPixelStride") ?: 1

        val pixels = IntArray(width * height)
        if (u != null && v != null && uvRowStride > 0) {
            yuvToRgb(y, u, v, width, height, yRowStride, uvRowStride, uvPixelStride, pixels)
        } else {
            greyToRgb(y, width, height, yRowStride, pixels)
        }

        val bitmap = Bitmap.createBitmap(pixels, width, height, Bitmap.Config.ARGB_8888)
        if (rotation % 360 == 0) return bitmap
        val matrix = Matrix().apply { postRotate(rotation.toFloat()) }
        val turned = Bitmap.createBitmap(bitmap, 0, 0, width, height, matrix, true)
        if (turned !== bitmap) bitmap.recycle()
        return turned
    }

    private fun yuvToRgb(
        y: ByteArray,
        u: ByteArray,
        v: ByteArray,
        width: Int,
        height: Int,
        yRowStride: Int,
        uvRowStride: Int,
        uvPixelStride: Int,
        out: IntArray,
    ) {
        for (row in 0 until height) {
            val yRow = row * yRowStride
            val uvRow = (row / 2) * uvRowStride
            for (col in 0 until width) {
                val yi = yRow + col
                if (yi >= y.size) continue
                val uvIndex = uvRow + (col / 2) * uvPixelStride
                if (uvIndex >= u.size || uvIndex >= v.size) continue

                val yy = (y[yi].toInt() and 0xFF) - 16
                val uu = (u[uvIndex].toInt() and 0xFF) - 128
                val vv = (v[uvIndex].toInt() and 0xFF) - 128

                val c = 1.164f * yy
                val r = (c + 1.596f * vv).toInt().coerceIn(0, 255)
                val g = (c - 0.392f * uu - 0.813f * vv).toInt().coerceIn(0, 255)
                val b = (c + 2.017f * uu).toInt().coerceIn(0, 255)
                out[row * width + col] = (0xFF shl 24) or (r shl 16) or (g shl 8) or b
            }
        }
    }

    private fun greyToRgb(
        y: ByteArray,
        width: Int,
        height: Int,
        yRowStride: Int,
        out: IntArray,
    ) {
        for (row in 0 until height) {
            val yRow = row * yRowStride
            for (col in 0 until width) {
                val i = yRow + col
                if (i >= y.size) continue
                val g = y[i].toInt() and 0xFF
                out[row * width + col] = (0xFF shl 24) or (g shl 16) or (g shl 8) or g
            }
        }
    }
}
