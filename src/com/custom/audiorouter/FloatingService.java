package com.custom.audiorouter;

import android.app.Service;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.PixelFormat;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.View;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.Toast;

public class FloatingService extends Service {
    private WindowManager mWindowManager;
    private Button mFloatingButton;
    private Handler mMainHandler;

    @Override
    public IBinder onBind(Intent intent) { return null; }

    @Override
    public void onCreate() {
        super.onCreate();
        mMainHandler = new Handler(Looper.getMainLooper());

        mFloatingButton = new Button(this);
        mFloatingButton.setText("🎧 Earphone");
        mFloatingButton.setBackgroundColor(Color.DKGRAY);
        mFloatingButton.setTextColor(Color.WHITE);

        final WindowManager.LayoutParams params = new WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
                PixelFormat.TRANSLUCENT);

        params.gravity = Gravity.TOP | Gravity.START;
        params.x = 0;
        params.y = 200;

        mWindowManager = (WindowManager) getSystemService(WINDOW_SERVICE);
        mWindowManager.addView(mFloatingButton, params);

        mFloatingButton.setOnTouchListener(new View.OnTouchListener() {
            private int initialX;
            private int initialY;
            private float initialTouchX;
            private float initialTouchY;

            @Override
            public boolean onTouch(View v, MotionEvent event) {
                switch (event.getAction()) {
                    case MotionEvent.ACTION_DOWN:
                        initialX = params.x;
                        initialY = params.y;
                        initialTouchX = event.getRawX();
                        initialTouchY = event.getRawY();
                        return true;

                    case MotionEvent.ACTION_MOVE:
                        params.x = initialX + (int) (event.getRawX() - initialTouchX);
                        params.y = initialY + (int) (event.getRawY() - initialTouchY);
                        mWindowManager.updateViewLayout(mFloatingButton, params);
                        return true;

                    case MotionEvent.ACTION_UP:
                        float diffX = event.getRawX() - initialTouchX;
                        float diffY = event.getRawY() - initialTouchY;
                        if (Math.abs(diffX) < 10 && Math.abs(diffY) < 10) {
                            toggleAudioRouteNatively();
                        }
                        return true;
                }
                return false;
            }
        });
    }

    private void toggleAudioRouteNatively() {
        new Thread(() -> {
            try {
                // 1. Get the live hardware path to your app's compiled base.apk
                String apkPath = getApplicationInfo().sourceDir;
                
                // 2. Build the shell command using your app's APK as the direct CLASSPATH!
                String cmd = "CLASSPATH=" + apkPath + " app_process / com.custom.audiorouter.SystemRouter";
                
                // 3. Spawn a pure Shizuku root shell process to execute the bundle
                java.lang.reflect.Method newProcessMethod = rikka.shizuku.Shizuku.class.getDeclaredMethod(
                    "newProcess", String[].class, String[].class, String.class
                );
                newProcessMethod.setAccessible(true);
                
                Process process = (Process) newProcessMethod.invoke(
                    null, new String[]{"sh", "-c", cmd}, null, null
                );
                
                // 4. Read the output from SystemRouter's System.out.println()
                java.io.BufferedReader reader = new java.io.BufferedReader(new java.io.InputStreamReader(process.getInputStream()));
                String line = reader.readLine();
                process.waitFor();
                
                final String finalStatus = line != null ? line : "Unknown";

                // 5. Update UI Buttons
                mMainHandler.post(() -> {
                    if ("Speaker".equals(finalStatus)) {
                        mFloatingButton.setText("🔊 Speaker");
                        mFloatingButton.setBackgroundColor(Color.rgb(0, 150, 136));
                    } else if ("Earphone".equals(finalStatus)) {
                        mFloatingButton.setText("🎧 Earphone");
                        mFloatingButton.setBackgroundColor(Color.DKGRAY);
                    } else {
                        Toast.makeText(FloatingService.this, "Routing failed. Status: " + finalStatus, Toast.LENGTH_SHORT).show();
                    }
                });

            } catch (Exception e) {
                e.printStackTrace();
                mMainHandler.post(() -> 
                    Toast.makeText(FloatingService.this, "Shizuku Engine Failed", Toast.LENGTH_SHORT).show()
                );
            }
        }).start();
    }



    @Override
    public void onDestroy() {
        super.onDestroy();
        if (mFloatingButton != null) mWindowManager.removeView(mFloatingButton);
    }
}
