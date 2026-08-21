// Optional memory shim for tests run through `xcodebuild test-without-building`.
//
// xcodebuild captures the test process's stdout/stderr into its structured
// session log with roughly 26x per-byte memory overhead: 300MB of test output
// drives the xcodebuild client to ~8GB resident. For log-heavy suites this -
// not attachments - is usually what limits simulator parallelism.
//
// Link this library into a test's `deps` and set
// RULES_APPLE_REDIRECT_TEST_OUTPUT (e.g. via the test rule's `env`
// attribute) to choose which of the test process's streams are redirected at
// load time to $TEST_UNDECLARED_OUTPUTS_DIR/test_process_output.log (which
// Bazel delivers in the test outputs zip):
//   - "stdout": redirect standard output (Swift `print`, C stdio).
//   - "stderr": redirect standard error (NSLog and friends).
//   - "all":    redirect both.
//
// IMPORTANT: XCTest emits its own test-result lines ("Test Suite ...",
// "Executed N tests") on one of these streams, and the test runner greps
// them to decide whether tests ran. Redirecting the stream that carries them
// breaks that verdict. Only redirect the stream your suite actually spams;
// see the target's documentation for which modes are safe with
// ios_xctestrun_runner.
#import <Foundation/Foundation.h>
#include <fcntl.h>
#include <limits.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

__attribute__((constructor)) static void RulesAppleInstallOutputRedirect(void) {
  const char *mode = getenv("RULES_APPLE_REDIRECT_TEST_OUTPUT");
  if (!mode) return;
  int redirect_out = strcmp(mode, "stdout") == 0 || strcmp(mode, "all") == 0;
  int redirect_err = strcmp(mode, "stderr") == 0 || strcmp(mode, "all") == 0;
  if (!redirect_out && !redirect_err) return;
  const char *outDir = getenv("TEST_UNDECLARED_OUTPUTS_DIR");
  if (!outDir) {
    NSLog(@"RulesAppleOutputRedirect: TEST_UNDECLARED_OUTPUTS_DIR unset; redirect inactive");
    return;
  }
  char path[PATH_MAX];
  snprintf(path, sizeof(path), "%s/test_process_output.log", outDir);
  int fd = open(path, O_WRONLY | O_CREAT | O_APPEND, 0644);
  if (fd < 0) {
    NSLog(@"RulesAppleOutputRedirect: cannot open %s; redirect inactive", path);
    return;
  }
  // Announce before redirecting so the pointer survives in the session log.
  NSLog(@"RulesAppleOutputRedirect: %s -> %s", mode, path);
  if (redirect_out) dup2(fd, STDOUT_FILENO);
  if (redirect_err) dup2(fd, STDERR_FILENO);
  close(fd);
}
