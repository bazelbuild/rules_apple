# Copyright 2024 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Implementation of the `use_runfiles_hint` rule."""

load(
    "//apple/internal:providers.bzl",
    "new_appleresourceinfo",
)

def _use_runfiles_hint_impl(ctx):
    # Create an empty AppleResourceInfo to signify that
    # this target wants runfiles.
    return new_appleresourceinfo()

use_runfiles_hint = rule(
    attrs = {
    },
    doc = """\
Defines an aspect hint that generates an appropriate AppleResourceInfo based on the
runfiles for this target.

> [!NOTE]
> Bazel 6 users must set the `--experimental_enable_aspect_hints` flag to utilize
> this rule. In addition, downstream consumers of rules that utilize this rule
> must also set the flag. The flag is enabled by default in Bazel 7.

Some rules like `cc_library` may have data associated with them in the data attribute
that is needed at runtime. If the library was linked in a `cc_binary` then those data
files would be made available to the application as `runfiles`. To have similar
functionality with a `macos_application` you may use this aspect hint.

Adding this aspect to a cc_library will include the entire runfiles tree so you only
need to add the aspect to your main cc_library. There is no need to add the aspect to
libraries that are transitive dependencies.


#### Adding runfiles to a cc_library

If you want to add runfiles to the Contents/Resources folder of a `macos_application`
then apply this aspect to your cc_library.

```build
# //my/project/BUILD
cc_library(
    name = "somelib",
    data = ["mydata.txt"],
    aspect_hints = ["@build_bazel_rules_apple//apple:use_runfiles"],
)
```
""",
    implementation = _use_runfiles_hint_impl,
)
