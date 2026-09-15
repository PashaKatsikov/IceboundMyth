package com.iceboundmyth.iceboundmythgame

import android.app.Activity
import android.content.Intent
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// ============================================================
// MainActivity — immersive chrome + WebView file-upload bridge
// ============================================================
// Dependency-free WebView file upload: the site's <input type="file">
// triggers the WebView's file selector, which hops here over a
// MethodChannel and returns the picked content:// URIs back to the
// WebView. No file_picker dependency (gray_part_pitfalls §1).
// ============================================================
class MainActivity : FlutterActivity() {
    // [FORGE] Rotated per project. Keep in sync with
    // lib/relay/stage/portal_stage.dart -> MethodChannel('...').
    private val channelName = "myth/vault"
    private val pickRequest = 0x5C1E
    private var pendingResult: MethodChannel.Result? = null
    private var launchTapConsumed = false
    private var createdFresh = false
    private var sessionTap = false
    private var methodChannel: MethodChannel? = null
    private var lastCutout: List<Int>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createdFresh = savedInstanceState == null
        drawIntoCutout()
        hideSystemUi()
        lockSoftInput()
        listenCutout()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        launchTapConsumed = false
        createdFresh = true
        sessionTap = true
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) hideSystemUi()
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        hideSystemUi()
        // Insets are still the pre-rotation ones during the callback;
        // read them once the new layout pass has run.
        window.decorView.post { pushCutout(force = true) }
    }

    private fun hideSystemUi() {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        val controller = WindowInsetsControllerCompat(window, window.decorView)
        controller.hide(WindowInsetsCompat.Type.statusBars() or WindowInsetsCompat.Type.navigationBars())
        controller.systemBarsBehavior =
            WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
    }

    /// The theme already asks for SHORT_EDGES; setting it on the window
    /// as well keeps the behaviour if the theme is ever swapped. Without
    /// it the system letterboxes the window away from the cutout in
    /// landscape and reports zero cutout insets, which is what made the
    /// gutter collapse onto the top edge.
    private fun drawIntoCutout() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return
        val params = window.attributes
        params.layoutInDisplayCutoutMode =
            WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        window.attributes = params
    }

    /// API 30+ reports IME height through WindowInsets.Type.ime()
    /// even when the window does not resize, so we freeze the layout
    /// (ADJUST_NOTHING) and let Flutter hand a cover fraction to the
    /// page. Older APIs only learn the height from a resize, so they
    /// stay on ADJUST_RESIZE and Chromium scrolls the caret itself.
    private fun lockSoftInput() {
        window.setSoftInputMode(
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                WindowManager.LayoutParams.SOFT_INPUT_ADJUST_NOTHING
            } else {
                WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE
            },
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        methodChannel!!.setMethodCallHandler { call, result ->
                when (call.method) {
                    "pick" -> {
                        val multiple = call.argument<Boolean>("multiple") ?: false
                        val mimes = call.argument<List<String>>("mimeTypes") ?: emptyList()
                        openChooser(multiple, mimes, result)
                    }
                    "takeLaunchTap" -> result.success(takeLaunchTapUrl())
                    "launchKind" -> result.success(launchKind())
                    "cutout" -> result.success(cutoutInsets())
                    else -> result.notImplemented()
                }
            }
    }

    private fun openChooser(
        multiple: Boolean,
        mimes: List<String>,
        result: MethodChannel.Result,
    ) {
        // Resolve any abandoned request before starting a new one.
        pendingResult?.success(emptyList<String>())
        pendingResult = result

        val valid = mimes.filter { it.contains("/") }
        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, multiple)
            when {
                valid.isEmpty() -> type = "*/*"
                valid.size == 1 -> type = valid[0]
                else -> {
                    type = "*/*"
                    putExtra(Intent.EXTRA_MIME_TYPES, valid.toTypedArray())
                }
            }
        }

        try {
            startActivityForResult(Intent.createChooser(intent, null), pickRequest)
        } catch (e: Exception) {
            pendingResult = null
            result.success(emptyList<String>())
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickRequest) return

        val result = pendingResult
        pendingResult = null
        if (result == null) return

        if (resultCode != Activity.RESULT_OK || data == null) {
            result.success(emptyList<String>())
            return
        }

        val uris = ArrayList<String>()
        val clip = data.clipData
        if (clip != null) {
            for (i in 0 until clip.itemCount) {
                uris.add(clip.getItemAt(i).uri.toString())
            }
        } else {
            data.data?.let { uris.add(it.toString()) }
        }
        result.success(uris)
    }

    /// How this process was opened. `restore` / `icon` must never
    /// be treated as a push tap — Android re-delivers the last
    /// notification extras when the task is recreated.
    private fun launchKind(): String {
        if (!createdFresh && !sessionTap) return "restore"
        if (isFcmTap()) return "push"
        if (isLocalTap()) return "local"
        return "icon"
    }

    private fun isFcmTap(): Boolean {
        val extras = intent?.extras ?: return false
        return extras.containsKey("google.message_id")
            || extras.containsKey("google.sent_time")
            || extras.containsKey("gcm.message_id")
    }

    private fun isLocalTap(): Boolean {
        val action = intent?.action ?: ""
        if (action.contains("SELECT_NOTIFICATION", ignoreCase = true)) return true
        val extras = intent?.extras ?: return false
        val payload = extras.getString("payload")
        return !payload.isNullOrEmpty()
    }

    /// Display-cutout safe insets in logical pixels, ordered
    /// left/top/right/bottom for the CURRENT rotation. Android rotates
    /// these with the display, so the gutter follows the camera hole
    /// instead of pinning itself to the top edge in landscape. System
    /// bars are deliberately NOT part of this — only the cutout.
    private fun cutoutInsets(): List<Int> {
        val cutout = ViewCompat.getRootWindowInsets(window.decorView)?.displayCutout
            ?: return listOf(0, 0, 0, 0)
        val density = resources.displayMetrics.density.let { if (it > 0f) it else 1f }
        fun dp(px: Int): Int = Math.ceil(px / density.toDouble()).toInt()
        return listOf(
            dp(cutout.safeInsetLeft),
            dp(cutout.safeInsetTop),
            dp(cutout.safeInsetRight),
            dp(cutout.safeInsetBottom),
        )
    }

    private fun listenCutout() {
        window.decorView.viewTreeObserver.addOnGlobalLayoutListener { pushCutout(force = false) }
    }

    private fun pushCutout(force: Boolean) {
        val next = cutoutInsets()
        if (!force && next == lastCutout) return
        lastCutout = next
        methodChannel?.invokeMethod("cutout", next)
    }

    /// URL from an FCM notification tap on a killed process.
    /// The data payload is copied onto the launch Intent extras;
    /// `google.message_id` / `google.sent_time` mark a real push
    /// tap as opposed to a cold launcher icon open.
    private fun takeLaunchTapUrl(): String? {
        if (launchTapConsumed) return null
        if (!isFcmTap()) return null
        val extras = intent?.extras ?: return null
        val url = extras.getString("url")
            ?: extras.getString("link")
            ?: extras.getString("click_url")
            ?: extras.getString("deeplink")
        if (url.isNullOrEmpty() || !url.startsWith("http")) return null
        launchTapConsumed = true
        return url
    }
}
