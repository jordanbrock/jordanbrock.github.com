class PostMeta < Bridgetown::Component
  def initialize(resource:, show_type: true)
    @resource = resource
    @show_type = show_type
  end

  def date = @resource.date
  def type = @type ||= PostType.for_resource(@resource)
  def show_type? = @show_type && type != "article"

  def tags
    Array(@resource.data.tags).map(&:to_s)
  end
end
