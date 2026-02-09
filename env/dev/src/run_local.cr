require "../../../data/src/tremolite/src/tremolite/tremolite"
require "../../../data/src/blog"

t = Tremolite::Blog.for_env("dev", "local")

t.make_it_so(
  force_full_render: false,
)
