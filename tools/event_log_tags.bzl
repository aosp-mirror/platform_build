"""Event log tags generation rule"""

load("@bazel_skylib//lib:paths.bzl", "paths")

def _event_log_tags_impl(ctx):
    out_files = []
    for logtag_file in ctx.files.srcs:
        out_filename = paths.replace_extension(logtag_file.basename, ".java")
        out_file = ctx.actions.declare_file(out_filename)
        out_files.append(out_file)
        ctx.actions.run(
            inputs = [logtag_file],
            outputs = [out_file],
            arguments = [
                "-o",
                out_file.path,
                logtag_file.path,
            ],
            progress_message = "Generating Java logtag file from %s" % logtag_file.short_path,
            executable = ctx.executable._logtag_to_java_tool,
        )
    return [DefaultInfo(files = depset(out_files))]

event_log_tags = rule(
    implementation = _event_log_tags_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = [".logtags"], mandatory = True),
        "_logtag_to_java_tool": attr.label(
            executable = True,
            cfg = "exec",
            allow_files = True,
            default = Label("//build/make/tools:java-event-log-tags"),
        ),
    },
)
