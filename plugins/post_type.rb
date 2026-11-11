require "uri"

# Decides which post type a post is (see TYPES), from its front matter.
module PostType
  TYPES = %w[article note link photo album].freeze

  def self.for(data)
    data = data.to_h.transform_keys(&:to_s)
    if present?(data["image"]) && listed?(data["photos"])
      raise ArgumentError, "Use either image or photos, not both"
    end

    explicit = data["type"].to_s.strip
    unless explicit.empty?
      raise ArgumentError, "Unknown post type: #{explicit}" unless TYPES.include?(explicit)

      if explicit != "album" && listed?(data["photos"])
        raise ArgumentError, "photos is only for album posts"
      end

      return explicit
    end

    return "photo" if present?(data["image"])
    return "album" if listed?(data["photos"])
    return "link" if present?(data["link"])
    return "article" if present?(data["title"])

    "note"
  end

  # Uses the resource's real front matter: Bridgetown fills data.title from
  # the slug, which would make every untitled note look like an article.
  def self.front_matter(resource) = resource.model.attributes.to_h.reject { |k, _| k.to_s.start_with?("_") }
  def self.for_resource(resource)
    self.for(front_matter(resource))
  rescue ArgumentError => e
    raise ArgumentError, "#{e.message} (in #{resource.relative_path})"
  end

  def self.title(resource) = front_matter(resource)["title"].to_s.strip

  # Posts newest first (ties broken by path, so the order is stable),
  # optionally only those of one type.
  def self.posts(resources, type = nil)
    resources = resources.select { for_resource(_1) == type } if type
    resources.sort_by { [-_1.date.to_i, _1.relative_path.to_s] }
  end

  # The link as an href: only http(s) URLs pass; anything else (javascript:,
  # data:, host-less like http:foo, unparseable) becomes "#".
  def self.safe_link(url)
    raw = url.to_s.strip
    uri = URI(raw)
    uri.is_a?(URI::HTTP) && !uri.host.to_s.empty? ? raw : "#"
  rescue URI::InvalidURIError
    "#"
  end

  # Host of a URL without "www.", or the raw string when there is no host.
  def self.link_domain(url)
    host = URI(url.to_s).host.to_s.delete_prefix("www.")
    host.empty? ? url.to_s : host
  rescue URI::InvalidURIError
    url.to_s
  end

  def self.present?(value) = !value.to_s.strip.empty?
  # A photos: value worth treating as an album: a non-empty list, or any other
  # non-blank value (which PostPhotos then rejects as "not a list").
  def self.listed?(value) = value.is_a?(Array) ? !value.empty? : present?(value)
  private_class_method :present?, :listed?
end
