def _create_simulator_pool_impl(ctx):
    executable = ctx.actions.declare_file(ctx.label.name + ".sh")
    ctx.actions.expand_template(
        template = ctx.file._template,
        output = executable,
        is_executable = True,
        substitutions = {
            "%create_simulator_pool%": ctx.executable._create_simulator_pool_tool.short_path,
            "%simulator_pool_server%": ctx.executable._simulator_pool_server.short_path,
            "%simulator_pool_port%": str(ctx.attr.server_port),
            "%os_version%": ctx.attr.os_version,
            "%device_type%": ctx.attr.device_type,
            "%pool_size%": str(ctx.attr.pool_size),
        },
    )
    runfiles = ctx.runfiles(files = [ctx.executable._create_simulator_pool_tool, ctx.executable._simulator_pool_server])
    runfiles = runfiles.merge(ctx.attr._create_simulator_pool_tool[DefaultInfo].default_runfiles)
    runfiles = runfiles.merge(ctx.attr._simulator_pool_server[DefaultInfo].default_runfiles)
    return [DefaultInfo(executable = executable, runfiles = runfiles)]

create_simulator_pool = rule(
    implementation = _create_simulator_pool_impl,
    executable = True,
    attrs = {
        "_create_simulator_pool_tool": attr.label(
            default = "//apple/testing/simulator_pool:create_simulator_pool_tool",
            executable = True,
            cfg = "exec",
        ),
        "_simulator_pool_server": attr.label(
            default = "//apple/testing/simulator_pool:simulator_pool_server",
            executable = True,
            cfg = "exec",
        ),
        "_template": attr.label(
            allow_single_file = True,
            default = "//apple/testing/simulator_pool:create_simulator_pool.template.sh",
        ),
        "server_port": attr.int(
            mandatory = True,
            doc = "The port to run the simulator pool server on, this value must match the value set in your test runner otherwise the test runner will not be able to connect to the simulator pool server.",
        ),
        "os_version": attr.string(
            mandatory = True,
            doc = "The OS version to create the simulator pool for.",
        ),
        "device_type": attr.string(
            mandatory = True,
            doc = "The device type to create the simulator pool for.",
        ),
        "pool_size": attr.int(
            mandatory = True,
            doc = "The number of simulators to create in the pool.",
        ),
    },
)
