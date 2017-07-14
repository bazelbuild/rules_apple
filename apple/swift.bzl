# Copyright 2017 The Bazel Authors. All rights reserved.
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

"""Skylark rules for Swift."""

load("@build_bazel_rules_apple//apple/bundling:apple_bundling_aspect.bzl",
     "apple_bundling_aspect")
load("@build_bazel_rules_apple//apple:providers.bzl",
     "AppleResourceInfo",
     "SwiftInfo")
load("@build_bazel_rules_apple//apple:utils.bzl",
     "xcrun_action",
     "XCRUNWRAPPER_LABEL",
     "module_cache_path",
     "label_scoped_path")
load("@build_bazel_rules_apple//apple/bundling:xcode_support.bzl",
     "xcode_support")

def _parent_dirs(dirs):
  """Returns a set of parent directories for each directory in dirs."""
  return depset([f.rpartition("/")[0] for f in dirs])


def _framework_names(dirs):
  """Returns the framework name for each directory in dir."""
  return depset([f.rpartition("/")[2].partition(".")[0] for f in dirs])


def _intersperse(separator, iterable):
  """Inserts separator before each item in iterable."""
  result = []
  for x in iterable:
    result.append(separator)
    result.append(x)

  return result


def _swift_target(cpu, platform, sdk_version):
  """Returns a target triplet for Swift compiler."""
  platform_string = str(platform.platform_type)
  if platform_string not in ["ios", "watchos", "tvos", "macos"]:
    fail("Platform '%s' is not supported" % platform_string)
  if platform_string == "macos":
    platform_string = "macosx"

  return "%s-apple-%s%s" % (cpu, platform_string, sdk_version)


def _swift_compilation_mode_flags(config_vars, objc_fragment):
  """Returns additional `swiftc` flags for the current compilation mode.

  Args:
    config_vars: The dictionary of configuration variables (i.e., `ctx.var`)
        that affect compilation of this target.
    objc_fragment: The Objective-C configuration fragment.
  Returns:
    The additional command line flags to pass to `swiftc`.
  """
  mode = config_vars["COMPILATION_MODE"]

  flags = []
  if mode == "dbg" or mode == "fastbuild":
    # TODO(dmishe): Find a way to test -serialize-debugging-options
    flags += [
        "-Onone", "-DDEBUG", "-enable-testing", "-Xfrontend",
        "-serialize-debugging-options"
    ]
  elif mode == "opt":
    flags += ["-O", "-DNDEBUG"]

  if mode == "dbg" or objc_fragment.generate_dsym:
    flags.append("-g")

  return flags


def _clang_compilation_mode_flags(objc_fragment):
  """Returns additional clang flags for the current compilation mode."""

  # In general, every compilation mode flag from native objc_ rules should be
  # passed, but -g seems to break Clang module compilation. Since this flag does
  # not make much sense for module compilation and only touches headers,
  # it's ok to omit.
  native_clang_flags = objc_fragment.copts_for_current_compilation_mode

  return [x for x in native_clang_flags if x != "-g"]


def _swift_bitcode_flags(apple_fragment):
  """Returns bitcode flags based on selected mode."""
  mode = str(apple_fragment.bitcode_mode)
  if mode == "embedded":
    return ["-embed-bitcode"]
  elif mode == "embedded_markers":
    return ["-embed-bitcode-marker"]

  return []


def _swift_sanitizer_flags(config_vars):
  """Returns sanitizer mode flags."""
  sanitizer = config_vars.get("apple_swift_sanitize")
  if not sanitizer:
    return []
  elif sanitizer == "address":
    return ["-sanitize=address"]
  else:
    fail("Swift sanitizer '%s' is not supported" % sanitizer)


def swift_module_name(label):
  """Returns a module name for the given label."""
  return label.package.lstrip("//").replace("/", "_") + "_" + label.name


