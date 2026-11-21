package io.github.ppxh123.remember

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import android.icu.util.Calendar
import android.icu.util.GregorianCalendar
import android.icu.util.TimeZone

class MainActivity : FlutterActivity() {
    private var clockReceiver: BroadcastReceiver? = null
    private val calendarChannel = "io.github.ppxh123.remember/device_calendar"
    private val eventsChannel = "io.github.ppxh123.remember/clock_changes"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, calendarChannel).setMethodCallHandler { call, result ->
            val zone = TimeZone.getTimeZone(java.util.TimeZone.getDefault().id)
            val calendar = GregorianCalendar(zone).apply {
                repeatedWallTimeOption = Calendar.WALLTIME_FIRST
                skippedWallTimeOption = Calendar.WALLTIME_NEXT_VALID
            }
            if (call.method == "instantAt") {
                val date = (call.arguments as? List<*>)?.mapNotNull { (it as? Number)?.toInt() }
                if (date?.size != 5) {
                    result.error("invalid_time", null, null)
                } else {
                    calendar.clear()
                    calendar.set(date[0], date[1] - 1, date[2], date[3], date[4], 0)
                    result.success(calendar.timeInMillis)
                }
                return@setMethodCallHandler
            }
            val instant = call.arguments as? Number
            if (call.method != "dayAt") {
                result.notImplemented()
            } else if (instant == null) {
                result.error("invalid_instant", null, null)
            } else {
                calendar.timeInMillis = instant.toLong()
                val date = listOf(
                    calendar.get(Calendar.YEAR),
                    calendar.get(Calendar.MONTH) + 1,
                    calendar.get(Calendar.DAY_OF_MONTH)
                )
                calendar.add(Calendar.DAY_OF_MONTH, 1)
                calendar.set(Calendar.HOUR_OF_DAY, 0)
                calendar.set(Calendar.MINUTE, 0)
                calendar.set(Calendar.SECOND, 0)
                calendar.set(Calendar.MILLISECOND, 0)
                result.success(date + calendar.timeInMillis)
            }
        }

        EventChannel(messenger, eventsChannel).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                unregisterClockReceiver()
                val receiver = object : BroadcastReceiver() {
                    override fun onReceive(context: Context, intent: Intent) {
                        events.success(null)
                    }
                }
                // These intents are sent by the system.
                registerReceiver(receiver, IntentFilter().apply {
                    addAction(Intent.ACTION_TIMEZONE_CHANGED)
                    addAction(Intent.ACTION_TIME_CHANGED)
                })
                clockReceiver = receiver
            }

            override fun onCancel(arguments: Any?) {
                unregisterClockReceiver()
            }
        })
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        unregisterClockReceiver()
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        EventChannel(messenger, eventsChannel).setStreamHandler(null)
        MethodChannel(messenger, calendarChannel).setMethodCallHandler(null)
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun unregisterClockReceiver() {
        clockReceiver?.let { unregisterReceiver(it) }
        clockReceiver = null
    }
}
