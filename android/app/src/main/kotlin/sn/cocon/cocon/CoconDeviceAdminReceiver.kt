package sn.cocon.cocon

import android.app.admin.DeviceAdminReceiver

/// Récepteur exigé par Android pour l'admin d'appareil (Device Admin).
///
/// Cocon s'enregistre comme administrateur pendant une session pour bloquer
/// sa désinstallation, puis se retire automatiquement à la fin du chrono.
class CoconDeviceAdminReceiver : DeviceAdminReceiver()