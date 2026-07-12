package com.custom.audiorouter;

import java.lang.reflect.Method;

public class SystemRouter {
    public static void main(String[] args) {
        try {
            int FOR_MEDIA = 1;
            int FORCE_SPEAKER = 1;
            int FORCE_NONE = 0;
            
            Class<?> audioSystemClass = Class.forName("android.media.AudioSystem");
            Method setForceUseMethod = audioSystemClass.getMethod("setForceUse", int.class, int.class);
            Method getForceUseMethod = audioSystemClass.getMethod("getForceUse", int.class);
            
            // Read the hardware's active configuration
            int currentState = (Integer) getForceUseMethod.invoke(null, FOR_MEDIA);
            
            if (currentState == FORCE_SPEAKER) {
                setForceUseMethod.invoke(null, FOR_MEDIA, FORCE_NONE);
                System.out.println("Earphone"); // Streamed back to the FloatingService
            } else {
                setForceUseMethod.invoke(null, FOR_MEDIA, FORCE_SPEAKER);
                System.out.println("Speaker"); // Streamed back to the FloatingService
            }
            System.exit(0);
        } catch (Exception e) {
            System.err.println("Error: " + e.getMessage());
            System.exit(1);
        }
    }
}
