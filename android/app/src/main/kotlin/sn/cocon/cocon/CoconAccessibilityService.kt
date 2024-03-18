package sn.cocon.cocon

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityWindowInfo

/// Cœur du blocage : détecte quand une application bloquée passe au premier
/// plan. Combine trois mécanismes de résilience :
///
/// 1. Événements TYPE_WINDOW_STATE_CHANGED (rapide).
/// 2. Polling léger (500 ms) de la fenêtre focusée — rattrape les transitions
///    ratées (apps récentes One UI).
/// 3. Re-binding à la volée : si l'état natif s'arme alors que le service
///    tournait déjà (session armée process vivant), on relance le polling ;
///    si le process meurt, le système relance le service tout seul grâce à
///    l'état persistant, et onServiceConnected() repart.
class CoconAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "CoconService"
        private const val POLL_INTERVAL_MS = 500L
    }

    private val handler = Handler(Looper.getMainLooper())
    private var polling = false

    private val pollRunnable = object : Runnable {
        override fun run() {
            android.util.Log.d(TAG, "tick")
            checkForegroundWindow()
            if (polling) handler.postDelayed(this, POLL_INTERVAL_MS)
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        android.util.Log.w(TAG, "onServiceConnected")
        serviceInfo = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS or
                AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
            notificationTimeout = 100
        }
        startPolling()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val pkg = event.packageName?.toString() ?: return
        android.util.Log.d(TAG, "event pkg=$pkg")
        evaluate(pkg)
    }

    override fun onInterrupt() {
        // Rien à interrompre.
    }

    override fun onDestroy() {
        polling = false
        handler.removeCallbacks(pollRunnable)
        super.onDestroy()
    }

    private fun startPolling() {
        if (polling) return
        polling = true
        handler.post(pollRunnable)
    }

    private fun checkForegroundWindow() {
        try {
            val all = windows
            if (all.isEmpty()) {
                android.util.Log.d(TAG, "poll: windows vide")
                return
            }
            val window = all.firstOrNull {
                it.type == AccessibilityWindowInfo.TYPE_APPLICATION && it.isFocused
            } ?: all.firstOrNull {
                it.type == AccessibilityWindowInfo.TYPE_APPLICATION
            } ?: return
            val pkg = window.root?.packageName?.toString()
            android.util.Log.d(TAG, "poll pkg=$pkg")
            if (pkg != null) evaluate(pkg)
        } catch (e: Exception) {
            android.util.Log.e(TAG, "poll error", e)
        }
    }

    /// Déclenche le blocage si [pkg] est bloqué et qu'une session est active.
    private fun evaluate(pkg: String) {
        if (pkg == packageName) return
        if (pkg.startsWith("com.android.systemui")) return

        val context = applicationContext
        val active = SessionStateManager.isSessionActive(context)
        val blocked = SessionStateManager.getBlockedPackages(context).contains(pkg)
        if (!active || !blocked) return

        android.util.Log.w(TAG, "BLOCAGE déclenché pour $pkg")
        launchBlocking()
    }

    private fun launchBlocking() {
        val intent = Intent(this, BlockingActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            )
        }
        try {
            startActivity(intent)
        } catch (e: Exception) {
            android.util.Log.e(TAG, "startActivity bloqué", e)
        }
    }

}
