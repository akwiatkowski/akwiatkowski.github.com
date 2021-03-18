module RendererMixin::Accessors
  def validator
    return @blog.validator.not_nil!
  end
end
