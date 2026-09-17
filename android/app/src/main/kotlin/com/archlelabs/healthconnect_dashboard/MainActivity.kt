package com.archlelabs.healthconnect_dashboard

import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.changes.UpsertionChange
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.ChangesTokenRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import androidx.lifecycle.lifecycleScope
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.temporal.ChronoUnit

class MainActivity : FlutterFragmentActivity() {
    private val METHOD_CHANNEL = "com.archlelabs.healthconnect/methods"
    private val EVENT_CHANNEL = "com.archlelabs.healthconnect/events"

    private var healthConnectClient: HealthConnectClient? = null
    private var eventSink: EventChannel.EventSink? = null
    private var pollingJob: Job? = null
    private var changesToken: String? = null

    private val PERMISSIONS = setOf(
        HealthPermission.getReadPermission(StepsRecord::class),
        HealthPermission.getReadPermission(HeartRateRecord::class)
    )

    private val requestPermissionContract =
        PermissionController.createRequestPermissionResultContract()

    private val requestPermissionLauncher =
        registerForActivityResult(requestPermissionContract) { granted ->
            val hasSteps = granted.contains(HealthPermission.getReadPermission(StepsRecord::class))
            val hasHr = granted.contains(HealthPermission.getReadPermission(HeartRateRecord::class))
            val result = mapOf(
                "steps" to hasSteps,
                "heartRate" to hasHr,
                "allGranted" to (hasSteps && hasHr)
            )
            pendingPermissionResult?.success(result)
            pendingPermissionResult = null
        }

    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        if (HealthConnectClient.getSdkStatus(this) == HealthConnectClient.SDK_AVAILABLE) {
            healthConnectClient = HealthConnectClient.getOrCreate(this)
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSdkStatus" -> {
                        val status = HealthConnectClient.getSdkStatus(this)
                        val statusStr = when (status) {
                            HealthConnectClient.SDK_AVAILABLE -> "available"
                            HealthConnectClient.SDK_UNAVAILABLE -> "unavailable"
                            HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> "update_required"
                            else -> "unknown"
                        }
                        result.success(statusStr)
                    }

                    "checkPermissions" -> {
                        val client = healthConnectClient
                        if (client == null) {
                            result.success(mapOf("steps" to false, "heartRate" to false, "allGranted" to false))
                            return@setMethodCallHandler
                        }
                        lifecycleScope.launch {
                            try {
                                val granted = client.permissionController.getGrantedPermissions()
                                val hasSteps = granted.contains(HealthPermission.getReadPermission(StepsRecord::class))
                                val hasHr = granted.contains(HealthPermission.getReadPermission(HeartRateRecord::class))
                                result.success(mapOf(
                                    "steps" to hasSteps,
                                    "heartRate" to hasHr,
                                    "allGranted" to (hasSteps && hasHr)
                                ))
                            } catch (e: Exception) {
                                result.error("PERMISSION_ERROR", e.message, null)
                            }
                        }
                    }

                    "requestPermissions" -> {
                        pendingPermissionResult = result
                        requestPermissionLauncher.launch(PERMISSIONS)
                    }

                    "readRecentData" -> {
                        val client = healthConnectClient
                        if (client == null) {
                            result.success(emptyMap<String, Any>())
                            return@setMethodCallHandler
                        }
                        lifecycleScope.launch {
                            try {
                                val now = Instant.now()
                                val oneHourAgo = now.minus(1, ChronoUnit.HOURS)

                                val stepsResponse = client.readRecords(
                                    ReadRecordsRequest(
                                        recordType = StepsRecord::class,
                                        timeRangeFilter = TimeRangeFilter.between(oneHourAgo, now)
                                    )
                                )

                                val hrResponse = client.readRecords(
                                    ReadRecordsRequest(
                                        recordType = HeartRateRecord::class,
                                        timeRangeFilter = TimeRangeFilter.between(oneHourAgo, now)
                                    )
                                )

                                val stepsList = stepsResponse.records.map {
                                    mapOf("ts" to it.startTime.toEpochMilli(), "count" to it.count)
                                }

                                val hrList = mutableListOf<Map<String, Any>>()
                                hrResponse.records.forEach { record ->
                                    record.samples.forEach { sample ->
                                        hrList.add(
                                            mapOf(
                                                "ts" to sample.time.toEpochMilli(),
                                                "bpm" to sample.beatsPerMinute.toInt()
                                            )
                                        )
                                    }
                                }

                                result.success(mapOf("steps" to stepsList, "heartRate" to hrList))
                            } catch (e: Exception) {
                                result.error("READ_ERROR", e.message, null)
                            }
                        }
                    }

                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    startChangesPolling()
                }

                override fun onCancel(arguments: Any?) {
                    pollingJob?.cancel()
                    pollingJob = null
                    eventSink = null
                }
            })
    }

    private fun startChangesPolling() {
        val client = healthConnectClient ?: return
        pollingJob?.cancel()

        pollingJob = lifecycleScope.launch(Dispatchers.IO) {
            try {
                if (changesToken == null) {
                    changesToken = client.getChangesToken(
                        ChangesTokenRequest(
                            recordTypes = setOf(
                                StepsRecord::class,
                                HeartRateRecord::class
                            )
                        )
                    )
                }

                while (isActive) {
                    val token = changesToken ?: break
                    val changesResponse = client.getChanges(token)
                    changesToken = changesResponse.nextChangesToken

                    val mainHandler = Handler(Looper.getMainLooper())
                    for (change in changesResponse.changes) {
                        if (change is UpsertionChange) {
                            val record = change.record
                            when (record) {
                                is StepsRecord -> {
                                    val data = mapOf(
                                        "type" to "steps",
                                        "ts" to record.startTime.toEpochMilli(),
                                        "count" to record.count
                                    )
                                    mainHandler.post { eventSink?.success(data) }
                                }

                                is HeartRateRecord -> {
                                    for (sample in record.samples) {
                                        val data = mapOf(
                                            "type" to "heartRate",
                                            "ts" to sample.time.toEpochMilli(),
                                            "bpm" to sample.beatsPerMinute.toInt()
                                        )
                                        mainHandler.post { eventSink?.success(data) }
                                    }
                                }
                            }
                        }
                    }

                    // Poll cadence: 5 seconds (well within <= 10s latency target)
                    delay(5000)
                }
            } catch (e: Exception) {
                // Polling error or permissions revoked
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        pollingJob?.cancel()
    }
}
