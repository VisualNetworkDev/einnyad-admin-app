package com.visualnetworkdev.einnyad_admin_mobile

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import android.util.Base64
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.security.KeyStore
import java.util.UUID
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** No plaintext credential is persisted or cached. Every read requires a new
 * CryptoObject operation authorized by Android's biometric system. */
class BiometricVault(private val activity: FragmentActivity) {
    private val prefs = activity.getSharedPreferences("einnyad_biometric_vault", Context.MODE_PRIVATE)
    private val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
    private var prompt: BiometricPrompt? = null
    private var pending: Operation? = null

    private class Operation(
        val result: MethodChannel.Result,
        val execute: (Cipher) -> Any?,
        val cleanup: (Boolean) -> Unit = {},
    )

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "status" -> result.success(mapOf(
                    "available" to available(),
                    "enabled" to prefs.contains("ciphertext"),
                ))
                "save" -> save(call, result)
                "read" -> read(result)
                "delete" -> {
                    if (pending != null) { result.error("busy", "Termina la verificación actual.", null); return }
                    clear()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (_: KeyPermanentlyInvalidatedException) {
            clear()
            result.error("invalidated", "Cambió la biometría del teléfono. Entra con contraseña y activa el acceso rápido otra vez.", null)
        } catch (_: Exception) {
            result.error("unavailable", "No se pudo abrir el acceso rápido. Usa tu contraseña.", null)
        }
    }

    private fun available() = BiometricManager.from(activity)
        .canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG) == BiometricManager.BIOMETRIC_SUCCESS

    private fun save(call: MethodCall, result: MethodChannel.Result) {
        if (!ready(result)) return
        val email = call.argument<String>("email")?.trim().orEmpty()
        val password = call.argument<String>("password").orEmpty()
        if (email.isEmpty() || password.isEmpty()) {
            result.error("invalid", "Primero verifica tu correo y contraseña.", null)
            return
        }
        val oldAlias = prefs.getString("alias", null)
        val newAlias = "einnyad.quick_login." + UUID.randomUUID()
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(KeyGenParameterSpec.Builder(newAlias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .setUserAuthenticationRequired(true)
            .setUserAuthenticationValidityDurationSeconds(-1)
            .setInvalidatedByBiometricEnrollment(true)
            .build())
        val key = generator.generateKey()
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        try {
            cipher.init(Cipher.ENCRYPT_MODE, key)
            authenticate(cipher, Operation(result, { authenticatedCipher ->
                val bytes = JSONObject().put("email", email).put("password", password).toString().toByteArray(Charsets.UTF_8)
                try {
                    val encrypted = authenticatedCipher.doFinal(bytes)
                    check(prefs.edit()
                        .putString("alias", newAlias)
                        .putString("iv", Base64.encodeToString(authenticatedCipher.iv, Base64.NO_WRAP))
                        .putString("ciphertext", Base64.encodeToString(encrypted, Base64.NO_WRAP))
                        .commit())
                    if (oldAlias != null) runCatching { keyStore.deleteEntry(oldAlias) }
                    null
                } finally { bytes.fill(0) }
            }, { success -> if (!success) runCatching { keyStore.deleteEntry(newAlias) } }))
        } catch (error: Exception) {
            pending = null
            prompt = null
            runCatching { keyStore.deleteEntry(newAlias) }
            throw error
        }
    }

    private fun read(result: MethodChannel.Result) {
        if (!ready(result)) return
        val alias = prefs.getString("alias", null)
        val encoded = prefs.getString("ciphertext", null)
        val iv = prefs.getString("iv", null)
        if (alias == null || encoded == null || iv == null) {
            result.error("missing", "Activa el acceso rápido después de entrar con contraseña.", null)
            return
        }
        val key = keyStore.getKey(alias, null) as? SecretKey
        if (key == null) {
            clear()
            result.error("invalidated", "El acceso guardado ya no está disponible. Usa tu contraseña.", null)
            return
        }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(128, Base64.decode(iv, Base64.NO_WRAP)))
        authenticate(cipher, Operation(result, { authenticatedCipher ->
            val bytes = authenticatedCipher.doFinal(Base64.decode(encoded, Base64.NO_WRAP))
            try {
                val json = JSONObject(String(bytes, Charsets.UTF_8))
                mapOf("email" to json.getString("email"), "password" to json.getString("password"))
            } finally { bytes.fill(0) }
        }))
    }

    private fun ready(result: MethodChannel.Result): Boolean {
        if (pending != null) { result.error("busy", "Termina la verificación actual.", null); return false }
        if (!available()) { result.error("unavailable", "Configura una huella o un rostro compatible en los ajustes del teléfono, o usa tu contraseña.", null); return false }
        return true
    }

    private fun authenticate(cipher: Cipher, operation: Operation) {
        pending = operation
        prompt = BiometricPrompt(activity, ContextCompat.getMainExecutor(activity), object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationSucceeded(authentication: BiometricPrompt.AuthenticationResult) {
                val op = pending ?: return
                pending = null
                prompt = null
                try {
                    val authenticatedCipher = authentication.cryptoObject?.cipher ?: error("Missing crypto object")
                    val value = op.execute(authenticatedCipher)
                    op.cleanup(true)
                    op.result.success(value)
                } catch (_: Exception) {
                    op.cleanup(false)
                    op.result.error("invalidated", "No se pudo desbloquear el acceso. Usa tu contraseña y vuelve a activarlo.", null)
                }
            }

            override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                val op = pending ?: return
                pending = null
                prompt = null
                op.cleanup(false)
                val cancelled = errorCode == BiometricPrompt.ERROR_USER_CANCELED ||
                    errorCode == BiometricPrompt.ERROR_NEGATIVE_BUTTON || errorCode == BiometricPrompt.ERROR_CANCELED
                op.result.error(if (cancelled) "cancelled" else "unavailable", if (cancelled) "Verificación cancelada." else "No se pudo verificar tu identidad. Usa tu contraseña.", null)
            }
        })
        try { prompt!!.authenticate(BiometricPrompt.PromptInfo.Builder()
            .setTitle("Acceso rápido a EinnyadNails")
            .setSubtitle("Confirma tu huella o rostro compatible")
            .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
            .setNegativeButtonText("Usar contraseña")
            .build(), BiometricPrompt.CryptoObject(cipher))
        } catch (error: Exception) {
            pending = null
            prompt = null
            operation.cleanup(false)
            throw error
        }
    }

    private fun clear() {
        val alias = prefs.getString("alias", null)
        prefs.edit().clear().commit()
        if (alias != null && keyStore.containsAlias(alias)) keyStore.deleteEntry(alias)
    }

    fun cancel() { prompt?.cancelAuthentication() }
}
