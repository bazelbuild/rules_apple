// Copyright 2026 The Bazel Authors. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include <dlfcn.h>
#include <mach-o/ldsyms.h>
#include <stdio.h>

int main(void) {
  void *header = dlsym(RTLD_MAIN_ONLY, MH_EXECUTE_SYM);
  Dl_info image = {0};
  if (!header || !dladdr(header, &image) || image.dli_fbase != header) {
    fprintf(stderr, "The executable header must remain discoverable.\n");
    return 1;
  }
  if (dlsym(RTLD_MAIN_ONLY, "main")) {
    fprintf(stderr, "Ordinary executable symbols must not be exported.\n");
    return 1;
  }
  return 0;
}
