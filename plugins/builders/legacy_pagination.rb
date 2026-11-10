module Builders
  # After pagination has run, stub the legacy /pageN/ URLs it no longer makes.
  class LegacyPagination < SiteBuilder
    def build
      hook :site, :pre_render, :add_stubs
    end

    def add_stubs(site) = ::LegacyPagination.add_stubs!(site)
  end
end
