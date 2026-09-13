package sn.cocon.cocon

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channelName = "cocon/native"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isBlockingSupported" -> result.success(true)

                    "getInstalledApps" -> result.success(getInstalledApps())

                    "isAccessibilityEnabled" -> result.success(isAccessibilityServiceEnabled())

                    "openAccessibilitySettings" -> {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(null)
                    }

                    "isDeviceAdminEnabled" ->
                        result.success(DeviceAdminManager.isActive(this))

                    "activateDeviceAdmin" -> {
                        DeviceAdminManager.ensureActive(this)
                        result.success(null)
                    }

                    "scheduleSessionEnd" -> {
                        val args = call.arguments as? Map<*, *>
                        val minutes = (args?.get("minutes") as? Number)?.toInt() ?: 25
                        @Suppress("UNCHECKED_CAST")
                        val packages =
                            (args?.get("packages") as? List<String>) ?: emptyList()
                        // Verrou anti-désinstallation : une session ne démarre
                        // que si Cocon est administrateur actif, pour garantir
                        // la protection à chaque session.
                        if (!DeviceAdminManager.isActive(this)) {
                            result.success(false)
                        } else {
                            SessionStateManager.armSession(this, minutes, packages)
                            SessionAlarmScheduler.schedule(this, minutes)
                            result.success(true)
                        }
                    }

                    "cancelSessionEnd" -> {
                        SessionStateManager.clearSession(this)
                        SessionAlarmScheduler.cancel(this)
                        result.success(null)
                    }

                    "getActiveSession" -> {
                        if (SessionStateManager.isSessionActive(this)) {
                            result.success(
                                mapOf(
                                    "remainingSeconds" to SessionStateManager.remainingSeconds(this),
                                    "plannedMinutes" to SessionStateManager.getPlannedMinutes(this),
                                )
                            )
                        } else {
                            result.success(null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    /// Liste des apps lançables par l'utilisateur (filtre les composants système
    /// sans icône d'application propre, exclut Cocon lui-même).
    private fun getInstalledApps(): List<Map<String, Any?>> {
        val pm = packageManager
        val launcherIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val resolveInfos = pm.queryIntentActivities(launcherIntent, 0)

        return resolveInfos
            .asSequence()
            .map { it.activityInfo.applicationInfo }
            .distinctBy { it.packageName }
            .filter { it.packageName != packageName }
            .map { appInfo ->
                mapOf(
                    "package" to appInfo.packageName,
                    "label" to pm.getApplicationLabel(appInfo).toString(),
                    "icon" to null, // simplification v1 : pas d'icônes
                    "system" to ((appInfo.flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM) != 0),
                )
            }
            .sortedBy { (it["label"] as String).lowercase() }
            .toList()
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val expected = "$packageName/${CoconAccessibilityService::class.java.canonicalName}"
        val enabled = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: return false
        return enabled.split(':').any { it.equals(expected, ignoreCase = true) }
    }
}
