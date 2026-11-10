require "uri"

# Decides which of the four post types a post is, from its front matter.
module PostType
  TYPES = %w[article note link photo].freeze

  def self.for(data)
    data = data.to_h.transform_keys(&:to_s)
    explicit = data["type"].to_s.strip
    unless explicit.empty?
      raise ArgumentError, "Unknown post type: #{explicit}" unless TYPES.include?(explicit)

      return explicit
    end

    return "photo" if present?(data["image"])
    return "link" if present?(data["link"])
    return "article" if present?(data["title"])

    "note"
  end

  # Uses the resource's real front matter: Bridgetown fills data.title from
  # the slug, which would make every untitled note look like an article.
  def self.front_matter(resource) = resource.model.attributes.to_h.reject { |k, _| k.to_s.start_with?("_") }
  def self.for_resource(resource) = self.for(front_matter(resource))
  def self.title(resource) = front_matter(resource)["title"].to_s.strip

  # Posts newest first (ties broken by path, so the order is stable),
  # optionally only those of one type.
  def self.posts(resources, type = nil)
    resources = resources.select { for_resource(_1) == type } if type
    resources.sort_by { [-_1.date.to_i, _1.relative_path.to_s] }
  end

  # Host of a URL without "www.", or the raw string when there is no host.
  def self.link_domain(url)
    host = URI(url.to_s).host.to_s.delete_prefix("www.")
    host.empty? ? url.to_s : host
  rescue URI::InvalidURIError
    url.to_s
  end

  def self.present?(value) = !value.to_s.strip.empty?
  private_class_method :present?
end
