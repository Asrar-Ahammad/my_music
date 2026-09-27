package com.retro.mymusic.my_music

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioManager
import android.media.audiofx.AudioEffect
import android.media.audiofx.Equalizer
import android.media.audiofx.Virtualizer
import android.media.MediaCodecList
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import com.ryanheise.audioservice.AudioServiceActivity
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : AudioServiceActivity() {
    private var volumeEventSink: EventChannel.EventSink? = null
    private var volumeReceiver: BroadcastReceiver? = null

    private var equalizer: Equalizer? = null
    private var currentEqualizerSessionId: Int = -1
    private var equalizerEnabledState: Boolean = false
    private var equalizerBandGains: List<Double> = emptyList()

    private var virtualizer: Virtualizer? = null
    private var currentSpatialSessionId: Int = -1
    private var spatialEnabledState: Boolean = false
    private var spatialStrengthState: Int = 1000
    private var spatialModeState: String = "binaural"

    private val audioManager by lazy {
        getSystemService(Context.AUDIO_SERVICE) as AudioManager
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        window.decorView.setBackgroundColor(android.graphics.Color.BLACK)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Request highest-available display refresh rate (120Hz / 144Hz etc.).
        // Must be done after the window is fully attached.
        requestHighRefreshRate()

        // App Navigation & Background Exit Control
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.retro.mymusic/app_control")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "exitToHome" -> {
                        moveTaskToBack(true)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // System Music Volume Channels
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.retro.mymusic/volume_control")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getVolume" -> {
                        result.success(getSystemVolume())
                    }
                    "setVolume" -> {
                        val vol = call.argument<Double>("volume") ?: 1.0
                        setSystemVolume(vol)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.retro.mymusic/volume_stream")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    volumeEventSink = events
                    events?.success(getSystemVolume())
                    registerVolumeReceiver()
                }

                override fun onCancel(arguments: Any?) {
                    volumeEventSink = null
                    unregisterVolumeReceiver()
                }
            })

        // Equalizer Channels
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.retro.mymusic/equalizer_control")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "init" -> {
                        val sessionId = call.argument<Int>("sessionId") ?: 0
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        val bandGains = call.argument<List<Double>>("bandGains") ?: emptyList()
                        val success = initEqualizer(sessionId, enabled, bandGains)
                        result.success(success)
                    }
                    "setEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        setEqualizerEnabled(enabled)
                        result.success(true)
                    }
                    "setBandGain" -> {
                        val band = call.argument<Int>("band") ?: 0
                        val gain = call.argument<Double>("gain") ?: 0.0
                        setEqualizerBandGain(band, gain)
                        result.success(true)
                    }
                    "setAllBands" -> {
                        val bandGains = call.argument<List<Double>>("bandGains") ?: emptyList()
                        setEqualizerAllBands(bandGains)
                        result.success(true)
                    }
                    "getParameters" -> {
                        result.success(getEqualizerParameters())
                    }
                    "release" -> {
                        releaseEqualizer()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // Spatial Audio & Dolby Virtualizer Channels
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.retro.mymusic/spatial_audio_control")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "init" -> {
                        val sessionId = call.argument<Int>("sessionId") ?: 0
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        val strength = call.argument<Int>("strength") ?: 1000
                        val mode = call.argument<String>("mode") ?: "binaural"
                        val success = initSpatialAudio(sessionId, enabled, strength, mode)
                        result.success(success)
                    }
                    "setEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        setSpatialAudioEnabled(enabled)
                        result.success(true)
                    }
                    "setStrength" -> {
                        val strength = call.argument<Int>("strength") ?: 1000
                        setSpatialAudioStrength(strength)
                        result.success(true)
                    }
                    "setMode" -> {
                        val mode = call.argument<String>("mode") ?: "binaural"
                        setSpatialAudioMode(mode)
                        result.success(true)
                    }
                    "getCapabilities" -> {
                        result.success(getSpatialAudioCapabilities())
                    }
                    "openSystemSettings" -> {
                        val opened = openSystemAudioPanel()
                        result.success(opened)
                    }
                    "release" -> {
                        releaseSpatialAudio()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // MediaStore Audio Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.retro.mymusic/media_store")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "queryAudioFiles" -> {
                        @Suppress("UNCHECKED_CAST")
                        val folderPrefixes = (call.argument<List<*>>("folderPrefixes") ?: emptyList<String>()).filterIsInstance<String>()
                        CoroutineScope(Dispatchers.IO).launch {
                            try {
                                val files = queryAudioFilesFromMediaStore(folderPrefixes)
                                withContext(Dispatchers.Main) {
                                    result.success(files)
                                }
                            } catch (e: Exception) {
                                withContext(Dispatchers.Main) {
                                    result.error("MEDIA_STORE_ERROR", e.message, null)
                                }
                            }
                        }
                    }
                    "rescanPaths" -> {
                        @Suppress("UNCHECKED_CAST")
                        val paths = (call.argument<List<*>>("paths") ?: emptyList<String>()).filterIsInstance<String>()
                        if (paths.isEmpty()) {
                            result.success(true)
                        } else {
                            MediaScannerConnection.scanFile(
                                applicationContext,
                                paths.toTypedArray(),
                                null
                            ) { _, _ -> }
                            result.success(true)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Requests the highest available display refresh rate from Android.
     * Works on Android 6+ (API 23) via [WindowManager.LayoutParams.preferredDisplayModeId]
     * and additionally on API 30+ via per-surface frame-rate hints.
     */
    private fun requestHighRefreshRate() {
        try {
            val display = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                display
            } else {
                @Suppress("DEPRECATION")
                windowManager.defaultDisplay
            } ?: return

            // Pick the supported display mode with the highest refresh rate.
            @Suppress("DEPRECATION")
            val modes = display.supportedModes
            val highestMode = modes.maxByOrNull { it.refreshRate } ?: return

            val params = window.attributes
            params.preferredDisplayModeId = highestMode.modeId
            window.attributes = params
        } catch (e: Exception) {
            // Device doesn't support refresh-rate selection — no-op.
        }
    }

    private fun queryAudioFilesFromMediaStore(folderPrefixes: List<String>): List<Map<String, Any?>> {
        val results = mutableListOf<Map<String, Any?>>()
        val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
        } else {
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        }

        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.DATA,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.SIZE,
            MediaStore.Audio.Media.DATE_MODIFIED,
            MediaStore.Audio.Media.TRACK,
            MediaStore.Audio.Media.MIME_TYPE,
        )

        // Only music (duration >= 5 seconds) to skip notification sounds
        val selection = "${MediaStore.Audio.Media.DURATION} >= ?"
        val selectionArgs = arrayOf("5000")
        val sortOrder = "${MediaStore.Audio.Media.DATE_MODIFIED} DESC"

        try {
            val cursor = contentResolver.query(collection, projection, selection, selectionArgs, sortOrder)
            cursor?.use { c ->
                val dataIdx = c.getColumnIndexOrThrow(MediaStore.Audio.Media.DATA)
                val titleIdx = c.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
                val artistIdx = c.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
                val albumIdx = c.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
                val durationIdx = c.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
                val sizeIdx = c.getColumnIndexOrThrow(MediaStore.Audio.Media.SIZE)
                val mtimeIdx = c.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_MODIFIED)
                val trackIdx = c.getColumnIndexOrThrow(MediaStore.Audio.Media.TRACK)
                val mimeIdx = c.getColumnIndexOrThrow(MediaStore.Audio.Media.MIME_TYPE)

                while (c.moveToNext()) {
                    val path = c.getString(dataIdx) ?: continue
                    // Filter by folder prefix if specified
                    if (folderPrefixes.isNotEmpty() && folderPrefixes.none { path.startsWith(it) }) continue
                    results.add(mapOf(
                        "path" to path,
                        "title" to (c.getString(titleIdx) ?: ""),
                        "artist" to (c.getString(artistIdx) ?: ""),
                        "album" to (c.getString(albumIdx) ?: ""),
                        "durationMs" to (c.getLong(durationIdx)),
                        "size" to (c.getLong(sizeIdx)),
                        "mtime" to (c.getLong(mtimeIdx) * 1000L),
                        "track" to (c.getInt(trackIdx)),
                        "mimeType" to (c.getString(mimeIdx) ?: ""),
                    ))
                }
            }
        } catch (_: Exception) {}
        return results
    }

    private fun getSystemVolume(): Double {
        return try {
            val current = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
            val max = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
            val min = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                audioManager.getStreamMinVolume(AudioManager.STREAM_MUSIC)
            } else {
                0
            }
            if (max > min) {
                (current - min).toDouble() / (max - min).toDouble()
            } else {
                1.0
            }
        } catch (e: Exception) {
            1.0
        }
    }

    private fun setSystemVolume(volumeFraction: Double) {
        try {
            val max = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
            val min = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                audioManager.getStreamMinVolume(AudioManager.STREAM_MUSIC)
            } else {
                0
            }
            val target = (min + (volumeFraction.coerceIn(0.0, 1.0) * (max - min))).toInt()
            audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, target, 0)
        } catch (e: Exception) {
            // Ignored
        }
    }

    private fun registerVolumeReceiver() {
        if (volumeReceiver != null) return
        volumeReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == "android.media.VOLUME_CHANGED_ACTION") {
                    val streamType = intent.getIntExtra("android.media.EXTRA_VOLUME_STREAM_TYPE", -1)
                    if (streamType == AudioManager.STREAM_MUSIC) {
                        val currentVol = getSystemVolume()
                        runOnUiThread {
                            volumeEventSink?.success(currentVol)
                        }
                    }
                }
            }
        }
        val filter = IntentFilter("android.media.VOLUME_CHANGED_ACTION")
        registerReceiver(volumeReceiver, filter)
    }

    private fun unregisterVolumeReceiver() {
        try {
            volumeReceiver?.let { unregisterReceiver(it) }
            volumeReceiver = null
        } catch (e: Exception) {
            // Ignored
        }
    }


    private fun initEqualizer(sessionId: Int, enabled: Boolean, bandGains: List<Double>): Boolean {
        return try {
            equalizerEnabledState = enabled
            if (bandGains.isNotEmpty()) {
                equalizerBandGains = bandGains
            }

            if (equalizer != null && currentEqualizerSessionId == sessionId) {
                equalizer?.enabled = equalizerEnabledState
                applyEqualizerBands()
                return true
            }

            releaseEqualizer()
            val targetSession = if (sessionId > 0) sessionId else 0
            val eq = Equalizer(0, targetSession).apply {
                this.enabled = equalizerEnabledState
            }
            equalizer = eq
            currentEqualizerSessionId = sessionId
            applyEqualizerBands()
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun setEqualizerEnabled(enabled: Boolean) {
        equalizerEnabledState = enabled
        try {
            equalizer?.enabled = enabled
        } catch (e: Exception) {
            // Ignored
        }
    }

    private fun setEqualizerBandGain(bandIndex: Int, gainDb: Double) {
        try {
            val gains = equalizerBandGains.toMutableList()
            while (gains.size <= bandIndex) {
                gains.add(0.0)
            }
            gains[bandIndex] = gainDb
            equalizerBandGains = gains

            val eq = equalizer ?: return
            val numBands = eq.numberOfBands.toInt()
            if (bandIndex in 0 until numBands) {
                val range = eq.bandLevelRange
                val minLevel = range[0].toInt()
                val maxLevel = range[1].toInt()
                val millibels = (gainDb * 100.0).toInt().coerceIn(minLevel, maxLevel)
                eq.setBandLevel(bandIndex.toShort(), millibels.toShort())
            }
        } catch (e: Exception) {
            // Ignored
        }
    }

    private fun setEqualizerAllBands(bandGains: List<Double>) {
        equalizerBandGains = bandGains
        applyEqualizerBands()
    }

    private fun applyEqualizerBands() {
        try {
            val eq = equalizer ?: return
            val numBands = eq.numberOfBands.toInt()
            if (numBands <= 0) return
            val range = eq.bandLevelRange
            val minLevel = range[0].toInt()
            val maxLevel = range[1].toInt()

            for (i in 0 until minOf(numBands, equalizerBandGains.size)) {
                val gainDb = equalizerBandGains[i]
                val millibels = (gainDb * 100.0).toInt().coerceIn(minLevel, maxLevel)
                eq.setBandLevel(i.toShort(), millibels.toShort())
            }
        } catch (e: Exception) {
            // Ignored
        }
    }

    private fun getEqualizerParameters(): Map<String, Any> {
        return try {
            val eq = equalizer
            if (eq != null) {
                val numBands = eq.numberOfBands.toInt()
                val range = eq.bandLevelRange
                val freqs = (0 until numBands).map { eq.getCenterFreq(it.toShort()) }
                mapOf(
                    "numberOfBands" to numBands,
                    "minLevel" to range[0].toInt(),
                    "maxLevel" to range[1].toInt(),
                    "centerFreqs" to freqs
                )
            } else {
                emptyMap()
            }
        } catch (e: Exception) {
            emptyMap()
        }
    }

    private fun releaseEqualizer() {
        try {
            equalizer?.enabled = false
            equalizer?.release()
            equalizer = null
            currentEqualizerSessionId = -1
        } catch (e: Exception) {
            // Ignored
        }
    }

    private fun initSpatialAudio(sessionId: Int, enabled: Boolean, strength: Int, mode: String): Boolean {
        spatialEnabledState = enabled
        spatialStrengthState = strength
        spatialModeState = mode

        if (sessionId == 0 || (sessionId == currentSpatialSessionId && virtualizer != null)) {
            setSpatialAudioEnabled(enabled)
            setSpatialAudioStrength(strength)
            setSpatialAudioMode(mode)
            return true
        }

        return try {
            releaseSpatialAudio()
            val virt = Virtualizer(0, sessionId)
            virtualizer = virt
            currentSpatialSessionId = sessionId
            setSpatialAudioStrength(strength)
            setSpatialAudioMode(mode)
            virt.enabled = enabled
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun setSpatialAudioEnabled(enabled: Boolean) {
        spatialEnabledState = enabled
        try {
            virtualizer?.enabled = enabled
        } catch (e: Exception) {
            // Ignored
        }
    }

    private fun setSpatialAudioStrength(strength: Int) {
        spatialStrengthState = strength.coerceIn(0, 1000)
        try {
            val virt = virtualizer ?: return
            if (virt.strengthSupported) {
                virt.setStrength(spatialStrengthState.toShort())
            }
        } catch (e: Exception) {
            // Ignored
        }
    }

    private fun setSpatialAudioMode(mode: String) {
        spatialModeState = mode
        try {
            val virt = virtualizer ?: return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                when (mode.lowercase()) {
                    "binaural" -> virt.forceVirtualizationMode(Virtualizer.VIRTUALIZATION_MODE_BINAURAL)
                    "transaural" -> virt.forceVirtualizationMode(Virtualizer.VIRTUALIZATION_MODE_TRANSAURAL)
                    else -> virt.forceVirtualizationMode(Virtualizer.VIRTUALIZATION_MODE_AUTO)
                }
            }
        } catch (e: Exception) {
            // Ignored
        }
    }

    private fun getSpatialAudioCapabilities(): Map<String, Any?> {
        val virt = virtualizer
        val strengthSupported = virt?.strengthSupported ?: true
        val currentStrength = try { virt?.roundedStrength?.toInt() ?: spatialStrengthState } catch (e: Exception) { spatialStrengthState }

        var isSpatializerAvailable = false
        var isSpatializerEnabled = false
        var isHeadTrackerAvailable = false
        var immersiveAudioLevel = 0

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S_V2) {
            try {
                val spatializer = audioManager.spatializer
                isSpatializerAvailable = spatializer.isAvailable
                isSpatializerEnabled = spatializer.isEnabled
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    isHeadTrackerAvailable = spatializer.isHeadTrackerAvailable
                    immersiveAudioLevel = spatializer.immersiveAudioLevel
                }
            } catch (e: Exception) {
                // Ignored
            }
        }

        var hasDolbyEac3 = false
        var hasDolbyAc4 = false
        try {
            val codecList = MediaCodecList(MediaCodecList.REGULAR_CODECS)
            for (info in codecList.codecInfos) {
                if (!info.isEncoder) {
                    for (type in info.supportedTypes) {
                        val t = type.lowercase()
                        if (t == "audio/eac3" || t == "audio/eac3-joc") {
                            hasDolbyEac3 = true
                        }
                        if (t == "audio/ac4") {
                            hasDolbyAc4 = true
                        }
                    }
                }
            }
        } catch (e: Exception) {
            // Ignored
        }

        val panelIntent = Intent(AudioEffect.ACTION_DISPLAY_AUDIO_EFFECT_CONTROL_PANEL).apply {
            putExtra(AudioEffect.EXTRA_AUDIO_SESSION, if (currentSpatialSessionId > 0) currentSpatialSessionId else 0)
            putExtra(AudioEffect.EXTRA_PACKAGE_NAME, packageName)
            putExtra(AudioEffect.EXTRA_CONTENT_TYPE, AudioEffect.CONTENT_TYPE_MUSIC)
        }
        val hasSystemPanel = panelIntent.resolveActivity(packageManager) != null

        return mapOf(
            "strengthSupported" to strengthSupported,
            "currentStrength" to currentStrength,
            "isSpatializerAvailable" to isSpatializerAvailable,
            "isSpatializerEnabled" to isSpatializerEnabled,
            "isHeadTrackerAvailable" to isHeadTrackerAvailable,
            "immersiveAudioLevel" to immersiveAudioLevel,
            "hasDolbyEac3Decoder" to hasDolbyEac3,
            "hasDolbyAc4Decoder" to hasDolbyAc4,
            "hasSystemAudioEffectPanel" to hasSystemPanel,
            "sdkVersion" to Build.VERSION.SDK_INT
        )
    }

    private fun openSystemAudioPanel(): Boolean {
        return try {
            val panelIntent = Intent(AudioEffect.ACTION_DISPLAY_AUDIO_EFFECT_CONTROL_PANEL).apply {
                putExtra(AudioEffect.EXTRA_AUDIO_SESSION, if (currentSpatialSessionId > 0) currentSpatialSessionId else 0)
                putExtra(AudioEffect.EXTRA_PACKAGE_NAME, packageName)
                putExtra(AudioEffect.EXTRA_CONTENT_TYPE, AudioEffect.CONTENT_TYPE_MUSIC)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            if (panelIntent.resolveActivity(packageManager) != null) {
                startActivity(panelIntent)
                true
            } else {
                val soundIntent = Intent(Settings.ACTION_SOUND_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(soundIntent)
                true
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun releaseSpatialAudio() {
        try {
            virtualizer?.enabled = false
            virtualizer?.release()
            virtualizer = null
            currentSpatialSessionId = -1
        } catch (e: Exception) {
            // Ignored
        }
    }

    override fun onDestroy() {
        unregisterVolumeReceiver()
        releaseEqualizer()
        releaseSpatialAudio()
        super.onDestroy()
    }
}

