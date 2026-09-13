package sn.cocon.cocon

import android.content.Context
import android.content.SharedPreferences

/// État de session partagé entre Flutter (via MainActivity) et les composants
/// natifs (AccessibilityService, BlockingActivity, récepteur d'alarme).
object SessionStateManager {
    private const val PREFS = "cocon_native_prefs"
    private const val KEY_END_TS = "session_end_ts"
    private const val KEY_PACKAGES = "blocked_packages"
    private const val KEY_PLANNED_MIN = "session_planned_minutes"
    private const val KEY_EXIT_PIN = "session_exit_pin"

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /// Longueur du code PIN de sortie (6 chiffres).
    const val PIN_LENGTH = 6

    fun armSession(context: Context, minutes: Int, packages: List<String>) {
        val exitPin = java.util.Random().nextInt(900_000) + 100_000 // 100000..999999
        prefs(context).edit()
            .putLong(KEY_END_TS, System.currentTimeMillis() + minutes * 60_000L)
            .putStringSet(KEY_PACKAGES, packages.toSet())
            .putInt(KEY_PLANNED_MIN, minutes)
            .putInt(KEY_EXIT_PIN, exitPin)
            .apply()
        // Force le système à (re)lier le service d'accessibilité immédiatement
        // (survit à un kill du process grâce à l'état persistant ci-dessus).
        try {
            val am = context.getSystemService(Context.ACCESSIBILITY_SERVICE)
                as android.view.accessibility.AccessibilityManager
            am.getEnabledAccessibilityServiceList(
                android.accessibilityservice.AccessibilityServiceInfo.FEEDBACK_ALL_MASK
            )
        } catch (_: Exception) {
            // Best effort : le service sera lié au prochain événement système.
        }
    }

    fun clearSession(context: Context) {
        prefs(context).edit()
            .remove(KEY_END_TS)
            .remove(KEY_PACKAGES)
            .remove(KEY_PLANNED_MIN)
            .remove(KEY_EXIT_PIN)
            .apply()
        // Session terminée : l'admin d'appareil n'a plus lieu d'être,
        // l'app redevient désinstallable.
        DeviceAdminManager.disable(context)
    }

    fun getPlannedMinutes(context: Context): Int =
        prefs(context).getInt(KEY_PLANNED_MIN, 0)

    fun getExitPin(context: Context): Int =
        prefs(context).getInt(KEY_EXIT_PIN, -1)

    fun isSessionActive(context: Context): Boolean = remainingSeconds(context) > 0

    fun remainingSeconds(context: Context): Long {
        val end = prefs(context).getLong(KEY_END_TS, 0L)
        return (end - System.currentTimeMillis()) / 1000L
    }

    fun getBlockedPackages(context: Context): Set<String> =
        prefs(context).getStringSet(KEY_PACKAGES, emptySet()) ?: emptySet()
}
