package com.prombt.prombt_app

import android.util.Log
import android.view.WindowManager
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.StandardIntegrityException
import com.google.android.play.core.integrity.StandardIntegrityManager
import com.google.android.play.core.integrity.StandardIntegrityManager.PrepareIntegrityTokenRequest
import com.google.android.play.core.integrity.StandardIntegrityManager.StandardIntegrityTokenProvider
import com.google.android.play.core.integrity.StandardIntegrityManager.StandardIntegrityTokenRequest
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * SEC-0.1 - Play Integrity (Standard API) host binding.
 *
 * This class does exactly two things: warm up a StandardIntegrityTokenProvider,
 * and mint a request-bound integrity token. It deliberately does NOT inspect,
 * decode, parse or act on the token.
 *
 * ALL TRUST DECISIONS BELONG EXCLUSIVELY TO THE BACKEND (SEC-0.2).
 *
 * The token is an opaque, Google-signed, encrypted blob whose verdict can only
 * be read on Google's servers. That is the entire reason the control works:
 * everything on this side of the wire runs in a process an attacker controls,
 * so nothing decided here could be trusted. The client's only job is delivery.
 */
class MainActivity : FlutterActivity() {

    private companion object {
        const val CHANNEL = "styliai/play_integrity"
        const val SECURE_CHANNEL = "styliai/secure_screen"
        const val TAG = "PlayIntegrity"

        /**
         * Google: "If your app uses the same token provider for too long, the
         * token provider can expire which results in the
         * INTEGRITY_TOKEN_PROVIDER_INVALID error on the next token request. You
         * should handle this error by requesting a new provider."
         */
        const val ERR_PROVIDER_INVALID = -19
    }

    private var integrityManager: StandardIntegrityManager? = null
    private var tokenProvider: StandardIntegrityTokenProvider? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "prepare" -> prepare(call.argument<String>("cloudProjectNumber"), result)
                    "requestToken" -> requestToken(call.argument<String>("requestHash"), result)
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SECURE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSecure" -> setSecure(call.argument<Boolean>("enabled") == true, result)
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Phase 6 - FLAG_SECURE, applied per screen rather than app-wide.
     *
     * The flag does three things at once on Android: it blocks screenshots and
     * screen recording, and it blanks the window in the recent-apps switcher.
     * That last one is why it is worth setting on the auth and profile screens
     * specifically - the task-switcher thumbnail is a screenshot the user never
     * asked for and never sees being taken.
     *
     * Deliberately NOT set app-wide. Users legitimately screenshot their own
     * generated images to save or share them, and that is the product working.
     * The Dart side (utils/secure_screen.dart) reference-counts, so overlapping
     * secure screens cannot leave the flag stuck either on or off.
     *
     * Window flags must be touched on the UI thread; `runOnUiThread` makes that
     * true regardless of which thread the channel call arrives on. Failure is
     * reported as false rather than as an exception, so the Dart side has one
     * boring fail-open path - a device that refuses the flag must not crash the
     * screen the user was opening.
     */
    private fun setSecure(enabled: Boolean, result: MethodChannel.Result) {
        runOnUiThread {
            try {
                if (enabled) {
                    window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                }
                result.success(true)
            } catch (e: Exception) {
                Log.w(TAG, "setSecure($enabled) failed")
                result.success(false)
            }
        }
    }

    /**
     * Warms up the provider. Google caches partial attestation state on the
     * device so the on-demand request stays in the few-hundred-millisecond
     * range instead of the multi-second warm-up.
     *
     * Never fails the call: a warm-up failure returns false and the app carries
     * on without integrity tokens, because the backend - not this client - is
     * what decides whether a missing token matters.
     */
    private fun prepare(cloudProjectNumber: String?, result: MethodChannel.Result) {
        val projectNumber = cloudProjectNumber?.toLongOrNull()
        if (projectNumber == null) {
            Log.w(TAG, "prepare skipped: cloud project number missing or not numeric")
            result.success(false)
            return
        }

        val manager = integrityManager
            ?: IntegrityManagerFactory.createStandard(applicationContext).also {
                integrityManager = it
            }

        manager.prepareIntegrityToken(
            PrepareIntegrityTokenRequest.builder()
                .setCloudProjectNumber(projectNumber)
                .build()
        ).addOnSuccessListener { provider ->
            tokenProvider = provider
            result.success(true)
        }.addOnFailureListener { e ->
            tokenProvider = null
            Log.w(TAG, "prepare failed: ${errorCodeOf(e)}")
            result.success(false)
        }
    }

    /**
     * Mints one token bound to [requestHash]. Returns the opaque token string,
     * or null on any failure - never an exception across the channel, so the
     * Dart side has a single, boring fail-open path.
     *
     * Tokens are never cached here. Google's guidance is explicit that caching
     * integrity verdicts increases proxying risk, and a cached token would also
     * defeat the request binding that requestHash exists to provide.
     */
    private fun requestToken(requestHash: String?, result: MethodChannel.Result) {
        if (requestHash.isNullOrEmpty()) {
            Log.w(TAG, "requestToken skipped: empty request hash")
            result.success(null)
            return
        }

        val provider = tokenProvider
        if (provider == null) {
            Log.w(TAG, "requestToken skipped: provider not prepared")
            result.success(null)
            return
        }

        provider.request(
            StandardIntegrityTokenRequest.builder()
                .setRequestHash(requestHash)
                .build()
        ).addOnSuccessListener { response ->
            result.success(response.token())
        }.addOnFailureListener { e ->
            val code = errorCodeOf(e)
            // Drop the cached provider so the next prepare() rebuilds it, rather
            // than every later request failing the same way.
            if (code == ERR_PROVIDER_INVALID) {
                tokenProvider = null
                Log.w(TAG, "provider expired; will re-prepare on next warm-up")
            } else {
                Log.w(TAG, "requestToken failed: $code")
            }
            result.success(null)
        }
    }

    private fun errorCodeOf(e: Exception): Int? =
        (e as? StandardIntegrityException)?.errorCode
}
