# Copyright 2019 The Bazel Authors. All rights reserved.
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

"""Aspect implementation for Swift static framework support."""

load(
    "@build_bazel_rules_swift//swift:swift.bzl",
    "SwiftInfo",
)
load("@bazel_skylib//lib:sets.bzl", "sets")

SwiftStaticFrameworkInfo = provider(
    fields = {
        "module_name": "The module name for the single swift_library dependency.",
        "swiftinterfaces": """
Dictionary of architecture to the generated swiftinterface file for that architecture.
""",
        "swiftdocs": """
Dictionary of architecture to the generated swiftdoc file for that architecture.
""",
        "generated_header": """
The generated Objective-C header for the single swift_library dependency.
""",
    },
    doc = """
Provider that collects artifacts required to build a Swift based static framework.
""",
)

def _swift_target_for_dep(dep):
    """Returns the target for which the dependency was compiled.

    This is really hacky, but there's no easy way to acquire the Apple CPU for which the target was
    built. One option would be to let this aspect propagate transitively through deps and have
    another provider that propagates the CPU, but the model there gets a bit more complicated to
    follow. With this approach, we avoid propagating the aspect transitively as well.

    This should be cleaned up when b/141931700 is fixed (adding support for ctx.rule.split_attr).
    """
    for action in dep.actions:
        if action.mnemonic == "SwiftCompile":
            target_found = False
            for arg in action.argv:
                if target_found:
                    return arg
                if arg == "-target":
                    target_found = True
    fail("error: Expected at least one Swift compilation action for target {}.".format(dep.label))

def _swift_arch_for_dep(dep):
    """Returns the architecture for which the dependency was built."""
    target = _swift_target_for_dep(dep)
    return target.split("-", 1)[0]

def _swift_static_framework_aspect_impl(target, ctx):
    """Aspect implementation for Swift static framework support."""

    # Only process the apple_static_library dependency, as that's the place where we can process the
    # first level dependencies of the static framework. This is only needed because static framework
    # rules (i.e. ios_static_framework) are still macros and not rules.
    # Once the static framework rules are migrated to rules instead of macros, this aspect can be
    # removed.
    if ctx.rule.kind != "apple_static_library":
        fail("Internal Error: Should only see the the apple_static_library as a dependency.")

    swiftdeps = [x for x in ctx.rule.attr.deps if SwiftInfo in x]

    # If there are no Swift dependencies, return nothing.
    if not swiftdeps:
        return []

    # Collect the names of any Swift modules reachable from `avoid_deps`. These
    # will be ignored when checking for a single `swift_library` below.
    avoid_swiftinfos = [t[SwiftInfo] for t in ctx.rule.attr.avoid_deps if SwiftInfo in t]
    avoid_modules = sets.make()
    for swiftinfo in avoid_swiftinfos:
        for module in swiftinfo.transitive_modules.to_list():
            if not module.swift:
                continue
            sets.insert(avoid_modules, module.name)

    # There can only be one (transitively) exposed swift_library in when wanting to expose a Swift
    # from the framework. And there can't really be exposed ObjC since it wouldn't be importable by
    # a Swift consumer, but don't bother checking that since it can be useful for other
    # libraries/sdks to add implementation detail objc_library instances that aren't exposed, but
    # need to be linked to provide a complete library.

    # Collect all relevant artifacts for Swift static framework generation.
    module_name = None
    generated_header = None
    swiftdocs = {}
    swiftinterfaces = {}
    for dep in swiftdeps:
        swiftinfo = dep[SwiftInfo]

        swiftinterface = None
        swiftdoc = None
        for module in swiftinfo.transitive_modules.to_list():
            if not module.swift or sets.contains(avoid_modules, module.name):
                continue
            if swiftinterface:
                fail(
                    """\
error: Found transitive swift_library dependencies. Swift static frameworks expect a single \
swift_library dependency with no transitive swift_library dependencies.\
""",
                )
            swiftinterface = module.swift.swiftinterface
            swiftdoc = module.swift.swiftdoc

            if not module_name:
                module_name = module.name
            elif module.name and module.name != module_name:
                fail(
                    """\
error: Found multiple direct swift_library dependencies. Swift static frameworks expect a single \
swift_library dependency with no transitive swift_library dependencies.\
""",
                )

        arch = _swift_arch_for_dep(dep)
        swiftdocs[arch] = swiftdoc
        swiftinterfaces[arch] = swiftinterface

        # Collect the interface artifacts. Only get the first element from each depset since
        # they should only contain 1. If there are transitive swift_library dependencies, this
        # aspect would have errored out before.
        #
        # If headers are generated, they should be generated equally for all archs, so
        # just take any of them.
        if not generated_header:
            for module in swiftinfo.direct_modules:
                # If this is both a Swift and a Clang module, then the header in its compilation
                # context is its Swift generated header.
                if module.swift and module.clang:
                    headers = module.clang.compilation_context.headers.to_list()
                    if headers:
                        generated_header = headers[0]

    # Make sure that all dictionaries contain at least one module before returning the provider.
    if all([module_name, swiftdocs, swiftinterfaces]):
        return [
            SwiftStaticFrameworkInfo(
                module_name = module_name,
                generated_header = generated_header,
                swiftdocs = swiftdocs,
                swiftinterfaces = swiftinterfaces,
            ),
        ]

    fail(
        """\
error: Could not find all required artifacts and information to build a Swift static framework. \
Please file an issue with a reproducible error case.\
""",
    )

swift_static_framework_aspect = aspect(
    implementation = _swift_static_framework_aspect_impl,
    doc = """
Aspect that collects Swift information to construct a static framework that supports Swift.
""",
)
