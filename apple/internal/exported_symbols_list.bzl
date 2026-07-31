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

"""Generates an exported-symbol list for a closed-world Apple framework."""

load(
    "@apple_support//lib:apple_support.bzl",
    "apple_support",
)
load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")

visibility([
    "//apple/...",
    "//test/...",
])

def _transitive_link_files(targets):
    """Returns static link inputs reachable through the targets' CcInfo."""
    files = {}
    for target in targets:
        # The providers constraint on the attributes makes this defensive
        # branch relevant only to unusual forwarding rules.
        if CcInfo not in target:
            continue

        # linking_context is already transitive, so this follows deps,
        # implementation_deps, and rule-specific forwarding without needing
        # to know which attributes each language rule uses.
        for linker_input in target[CcInfo].linking_context.linker_inputs.to_list():
            for library in linker_input.libraries:
                if library.static_library:
                    files[library.static_library.path] = library.static_library
                    continue

                if library.pic_static_library:
                    files[library.pic_static_library.path] = library.pic_static_library
                    continue

                for obj in library.objects:
                    files[obj.path] = obj
                for obj in library.pic_objects:
                    files[obj.path] = obj
    return files

def _sorted_files(files_by_path):
    return [files_by_path[path] for path in sorted(files_by_path.keys())]

def _exported_symbols_list_impl(ctx):
    framework_files = _transitive_link_files(ctx.attr.deps)
    if not framework_files:
        fail("deps must provide at least one static link input through CcInfo")

    client_files = _transitive_link_files(ctx.attr.clients)

    # A client CcInfo graph normally includes the framework libraries it uses.
    # Remove those inputs so references internal to the framework do not look
    # like client imports and unnecessarily widen the exported ABI.
    for framework_path in framework_files:
        client_files.pop(framework_path, None)

    if not client_files:
        fail("clients must provide at least one link input outside deps")

    framework_inputs = _sorted_files(framework_files)
    client_inputs = _sorted_files(client_files)
    framework_manifest = ctx.actions.declare_file(
        ctx.label.name + ".framework-inputs",
    )
    client_manifest = ctx.actions.declare_file(
        ctx.label.name + ".client-inputs",
    )
    exported_symbols = ctx.actions.declare_file(
        ctx.label.name + ".exported_symbols",
    )
    report = ctx.actions.declare_file(ctx.label.name + ".report.json")

    # Manifests keep the command line short and make analysis deterministic.
    ctx.actions.write(
        framework_manifest,
        "\n".join([file.path for file in framework_inputs]) + "\n",
    )
    ctx.actions.write(
        client_manifest,
        "\n".join([file.path for file in client_inputs]) + "\n",
    )

    args = ctx.actions.args()
    args.add("--framework-inputs", framework_manifest)
    args.add("--client-inputs", client_manifest)
    for additional_list in ctx.files.additional_exported_symbols_lists:
        args.add("--additional-exported-symbols", additional_list)
    if ctx.attr.preserve_all_non_swift_exports:
        args.add("--preserve-all-non-swift-exports")
    if ctx.executable.nm:
        args.add("--nm", ctx.executable.nm)
    args.add("--output", exported_symbols)
    args.add("--report", report)

    direct_inputs = [framework_manifest, client_manifest]
    direct_inputs.extend(ctx.files.additional_exported_symbols_lists)
    tools = []
    if ctx.executable.nm:
        tools.append(ctx.executable.nm)

    apple_support.run(
        actions = ctx.actions,
        apple_fragment = ctx.fragments.apple,
        arguments = [args],
        executable = ctx.executable._generator,
        inputs = depset(
            direct = direct_inputs,
            transitive = [
                depset(framework_inputs),
                depset(client_inputs),
            ],
        ),
        mnemonic = "AppleExportedSymbolsList",
        outputs = [exported_symbols, report],
        progress_message = "Deriving client-required exports for {}".format(ctx.label),
        tools = tools,
        xcode_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig],
    )

    return [
        DefaultInfo(files = depset([exported_symbols])),
        # The report is useful for audits, but it is not a linker input and
        # should not be downloaded by every consumer of the symbol list.
        OutputGroupInfo(report = depset([report])),
    ]

exported_symbols_list = rule(
    implementation = _exported_symbols_list_impl,
    attrs = dicts.add(apple_support.action_required_attrs(), {
        "additional_exported_symbols_lists": attr.label_list(
            allow_files = True,
            doc = """\
Optional authored symbol lists for runtime-discovered entry points that do not
appear as undefined symbols in `clients`.
""",
        ),
        "clients": attr.label_list(
            allow_empty = False,
            doc = """\
The complete set of application and extension link roots that may load the
framework. Pass library or binary targets that provide `CcInfo`, not bundle
targets that embed the framework, to avoid a dependency cycle.
""",
            mandatory = True,
            providers = [CcInfo],
        ),
        "deps": attr.label_list(
            allow_empty = False,
            doc = """\
The same library roots linked into the private framework. Their transitive
static definitions are the maximum possible export surface.
""",
            mandatory = True,
            providers = [CcInfo],
        ),
        "nm": attr.label(
            cfg = "exec",
            doc = """\
Optional `llvm-nm` executable. By default the selected Xcode's `llvm-nm` is
used through `xcrun`. Override this when the link inputs come from another LLVM
toolchain, especially when they contain LLVM bitcode.
""",
            executable = True,
        ),
        "preserve_all_non_swift_exports": attr.bool(
            default = True,
            doc = """\
Whether to retain every non-Swift definition conservatively for Objective-C
runtime and `dlsym` lookup. This can pull otherwise-unreferenced archive
members into the framework. Set this to `False` only when all runtime-discovered
entry points are absent or listed in `additional_exported_symbols_lists`.
""",
        ),
        "_generator": attr.label(
            cfg = "exec",
            default = "//tools/exported_symbols_list",
            executable = True,
        ),
    }),
    doc = """\
Derives the exported-symbol list for a closed-world, app-private framework.

The rule keeps definitions referenced by the declared client link graphs. By
default it also keeps every non-Swift definition because Objective-C runtime
lookup and `dlsym` do not necessarily leave static undefined references. That
conservative policy can pull otherwise-unreferenced archive members into the
framework; set `preserve_all_non_swift_exports = False` only after auditing
runtime lookup and listing its roots in `additional_exported_symbols_lists`.

```starlark
apple_exported_symbols_list(
    name = "private_framework_exports",
    deps = [":private_framework_lib"],
    clients = [
        ":app_binary_lib",
        ":extension_binary_lib",
    ],
)

ios_framework(
    name = "PrivateFramework",
    deps = [":private_framework_lib"],
    exported_symbols_lists = [":private_framework_exports"],
    ...
)
```

Bazel cannot discover reverse dependencies, so `clients` must name the complete
set explicitly. Do not use a client-derived list for a public framework: its
current consumers are not a stable public ABI contract.
""",
    exec_compatible_with = ["@platforms//os:macos"],
    fragments = ["apple"],
)
