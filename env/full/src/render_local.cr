require "../../../crystal/src/tremolite/tremolite"
require "../../../crystal/src/blog"

t = Tremolite::Blog.for_env("full", "local")

t.make_it_so(
  force_full_render: true,
)
