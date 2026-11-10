# The old site showed 5 posts a page, so /page2/ to /page37/ were linked and
# indexed. Pagination now makes fewer pages; add_stubs! fills each missing
# /pageN/ with a small page that sends readers to the archive. Stubs are not
# listed in the sitemap (src/sitemap.erb lists its pages explicitly).
module LegacyPagination
  PAGES = (2..37)
  TARGET = "/archive.html"

  def self.urls = PAGES.map { "/page#{_1}/" }

  # Legacy URLs that no real page (paginated or otherwise) already produces.
  def self.missing(site)
    taken = (site.generated_pages + site.resources).to_set(&:relative_url)
    urls.reject { taken.include?(_1) }
  end

  def self.add_stubs!(site)
    missing(site).each { site.generated_pages << stub(site, _1) }
  end

  def self.stub(site, url)
    Bridgetown::GeneratedPage.new(site, site.source, "", "#{url.delete("/")}.html").tap do |page|
      page.data = HashWithDotAccess::Hash.new(
        "layout" => "default", "title" => "This page has moved", "permalink" => url, "redirect_to" => TARGET
      )
      page.content = <<~HTML
        <div class="col">
          <h1 class="article__title">This page has moved</h1>
          <p>Older posts are listed in the <a href="#{TARGET}">archive</a>.</p>
        </div>
      HTML
    end
  end
end
