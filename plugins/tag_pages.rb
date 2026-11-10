# Which tags get a /tags/:term/ page (from the src/tags/tag.erb prototype) and
# what their URL is. Only tags on MIN_POSTS or more posts keep a page; the
# rest are pruned by Builders::TagPages and shown in PostMeta without a link.
module TagPages
  MIN_POSTS = 3

  # The prototype generator downcases and strips terms, then slugifies them.
  def self.term(tag) = tag.to_s.downcase.strip
  def self.slug(site, tag) = Bridgetown::Utils.slugify(term(tag), mode: site.config.slugify_mode)

  # term => posts, grouped exactly as the prototype generator groups them.
  def self.index(site)
    Bridgetown::Paginate::PaginationIndexer.index_documents_by(site.collections.posts.resources, "tags")
  end

  def self.page?(site, tag)
    !slug(site, tag).empty? && index(site).fetch(term(tag), []).size >= MIN_POSTS
  end

  # URL of the tag's page, or nil when it has none.
  def self.href(site, tag) = ("/tags/#{slug(site, tag)}/" if page?(site, tag))
end
