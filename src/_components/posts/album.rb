module Posts
  # An album: in the stream, its cover and a strip of up to STRIP more
  # photos (the last showing "+N" for the rest); on its page, every photo.
  class Album < Bridgetown::Component
    STRIP = 4
    # The strip fills .wrap in 4 columns with 0.5rem gaps (see .album__strip).
    STRIP_SIZES = "(min-width: 56rem) 13rem, calc((100vw - 4rem) / 4)".freeze

    def initialize(resource:, mode:)
      @resource = resource
      @mode = mode
    end

    def full? = @mode == :full
    def photos = @photos ||= PostPhotos.for(@resource)
    def cover = photos.first
    def strip = photos[1, STRIP] || []
    def more = [photos.size - 1 - STRIP, 0].max # photos neither the cover nor in the strip
    def title = PostType.title(@resource)
    def url = PostUrl.for(@resource)
  end
end
