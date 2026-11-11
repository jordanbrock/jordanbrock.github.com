module Posts
  # An album: in the stream, its cover and a strip of up to STRIP_COUNT more
  # photos (the last showing "+N" for the rest); on its page, every photo.
  class Album < Bridgetown::Component
    STRIP_COUNT = 4
    # The strip fills .wrap in 4 columns with 0.5rem gaps (see .album__strip).
    STRIP_SIZES = "(min-width: 56rem) 13rem, calc((100vw - 4rem) / 4)".freeze

    def initialize(resource:, mode:)
      @resource = resource
      @mode = mode
    end

    def full? = @mode == :full
    def photos = @photos ||= PostPhotos.for(@resource)
    def cover = photos.first
    def strip = photos[1, STRIP_COUNT] || []
    def more = [photos.size - 1 - STRIP_COUNT, 0].max # photos neither the cover nor in the strip
    def anchor_id(photo) = PostPhotos.anchor(photo).delete_prefix("#")

    # The last strip tile stands for the hidden photos: it links to the first
    # of them. Every other tile links to its own photo.
    def last_with_more?(i) = i == strip.size - 1 && more.positive?
    def strip_target(i) = last_with_more?(i) ? photos[1 + STRIP_COUNT] : strip[i]
    def strip_href(i) = "#{url}#{PostPhotos.anchor(strip_target(i))}"
    def strip_label(i) = last_with_more?(i) ? "#{strip[i][:alt]} (and #{more} more)" : nil

    def title = PostType.title(@resource)
    def url = PostUrl.for(@resource)
  end
end
