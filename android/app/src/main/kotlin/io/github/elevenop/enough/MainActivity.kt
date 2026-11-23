package io.github.elevenop.enough

import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.webkit.WebView
import androidx.webkit.UserAgentMetadata
import androidx.webkit.WebSettingsCompat
import androidx.webkit.WebViewFeature
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "focusfeed/webview")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "desktopClientHints" -> result.success(applyClientHints(desktop = true))
                    "chromeClientHints" -> result.success(applyClientHints(desktop = false))
                    "setSecure" -> {
                        setSecure(call.arguments as? Boolean ?: false)
                        result.success(null)
                    }
                    "privateDns" -> result.success(readPrivateDns())
                    "openNetworkSettings" -> result.success(openNetworkSettings())
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Makes every WebView on screen report "Google Chrome" instead of
     * "Android WebView" in its User-Agent Client Hints and stops the
     * X-Requested-With header. With [desktop], also reports a desktop Linux
     * browser (Sec-CH-UA-Mobile / -Platform, navigator.userAgentData).
     * Returns a short status string for logging.
     */
    private fun applyClientHints(desktop: Boolean): String {
        val views = mutableListOf<WebView>()
        collectWebViews(window.decorView, views)
        if (views.isEmpty()) return "no-webview"
        if (!WebViewFeature.isFeatureSupported(WebViewFeature.USER_AGENT_METADATA)) {
            return "unsupported"
        }
        for (wv in views) {
            val s = wv.settings
            val current = WebSettingsCompat.getUserAgentMetadata(s)
            // Present as Google Chrome instead of "Android WebView".
            val brands = current.brandVersionList.map { b ->
                if (b.brand.contains("WebView")) {
                    UserAgentMetadata.BrandVersion.Builder()
                        .setBrand("Google Chrome")
                        .setMajorVersion(b.majorVersion)
                        .setFullVersion(b.fullVersion)
                        .build()
                } else b
            }
            val builder = UserAgentMetadata.Builder(current).setBrandVersionList(brands)
            if (desktop) {
                builder
                    .setFormFactors(listOf("Desktop"))
                    .setMobile(false)
                    .setPlatform("Linux")
                    .setPlatformVersion("")
                    .setModel("")
                    .setArchitecture("x86")
                    .setBitness(64)
            }
            WebSettingsCompat.setUserAgentMetadata(s, builder.build())
            if (WebViewFeature.isFeatureSupported(WebViewFeature.REQUESTED_WITH_HEADER_ALLOW_LIST)) {
                WebSettingsCompat.setRequestedWithHeaderOriginAllowList(s, emptySet())
            }
        }
        return "ok:${views.size}"
    }

    private fun collectWebViews(v: View, out: MutableList<WebView>) {
        if (v is WebView) out.add(v)
        if (v is ViewGroup) for (i in 0 until v.childCount) collectWebViews(v.getChildAt(i), out)
    }

    /** Blank screenshots and a hidden preview in recents. */
    private fun setSecure(on: Boolean) {
        if (on) window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        else window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        if (Build.VERSION.SDK_INT >= 33) setRecentsScreenshotEnabled(!on)
    }

    /** Current Private DNS mode and hostname, or null if Android won't say. */
    private fun readPrivateDns(): Map<String, String?>? = try {
        mapOf(
            "mode" to Settings.Global.getString(contentResolver, "private_dns_mode"),
            "specifier" to Settings.Global.getString(contentResolver, "private_dns_specifier"),
        )
    } catch (e: Exception) {
        null
    }

    private fun openNetworkSettings(): Boolean {
        for (action in listOf(Settings.ACTION_WIRELESS_SETTINGS, Settings.ACTION_SETTINGS)) {
            try {
                startActivity(Intent(action).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                return true
            } catch (e: Exception) {
            }
        }
        return false
    }
}
