// JNI helper that package:media_kit expects next to libmpv on Android
// (libmediakitandroidhelper.so). Written for OpenPlayX against media_kit's
// interface: com.alexmercerind.mediakitandroidhelper.MediaKitAndroidHelper
// natives, plus the C functions media_kit's Dart code looks up.
#include <android/api-level.h>
#include <android/asset_manager_jni.h>
#include <jni.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/system_properties.h>

#define EXPORT __attribute__((visibility("default")))

static JavaVM *g_vm;
static jobject g_context;
static char g_files_dir[1024];

EXPORT jint JNI_OnLoad(JavaVM *vm, void *reserved) {
  (void)reserved;
  g_vm = vm;
  return JNI_VERSION_1_6;
}

static JNIEnv *env_for_thread(void) {
  JNIEnv *env = NULL;
  if (!g_vm) return NULL;
  if ((*g_vm)->GetEnv(g_vm, (void **)&env, JNI_VERSION_1_6) == JNI_EDETACHED &&
      (*g_vm)->AttachCurrentThread(g_vm, &env, NULL) != JNI_OK)
    return NULL;
  return env;
}

// --- C functions looked up by media_kit (lib/src/player/native/utils/android_helper.dart)

EXPORT void *MediaKitAndroidHelperGetJavaVM(void) { return g_vm; }

EXPORT const char *MediaKitAndroidHelperGetFilesDir(void) { return g_files_dir; }

EXPORT int32_t MediaKitAndroidHelperIsEmulator(void) {
  char value[PROP_VALUE_MAX] = {0};
  if (__system_property_get("ro.kernel.qemu", value) > 0 && value[0] == '1') return 1;
  if (__system_property_get("ro.hardware", value) > 0 &&
      (strstr(value, "goldfish") || strstr(value, "ranchu")))
    return 1;
  if (__system_property_get("ro.product.model", value) > 0 && strstr(value, "sdk")) return 1;
  return 0;
}

EXPORT int32_t MediaKitAndroidHelperGetAPILevel(void) { return android_get_device_api_level(); }

// --- MediaKitAndroidHelper natives

#define JNI(name) Java_com_alexmercerind_mediakitandroidhelper_MediaKitAndroidHelper_##name

EXPORT jlong JNICALL JNI(newGlobalObjectRef)(JNIEnv *env, jclass cls, jobject obj) {
  (void)cls;
  return (jlong)(intptr_t)(*env)->NewGlobalRef(env, obj);
}

EXPORT void JNICALL JNI(deleteGlobalObjectRef)(JNIEnv *env, jclass cls, jlong ref) {
  (void)cls;
  if (ref) (*env)->DeleteGlobalRef(env, (jobject)(intptr_t)ref);
}

EXPORT void JNICALL JNI(setApplicationContextNative)(JNIEnv *env, jclass cls, jobject context) {
  (void)cls;
  if (g_context) (*env)->DeleteGlobalRef(env, g_context);
  g_context = (*env)->NewGlobalRef(env, context);
  // context.getFilesDir().getAbsolutePath()
  jclass ctx_cls = (*env)->GetObjectClass(env, context);
  jmethodID get_files = (*env)->GetMethodID(env, ctx_cls, "getFilesDir", "()Ljava/io/File;");
  jobject dir = (*env)->CallObjectMethod(env, context, get_files);
  if (!dir) return;
  jclass file_cls = (*env)->GetObjectClass(env, dir);
  jmethodID abs = (*env)->GetMethodID(env, file_cls, "getAbsolutePath", "()Ljava/lang/String;");
  jstring path = (jstring)(*env)->CallObjectMethod(env, dir, abs);
  const char *chars = (*env)->GetStringUTFChars(env, path, NULL);
  snprintf(g_files_dir, sizeof g_files_dir, "%s", chars);
  (*env)->ReleaseStringUTFChars(env, path, chars);
}

// Copies an APK asset (flutter_assets/...) into filesDir; returns its path or "".
EXPORT jstring JNICALL JNI(copyAssetToFilesDir)(JNIEnv *env, jclass cls, jstring name) {
  (void)cls;
  char out_path[2048] = {0};
  if (!g_context || !g_files_dir[0]) return (*env)->NewStringUTF(env, "");
  jclass ctx_cls = (*env)->GetObjectClass(env, g_context);
  jmethodID get_assets =
      (*env)->GetMethodID(env, ctx_cls, "getAssets", "()Landroid/content/res/AssetManager;");
  jobject java_assets = (*env)->CallObjectMethod(env, g_context, get_assets);
  AAssetManager *assets = AAssetManager_fromJava(env, java_assets);
  const char *asset_name = (*env)->GetStringUTFChars(env, name, NULL);
  AAsset *asset = assets ? AAssetManager_open(assets, asset_name, AASSET_MODE_STREAMING) : NULL;
  if (asset) {
    const char *base = strrchr(asset_name, '/');
    snprintf(out_path, sizeof out_path, "%s/%s", g_files_dir, base ? base + 1 : asset_name);
    FILE *out = fopen(out_path, "wb");
    if (out) {
      char buffer[65536];
      int n;
      while ((n = AAsset_read(asset, buffer, sizeof buffer)) > 0) fwrite(buffer, 1, (size_t)n, out);
      fclose(out);
    } else {
      out_path[0] = 0;
    }
    AAsset_close(asset);
  }
  (*env)->ReleaseStringUTFChars(env, name, asset_name);
  return (*env)->NewStringUTF(env, out_path);
}

// content:// URIs: calls back MediaKitAndroidHelper.openFileDescriptorJava.
EXPORT jint JNICALL JNI(openFileDescriptorNative)(JNIEnv *env, jclass cls, jstring uri) {
  jmethodID open = (*env)->GetStaticMethodID(env, cls, "openFileDescriptorJava", "(Ljava/lang/String;)I");
  return open ? (*env)->CallStaticIntMethod(env, cls, open, uri) : -1;
}

// For native callers (mpv's fd:// via content resolvers) on any thread.
EXPORT int MediaKitAndroidHelperOpenFileDescriptor(const char *uri) {
  JNIEnv *env = env_for_thread();
  if (!env) return -1;
  jclass cls = (*env)->FindClass(env, "com/alexmercerind/mediakitandroidhelper/MediaKitAndroidHelper");
  if (!cls) return -1;
  jint fd = JNI(openFileDescriptorNative)(env, cls, (*env)->NewStringUTF(env, uri));
  return fd;
}