def _swift_lib_dir(apple_fragment, config_vars, is_static=False):
  """Returns the location of Swift runtime directory to link against.

  Args:
    apple_fragment: The Apple configuration fragment.
    config_vars: The dictionary of configuration variables (i.e., `ctx.var`)
        that affect compilation of this target.
    is_static: If True, the static library directory will be used instead of the
        dynamic library directory (currently available only on macOS).
  Returns:
    The location of the Swift runtime directory to link against.
  """
  dir_name = "swift_static" if is_static else "swift"
  platform_str = apple_fragment.single_arch_platform.name_in_plist.lower()

  if "xcode_toolchain_path" in config_vars:
    return "{0}/usr/lib/{1}/{2}".format(
        config_vars["xcode_toolchain_path"], dir_name, platform_str)

  toolchain_name = "XcodeDefault"
  if hasattr(apple_fragment, "xcode_toolchain"):
    toolchain = apple_fragment.xcode_toolchain

    # We cannot use non Xcode-packaged toolchains, and the only one non-default
    # toolchain known to exist (as of Xcode 8.1) is this one.
    # TODO(b/29338444): Write an integration test when Xcode 8 is available.
    if toolchain == "com.apple.dt.toolchain.Swift_2_3":
      toolchain_name = "Swift_2.3"

  return "{0}/Toolchains/{1}.xctoolchain/usr/lib/{2}/{3}".format(
      apple_common.apple_toolchain().developer_dir(), toolchain_name,
      dir_name, platform_str)


def swift_linkopts(apple_fragment, config_vars, is_static=False):
  """Returns additional linker arguments needed to link Swift.

  Args:
    apple_fragment: The Apple configuration fragment.
    config_vars: The dictionary of configuration variables (i.e., `ctx.var`)
        that affect compilation of this target.
    is_static: If True, the static library directory will be used instead of the
        dynamic library directory (currently available only on macOS).
  Returns:
    Additional linker arguments needed to link Swift.
  """
  return ["-L" + _swift_lib_dir(apple_fragment, config_vars, is_static)]


def _swift_xcrun_args(apple_fragment):
  """Returns additional arguments that should be passed to xcrun.

  Args:
    apple_fragment: The `apple` configuration fragment.
  Returns:
    A list of flags, possibly empty, that should be passed to xcrun.
  """
  if apple_fragment.xcode_toolchain:
    return ["--toolchain", apple_fragment.xcode_toolchain]

  return []


def _swift_parsing_flags(srcs):
  """Returns additional parsing flags for swiftc."""
  # swiftc has two different parsing modes: script and library.
  # The difference is that in script mode top-level expressions are allowed.
  # This mode is triggered when the file compiled is called main.swift.
  # Additionally, script mode is used when there's just one file in the
  # compilation. we would like to avoid that and therefore force library mode
  # when there's only one source and it's not called main.
  if len(srcs) == 1 and srcs[0].basename != "main.swift":
    return ["-parse-as-library"]
  return []


def _is_valid_swift_module_name(string):
  """Returns True if the string is a valid Swift module name."""
  if not string:
    return False

  for char in string:
    # Check that the character is in [a-zA-Z0-9_]
    if not (char.isalnum() or char == "_"):
      return False

  return True


def _validate_rule_and_deps(ctx):
  """Validates the target and its dependencies."""

  name_error_str = ("Error in target '%s', Swift target and its dependencies' "+
                    "names can only contain characters in [a-zA-Z0-9_].")

  # Validate the name of the target
  if not _is_valid_swift_module_name(ctx.label.name):
    fail(name_error_str % ctx.label)

  # Validate names of the dependencies
  for dep in ctx.attr.deps:
    if not _is_valid_swift_module_name(dep.label.name):
      fail(name_error_str % dep.label)


def _get_wmo_state(copts, swift_fragment):
  """Returns the status of Whole Module Optimization feature.

  Whole Module Optimization can be enabled for the whole build by setting a
  bazel flag, in which case we still need to insert a corresponding compiler
  flag into the swiftc command line.

  It can also be enabled per target, by putting the compiler flag
  (-whole-module-optimization or -wmo) into the copts of the target.
  In this case, the compiler flag is already there, and we need not to
  insert one.

  This method checks whether WMO is enabled, and if it is, whether the compiler
  flag is already present.

  Args:
    copts: The list of copts to search for WMO flags.
    swift_fragment: The Swift configuration fragment.
  Returns:
    A tuple with two booleans. First value indicates whether WMO has been
    enabled, the second indicates whether a compiler flag is needed.
  """
  has_wmo = False
  has_flag = False

  if "-wmo" in copts or "-whole-module-optimization" in copts:
    has_wmo = True
    has_flag = True
  elif swift_fragment.enable_whole_module_optimization():
    has_wmo = True
    has_flag = False

  return has_wmo, has_flag


