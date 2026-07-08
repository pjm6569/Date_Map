package com.example.date_map

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "date_map/external_intent"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "launchIntentUrl" -> {
                        val url = call.argument<String>("url")
                        if (url == null) {
                            result.error("NO_URL", "url is null", null)
                        } else {
                            result.success(launchIntentUrl(url))
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /// intent:// 또는 커스텀 스킴 URL 을 외부 앱으로 실행. 성공 여부를 반환한다.
    /// intent:// 는 Intent.parseUri 로 파싱해야 실제 스킴(nmap://)·패키지로 열린다.
    private fun launchIntentUrl(url: String): Boolean {
        return try {
            val intent = if (url.startsWith("intent://")) {
                Intent.parseUri(url, Intent.URI_INTENT_SCHEME)
            } else {
                Intent(Intent.ACTION_VIEW, Uri.parse(url))
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

            try {
                startActivity(intent)
                true
            } catch (e: ActivityNotFoundException) {
                // 앱이 없으면 intent 의 fallback URL(브라우저 링크)로, 없으면 마켓으로.
                val fallback = intent.getStringExtra("browser_fallback_url")
                if (fallback != null) {
                    startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(fallback)))
                    return true
                }
                val pkg = intent.`package`
                if (pkg != null) {
                    startActivity(
                        Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$pkg"))
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    )
                    return true
                }
                false
            }
        } catch (e: Exception) {
            false
        }
    }
}
