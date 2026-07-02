require "../../../crystal/src/framework/src/tremolite/tremolite"
require "../../../crystal/src/blog"

blog = Tremolite::Blog.for_env("full", "local")

# loads posts. w/o it array is empty
blog.initialize_posts
blog.post_collection.posts.each do |post|
  # load and process photos with exif data
  # little overkill here
  blog.data_manager.exif_db.initialize_post_photos_exif(post)

  post.published_photo_entities.each do |photo_entity|
    puts photo_entity.tags.inspect
    # TODO: put code here
  end
end
