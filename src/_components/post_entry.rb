class PostEntry < Bridgetown::Component
  def initialize(resource:, mode: :summary)
    @resource = resource
    @mode = mode
  end

  def call
    klass = Object.const_get("Posts::#{PostType.for(@resource.data).capitalize}")
    render klass.new(resource: @resource, mode: @mode)
  end
end
