# The photos a post shows, as entries { image:, alt:, caption:, index: }:
# one for a photo post (index nil), one per listed photo for an album
# (index from 1, alt falling back to the caption), none for other types.
# Plain functions of the resource, so they can be unit-tested with stubs.
module PostPhotos
  TYPES = %w[photo album].freeze

  def self.for(resource)
    case PostType.for_resource(resource)
    when "photo"
      [{ image: resource.data.image.to_s, alt: FeedEntry.alt(resource), caption: nil, index: nil }]
    when "album"
      album(resource)
    else
      []
    end
  end

  # [post, entry] pairs for every photo, newest post first, album order within.
  def self.tiles(resources)
    PostType.posts(resources)
      .select { TYPES.include?(PostType.for_resource(_1)) }
      .flat_map { |post| self.for(post).map { [post, _1] } }
  end

  # Fragment linking to an album photo on its post's page.
  def self.anchor(entry) = entry[:index] ? "#photo-#{entry[:index]}" : ""

  # Error-message suffix naming the post and, for albums, the photo.
  def self.where(resource, entry)
    "(in #{resource.relative_path}#{", photo #{entry[:index]}" if entry[:index]})"
  end

  def self.album(resource)
    list = PostType.front_matter(resource)["photos"]
    raise ArgumentError, "photos must be a list (in #{resource.relative_path})" unless list.is_a?(Array)

    list.each_with_index.map do |raw, i|
      entry = { index: i + 1 }
      raise ArgumentError, "Album photo must have image and alt #{where(resource, entry)}" unless raw.respond_to?(:to_h) && !raw.is_a?(String)

      fields = raw.to_h.transform_keys(&:to_s)
      image = fields["image"].to_s.strip
      caption = fields["caption"].to_s.strip
      alt = fields["alt"].to_s.strip
      alt = caption if alt.empty?
      raise ArgumentError, "Album photo has no image #{where(resource, entry)}" if image.empty?
      raise ArgumentError, "Album photo needs alt text or a caption #{where(resource, entry)}" if alt.empty?

      { image:, alt:, caption: (caption unless caption.empty?), index: i + 1 }
    end
  end
  private_class_method :album
end
