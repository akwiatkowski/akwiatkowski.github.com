require "../../../crystal/src/framework/src/tremolite/tremolite"
require "../../../crystal/src/blog"

blog = Tremolite::Blog.for_env("dev", "release")

blog.make_it_so(
  force_full_render: true,
  hide_not_finished: true
)
