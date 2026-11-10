require "minitest_helper"
require "rexml/document"
require_relative "../plugins/post_type"

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
      expect(site.collections.posts.resources.size).must_equal Dir["src/_posts/*.{md,markdown}"].size
    end

    it "applies the initializer's default permalink to posts" do
      meta = site.collections.posts.metadata
      expect(meta["permalink"]).must_equal "/:year/:month/:day/:slug/"
      expect(site.collections.posts.resources.first.collection.metadata["permalink"]).must_equal "/:year/:month/:day/:slug/"
    end
  end

  describe "posts" do
    it "have no unrendered Liquid tags in built HTML" do
      checked = 0
      offenders = site.collections.posts.resources.filter_map do |post|
        url = post.relative_url
        file = url.end_with?("/") ? "output#{url}index.html" : "output#{url}"
        file = "#{file}.html" unless File.file?(file) || File.extname(file) == ".html"
        next unless File.file?(file)

        checked += 1
        url if File.read(file, encoding: "UTF-8").match?(/\{%|%\}/)
      end
      expect(checked).must_be :>, 0
      expect(offenders).must_be_empty
    end
  end

  describe "templates" do
    it "uses no Liquid templates" do
      expect(Dir["src/**/*.liquid"]).must_be_empty
    end
  end

  def first_of(type)
    site.collections.posts.resources.find { PostType.for_resource(_1) == type } or skip("no #{type} posts")
  end

  describe "layout" do
    it "has the masthead and nav" do
      html get "/"
      expect(document.query_selector(".masthead__name").text).must_equal "Jordan Brock"
      expect(document.query_selector_all(".masthead nav a").map(&:text)).must_equal %w[Archive Photos About]
    end

    it "loads the new stylesheet only" do
      html get "/"
      hrefs = document.query_selector_all("link[rel=stylesheet]").map { _1["href"] }
      expect(hrefs).must_equal ["/css/site.css"]
    end
  end

  describe "post types on the home page" do
    it "renders each type with its own class" do
      html get "/"
      classes = document.query_selector_all(".stream > *").map { _1["class"] }
      expect(classes.all? { _1 =~ /\b(article|note|link|photo)\b/ }).must_equal true
    end

    it "articles in the stream show a summary and keep-reading link" do
      html get "/page2/"
      article = document.query_selector(".stream > .article")
      expect(article.query_selector(".more")).wont_be_nil
    end

    it "link posts show the external link with the domain" do
      post = first_of("link")
      html get post.relative_url
      a = document.query_selector(".link-card a.link-card__title")
      expect(a["href"]).must_equal post.data.link
      expect(document.query_selector(".link-card .meta").text).must_include URI(post.data.link).host.delete_prefix("www.")
    end

    it "a type-less, title-less post renders as a note with a body-derived title" do
      html get "/2026/11/08/rain-delay/"
      expect(document.query_selector("main .note")).wont_be_nil
      expect(document.query_selector("title").text).must_match(/\ARain delay at the WACA/)
    end

    it "notes have no heading" do
      post = first_of("note")
      html get post.relative_url
      expect(document.query_selector(".note h2, .note h1")).must_be_nil
    end
  end
end
