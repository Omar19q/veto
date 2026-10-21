package com.vetosanya.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.view.WindowManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerStateListener
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "veto_sanya/install_referral")
            .setMethodCallHandler { call, result ->
                if (call.method == "read") readInstallReferral(result) else result.notImplemented()
            }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "veto_sanya/screen_awake"
        ).setMethodCallHandler { call, result ->
            if (call.method != "setEnabled") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val enabled = call.arguments as? Boolean ?: false
            runOnUiThread {
                if (enabled) {
                    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                }
                result.success(null)
            }
        }
    }

    private fun readInstallReferral(result: MethodChannel.Result) {
        val client = InstallReferrerClient.newBuilder(this).build()
        val finished = AtomicBoolean(false)
        val handler = Handler(Looper.getMainLooper())
        fun respond(status: String, code: String? = null) {
            if (!finished.compareAndSet(false, true)) return
            try { client.endConnection() } catch (_: Exception) { /* Result still delivered. */ }
            runOnUiThread { result.success(mapOf("status" to status, "code" to code)) }
        }
        handler.postDelayed({ respond("unavailable") }, 8000)
        try {
            client.startConnection(object : InstallReferrerStateListener {
                override fun onInstallReferrerSetupFinished(responseCode: Int) {
                    if (responseCode == InstallReferrerClient.InstallReferrerResponse.OK) {
                        try {
                            val raw = client.installReferrer.installReferrer
                            val code = Uri.parse("https://referrer.invalid/?$raw").getQueryParameter("referral_code")
                            respond("ready", code?.takeIf { it.matches(Regex("(?:[0-9]{4,19}|C(?:[a-fA-F0-9]{12}|[a-fA-F0-9]{32}))")) })
                        } catch (_: Exception) { respond("unavailable") }
                    } else if (responseCode == InstallReferrerClient.InstallReferrerResponse.FEATURE_NOT_SUPPORTED) {
                        respond("unsupported")
                    } else { respond("unavailable") }
                }
                override fun onInstallReferrerServiceDisconnected() { respond("unavailable") }
            })
        } catch (_: Exception) { respond("unavailable") }
    }
}
