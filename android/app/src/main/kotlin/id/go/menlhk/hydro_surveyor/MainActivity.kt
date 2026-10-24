package id.go.menlhk.hydro_surveyor

import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {

    private val channelName = "hydro_surveyor/video_frames"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->

            if (call.method != "frameAt") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val path = call.argument<String>("path")
            val timeMs = call.argument<Number>("timeMs")?.toLong() ?: 0L
            val maxWidth = (
                call.argument<Number>("maxWidth")?.toInt() ?: 320
            ).coerceIn(80, 1280)

            val quality = (
                call.argument<Number>("quality")?.toInt() ?: 85
            ).coerceIn(30, 100)

            if (path.isNullOrBlank()) {
                result.error(
                    "INVALID_PATH",
                    "Path video kosong.",
                    null
                )
                return@setMethodCallHandler
            }

            Thread {
                var retriever: MediaMetadataRetriever? = null
                var bitmap: Bitmap? = null
                var scaledBitmap: Bitmap? = null

                try {
                    retriever = MediaMetadataRetriever()
                    retriever.setDataSource(path)

                    bitmap = if (
                        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1
                    ) {
                        retriever.getScaledFrameAtTime(
                            timeMs * 1000L,
                            MediaMetadataRetriever.OPTION_CLOSEST,
                            maxWidth,
                            maxWidth * 2
                        )
                    } else {
                        retriever.getFrameAtTime(
                            timeMs * 1000L,
                            MediaMetadataRetriever.OPTION_CLOSEST
                        )
                    }

                    if (bitmap == null) {
                        throw IllegalStateException(
                            "Frame pada ${timeMs} ms tidak ditemukan."
                        )
                    }

                    val sourceBitmap = bitmap

                    scaledBitmap = if (sourceBitmap.width > maxWidth) {
                        val targetHeight = (
                            sourceBitmap.height.toDouble() *
                                maxWidth / sourceBitmap.width
                        ).toInt().coerceAtLeast(1)

                        Bitmap.createScaledBitmap(
                            sourceBitmap,
                            maxWidth,
                            targetHeight,
                            true
                        )
                    } else {
                        sourceBitmap
                    }

                    val output = ByteArrayOutputStream()

                    scaledBitmap.compress(
                        Bitmap.CompressFormat.JPEG,
                        quality,
                        output
                    )

                    val bytes = output.toByteArray()

                    runOnUiThread {
                        result.success(bytes)
                    }

                } catch (e: Exception) {
                    runOnUiThread {
                        result.error(
                            "FRAME_EXTRACTION_FAILED",
                            e.message ?: "Gagal mengambil frame video.",
                            null
                        )
                    }
                } finally {
                    try {
                        if (
                            scaledBitmap != null &&
                            scaledBitmap !== bitmap &&
                            !scaledBitmap.isRecycled
                        ) {
                            scaledBitmap.recycle()
                        }
                    } catch (_: Exception) {
                    }

                    try {
                        if (bitmap != null && !bitmap.isRecycled) {
                            bitmap.recycle()
                        }
                    } catch (_: Exception) {
                    }

                    try {
                        retriever?.release()
                    } catch (_: Exception) {
                    }
                }
            }.start()
        }
    }
}
