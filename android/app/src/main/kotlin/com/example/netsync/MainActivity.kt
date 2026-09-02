package com.example.netsync

import android.content.Context
import android.content.Intent
import android.location.Location
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.example.netsync.services.ChildMonitorService

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.netsync/service"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startMonitorService" -> {
                    startChildService()
                    result.success(true)
                }
                "stopMonitorService" -> {
                    stopChildService()
                    result.success(true)
                }
                "isServiceRunning" -> {
                    result.success(ChildMonitorService.isRunning)
                }
                "requestBatteryOptimization" -> {
                    requestBatteryOptimization()
                    result.success(true)
                }
                "isBatteryOptimizationIgnored" -> {
                    result.success(isBatteryOptimizationIgnored())
                }
                "getCurrentLocation" -> {
                    try {
                        val locationManager = getSystemService(Context.LOCATION_SERVICE) as? LocationManager
                        val lastGps = try { locationManager?.getLastKnownLocation(LocationManager.GPS_PROVIDER) } catch (e: SecurityException) { null }
                        val lastNet = try { locationManager?.getLastKnownLocation(LocationManager.NETWORK_PROVIDER) } catch (e: SecurityException) { null }
                        val bestLoc: Location? = lastGps ?: lastNet
                        if (bestLoc != null) {
                            result.success(mapOf(
                                "latitude" to bestLoc.latitude,
                                "longitude" to bestLoc.longitude,
                                "accuracy" to bestLoc.accuracy.toDouble(),
                                "speed" to bestLoc.speed.toDouble()
                            ))
                        } else {
                            result.success(null)
                        }
                    } catch (e: Exception) {
                        result.success(null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun startChildService() {
        val serviceIntent = Intent(this, ChildMonitorService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }

    private fun stopChildService() {
        val serviceIntent = Intent(this, ChildMonitorService::class.java)
        stopService(serviceIntent)
    }

    private fun isBatteryOptimizationIgnored(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
            return powerManager?.isIgnoringBatteryOptimizations(packageName) ?: false
        }
        return true
    }

    private fun requestBatteryOptimization() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!isBatteryOptimizationIgnored()) {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:$packageName")
                }
                startActivity(intent)
            }
        }
    }
}
