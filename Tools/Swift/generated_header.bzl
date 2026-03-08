load("@rules_swift//swift:swift.bzl", "SwiftInfo")

def _swift_generated_header_impl(ctx):
    swift_info = ctx.attr.swift_target[SwiftInfo]
    if not swift_info.direct_modules:
        fail("Swift target {} has no direct modules".format(ctx.attr.swift_target))

    module_name = ctx.attr.module_name
    if module_name:
        module = None
        for candidate in swift_info.direct_modules:
            if candidate.name == module_name:
                module = candidate
                break
        if module == None:
            available = ", ".join([m.name for m in swift_info.direct_modules])
            fail("Module '{}' not found in {}. Available modules: {}".format(module_name, ctx.attr.swift_target, available))
    else:
        module = swift_info.direct_modules[0]

    header = module.swift.generated_header
    if not header:
        fail("Swift target {} does not generate a bridging header".format(ctx.attr.swift_target))

    if not ctx.attr.output_path:
        fail("swift_generated_header requires 'output_path' to be set")

    output = ctx.actions.declare_file(ctx.attr.output_path)
    ctx.actions.symlink(
        output = output,
        target_file = header,
    )

    return [DefaultInfo(files = depset([output]))]

swift_generated_header = rule(
    implementation = _swift_generated_header_impl,
    attrs = {
        "swift_target": attr.label(providers = [SwiftInfo]),
        "output_path": attr.string(mandatory = True),
        "module_name": attr.string(),
    },
)
