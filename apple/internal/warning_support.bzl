# /third_party/bazel_rules/rules_apple/apple/internal/warning_support.bzl
# Copyright 2026 The Bazel Authors. All rights reserved.
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

"""Warning support methods for Apple rules."""

visibility([
    "@build_bazel_rules_apple//apple/...",
])

def _make_warning_handler(build_settings):
    """Returns a lambda that emits warnings or errors based on `build_settings`."""
    warnings_as_errors = build_settings.warnings_as_errors if build_settings != None else False

    def _warning_handler(*args, **kwargs):
        if warnings_as_errors:
            fail(*args, **kwargs)
        else:
            print_kwargs = {k: v for k, v in kwargs.items() if k != "attr"}
            attr = kwargs.get("attr")
            prefix = ("WARNING [%s]: " % attr) if attr else "WARNING: "
            if args:
                # buildifier: disable=print
                print("%s%s" % (prefix, args[0]), *args[1:], **print_kwargs)
            else:
                # buildifier: disable=print
                print(prefix, **print_kwargs)

    return _warning_handler

warning_support = struct(
    make_warning_handler = _make_warning_handler,
)
