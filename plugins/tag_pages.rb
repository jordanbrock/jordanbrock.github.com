# Which tags get a /tags/:term/ page. The src/tags/tag.erb prototype makes one
# for every tag; prune! keeps those on MIN_POSTS or more posts with a usable
# slug, and records them in site.data.tag_pages as { term => url } for
# PostMeta and the sitemap.
module TagPages
  MIN_POSTS = 3

  # The prototype generator downcases and strips terms, and splits on , and ;.
  def self.term(tag) = tag.to_s.downcase.strip
  def self.terms(tag) = term(tag).split(/[,;]/).map(&:strip).reject(&:empty?)
  def self.slug(site, tag) = Bridgetown::Utils.slugify(term(tag), mode: site.config.slugify_mode)

  def self.counts(site)
    site.collections.posts.resources.flat_map { |post| Array(post.data.tags).flat_map { terms(_1) }.uniq }.tally
  end

  def self.tag_page?(page) = page.data["prototype"].is_a?(Hash) && page.data.key?("tag")

  # Drops ineligible tag pages from site.generated_pages and returns the map.
  def self.prune!(site)
    counts = counts(site)
    site.generated_pages.reject! do |page|
      tag_page?(page) && (counts.fetch(term(page.data["tag"]), 0) < MIN_POSTS || slug(site, page.data["tag"]).empty?)
    end
    kept = site.generated_pages.select { tag_page?(_1) }
    kept.group_by(&:relative_url).each do |url, pages|
      next if pages.size < 2

      Bridgetown.logger.warn "TagPages:", "#{url} is shared by tags #{pages.map { _1.data["tag"] }.join(", ")}"
    end
    site.data.tag_pages = kept.to_h { [term(_1.data["tag"]), _1.relative_url] }
  end
end
