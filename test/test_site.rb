require "minitest_helper"
require "rexml/document"

class TestSite < Bridgetown::Test
  describe "feeds" do
    it "atom.xml is well-formed with 20 entries" do
      doc = REXML::Document.new(File.read("output/atom.xml"))
      expect(REXML::XPath.match(doc, "//entry").size).must_equal 20
    end

    it "sitemap.xml is well-formed and lists every post" do
      doc = REXML::Document.new(File.read("output/sitemap.xml"))
      post_count = Dir["src/_posts/**/*.{md,markdown}"].size
      expect(REXML::XPath.match(doc, "//url").size).must_be :>=, post_count
    end
  end

  describe "templates" do
    it "uses no Liquid templates" do
      expect(Dir["src/**/*.liquid"]).must_be_empty
    end
  end
end
