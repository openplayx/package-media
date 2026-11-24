package com.alexmercerind.mediakitandroidhelper;

import android.content.Context;
import android.net.Uri;
import androidx.annotation.Keep;

/**
 * JNI helper with the interface package:media_kit and media_kit_video use
 * (natives in package-media tool/android/mediakitandroidhelper.c).
 */
@Keep
public class MediaKitAndroidHelper {
  static {
    System.loadLibrary("mediakitandroidhelper");
  }

  private static Context applicationContext;

  public static native long newGlobalObjectRef(Object obj);

  public static native void deleteGlobalObjectRef(long ref);

  public static native String copyAssetToFilesDir(String assetName);

  private static native void setApplicationContextNative(Context context);

  public static native int openFileDescriptorNative(String uri);

  public static void setApplicationContextJava(Context context) {
    applicationContext = context;
    setApplicationContextNative(context);
  }

  public static int openFileDescriptorJava(String uri) {
    try {
      return applicationContext.getContentResolver().openFileDescriptor(Uri.parse(uri), "r").detachFd();
    } catch (Throwable e) {
      e.printStackTrace();
      return -1;
    }
  }
}
