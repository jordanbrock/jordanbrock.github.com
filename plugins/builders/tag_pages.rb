module Builders
  # After the prototype and pagination generators have run, drop tag pages
  # for rare or unsluggable tags and record the rest (rebuilt every build).
  class TagPages < SiteBuilder
    def build
      hook :site, :pre_render, :prune
    end

    def prune(site) = ::TagPages.prune!(site)
  end
end
