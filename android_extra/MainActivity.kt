package br.fisionit.tc421_app

import android.content.Context
import android.net.wifi.WifiManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// O Android descarta pacotes de broadcast do Wi-Fi para economizar bateria.
// A resposta da TC421 chega em broadcast, então o app segura esta "trava"
// enquanto está aberto para conseguir encontrar a controladora.
class MainActivity : FlutterActivity() {
    private var lock: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "aqua/net")
            .setMethodCallHandler { call, result ->
                if (call.method == "acquireMulticast") {
                    try {
                        if (lock == null) {
                            val wifi = applicationContext
                                .getSystemService(Context.WIFI_SERVICE) as WifiManager
                            lock = wifi.createMulticastLock("aqualight").apply {
                                setReferenceCounted(false)
                                acquire()
                            }
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        lock?.release()
        lock = null
        super.onDestroy()
    }
}
