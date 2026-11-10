require "uri"

module Posts
  class Link < Bridgetown::Component
    def initialize(resource:, mode:)
      @resource = resource
      @mode = mode
    end

    def url = @resource.data.link.to_s

    def domain
      URI(url).host.to_s.delete_prefix("www.")
    rescue URI::InvalidURIError
      url
    end

    def title
      t = @resource.data.title.to_s.strip
      t.empty? ? domain : t
    end
  end
end
