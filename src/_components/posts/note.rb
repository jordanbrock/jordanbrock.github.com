module Posts
  class Note < Bridgetown::Component
    def initialize(resource:, mode:)
      @resource = resource
      @mode = mode
    end
  end
end
