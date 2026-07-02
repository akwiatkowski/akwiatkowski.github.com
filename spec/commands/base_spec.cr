require "../spec_helper"
require "../../crystal/src/commands/base"

describe Commands do
  describe "ENVS" do
    it "contains dev and full" do
      Commands::ENVS.should eq ["dev", "full"]
    end

    it "has exactly 2 environments" do
      Commands::ENVS.size.should eq 2
    end
  end

  describe ".init_blog" do
    it "returns a Tremolite::Blog for dev env" do
      blog = Commands.init_blog("dev")
      blog.should be_a Tremolite::Blog
    end

    it "initializes posts" do
      blog = Commands.init_blog("dev")
      blog.post_collection.posts.should_not be_empty
    end

    it "sets correct cache path for given env" do
      blog = Commands.init_blog("dev")
      blog.cache_path.should eq "env/dev/cache"
    end
  end
end
