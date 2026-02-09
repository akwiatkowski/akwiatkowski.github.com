require "../../../data/src/tremolite/src/tremolite/tremolite"
require "../../../data/src/blog"

blog = Tremolite::Blog.for_env("dev", "release")

blog.make_it_so(
  force_full_render: true,
  hide_not_finished: true
)
