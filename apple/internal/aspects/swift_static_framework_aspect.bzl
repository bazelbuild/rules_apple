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
    if ctx.rule.kind == "apple_static_library":
        swiftdeps = [x for x in ctx.rule.attr.deps if SwiftInfo in x]

        # If there are no Swift dependencies, return nothing.
        if not swiftdeps:
            return []

        # If there's a different number of swift_library dependencies than all the declared
        # dependencies, then there must be a mix of dependency types, which is not allowed for Swift
        # based frameworks. We can't check that the count is exactly one since ctx.rule.attr.deps
        # might return multiple configured targets for the same target based on the split.
        # ctx.rule does not support split_attr, which seems to be an oversight. b/141931700 to track
        # this.
        if len(swiftdeps) != len(ctx.rule.attr.deps):
            fail(
                """\
error: Found a mix of swift_library and other rule dependencies. Swift static frameworks expect a \
single swift_library dependency with no transitive swift_library dependencies.\
""",
            )

        # Collect all relevant artifacts for Swift static framework generation.
        module_name = None
        generated_header = None
        swiftdocs = {}
        swiftinterfaces = {}
        for dep in swiftdeps:
            swiftinfo = dep[SwiftInfo]

            if len(swiftinfo.transitive_swiftinterfaces.to_list()) > 1:
                fail(
                    """\
error: Found transitive swift_library dependencies. Swift static frameworks expect a single \
swift_library dependency with no transitive swift_library dependencies.\
""",
                )

            if not module_name:
                module_name = swiftinfo.module_name
            elif module_name != swiftinfo.module_name:
                fail(
                    """\
error: Found multiple direct swift_library dependencies. Swift static frameworks expect a single \
swift_library dependency with no transitive swift_library dependencies.\
""",
                )

            arch = _swift_arch_for_dep(dep)

            # Collect the interface artifacts. Only get the first element from each depset since
            # they should only contain 1. If there are transitive swift_library dependencies, this
            # aspect would have errored out before.
            if swiftinfo.transitive_generated_headers:
                if not generated_header:
                    # If headers are generated, they should be generated equally for all archs, so
                    # just take any of them.
                    generated_header = swiftinfo.transitive_generated_headers.to_list()[0]

            swiftdocs[arch] = swiftinfo.transitive_swiftdocs.to_list()[0]
            swiftinterfaces[arch] = swiftinfo.transitive_swiftinterfaces.to_list()[0]

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
        else:
            fail(
                """\
error: Could not find all required artifacts and information to build a Swift static framework. \
Please file an issue with a reproducible error case.\
""",
            )

    # If the current target is not an apple_static_library, or there was nothing to propagate,
    # return nothing.
    return []

swift_static_framework_aspect = aspect(
    implementation = _swift_static_framework_aspect_impl,
    doc = """
Aspect that collects Swift information to construct a static framework that supports Swift.
""",
)