def swift_compile_requirements(
    srcs,
    deps,
    module_name,
    label,
    swift_version,
    copts,
    defines,
    apple_fragment,
    objc_fragment,
    swift_fragment,
    config_vars,
    default_configuration,
    genfiles_dir):
  """Returns a struct that contains the requirements to compile Swift code.

  Args:
    srcs: The list of `*.swift` sources to compile.
    deps: The list of targets that are dependencies for the sources being
        compiled.
    module_name: The name of the Swift module to which the compiled files
        belong.
    label: The label used to generate the Swift module name if one was not
        provided.
    swift_version: The Swift language version to pass to the compiler.
    copts: A list of compiler options to pass to `swiftc`. Defaults to an empty
        list.
    defines: A list of compiler defines to pass to `swiftc`. Defaults to an
        empty list.
    apple_fragment: The Apple configuration fragment.
    objc_fragment: The Objective-C configuration fragment.
    swift_fragment: The Swift configuration fragment.
    config_vars: The dictionary of configuration variables (i.e., `ctx.var`)
        that affect compilation of this target.
    default_configuration: The default configuration retrieved from the rule
        context.
    genfiles_dir: The directory where genfiles are written.
  Returns:
    A structure that contains the information required to compile Swift code.
  """
  return struct(
      srcs=srcs,
      deps=deps,
      module_name=module_name,
      label=label,
      swift_version=swift_version,
      copts=copts,
      defines=defines,
      apple_fragment=apple_fragment,
      objc_fragment=objc_fragment,
      swift_fragment=swift_fragment,
      config_vars=config_vars,
      default_configuration=default_configuration,
      genfiles_dir=genfiles_dir,
  )


def swiftc_inputs(ctx):
  """Determine the list of inputs required for the compile action.

  Args:
    ctx: rule context.

  Returns:
    A list of files needed by swiftc.
  """
  # TODO(allevato): Simultaneously migrate callers off this function and swap it
  # out with swiftc_inputs.
  return _swiftc_inputs(ctx.files.srcs, ctx.attr.deps)


def _swiftc_inputs(srcs, deps=[]):
  """Determines the list of inputs required for a compile action.

  Args:
    srcs: A list of `*.swift` source files being compiled.
    deps: A list of targetsthat are dependencies of the files being compiled.
  Returns:
    A list of files that should be passed as inputs to the Swift compilation
    action.
  """
  swift_providers = [x[SwiftInfo] for x in deps if SwiftInfo in x]
  objc_providers = [x.objc for x in deps if hasattr(x, "objc")]

  dep_modules = depset()
  for swift in swift_providers:
    dep_modules += swift.transitive_modules

  objc_files = depset()
  for objc in objc_providers:
    objc_files += objc.header
    objc_files += objc.module_map
    objc_files += objc.umbrella_header
    objc_files += depset(objc.static_framework_file)
    objc_files += depset(objc.dynamic_framework_file)

  return srcs + dep_modules.to_list() + list(objc_files)


def swiftc_args(ctx):
  """Returns an almost compelete array of arguments to be passed to swiftc.

  This macro is intended to be used by the swift_library rule implementation
  below but it also may be used by other rules outside this file. It has no
  side effects and does not modify ctx. It expects ctx to contain the same
  fragments and attributes as swift_library (you're encouraged to depend on
  SWIFT_LIBRARY_ATTRS in your rule definition).

  Args:
    ctx: rule context

  Returns:
    A list of command line arguments for swiftc. The returned arguments
    include everything except the arguments generation of which would require
    adding new files or actions.
  """
  # TODO(allevato): Simultaneously migrate callers off this function and swap it
  # out with swiftc_args.
  reqs = swift_compile_requirements(
      ctx.files.srcs, ctx.attr.deps, ctx.attr.module_name, ctx.label,
      ctx.attr.swift_version, ctx.attr.copts, ctx.attr.defines,
      ctx.fragments.apple, ctx.fragments.objc, ctx.fragments.swift, ctx.var,
      ctx.configuration, ctx.genfiles_dir)
  return _swiftc_args(reqs)


