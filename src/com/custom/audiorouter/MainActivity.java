package com.custom.audiorouter;

import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Bundle;
import android.provider.Settings;
import android.widget.Toast;
import rikka.shizuku.Shizuku;

public class MainActivity extends Activity {
    private static final int OVERLAY_PERMISSION_REQ = 1001;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // 1. Verify Shizuku Binder state
        if (Shizuku.checkSelfPermission() != PackageManager.PERMISSION_GRANTED) {
            Shizuku.requestPermission(0);
            Toast.makeText(this, "Grant Shizuku permission and restart the app.", Toast.LENGTH_LONG).show();
            finish();
            return;
        }

        // 2. Verify system overlay clearance
        if (!Settings.canDrawOverlays(this)) {
            Intent intent = new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:" + getPackageName()));
            startActivityForResult(intent, OVERLAY_PERMISSION_REQ);
        } else {
            launchService();
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode == OVERLAY_PERMISSION_REQ && Settings.canDrawOverlays(this)) {
            launchService();
        }
    }

    private void launchService() {
        startService(new Intent(this, FloatingService.class));
        finish();
    }
}
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
