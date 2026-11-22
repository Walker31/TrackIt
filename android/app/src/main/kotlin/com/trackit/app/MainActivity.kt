package com.trackit.app

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Passes "open with" requests to Flutter: a home-screen widget button
 * (EXTRA_ACTION) or text shared from another app, such as a bank SMS
 * shared from Messages (ACTION_SEND, text/plain).
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var pending: Map<String, String?>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pending = launchRequest(intent)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    // Asked once Flutter is ready, for the request that
                    // started the app; cleared so it isn't handled twice.
                    "takeLaunchRequest" -> {
                        result.success(pending)
                        pending = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        launchRequest(intent)?.let { channel?.invokeMethod("onRequest", it) }
    }

    private fun launchRequest(intent: Intent?): Map<String, String?>? {
        if (intent == null) return null
        intent.getStringExtra(EXTRA_ACTION)?.let { return mapOf("action" to it) }
        if (intent.action == Intent.ACTION_SEND && intent.type == "text/plain") {
            val text = intent.getStringExtra(Intent.EXTRA_TEXT) ?: return null
            return mapOf("action" to "shared_text", "text" to text)
        }
        return null
    }

    companion object {
        const val CHANNEL = "trackit/launch"
        const val EXTRA_ACTION = "com.trackit.app.ACTION"
    }
}