def _swiftc_args(reqs):
  """Returns an almost complete array of arguments to be passed to swiftc.

  This macro is intended to be used by the swift_library rule implementation
  below but it also may be used by other rules outside this file.

  Args:
    reqs: The compilation requirements as returned by
        `swift_compile_requirements`.
  Returns:
    A list of command line arguments for `swiftc`. The returned arguments
    include everything except the arguments generation of which would require
    adding new files or actions.
  """
  apple_fragment = reqs.apple_fragment
  deps = reqs.deps

  cpu = apple_fragment.single_arch_cpu
  platform = apple_fragment.single_arch_platform

  target_os = apple_fragment.minimum_os_for_platform_type(
      platform.platform_type)
  target = _swift_target(cpu, platform, target_os)
  apple_toolchain = apple_common.apple_toolchain()

  # A list of paths to pass with -F flag.
  framework_dirs = depset([
      apple_toolchain.platform_developer_framework_dir(apple_fragment)])

  # Collect transitive dependecies.
  dep_modules = depset()
  swiftc_defines = reqs.defines

  swift_providers = [x[SwiftInfo] for x in deps if SwiftInfo in x]
  objc_providers = [x.objc for x in deps if hasattr(x, "objc")]

  for swift in swift_providers:
    dep_modules += swift.transitive_modules
    swiftc_defines += swift.transitive_defines

  objc_includes = depset()     # Everything that needs to be included with -I
  objc_module_maps = depset()  # Module maps for dependent targets
  objc_defines = depset()
  static_frameworks = depset()
  for objc in objc_providers:
    objc_includes += objc.include
    objc_module_maps += objc.module_map

    static_frameworks += _framework_names(objc.framework_dir)
    framework_dirs += _parent_dirs(objc.framework_dir)
    framework_dirs += _parent_dirs(objc.dynamic_framework_dir)

    # objc_library#copts is not propagated to its dependencies and so it is not
    # collected here. In theory this may lead to un-importable targets (since
    # their module cannot be compiled by clang), but did not occur in practice.
    objc_defines += objc.define

  srcs_args = [f.path for f in reqs.srcs]

  # Include each swift module's parent directory for imports to work.
  include_dirs = depset([x.dirname for x in dep_modules])

  # Include the genfiles root so full-path imports can work for generated protos.
  include_dirs += depset([reqs.genfiles_dir.path])

  include_args = ["-I%s" % d for d in include_dirs + objc_includes]
  framework_args = ["-F%s" % x for x in framework_dirs]
  define_args = ["-D%s" % x for x in swiftc_defines]

  # Disable the LC_LINKER_OPTION load commands for static frameworks automatic
  # linking. This is needed to correctly deduplicate static frameworks from also
  # being linked into test binaries where it is also linked into the app binary.
  autolink_args =_intersperse(
      "-Xfrontend",
      _intersperse("-disable-autolink-framework", static_frameworks))

  clang_args = _intersperse(
      "-Xcc",

      # Add the current directory to clang's search path.
      # This instance of clang is spawned by swiftc to compile module maps and
      # is not passed the current directory as a search path by default.
      ["-iquote", "."]

      # Pass DEFINE or copt values from objc configuration and rules to clang
      + ["-D" + x for x in objc_defines] + reqs.objc_fragment.copts
      + _clang_compilation_mode_flags(reqs.objc_fragment)

      # Load module maps explicitly instead of letting Clang discover them on
      # search paths. This is needed to avoid a case where Clang may load the
      # same header both in modular and non-modular contexts, leading to
      # duplicate definitions in the same file.
      # https://llvm.org/bugs/show_bug.cgi?id=19501
      + ["-fmodule-map-file=%s" % x.path for x in objc_module_maps])

  args = [
      "-emit-object",
      "-module-name",
      reqs.module_name,
      "-target",
      target,
      "-sdk",
      apple_toolchain.sdk_dir(),
      "-module-cache-path",
      module_cache_path(reqs.genfiles_dir),
  ]

  if reqs.default_configuration.coverage_enabled:
    args.extend(["-profile-generate", "-profile-coverage-mapping"])

  args.extend(_swift_compilation_mode_flags(
      reqs.config_vars, reqs.objc_fragment))
  args.extend(_swift_bitcode_flags(apple_fragment))
  args.extend(_swift_parsing_flags(reqs.srcs))
  args.extend(_swift_sanitizer_flags(reqs.config_vars))
  args.extend(srcs_args)
  args.extend(include_args)
  args.extend(framework_args)
  args.extend(clang_args)
  args.extend(define_args)
  args.extend(autolink_args)
  args.extend(reqs.swift_fragment.copts())
  args.extend(reqs.copts)

  # Swift 3.1, which has this flag, has been bundled with Xcode 8.3. This check
  # won't work for out-of-Xcode toolchains if we ever going to support that.
  if xcode_support.is_xcode_at_least_version(reqs.apple_fragment, "8.3"):
    args.extend(["-swift-version", "%d" % reqs.swift_version])

  return args


