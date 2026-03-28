package com.shield.myfoodrx

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import me.leolin.shortcutbadger.ShortcutBadger

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BADGE_CHANNEL,
        ).setMethodCallHandler { call, result ->
            if (call.method != "setBadge") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val args = call.arguments as? Map<*, *>
            val raw = args?.get("count")
            val count = when (raw) {
                is Int -> raw
                is Number -> raw.toInt()
                else -> null
            }
            if (count == null) {
                result.error(
                    "BAD_ARGS",
                    "Missing or invalid 'count'",
                    null,
                )
                return@setMethodCallHandler
            }
            val safe = maxOf(0, count)
            try {
                if (safe == 0) {
                    ShortcutBadger.removeCount(this)
                } else {
                    ShortcutBadger.applyCount(this, safe)
                }
                result.success(null)
            } catch (e: Exception) {
                // Some launchers/OEMs don't support badges; fail silently for UX parity with iOS
                result.success(null)
            }
        }
    }

    companion object {
        private const val BADGE_CHANNEL = "foodrx/badge"
    }
}
