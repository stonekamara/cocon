package sn.cocon.cocon

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent

/// Gestion de l'admin d'appareil : pendant une session, Cocon s'enregistre
/// comme administrateur pour empêcher sa désinstallation. L'admin est retiré
/// automatiquement dès que la session se termine (clearSession).
object DeviceAdminManager {

    fun component(context: Context): ComponentName =
        ComponentName(context, CoconDeviceAdminReceiver::class.java)

    fun isActive(context: Context): Boolean {
        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE)
                as DevicePolicyManager
        return dpm.isAdminActive(component(context))
    }

    /// Demande l'activation de l'admin (dialogue système). Non bloquant :
    /// si l'utilisateur refuse, la session continue simplement sans verrou
    /// de désinstallation.
    fun ensureActive(context: Context) {
        if (isActive(context)) return
        try {
            val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
                putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, component(context))
                putExtra(
                    DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                    context.getString(R.string.admin_add_explanation),
                )
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
        } catch (_: Exception) {
            // Contexte/activité indisponible : réessayé à la prochaine session.
        }
    }

    /// Retire l'admin d'appareil dès que la session se termine (app redevient
    /// désinstallable).
    fun disable(context: Context) {
        try {
            val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE)
                    as DevicePolicyManager
            if (dpm.isAdminActive(component(context))) {
                dpm.removeActiveAdmin(component(context))
            }
        } catch (_: SecurityException) {
            // Déjà retiré ou droits insuffisants : rien à faire.
        }
    }
}