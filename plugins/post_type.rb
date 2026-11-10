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

  def self.present?(value) = !value.to_s.strip.empty?
  private_class_method :present?
end
