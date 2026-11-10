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
  def self.for_resource(resource)
    attrs = resource.model.attributes.to_h.reject { |k, _| k.to_s.start_with?("_") }
    self.for(attrs)
  end

  def self.present?(value) = !value.to_s.strip.empty?
  private_class_method :present?
end
