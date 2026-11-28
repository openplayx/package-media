// Deliberately invalid programs used only to prove CI instrumentation works.
// Never installed in the application bundle or shipped in a release.
#include <cstdlib>
#include <thread>

#ifndef __has_feature
#define __has_feature(x) 0
#endif

#if defined(OPX_SANITIZER_ADDRESS)
#if !defined(__SANITIZE_ADDRESS__) && !__has_feature(address_sanitizer)
#error AddressSanitizer instrumentation is not enabled
#endif
int main() {
  volatile unsigned index = 8;
  volatile char* data = static_cast<char*>(std::malloc(4));
  data[index] = 'x';  // Must report heap-buffer-overflow.
  std::free(const_cast<char*>(data));
  return 0;
}
#elif defined(OPX_SANITIZER_THREAD)
#if !defined(__SANITIZE_THREAD__) && !__has_feature(thread_sanitizer)
#error ThreadSanitizer instrumentation is not enabled
#endif
volatile int shared_value = 0;
int main() {
  auto write = [] { for (int i = 0; i < 10000; ++i) ++shared_value; };
  std::thread first(write), second(write);
  first.join();
  second.join();
  return 0;  // TSan must override this with its configured error exit code.
}
#else
#error A sanitizer mode must be selected
#endif
