"""# Rules for using locally installed provisioning profiles"""

load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleProvisioningProfileInfo",
)

def _provisioning_profile_repository(repository_ctx):
    system_profiles_path = "{}/Library/MobileDevice/Provisioning Profiles".format(repository_ctx.os.environ["HOME"])
    repository_ctx.execute(["mkdir", "-p", system_profiles_path])
    repository_ctx.symlink(system_profiles_path, "profiles")

    repository_ctx.file("BUILD.bazel", """\
filegroup(
    name = "profiles",
    srcs = glob(["profiles/*.mobileprovision"], allow_empty = True),
    visibility = ["//visibility:public"],
)

filegroup(
    name = "empty",
    srcs = [],
    visibility = ["//visibility:public"],
)

alias(
    name = "fallback_profiles",
    actual = "{}",
    visibility = ["//visibility:public"],
)
""".format(repository_ctx.attr.fallback_profiles or ":empty"))

provisioning_profile_repository = repository_rule(
    environ = ["HOME"],
    implementation = _provisioning_profile_repository,
    attrs = {
        "fallback_profiles": attr.label(
            allow_files = [".mobileprovision"],
        ),
    },
    doc = """
This rule declares an external repository for discovering locally installed
provisioning profiles. This is consumed by `local_provisioning_profile`.
You can optionally set 'fallback_profiles' to point at a stable location of
profiles if a newer version of the desired profile does not exist on the local
machine. This is useful for checking in the current version of the profile, but
not having to update it every time a new device or certificate is added.

## Example

### In your `MODULE.bazel` file:

You only need this in the case you want to setup fallback profiles, otherwise
it can be ommitted when using bzlmod.

```bzl
provisioning_profile_repository = use_extension("@build_bazel_rules_apple//apple:apple.bzl", "provisioning_profile_repository_extension")
provisioning_profile_repository.setup(
    fallback_profiles = "//path/to/some:filegroup", # Profiles to use if one isn't found locally
)
```

### In your `WORKSPACE` file:

```starlark
load("@build_bazel_rules_apple//apple:apple.bzl", "provisioning_profile_repository")

provisioning_profile_repository(
    name = "local_provisioning_profiles",
    fallback_profiles = "//path/to/some:filegroup", # Optional profiles to use if one isn't found locally
)
```

### In your `BUILD` files (see `local_provisioning_profile` for more examples):

```starlark
load("@build_bazel_rules_apple//apple:apple.bzl", "local_provisioning_profile")

local_provisioning_profile(
    name = "app_debug_profile",
    profile_name = "Development App",
    team_id = "abc123",
)

ios_application(
    name = "app",
    ...
    provisioning_profile = ":app_debug_profile",
)
```
""",
)

def _provisioning_profile_repository_extension(module_ctx):
    root_modules = [m for m in module_ctx.modules if m.is_root and m.tags.setup]
    if len(root_modules) > 1:
        fail("Expected at most one root module, found {}".format(", ".join([x.name for x in root_modules])))

    if root_modules:
        root_module = root_modules[0]
    else:
        root_module = module_ctx.modules[0]

    kwargs = {}
    if root_module.tags.setup:
        kwargs["fallback_profiles"] = root_module.tags.setup[0].fallback_profiles

    provisioning_profile_repository(
        name = "local_provisioning_profiles",
        **kwargs
    )

provisioning_profile_repository_extension = module_extension(
    implementation = _provisioning_profile_repository_extension,
    tag_classes = {
        "setup": tag_class(attrs = {
            "fallback_profiles": attr.label(
                allow_files = [".mobileprovision"],
            ),
        }),
    },
    doc = """
See [`provisioning_profile_repository`](#provisioning_profile_repository) for more information and examples.
""",
)

def _local_provisioning_profile(ctx):
    if not ctx.files._local_srcs and not ctx.attr._fallback_srcs:
        ctx.fail("Either local or fallback provisioning profiles must exist")

    profile_name = ctx.attr.profile_name or ctx.attr.name
    selected_profile_path = "{name}.mobileprovision".format(name = profile_name)
    selected_profile = ctx.actions.declare_file(selected_profile_path)

    args = ctx.actions.args()
    args.add(profile_name)
    args.add(selected_profile)
    if ctx.attr.team_id:
        args.add("--team_id", ctx.attr.team_id)
    if ctx.files._local_srcs:
        args.add_all("--local_profiles", ctx.files._local_srcs)
    if ctx.files._fallback_srcs:
        args.add_all("--fallback_profiles", ctx.files._fallback_srcs)
    if not ctx.files._local_srcs and not ctx.attr._fallback_srcs:
        fail("Either local or fallback provisioning profiles must exist")

    ctx.actions.run(
        executable = ctx.executable._finder,
        arguments = [args],
        inputs = ctx.files._local_srcs + ctx.files._fallback_srcs,
        outputs = [selected_profile],
        mnemonic = "FindProvisioningProfile",
        execution_requirements = {"no-sandbox": "1", "no-remote-exec": "1"},
        progress_message = "Finding provisioning profile %{label}",
    )

    return [
        DefaultInfo(files = depset([selected_profile])),
        AppleProvisioningProfileInfo(
            provisioning_profile = selected_profile,
            profile_name = profile_name,
            team_id = ctx.attr.team_id,
        ),
    ]

local_provisioning_profile = rule(
    attrs = {
        "profile_name": attr.string(
            doc = "Name of the profile to use, if it's not provided the name of the rule is used",
        ),
        "team_id": attr.string(
            doc = "Team ID of the profile to find. This is useful for disambiguating between multiple profiles with the same name on different developer accounts.",
        ),
        "_fallback_srcs": attr.label(
            default = "@local_provisioning_profiles//:fallback_profiles",
        ),
        "_local_srcs": attr.label(
            default = "@local_provisioning_profiles//:profiles",
        ),
        "_finder": attr.label(
            cfg = "exec",
            default = "@build_bazel_rules_apple//tools/local_provisioning_profile_finder",
            executable = True,
        ),
    },
    implementation = _local_provisioning_profile,
    doc = """
This rule declares a bazel target that you can pass to the
'provisioning_profile' attribute of rules that require it. It discovers a
provisioning profile for the given attributes either on the user's local
machine, or with the optional 'fallback_profiles' passed to
'provisioning_profile_repository'. This will automatically pick the newest
profile if there are multiple profiles matching the given criteria. By default
this rule will search for a profile with the same name as the rule itself, you
can pass profile_name to use a different name, and you can pass team_id if
you'd like to disambiguate between 2 Apple developer accounts that have the
same profile name.

## Example

```starlark
load("@build_bazel_rules_apple//apple:apple.bzl", "local_provisioning_profile")

local_provisioning_profile(
    name = "app_debug_profile",
    profile_name = "Development App",
    team_id = "abc123",
)

ios_application(
    name = "app",
    ...
    provisioning_profile = ":app_debug_profile",
)

local_provisioning_profile(
    name = "app_release_profile",
)

ios_application(
    name = "release_app",
    ...
    provisioning_profile = ":app_release_profile",
)
```
""",
)
