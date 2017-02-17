require "tremolite"
require "../data/src/blog"

t = Tremolite::Blog.new
t.logger.level = Logger::INFO
t.render
