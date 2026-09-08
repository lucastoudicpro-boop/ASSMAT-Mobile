package fr.lucas.assmat;

import android.content.Context;
import android.print.PrintAttributes;
import android.print.PrintDocumentAdapter;
import android.print.PrintManager;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

/**
 * Impression de la fiche A4 via le service d'impression d'Android.
 * Le menu propose « Enregistrer au format PDF » : le rendu est vectoriel,
 * identique a celui de la version PC (meme moteur Chromium).
 */
@CapacitorPlugin(name = "AssMatPrint")
public class AssMatPrint extends Plugin {

    /** Reference conservee : sans elle le WebView est ramasse avant la fin du rendu. */
    private WebView enCours;

    @PluginMethod
    public void printHTML(final PluginCall call) {
        final String html = call.getString("html", "");
        final String nom = call.getString("name", "Fiche de salaire");

        if (html.isEmpty()) {
            call.reject("Aucun contenu a imprimer");
            return;
        }

        getActivity().runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    final WebView wv = new WebView(getContext());
                    wv.getSettings().setJavaScriptEnabled(false);
                    wv.setWebViewClient(new WebViewClient() {
                        @Override
                        public void onPageFinished(WebView vue, String url) {
                            PrintManager pm = (PrintManager) getContext()
                                    .getSystemService(Context.PRINT_SERVICE);
                            if (pm == null) {
                                call.reject("Service d'impression indisponible");
                                return;
                            }
                            PrintAttributes attrs = new PrintAttributes.Builder()
                                    .setMediaSize(PrintAttributes.MediaSize.ISO_A4)
                                    .setMinMargins(PrintAttributes.Margins.NO_MARGINS)
                                    .build();
                            PrintDocumentAdapter adapter = vue.createPrintDocumentAdapter(nom);
                            pm.print(nom, adapter, attrs);
                            call.resolve();
                        }
                    });
                    enCours = wv;
                    wv.loadDataWithBaseURL(null, html, "text/html", "UTF-8", null);
                } catch (Exception e) {
                    call.reject(e.getMessage());
                }
            }
        });
    }
}
