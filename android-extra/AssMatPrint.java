package fr.lucas.cocon.parent;

import android.content.ContentValues;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.os.ParcelFileDescriptor;
import android.print.PdfPrint;
import android.print.PrintAttributes;
import android.print.PrintDocumentAdapter;
import android.print.PrintManager;
import android.provider.MediaStore;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

import java.io.File;
import java.io.FileOutputStream;

/**
 * Rendu de la fiche A4 : impression, enregistrement dans Telechargements,
 * et envoi par e-mail avec le PDF en piece jointe.
 */
@CapacitorPlugin(name = "AssMatPrint")
public class AssMatPrint extends Plugin {

    /** Sans cette reference le WebView est ramasse avant la fin du rendu. */
    private WebView enCours;

    private PrintAttributes attributsA4() {
        return new PrintAttributes.Builder()
                .setMediaSize(PrintAttributes.MediaSize.ISO_A4)
                .setMinMargins(PrintAttributes.Margins.NO_MARGINS)
                .build();
    }

    private String nomFichier(PluginCall call) {
        String nom = call.getString("name", "Fiche de salaire.pdf");
        if (!nom.toLowerCase().endsWith(".pdf")) nom = nom + ".pdf";
        return nom.replaceAll("[\\\\/:*?\"<>|]", "-");
    }

