package com.alexmercerind.media_kit_libs_android_video;

import androidx.annotation.NonNull;
import com.alexmercerind.mediakitandroidhelper.MediaKitAndroidHelper;
import io.flutter.embedding.engine.plugins.FlutterPlugin;

/** Loads libmpv and hands the application context to the JNI helper. */
public class MediaKitLibsAndroidVideoPlugin implements FlutterPlugin {
  static {
    // Older devices need System.loadLibrary before Dart's DynamicLibrary.open.
    try {
      System.loadLibrary("mpv");
    } catch (Throwable e) {
      e.printStackTrace();
    }
  }

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    try {
      MediaKitAndroidHelper.setApplicationContextJava(binding.getApplicationContext());
    } catch (Throwable e) {
      e.printStackTrace();
    }
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {}
}
