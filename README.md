# Cocon 🧘

**Cocon** transforme ton téléphone en outil de concentration : pendant une session, les applications que tu as choisies sont bloquées. Impossible de tricher pour sortir avant la fin, il faut trouver le code.

<p align="center">
  <img src="docs/screenshots/home.jpg" width="200" alt="Accueil" />
  <img src="docs/screenshots/session.jpg" width="200" alt="Session en cours" />
  <img src="docs/screenshots/apps.jpg" width="200" alt="Sélection des apps" />
  <img src="docs/screenshots/history.jpg" width="200" alt="Historique" />
</p>

## Fonctionnalités

- **Sessions de concentration** minuteur circulaire, durées prédéfinies (15, 25, 45, 60, 90 min)
- **Blocage réel des apps** quand une app bloquée s'ouvre pendant une session, un écran de blocage prend le dessus instantanément
- **Résistant aux contournements** détection par événements d'accessibilité **+** sondage de la fenêtre active toutes les 500 ms (fonctionne même en rouvrant depuis les apps récentes)
- **Code PIN secret à 6 chiffres** — un code est généré aléatoirement à chaque session, stocké côté natif, jamais affiché
- **Deux façons de sortir avant la fin** :
  - *Deviner le code* au pavé numérique
  - *Brute force* : une animation essaye les combinaisons (100000 → 999999) une par une, limitée à 6 essais par seconde — il faut mériter sa sortie
- **Aucun arrêt possible depuis l'app** — ni pause, ni stop : la session ne s'achève que par le chrono ou le code
- **Non désinstallable pendant une session** (v1.1.0) — Cocon s'enregistre comme administrateur d'appareil (Device Admin) au lancement et se retire automatiquement à la fin du chrono pour re-devenir désinstallable
- **Historique & statistiques** — sessions terminées/interrompues, minutes concentrées par semaine
- **100 % hors ligne** aucune donnée ne quitte le téléphone

## Captures

| Blocage en action | Sortie par code |
|---|---|
| L'app bloquée est recouverte par l'écran Cocon avec le temps restant | « Débloquer » propose de deviner le code ou de lancer le brute force |

## Architecture

### Flutter (interface)
| Élément | Rôle |
|---|---|
| `lib/providers/focus_provider.dart` | État central : session, minuteur, apps bloquées, historique |
| `lib/services/native_bridge.dart` | Pont MethodChannel vers le natif (tolérant hors Android) |
| `lib/services/local_store.dart` | Persistance locale (SharedPreferences) |
| `lib/theme.dart` | Thème bleu ciel Material 3 |

### Android natif (blocage)
| Élément | Rôle |
|---|---|
| `CoconAccessibilityService` | Détecte l'app au premier plan (événements + polling 500 ms) |
| `BlockingActivity` | Écran de blocage : chrono, pavé PIN, animation brute force |
| `SessionStateManager` | État de session persistant (fin, apps, PIN) survit à un kill |
| `SessionAlarmScheduler` + `SessionEndReceiver` | Alarme exacte de fin de session + notification |

## Compilation

```bash
flutter pub get
flutter run   # sur un appareil Android connecté
```

Premier lancement : activer le service dans **Réglages Android → Accessibilité → Services installés → Cocon** (l'app affiche une bannière qui guide vers les réglages).

> App Android développée avec Flutter, testée sur Samsung Galaxy A20e (Android 11).

## 📌 Nouveautés v1.1.0

- **Code PIN à 6 chiffres** au lieu de 3.
- **Brute force limitée à 6 essais par seconde**.
- **Protection anti-désinstallation** : pendant une session, Cocon s'active comme administrateur d'appareil (Device Admin) et ne peut plus être désinstallé. Un écran système demande l'activation au lancement d'une session ; si tu la refuses, le blocage fonctionne quand même, sans ce verrou. L'admin est retiré automatiquement à la fin du chrono.

## Télécharger

[![Télécharger v1.1.0](https://img.shields.io/badge/T%C3%A9l%C3%A9charger-v1.1.0-1E6FA8?style=for-the-badge&logo=android&logoColor=white)](https://github.com/stonekamara/cocon/releases/download/v1.1.0/app-release.apk)

> Android affichera un avertissement « application inconnue » : autorise simplement l'installation (l'app n'est pas sur le Play Store).

Toutes les versions : [Releases](https://github.com/stonekamara/cocon/releases)

## Licence

Projet personnel tous droits réservés.