    /** Charge le HTML dans un WebView hors ecran puis execute l'action demandee. */
    private void rendre(final PluginCall call, final Action action) {
        final String html = call.getString("html", "");
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
                            try {
                                action.surRendu(vue);
                            } catch (Exception e) {
                                call.reject(String.valueOf(e.getMessage()));
                            }
                        }
                    });
                    enCours = wv;
                    wv.loadDataWithBaseURL(null, html, "text/html", "UTF-8", null);
                } catch (Exception e) {
                    call.reject(String.valueOf(e.getMessage()));
                }
            }
        });
    }

    private interface Action {
        void surRendu(WebView vue) throws Exception;
    }

    /** Boite de dialogue d'impression du systeme (propose « Enregistrer au format PDF »). */
    @PluginMethod
    public void printHTML(final PluginCall call) {
        rendre(call, new Action() {
            @Override
            public void surRendu(WebView vue) {
                PrintManager pm = (PrintManager) getContext().getSystemService(Context.PRINT_SERVICE);
                if (pm == null) {
                    call.reject("Service d'impression indisponible");
                    return;
                }
                String nom = nomFichier(call);
                pm.print(nom, vue.createPrintDocumentAdapter(nom), attributsA4());
                call.resolve();
            }
        });
    }

    /** Ecrit le PDF dans Telechargements et renvoie son adresse. */
    @PluginMethod
    public void exportPdf(final PluginCall call) {
        rendre(call, new Action() {
            @Override
            public void surRendu(WebView vue) throws Exception {
                ecrirePdf(vue, nomFichier(call), new SuiteEcriture() {
                    @Override
                    public void ok(Uri uri, String nom) {
                        JSObject res = new JSObject();
                        res.put("uri", uri.toString());
                        res.put("name", nom);
                        call.resolve(res);
                    }

                    @Override
                    public void ko(String message) {
                        call.reject(message);
                    }
                });
            }
        });
    }

    /** Ecrit le PDF puis ouvre le selecteur d'applications e-mail, piece jointe incluse. */
    @PluginMethod
    public void sharePdf(final PluginCall call) {
        rendre(call, new Action() {
            @Override
            public void surRendu(WebView vue) throws Exception {
                ecrirePdf(vue, nomFichier(call), new SuiteEcriture() {
                    @Override
                    public void ok(Uri uri, String nom) {
                        try {
                            Intent envoi = new Intent(Intent.ACTION_SEND);
                            envoi.setType("application/pdf");
                            envoi.putExtra(Intent.EXTRA_STREAM, uri);
                            envoi.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);

                            String to = call.getString("to", "");
                            if (!to.isEmpty()) envoi.putExtra(Intent.EXTRA_EMAIL, new String[]{to});
                            envoi.putExtra(Intent.EXTRA_SUBJECT, call.getString("subject", nom));
                            envoi.putExtra(Intent.EXTRA_TEXT, call.getString("body", ""));

                            Intent choix = Intent.createChooser(envoi, "Envoyer la fiche");
                            choix.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                            getContext().startActivity(choix);

                            JSObject res = new JSObject();
                            res.put("uri", uri.toString());
                            call.resolve(res);
                        } catch (Exception e) {
                            call.reject(String.valueOf(e.getMessage()));
                        }
                    }

                    @Override
                    public void ko(String message) {
                        call.reject(message);
                    }
                });
            }
        });
    }

    /** Partage un simple texte : e-mail, messagerie, ce que propose le systeme. */
    @PluginMethod
    public void shareText(final PluginCall call) {
        final String texte = call.getString("text", "");
        if (texte.isEmpty()) {
            call.reject("Aucun texte a partager");
            return;
        }
        getActivity().runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    Intent envoi = new Intent(Intent.ACTION_SEND);
                    envoi.setType("text/plain");
                    envoi.putExtra(Intent.EXTRA_TEXT, texte);

                    String sujet = call.getString("subject", "");
                    if (!sujet.isEmpty()) envoi.putExtra(Intent.EXTRA_SUBJECT, sujet);
                    String to = call.getString("to", "");
                    if (!to.isEmpty()) envoi.putExtra(Intent.EXTRA_EMAIL, new String[]{to});

                    Intent choix = Intent.createChooser(envoi, "Envoyer");
                    choix.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    getContext().startActivity(choix);
                    call.resolve();
                } catch (Exception e) {
                    call.reject(String.valueOf(e.getMessage()));
                }
            }
        });
    }

    /** Ecrit un fichier texte (.ics, .json) dans Telechargements et le partage. */
    @PluginMethod
    public void shareTextFile(final PluginCall call) {
        final String texte = call.getString("text", "");
        final String mime = call.getString("mime", "text/plain");
        String n = call.getString("name", "fichier.txt");
        final String nom = n.replaceAll("[\\\\/:*?\"<>|]", "-");

        if (texte.isEmpty()) {
            call.reject("Aucun contenu a partager");
            return;
        }
        getActivity().runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    Uri uri = ecrireDansTelechargements(nom, mime, texte.getBytes("UTF-8"));
                    if (uri == null) {
                        call.reject("Impossible d'ecrire le fichier");
                        return;
                    }
                    Intent envoi = new Intent(Intent.ACTION_SEND);
                    envoi.setType(mime);
                    envoi.putExtra(Intent.EXTRA_STREAM, uri);
                    envoi.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                    Intent choix = Intent.createChooser(envoi, "Ouvrir avec");
                    choix.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    getContext().startActivity(choix);

                    JSObject res = new JSObject();
                    res.put("uri", uri.toString());
                    res.put("name", nom);
                    call.resolve(res);
                } catch (Exception e) {
                    call.reject(String.valueOf(e.getMessage()));
                }
            }
        });
    }

    /** Depose des octets dans le dossier Telechargements et renvoie leur adresse. */
    private Uri ecrireDansTelechargements(String nom, String mime, byte[] donnees) throws Exception {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ContentValues v = new ContentValues();
            v.put(MediaStore.Downloads.DISPLAY_NAME, nom);
            v.put(MediaStore.Downloads.MIME_TYPE, mime);
            Uri uri = getContext().getContentResolver()
                    .insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, v);
            if (uri == null) return null;
            java.io.OutputStream flux = getContext().getContentResolver().openOutputStream(uri);
            flux.write(donnees);
            flux.close();
            return uri;
        }
        File dossier = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS);
        if (!dossier.exists()) dossier.mkdirs();
        File fichier = new File(dossier, nom);
        FileOutputStream flux = new FileOutputStream(fichier);
        flux.write(donnees);
        flux.close();
        return Uri.fromFile(fichier);
    }

    private interface SuiteEcriture {
        void ok(Uri uri, String nom);
        void ko(String message);
    }

    /**
     * Ecrit le rendu du WebView dans un PDF du dossier Telechargements.
     * Android 10 et plus : MediaStore, aucune permission requise.
     * Avant : ecriture directe, la permission etant accordee a l'installation.
     */
    private void ecrirePdf(WebView vue, final String nom, final SuiteEcriture suite) throws Exception {
        final PrintDocumentAdapter adaptateur = vue.createPrintDocumentAdapter(nom);
        final PdfPrint pdf = new PdfPrint(attributsA4());

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ContentValues valeurs = new ContentValues();
            valeurs.put(MediaStore.Downloads.DISPLAY_NAME, nom);
            valeurs.put(MediaStore.Downloads.MIME_TYPE, "application/pdf");
            valeurs.put(MediaStore.Downloads.IS_PENDING, 1);

            final Uri uri = getContext().getContentResolver()
                    .insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, valeurs);
            if (uri == null) {
                suite.ko("Impossible de creer le fichier dans Telechargements");
                return;
            }
            final ParcelFileDescriptor pfd = getContext().getContentResolver()
                    .openFileDescriptor(uri, "w");

            pdf.ecrire(adaptateur, pfd, new PdfPrint.Retour() {
                @Override
                public void termine() {
                    try { pfd.close(); } catch (Exception e) { /* deja ferme */ }
                    ContentValues fin = new ContentValues();
                    fin.put(MediaStore.Downloads.IS_PENDING, 0);
                    getContext().getContentResolver().update(uri, fin, null, null);
                    suite.ok(uri, nom);
                }

                @Override
                public void echec(String message) {
                    try { pfd.close(); } catch (Exception e) { /* deja ferme */ }
                    getContext().getContentResolver().delete(uri, null, null);
                    suite.ko(message);
                }
            });
        } else {
            File dossier = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS);
            if (!dossier.exists()) dossier.mkdirs();
            final File fichier = new File(dossier, nom);
            final ParcelFileDescriptor pfd = ParcelFileDescriptor.open(fichier,
                    ParcelFileDescriptor.MODE_CREATE
                            | ParcelFileDescriptor.MODE_READ_WRITE
                            | ParcelFileDescriptor.MODE_TRUNCATE);

            pdf.ecrire(adaptateur, pfd, new PdfPrint.Retour() {
                @Override
                public void termine() {
                    try { pfd.close(); } catch (Exception e) { /* deja ferme */ }
                    suite.ok(Uri.fromFile(fichier), nom);
                }

                @Override
                public void echec(String message) {
                    try { pfd.close(); } catch (Exception e) { /* deja ferme */ }
                    suite.ko(message);
                }
            });
        }
    }
}
