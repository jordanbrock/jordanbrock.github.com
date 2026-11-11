module Posts
  class Link < Bridgetown::Component
    def initialize(resource:, mode:)
      @resource = resource
      @mode = mode
    end

    def url = PostType.safe_link(@resource.data.link)
    # From the raw link, so the card agrees with feed_title even when url is "#".
    def domain = PostType.link_domain(@resource.data.link)
    def title = FeedEntry.title(@resource)

    # The preview from front matter (preview: { title:, description:, site:,
    # image: }), as a string-keyed hash; {} when absent or not a mapping.
    def preview
      raw = PostType.front_matter(@resource)["preview"]
      raw.respond_to?(:to_hash) ? raw.to_hash.transform_keys(&:to_s) : {}
    end

    def preview_image = preview["image"].to_s.strip.then { _1.empty? ? nil : _1 }
    def preview_description = preview["description"].to_s.strip
    # Shown after "Link": the site's own name when the preview has one.
    def source = preview["site"].to_s.strip.then { _1.empty? ? domain : _1 }

    # The card is at most the column width (.col: var(--measure), 34rem), so
    # the image is too.
    IMAGE_SIZES = "(min-width: 36.5rem) 34rem, calc(100vw - 2.5rem)".freeze
    def image_sizes = IMAGE_SIZES
  end
end
