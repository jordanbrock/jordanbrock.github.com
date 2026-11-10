require "minitest_helper"
require "rexml/document"

class TestSite < Bridgetown::Test
  describe "feeds" do
    it "atom.xml is well-formed with 20 entries" do
      doc = REXML::Document.new(File.read("output/atom.xml"))
      expect(REXML::XPath.match(doc, "//entry").size).must_equal 20
    end

    it "atom.xml escapes exactly once" do
      doc = REXML::Document.new(File.read("output/atom.xml"))
      entries = REXML::XPath.match(doc, "//entry")
      entries.each do |entry|
        title = entry.elements["title"].text.to_s
        %w[&amp; &quot; &lt;].each { |bad| expect(title).wont_include bad }
      end
      expect(entries.first.elements["content"].text.to_s).must_match(/\A\s*</)
    end

    it "sitemap.xml is well-formed and lists every post" do
      doc = REXML::Document.new(File.read("output/sitemap.xml"))
      expect(REXML::XPath.match(doc, "//url").size).must_be :>=, site.collections.posts.resources.size
    end
  end

  describe "site" do
    it "loads all posts" do
      expect(site.collections.posts.resources.size).must_equal 182
    end

    it "applies the initializer's default permalink to posts" do
      meta = site.collections.posts.metadata
      expect(meta["permalink"]).must_equal "/:year/:month/:day/:slug/"
      expect(site.collections.posts.resources.first.collection.metadata["permalink"]).must_equal "/:year/:month/:day/:slug/"
    end
  end

  describe "templates" do
    it "uses no Liquid templates" do
      expect(Dir["src/**/*.liquid"]).must_be_empty
    end
  end
end
