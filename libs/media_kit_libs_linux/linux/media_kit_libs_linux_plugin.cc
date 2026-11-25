#include "include/media_kit_libs_linux/media_kit_libs_linux_plugin.h"

#include <locale.h>

// Carries libmpv only; media_kit loads it. mpv requires the C numeric locale.
void media_kit_libs_linux_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  setlocale(LC_NUMERIC, "C");
}
