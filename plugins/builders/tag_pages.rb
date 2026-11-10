module Builders
  # The tag prototype makes a page for every tag; drop those for tags too
  # rare (or unsluggable) to have one, after pagination has run.
  class TagPages < SiteBuilder
    def build
      hook :site, :pre_render, :prune
    end

    def prune(site)
      site.generated_pages.reject! do |page|
        page.data["prototype"].is_a?(Hash) && page.data.key?("tag") && !::TagPages.page?(site, page.data["tag"])
      end
    end
  end
end
