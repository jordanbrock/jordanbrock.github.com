require "cgi"

module Builders
  class Helpers < SiteBuilder
    def build
      # Title for feeds and lists; notes and photos have no title.
      helper :feed_title do |resource|
        feed_title_for(resource)
      end

      # <title> text: posts use feed_title, pages their own title.
      helper :page_title do |resource|
        page = resource.respond_to?(:collection) && resource.collection.label == "posts" ? feed_title_for(resource) : resource.data.title
        parts = [page, "Jordan Brock"].compact.map(&:to_s).reject(&:empty?).uniq
        parts.map { CGI.escapeHTML(_1) }.join(" &mdash; ").html_safe
      end
    end

    private

    def feed_title_for(resource)
      type = PostType.for_resource(resource)
      # data.title is slug-derived for untitled posts, so read the real front matter
      title = %w[article link].include?(type) ? PostType.title(resource) : ""
      title = PostType.link_domain(resource.data.link) if title.empty? && type == "link"
      return title unless title.empty?

      words = CGI.unescapeHTML(resource.content.to_s.gsub(/<[^>]+>/, " ")).split # templates escape on output
      return "#{type.capitalize}, #{resource.date.strftime("%-d %b")}" if words.empty?

      words.first(8).join(" ") + (words.size > 8 ? "…" : "")
    end
  end
end
