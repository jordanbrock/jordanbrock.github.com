module Posts
  class Photo < Bridgetown::Component
    def initialize(resource:, mode:)
      @resource = resource
      @mode = mode
    end

    def image = @resource.data.image.to_s
    def alt = PostType.alt(@resource)
    def eager? = @mode == :full # on its own page the photo is above the fold; lazy everywhere else
  end
end
