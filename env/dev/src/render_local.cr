require "../../../crystal/src/framework/tremolite"
require "../../../crystal/src/blog"

t = Tremolite::Blog.for_env("dev", "local")

t.make_it_so(
  force_full_render: true,
)
