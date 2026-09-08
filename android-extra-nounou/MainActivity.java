package fr.lucas.cocon.nounou;

import android.os.Bundle;
import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    @Override
    public void onCreate(Bundle savedInstanceState) {
        registerPlugin(CoconBio.class);
        super.onCreate(savedInstanceState);
    }
}
