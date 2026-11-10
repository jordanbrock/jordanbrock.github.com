module Builders
  class Helpers < SiteBuilder
    def build
      helper :post_type do |resource|
        PostType.for(resource.data)
      end

      # Title for feeds and lists; notes and photos have no title.
      helper :feed_title do |resource|
        title = resource.data.title.to_s.strip
        next title unless title.empty?

        words = resource.content.to_s.gsub(/<[^>]+>/, " ").split # templates escape on output
        if words.empty?
          "#{PostType.for(resource.data).capitalize}, #{resource.date.strftime("%-d %b")}"
        else
          words.first(8).join(" ") + (words.size > 8 ? "…" : "")
        end
      end
    end
  end
end
