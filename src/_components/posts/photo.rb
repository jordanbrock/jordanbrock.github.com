module Posts
  class Photo < Bridgetown::Component
    def initialize(resource:, mode:)
      @resource = resource
      @mode = mode
    end

    def image = @resource.data.image.to_s
    def alt = FeedEntry.alt(@resource)
    # The body without its <p> tags; paragraphs are joined with a space.
    def caption_html = @resource.content.to_s.gsub(%r{</p>\s*<p>}, " ").gsub(%r{</?p>}, "").strip.html_safe

    def eager? = @mode == :full # on its own page the photo is above the fold; lazy everywhere else
  end
end