def register_swift_compile_actions(ctx, reqs):
  """Registers actions to compile Swift sources.

  Args:
    ctx: The rule context. Within this function, it should only be used to
        register actions, or declare files; do not use it to access attributes
        because it may be called from many different rules.
    reqs: The compilation requirements as returned by
        `swift_compile_requirements`.
  Returns:
    A tuple containing the (1) output files of the compilation action, the (2)
    `objc` provider, and (3) the `SwiftInfo` provider that should be propagated
    by a target compiling these Swift sources.
  """
  module_name = reqs.module_name
  label = reqs.label

  # Collect transitive dependecies.
  dep_modules = depset()
  dep_libs = depset()
  swiftc_defines = reqs.defines

  swift_providers = [x[SwiftInfo] for x in reqs.deps if SwiftInfo in x]
  objc_providers = [x.objc for x in reqs.deps if hasattr(x, "objc")]

  for swift in swift_providers:
    dep_libs += swift.transitive_libs
    dep_modules += swift.transitive_modules
    swiftc_defines += swift.transitive_defines

  # A unique path for rule's outputs.
  objs_outputs_path = label_scoped_path(reqs.label, "_objs/")

  output_lib = ctx.new_file(objs_outputs_path + module_name + ".a")
  output_module = ctx.new_file(objs_outputs_path + module_name + ".swiftmodule")

  # These filenames are guaranteed to be unique, no need to scope.
  output_header = ctx.new_file(label.name + "-Swift.h")
  swiftc_output_map_file = ctx.new_file(label.name + ".output_file_map.json")

  swiftc_output_map = struct()  # Maps output types to paths.
  output_objs = []  # Object file outputs, used in archive action.
  swiftc_outputs = []  # Other swiftc outputs that aren't processed further.

  has_wmo, has_wmo_flag = _get_wmo_state(reqs.copts, reqs.swift_fragment)

  for source in reqs.srcs:
    basename = source.basename
    output_map_entry = {}

    # Output an object file
    obj = ctx.new_file(objs_outputs_path + basename + ".o")
    output_objs.append(obj)
    output_map_entry["object"] = obj.path

    # Output a partial module file, unless WMO is enabled in which case only
    # the final, complete module will be generated.
    if not has_wmo:
      partial_module = ctx.new_file(objs_outputs_path + basename +
                                    ".partial_swiftmodule")
      swiftc_outputs.append(partial_module)
      output_map_entry["swiftmodule"] = partial_module.path

    swiftc_output_map += struct(**{source.path: struct(**output_map_entry)})

  # Write down the intermediate outputs map for this compilation, to be used
  # with -output-file-map flag.
  # It's a JSON file that maps each source input (.swift) to its outputs
  # (.o, .bc, .d, ...)
  # Example:
  #   {'foo.swift':
  #       {'object': 'foo.o', 'bitcode': 'foo.bc', 'dependencies': 'foo.d'}}
  # There's currently no documentation on this option, however all of the keys
  # are listed here https://github.com/apple/swift/blob/swift-2.2.1-RELEASE/include/swift/Driver/Types.def
  ctx.file_action(
      output=swiftc_output_map_file,
      content=swiftc_output_map.to_json())

  args = (_swift_xcrun_args(reqs.apple_fragment) +
          ["swiftc"] +
          _swiftc_args(reqs))

  args += [
      "-I" + output_module.dirname,
      "-emit-module-path",
      output_module.path,
      "-emit-objc-header-path",
      output_header.path,
      "-output-file-map",
      swiftc_output_map_file.path,
  ]

  if has_wmo:
    if not has_wmo_flag:
      args.append("-whole-module-optimization")

    # WMO has two modes: threaded and not. We want the threaded mode because it
    # will use the output map we generate. This leads to a better debug
    # experience in lldb and Xcode.
    # TODO(b/32571265): 12 has been chosen as the best option for a Mac Pro,
    # we should get an interface in Bazel to get core count.
    args.extend(["-num-threads", "12"])

  xcrun_action(
      ctx,
      inputs=_swiftc_inputs(reqs.srcs, reqs.deps) + [swiftc_output_map_file],
      outputs=[output_module, output_header] + output_objs + swiftc_outputs,
      mnemonic="SwiftCompile",
      arguments=args,
      use_default_shell_env=False,
      progress_message=("Compiling Swift module %s (%d files)" %
                        (reqs.label.name, len(reqs.srcs))))

  xcrun_action(ctx,
               inputs=output_objs,
               outputs=(output_lib,),
               mnemonic="SwiftArchive",
               arguments=[
                   "libtool", "-static", "-o", output_lib.path
               ] + [x.path for x in output_objs],
               progress_message=(
                   "Archiving Swift objects %s" % reqs.label.name))

  # This tells the linker to write a reference to .swiftmodule as an AST symbol
  # in the final binary.
  # With dSYM enabled, this results in a __DWARF,__swift_ast section added to
  # the dSYM binary, from where LLDB is able deserialize module information.
  # Without dSYM, LLDB will follow the AST references, however there is a bug
  # where it follows only the first one https://bugs.swift.org/browse/SR-2637
  # This means that dSYM is required for debugging until that is resolved.
  extra_linker_args = ["-Xlinker -add_ast_path -Xlinker " + output_module.path]

  # The full transitive set of libraries and modules used by this target.
  transitive_libs = depset([output_lib]) + dep_libs
  transitive_modules = depset([output_module]) + dep_modules

  compile_outputs = [output_lib, output_module, output_header]

  objc_provider_args = {
      "library": depset([output_lib]) + dep_libs,
      "header": depset([output_header]),
      "providers": objc_providers,
      "link_inputs": depset([output_module]),
      "uses_swift": True,
  }

  # TODO(b/63674406): For macOS, don't propagate the runtime linker path flags,
  # because we need to be able to be able to choose the static version of the
  # library instead. Clean this up once the native bundling rules are deleted.
  platform_type = ctx.fragments.apple.single_arch_platform.platform_type
  if platform_type != apple_common.platform_type.macos:
    objc_provider_args["linkopt"] = depset(
        swift_linkopts(reqs.apple_fragment, reqs.config_vars) +
        extra_linker_args, order="topological")

  objc_provider = apple_common.new_objc_provider(**objc_provider_args)

  return compile_outputs, objc_provider, SwiftInfo(
      direct_lib=output_lib,
      direct_module=output_module,
      transitive_libs=transitive_libs,
      transitive_modules=transitive_modules,
      transitive_defines=swiftc_defines,
  )


