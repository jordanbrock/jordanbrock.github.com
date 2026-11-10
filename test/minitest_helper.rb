ENV["MT_NO_EXPECTATIONS"] = "true"
require "minitest/autorun"
require "minitest/reporters"
Minitest::Reporters.use! [Minitest::Reporters::ProgressReporter.new]

require "bridgetown/test"

# Bridgetown::Test#site is nil in this project (no booted Roda site), so load a
# memoised, read-only site for tests that need collections/resources.
module TestSiteLoader
  def self.site
    @site ||= begin
      config = Bridgetown::Current.preloaded_configuration || Bridgetown.configuration(root_dir: Dir.pwd)
      Bridgetown::Site.new(config).tap { |s| s.reset; s.read; s.generate }
    end
  end
end

class Bridgetown::Test
  def site = TestSiteLoader.site
end
