module Posts
  class Link < Bridgetown::Component
    def initialize(resource:, mode:)
      @resource = resource
      @mode = mode
    end

    def url = PostType.safe_link(@resource.data.link)
    # From the raw link, so the card agrees with feed_title even when url is "#".
    def domain = PostType.link_domain(@resource.data.link)

    def title
      t = PostType.title(@resource)
      t.empty? ? domain : t
    end
  end
end