def _collect_resource_sets(resources, structured_resources, deps, module_name):
  """Collects resource sets from the target and its dependencies.

  Args:
    resources: The resources associated with the target being built.
    structured_resources: The structured resources associated with the target
        being built.
    deps: The dependencies of the target being built.
    module_name: The name of the Swift module associated with the resources
        (either the user-provided name, or the auto-generated one).
  Returns:
    A list of structs representing the transitive resources to propagate to the
    bundling rules.
  """
  resource_sets = []

  # Create a resource set from the resources attached directly to this target.
  if resources or structured_resources:
    resource_sets.append(struct(
        bundle_dir=None,
        infoplists=depset(),
        objc_bundle_imports=depset(),
        resources=depset(resources),
        structured_resources=depset(structured_resources),
        structured_resource_zips=depset(),
        swift_module=module_name,
    ))

  # Collect transitive resource sets from dependencies.
  for dep in deps:
    if AppleResourceInfo in dep:
      resource_sets.extend(dep[AppleResourceInfo].resource_sets)

  return resource_sets


def _swift_library_impl(ctx):
  """Implementation for swift_library Skylark rule."""

  _validate_rule_and_deps(ctx)

  resolved_module_name = ctx.attr.module_name or swift_module_name(ctx.label)

  reqs = swift_compile_requirements(
      ctx.files.srcs,
      ctx.attr.deps,
      resolved_module_name,
      ctx.label,
      ctx.attr.swift_version,
      ctx.attr.copts,
      ctx.attr.defines,
      ctx.fragments.apple,
      ctx.fragments.objc,
      ctx.fragments.swift,
      ctx.var,
      ctx.configuration,
      ctx.genfiles_dir)

  compile_outputs, objc_provider, swift_info = register_swift_compile_actions(
      ctx, reqs)

  resource_sets = _collect_resource_sets(
      ctx.files.resources, ctx.files.structured_resources, ctx.attr.deps,
      resolved_module_name)

  return struct(
      files=depset(compile_outputs),
      swift=struct(
          direct_lib=swift_info.direct_lib,
          direct_module=swift_info.direct_module,
          transitive_libs=swift_info.transitive_libs,
          transitive_modules=swift_info.transitive_modules,
          transitive_defines=swift_info.transitive_defines,
      ),
      objc=objc_provider,
      providers=[
          AppleResourceInfo(resource_sets=resource_sets),
          swift_info,
      ])


