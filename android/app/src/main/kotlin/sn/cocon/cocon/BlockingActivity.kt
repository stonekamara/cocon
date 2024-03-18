package sn.cocon.cocon

import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.View
import android.widget.Button
import android.widget.TextView
import androidx.activity.ComponentActivity
import androidx.activity.OnBackPressedCallback

/// Écran de blocage natif : s'affiche par-dessus l'app bloquée et persiste
/// tant que la session est active.
///
/// Le code PIN à 3 chiffres n'est **jamais affiché** : il est généré
/// aléatoirement côté natif et n'en sort pas. Pour sortir avant la fin du
/// chrono, deux options :
/// - **Deviner** : saisie manuelle au pavé numérique.
/// - **Brute force** : animation qui essaye toutes les combinaisons
///   (100 → 999) une par une jusqu'à tomber sur le bon code.
class BlockingActivity : ComponentActivity() {

    private val handler = Handler(Looper.getMainLooper())
    private lateinit var remainingView: TextView
    private lateinit var pinDots: TextView
    private lateinit var pinHint: TextView
    private lateinit var unlockButton: Button
    private lateinit var optionsPanel: View
    private lateinit var guessButton: Button
    private lateinit var bruteButton: Button
    private lateinit var bruteText: TextView
    private lateinit var keypad: View
    private lateinit var backButton: View

    private var enteredPin = ""
    private var unlocking = false
    private var bruteRunning = false
    private var bruteCurrent = BRUTE_START

    private val tickRunnable = object : Runnable {
        override fun run() {
            val remaining = SessionStateManager.remainingSeconds(this@BlockingActivity)
            if (remaining <= 0) {
                closeAndGoHome()
                return
            }
            val mm = remaining / 60
            val ss = remaining % 60
            remainingView.text = getString(
                R.string.blocking_countdown,
                mm,
                String.format(java.util.Locale.US, "%02d", ss),
            )
            handler.postDelayed(this, 1000L)
        }
    }

    private val bruteRunnable = object : Runnable {
        override fun run() {
            if (!bruteRunning) return
            val expected = SessionStateManager.getExitPin(this@BlockingActivity)
            if (expected < 0) {
                // Plus de session : on sort.
                unlocking = true
                bruteRunning = false
                closeAndGoHome()
                return
            }
            bruteText.text = getString(R.string.brute_trying, bruteCurrent)
            if (bruteCurrent == expected) {
                bruteText.setText(R.string.brute_found)
                bruteRunning = false
                unlocking = true
                // Le code a été trouvé : la séance s'arrête automatiquement
                // et toutes les apps sont libérées.
                SessionStateManager.clearSession(this@BlockingActivity)
                SessionAlarmScheduler.cancel(this@BlockingActivity)
                handler.postDelayed({ closeAndGoHome() }, 800L)
                return
            }
            bruteCurrent++
            handler.postDelayed(this, BRUTE_STEP_MS)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_blocking)

        remainingView = findViewById(R.id.blocking_remaining)
        pinDots = findViewById(R.id.pin_dots)
        pinHint = findViewById(R.id.pin_hint)
        unlockButton = findViewById(R.id.unlock_button)
        optionsPanel = findViewById(R.id.options_panel)
        guessButton = findViewById(R.id.option_guess)
        bruteButton = findViewById(R.id.option_brute)
        bruteText = findViewById(R.id.brute_text)
        keypad = findViewById(R.id.keypad)
        backButton = findViewById(R.id.back_button)

        onBackPressedDispatcher.addCallback(
            this,
            object : OnBackPressedCallback(true) {
                override fun handleOnBackPressed() {
                    // Back bloqué tant que la session est active : no-op.
                }
            },
        )

        unlockButton.setOnClickListener {
            unlockButton.visibility = View.GONE
            optionsPanel.visibility = View.VISIBLE
            backButton.visibility = View.VISIBLE
        }

        backButton.setOnClickListener { goBack() }

        guessButton.setOnClickListener {
            optionsPanel.visibility = View.GONE
            pinDots.visibility = View.VISIBLE
            pinHint.visibility = View.VISIBLE
            keypad.visibility = View.VISIBLE
            backButton.visibility = View.VISIBLE
            pinHint.setText(R.string.pin_enter_code)
        }

        bruteButton.setOnClickListener {
            optionsPanel.visibility = View.GONE
            bruteText.visibility = View.VISIBLE
            backButton.visibility = View.VISIBLE
            bruteRunning = true
            bruteCurrent = BRUTE_START
            handler.post(bruteRunnable)
        }

        setupKeypad()
    }

    private fun setupKeypad() {
        val buttons = mapOf(
            R.id.key_0 to "0", R.id.key_1 to "1", R.id.key_2 to "2",
            R.id.key_3 to "3", R.id.key_4 to "4", R.id.key_5 to "5",
            R.id.key_6 to "6", R.id.key_7 to "7", R.id.key_8 to "8",
            R.id.key_9 to "9",
        )
        buttons.forEach { (id, digit) ->
            findViewById<Button>(id).setOnClickListener { onDigit(digit) }
        }
        findViewById<Button>(R.id.key_del).setOnClickListener {
            if (enteredPin.isNotEmpty()) {
                enteredPin = enteredPin.dropLast(1)
                renderDots()
            }
        }
    }

    private fun onDigit(digit: String) {
        if (unlocking || bruteRunning) return
        if (enteredPin.length >= 3) return
        enteredPin += digit
        renderDots()

        if (enteredPin.length == 3) {
            val expected = SessionStateManager.getExitPin(this)
            if (expected >= 0 && enteredPin == expected.toString()) {
                unlocking = true
                // Le code a été trouvé : la séance s'arrête automatiquement
                // et toutes les apps sont libérées.
                SessionStateManager.clearSession(this)
                SessionAlarmScheduler.cancel(this)
                closeAndGoHome()
            } else {
                pinHint.setText(R.string.pin_wrong)
                pinHint.postDelayed({
                    if (!isFinishing) pinHint.setText(R.string.pin_enter_code)
                }, 1500)
                enteredPin = ""
                pinDots.postDelayed({ renderDots() }, 400)
            }
        }
    }

    private fun renderDots() {
        val shown = buildString {
            repeat(3) { i ->
                append(if (i < enteredPin.length) "●" else "○")
                if (i < 2) append(' ')
            }
        }
        pinDots.text = shown
    }

    override fun onResume() {
        super.onResume()
        renderDots()
        handler.post(tickRunnable)
        if (bruteRunning) handler.post(bruteRunnable)
    }

    override fun onPause() {
        handler.removeCallbacks(tickRunnable)
        handler.removeCallbacks(bruteRunnable)
        super.onPause()
    }

    private fun goBack() {
        // Retour depuis le clavier ou l'animation brute force.
        if (bruteRunning) {
            bruteRunning = false
            handler.removeCallbacks(bruteRunnable)
        }
        enteredPin = ""
        renderDots()
        keypad.visibility = View.GONE
        pinDots.visibility = View.GONE
        pinHint.visibility = View.GONE
        bruteText.visibility = View.GONE
        optionsPanel.visibility = View.GONE
        backButton.visibility = View.GONE
        unlockButton.visibility = View.VISIBLE
    }

    private fun closeAndGoHome() {
        val goHome = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(goHome)
        finish()
    }

    private companion object {
        const val BRUTE_START = 100
        const val BRUTE_STEP_MS = 45L
    }
}
