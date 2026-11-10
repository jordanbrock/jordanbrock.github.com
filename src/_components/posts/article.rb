module Posts
  class Article < Bridgetown::Component
    def initialize(resource:, mode:)
      @resource = resource
      @mode = mode
    end

    def full? = @mode == :full

    # Excerpt from front matter, else the first <p> of the rendered HTML.
    def summary_html
      return helpers.markdownify(@resource.data.excerpt.to_s) if @resource.data.excerpt

      @resource.content.to_s[%r{<p[\s>].*?</p>}m] || ""
    end
  end
end