SWIFT_LIBRARY_ATTRS = {
    "srcs": attr.label_list(allow_files = [".swift"], allow_empty=False),
    "deps": attr.label_list(
        # TODO(b/37902442): Figure out why this is required here; it seems like
        # having it on the binary should be sufficient because the aspect goes
        # down all deps, but without this, the aspect runs *after* this rule
        # gets to examine its deps (so the AppleResource provider isn't there
        # yet).
        aspects=[apple_bundling_aspect],
        providers=[["swift"], [SwiftInfo], ["objc"]]
    ),
    "module_name": attr.string(mandatory=False),
    "defines": attr.string_list(mandatory=False, allow_empty=True),
    "copts": attr.string_list(mandatory=False, allow_empty=True),
    "resources": attr.label_list(
        mandatory=False,
        allow_empty=True,
        allow_files=True),
    "structured_resources": attr.label_list(
        mandatory=False,
        allow_empty=True,
        allow_files=True),
    "swift_version": attr.int(default=3, values=[3, 4], mandatory=False),
    "_xcrunwrapper": attr.label(
        executable=True,
        cfg="host",
        default=Label(XCRUNWRAPPER_LABEL))
}


swift_library = rule(
    _swift_library_impl,
    attrs = SWIFT_LIBRARY_ATTRS,
    fragments = ["apple", "objc", "swift"],
    output_to_genfiles=True,
)
"""
Builds a Swift module.

A module is a pair of static library (.a) + module header (.swiftmodule).
Dependant targets can import this module as "import RuleName".

Args:
  srcs: Swift sources that comprise this module.
  deps: Other Swift modules.
  module_name: Optional. Sets the Swift module name for this target. By default
      the module name is the target path with all special symbols replaced
      by "_", e.g. //foo:bar can be imported as "foo_bar".
  copts: A list of flags passed to swiftc command line.
  defines: Each VALUE in this attribute is passed as -DVALUE to the compiler for
      this and dependent targets.
  swift_version: A number that specifies the Swift language version to use.
      Valid options are 3, 4. This value is ignored for Xcode < 8.3.
"""
