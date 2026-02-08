require "../../../spec_helper"

describe Map::Renderer::PngRenderer do
  it ".available? returns a boolean" do
    result = Map::Renderer::PngRenderer.available?
    (result == true || result == false).should be_true
  end
end
