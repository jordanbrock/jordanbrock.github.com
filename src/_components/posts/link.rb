require "uri"

module Posts
  class Link < Bridgetown::Component
    def initialize(resource:, mode:)
      @resource = resource
      @mode = mode
    end

    # Only http(s) links are rendered as hrefs; anything else (javascript:, data:) becomes "#".
    def url
      raw = @resource.data.link.to_s.strip
      URI(raw).is_a?(URI::HTTP) ? raw : "#"
    rescue URI::InvalidURIError
      "#"
    end

    def domain = PostType.link_domain(url)

    def title
      t = PostType.title(@resource)
      t.empty? ? domain : t
    end
  end
end
