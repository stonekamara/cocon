package sn.cocon.cocon

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat

/// Reçoit l'alarme de fin de session : nettoie l'état et notifie l'utilisateur.
class SessionEndReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        SessionStateManager.clearSession(context)
        showEndNotification(context)
    }

    private fun showEndNotification(context: Context) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channelId = "cocon_session_end"
        val channel = NotificationChannel(
            channelId,
            "Fin de session",
            NotificationManager.IMPORTANCE_HIGH,
        )
        manager.createNotificationChannel(channel)

        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val contentIntent = PendingIntent.getActivity(
            context, 0, launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.ic_notification)            .setContentTitle("Session terminée")
            .setContentText("Bravo ! Ton cocon est terminé, les apps sont de nouveau accessibles.")
            .setAutoCancel(true)
            .setContentIntent(contentIntent)
            .build()

        manager.notify(1001, notification)
    }
}
