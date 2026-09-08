package fr.lucas.assmat;

import android.os.Bundle;
import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    @Override
    public void onCreate(Bundle savedInstanceState) {
        registerPlugin(AssMatPrint.class);
        registerPlugin(AssMatBio.class);
        super.onCreate(savedInstanceState);
    }
}
