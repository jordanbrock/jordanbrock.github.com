require "cgi"

module Builders
  class Helpers < SiteBuilder
    def build
      helper :post_type do |resource|
        PostType.for_resource(resource)
      end

      # Title for feeds and lists; notes and photos have no title.
      helper :feed_title do |resource|
        type = PostType.for_resource(resource)
        # data.title is slug-derived for untitled posts, so only trust it for articles and links
        title = %w[article link].include?(type) ? resource.data.title.to_s.strip : ""
        next title unless title.empty?

        words = CGI.unescapeHTML(resource.content.to_s.gsub(/<[^>]+>/, " ")).split # templates escape on output
        if words.empty?
          "#{type.capitalize}, #{resource.date.strftime("%-d %b")}"
        else
          words.first(8).join(" ") + (words.size > 8 ? "…" : "")
        end
      end
    end
  end
end
