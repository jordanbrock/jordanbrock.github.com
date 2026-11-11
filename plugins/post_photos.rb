# The photos a post shows, as entries { image:, alt:, caption:, index: }:
# one for a photo post (index nil), one per listed photo for an album
# (index from 1, alt falling back to the caption), none for other types.
# (link posts' preview images come from previews, not for).
# Plain functions of the resource, so they can be unit-tested with stubs.
module PostPhotos
  def self.for(resource)
    case PostType.for_resource(resource)
    when "photo"
      [{ image: resource.data.image.to_s.strip, alt: FeedEntry.alt(resource), caption: nil, index: nil }]
    when "album"
      album(resource)
    else
      []
    end
  end

  # [post, entry] pairs for every photo, newest post first, album order within.
  def self.tiles(resources)
    PostType.posts(resources).flat_map { |post| self.for(post).map { [post, _1] } }
  end

  # [post, entry] pairs for link posts' preview images (front matter
  # preview: { image: }), newest first. Processed like photos, but not tiles:
  # they never appear on the Photos page. alt is empty: the card's title is
  # the link text.
  def self.previews(resources)
    PostType.posts(resources, "link").filter_map do |post|
      preview = PostType.front_matter(post)["preview"]
      next unless preview.respond_to?(:to_hash)

      image = preview.to_hash.transform_keys(&:to_s)["image"].to_s.strip
      [post, { image:, alt: "", caption: nil, index: nil }] unless image.empty?
    end
  end

  # Fragment linking to an album photo on its post's page.
  def self.anchor(entry) = entry[:index] ? "#photo-#{entry[:index]}" : ""

  # Error-message suffix naming the post and, for albums, the photo.
  def self.where(resource, entry)
    "(in #{resource.relative_path}#{", photo #{entry[:index]}" if entry[:index]})"
  end

  def self.album(resource)
    list = PostType.front_matter(resource)["photos"]
    raise ArgumentError, "Album photos must be a list of mappings with image and alt or caption #{where(resource, {})}" unless list.is_a?(Array)
    raise ArgumentError, "Album has no photos #{where(resource, {})}" if list.empty?

    list.each.with_index(1).map do |raw, index|
      entry = { index: }
      unless raw.respond_to?(:to_hash)
        raise ArgumentError, "Album photo must be a mapping with image and alt or caption #{where(resource, entry)}"
      end

      fields = raw.to_hash.transform_keys(&:to_s)
      image = fields["image"].to_s.strip
      caption = fields["caption"].to_s.strip
      alt = fields["alt"].to_s.strip
      alt = caption if alt.empty?
      raise ArgumentError, "Album photo has no image #{where(resource, entry)}" if image.empty?
      raise ArgumentError, "Album photo needs alt text or a caption #{where(resource, entry)}" if alt.empty?

      { image:, alt:, caption: (caption unless caption.empty?), index: }
    end
  end
  private_class_method :album
end
