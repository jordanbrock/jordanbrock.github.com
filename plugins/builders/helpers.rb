require "cgi"

module Builders
  class Helpers < SiteBuilder
    SITE_NAME = "Jordan Brock"

    def build
      # Title for feeds and lists; notes and photos have no title.
      helper :feed_title do |resource|
        FeedEntry.title(resource)
      end

      # Where a post is linked: its legacy .html permalink if it has one.
      helper :post_url do |resource|
        PostUrl.for(resource)
      end

      # Absolute URL for <link rel="canonical">. Pages need the permalink too:
      # relative_url turns /archive.html into /archive. Redirect stubs point
      # at their target.
      helper :canonical_url do |resource|
        site.config.url + (resource.data.redirect_to || PostUrl.for(resource))
      end

      # Marks HTML as plain text so the feed template's <%= %> escapes it
      # exactly once, as Atom's type="html" content requires. Never escape it
      # again here: that double-escapes the feed.
      helper :feed_html do |html|
        String.new(html.to_s)
      end

      # Entry body for the feed: link posts lead with the external link,
      # photo posts with their 960px JPEG.
      helper :feed_body do |resource|
        FeedEntry.lead(resource, photos: site.data.photos, base_url: site.config.url) + resource.content.to_s
      end

      # <title> text: posts use feed_title, pages their own title, then the
      # site name, unless the title already starts with it ("Jordan Brock
      # (Page 2)" on paginated pages).
      helper :page_title do |resource|
        page = (post?(resource) ? FeedEntry.title(resource) : resource.data.title).to_s
        parts = page.start_with?(SITE_NAME) ? [page] : [page, SITE_NAME].reject(&:empty?)
        parts.map { CGI.escapeHTML(_1) }.join(" &mdash; ").html_safe
      end
    end

    private

    def post?(resource) = resource.respond_to?(:collection) && resource.collection&.label == "posts"
  end
end
