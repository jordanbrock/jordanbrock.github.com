class PostMeta < Bridgetown::Component
  def initialize(resource:, show_type: true)
    @resource = resource
    @show_type = show_type
  end

  def date = @resource.date
  def type = @type ||= PostType.for_resource(@resource)
  def show_type? = @show_type && type != "article"

  # [tag, href] pairs; href is nil for tags without a page.
  def tags
    Array(@resource.data.tags).map(&:to_s).map { [_1, TagPages.href(@resource.site, _1)] }
  end
end
