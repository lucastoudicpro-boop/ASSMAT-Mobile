package fr.lucas.assmat;

import android.os.Build;

import androidx.biometric.BiometricManager;
import androidx.biometric.BiometricPrompt;
import androidx.core.content.ContextCompat;
import androidx.fragment.app.FragmentActivity;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

/**
 * Deverrouillage par empreinte ou reconnaissance faciale.
 * Le code chiffre de l'application reste le recours : ce module ne fait que
 * confirmer une identite, il ne detient aucun secret.
 */
@CapacitorPlugin(name = "AssMatBio")
public class AssMatBio extends Plugin {

    private int autorises() {
        return BiometricManager.Authenticators.BIOMETRIC_WEAK;
    }

    @PluginMethod
    public void disponible(PluginCall call) {
        JSObject res = new JSObject();
        try {
            BiometricManager bm = BiometricManager.from(getContext());
            int etat = bm.canAuthenticate(autorises());
            res.put("disponible", etat == BiometricManager.BIOMETRIC_SUCCESS);
            res.put("etat", etat);
        } catch (Exception e) {
            res.put("disponible", false);
            res.put("etat", -1);
        }
        call.resolve(res);
    }

    @PluginMethod
    public void verifier(final PluginCall call) {
        getActivity().runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    FragmentActivity activite = (FragmentActivity) getActivity();

                    BiometricPrompt prompt = new BiometricPrompt(
                        activite,
                        ContextCompat.getMainExecutor(getContext()),
                        new BiometricPrompt.AuthenticationCallback() {
                            @Override
                            public void onAuthenticationSucceeded(BiometricPrompt.AuthenticationResult r) {
                                JSObject res = new JSObject();
                                res.put("ok", true);
                                call.resolve(res);
                            }

                            @Override
                            public void onAuthenticationError(int code, CharSequence message) {
                                JSObject res = new JSObject();
                                res.put("ok", false);
                                res.put("erreur", String.valueOf(message));
                                call.resolve(res);
                            }
                        });

                    BiometricPrompt.PromptInfo info = new BiometricPrompt.PromptInfo.Builder()
                            .setTitle("AssMat+")
                            .setSubtitle("Déverrouiller l'application")
                            .setNegativeButtonText("Utiliser le code")
                            .setAllowedAuthenticators(autorises())
                            .setConfirmationRequired(false)
                            .build();

                    prompt.authenticate(info);
                } catch (Exception e) {
                    call.reject(String.valueOf(e.getMessage()));
                }
            }
        });
    }
}
