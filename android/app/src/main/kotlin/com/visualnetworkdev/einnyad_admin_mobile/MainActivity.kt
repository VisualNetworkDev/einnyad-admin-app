package com.visualnetworkdev.einnyad_admin_mobile

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var vault: BiometricVault? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val currentVault = BiometricVault(this)
        vault = currentVault
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "einnyad/biometric_access")
            .setMethodCallHandler(currentVault::handle)
    }

    override fun onDestroy() {
        vault?.cancel()
        vault = null
        super.onDestroy()
    }
}
