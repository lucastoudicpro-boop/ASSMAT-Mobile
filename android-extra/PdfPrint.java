/*
 * Ce fichier est volontairement dans le paquet android.print : les classes de
 * rappel PrintDocumentAdapter.LayoutResultCallback et WriteResultCallback ont
 * un constructeur accessible au seul paquet. C'est la seule facon d'ecrire un
 * PDF dans un fichier sans passer par la boite de dialogue d'impression.
 */
package android.print;

import android.os.CancellationSignal;
import android.os.ParcelFileDescriptor;

public class PdfPrint {

    public interface Retour {
        void termine();
        void echec(String message);
    }

    private final PrintAttributes attributs;

    public PdfPrint(PrintAttributes attributs) {
        this.attributs = attributs;
    }

    public void ecrire(final PrintDocumentAdapter adaptateur,
                       final ParcelFileDescriptor sortie,
                       final Retour retour) {

        adaptateur.onLayout(null, attributs, null,
            new PrintDocumentAdapter.LayoutResultCallback() {
                @Override
                public void onLayoutFinished(PrintDocumentInfo info, boolean modifie) {
                    adaptateur.onWrite(
                        new PageRange[]{PageRange.ALL_PAGES},
                        sortie,
                        new CancellationSignal(),
                        new PrintDocumentAdapter.WriteResultCallback() {
                            @Override
                            public void onWriteFinished(PageRange[] pages) {
                                if (pages != null && pages.length > 0) retour.termine();
                                else retour.echec("Document vide");
                            }

                            @Override
                            public void onWriteFailed(CharSequence erreur) {
                                retour.echec(String.valueOf(erreur));
                            }

                            @Override
                            public void onWriteCancelled() {
                                retour.echec("Ecriture annulee");
                            }
                        });
                }

                @Override
                public void onLayoutFailed(CharSequence erreur) {
                    retour.echec(String.valueOf(erreur));
                }

                @Override
                public void onLayoutCancelled() {
                    retour.echec("Mise en page annulee");
                }
            }, null);
    }
}
