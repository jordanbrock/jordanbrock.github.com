require "minitest_helper"
require "rexml/document"
require_relative "../plugins/post_type"
require_relative "../plugins/tag_pages"

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
      expect(site.collections.posts.resources.size).must_equal Dir[File.expand_path("../src/_posts/*.{md,markdown}", __dir__)].size
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
      expect(classes).wont_be_empty
      expect(classes.all? { _1 =~ /\b(article|note|link|photo)\b/ }).must_equal true
    end

    it "articles in the stream show a summary and keep-reading link" do
      first_of("article")
      html get "/"
      article = document.query_selector(".stream > .article")
      expect(article).wont_be_nil
      expect(article.query_selector(".more")).wont_be_nil
    end

    it "link posts show the external link with the domain" do
      post = first_of("link")
      html get post.relative_url
      a = document.query_selector(".link-card a.link-card__title")
      expect(a["href"]).must_equal post.data.link
      expect(document.query_selector(".link-card .meta").text).must_include "example.com"
    end

    it "a type-less, title-less post renders as a note with a body-derived title" do
      html get "/2026/11/08/rain-delay/"
      expect(document.query_selector("main .note")).wont_be_nil
      expect(document.query_selector("title").text).must_match(/\ARain delay at the WACA/)
    end

    it "title-less link posts fall back to the domain, and non-http links are neutralised" do
      stub = lambda do |link|
        model = Struct.new(:attributes).new({ "link" => link })
        data = Struct.new(:link).new(link)
        Struct.new(:model, :data).new(model, data)
      end
      link = Posts::Link.new(resource: stub.call("https://www.example.com/x"), mode: :full)
      expect(link.title).must_equal "example.com"
      expect(link.url).must_equal "https://www.example.com/x"
      expect(Posts::Link.new(resource: stub.call("javascript:alert(1)"), mode: :full).url).must_equal "#"
    end

    it "notes have no heading" do
      post = first_of("note")
      html get post.relative_url
      expect(document.query_selector(".note h2, .note h1")).must_be_nil
    end
  end

  describe "photos" do
    def photo_srcs(img, source) = [img["src"], *"#{img["srcset"]}, #{source["srcset"]}".split(",").map { _1.strip.split.first }]

    it "photo post page has an eager picture with webp and jpeg srcsets, dimensions and alt" do
      post = first_of("photo")
      html get post.relative_url
      source = document.query_selector(".photo picture source[type='image/webp']")
      img = document.query_selector(".photo picture img")
      expect(source["srcset"]).must_match(/\.webp \d+w/)
      expect(img["srcset"]).must_match(/\.jpg \d+w/)
      expect(img["width"].to_i).must_be :>, 0
      expect(img["height"].to_i).must_be :>, 0
      expect(img["alt"]).must_equal post.data.alt
      expect(img["loading"]).must_be_nil
      photo_srcs(img, source).each { expect(File.file?(File.expand_path("../output#{_1}", __dir__))).must_equal true, _1 }
    end

    it "photos lazy-load in the stream" do
      first_of("photo")
      html get "/"
      img = document.query_selector(".stream .photo picture img")
      expect(img["loading"]).must_equal "lazy"
    end

    it "registers processed photos under the post's image path" do
      post = first_of("photo")
      info = site.data.photos[post.data.image]
      expect(info[:widths]).wont_be_empty
      expect(info[:base]).must_equal post.data.image.sub(/\.[^.]+\z/, "")
    end

    it "escapes alt text and names the image when it was not processed" do
      Bridgetown::Current.site = site
      post = first_of("photo")
      html = Picture.new(image: post.data.image, alt: %(a "quoted" <b>)).render_in(Bridgetown::ERBView.new(post))
      expect(html).must_include %(alt="a &quot;quoted&quot; &lt;b&gt;")
      err = expect { Picture.new(image: "2026/missing.jpg", alt: "x") }.must_raise ArgumentError
      expect(err.message).must_include "2026/missing.jpg"
    end

    def photos_src = File.expand_path("../src/photos", __dir__)
    def originals = Dir[File.join(photos_src, "**", "*")].select { File.file?(_1) }.tap { skip("no files in src/photos") if _1.empty? }

    it "never publishes originals" do
      photos = photos_src
      originals.each do |orig|
        rel = orig.delete_prefix("#{photos}/")
        expect(File.exist?(File.expand_path("../output/photos/#{rel}", __dir__))).must_equal false, rel
      end
    end

    it "publishes only resized files under output/photos" do
      originals
      files = Dir[File.expand_path("../output/photos/**/*", __dir__)].select { File.file?(_1) }
      expect(files.reject { _1.match?(/-\d+\.(webp|jpg)\z/) || _1.end_with?("/photos/index.html") }).must_be_empty
    end
  end
  describe "pages" do
    def posts_of(type) = site.collections.posts.resources.select { PostType.for_resource(_1) == type }
    def output(path) = File.expand_path("../output#{path}#{"index.html" if path.end_with?("/")}", __dir__)

    it "archive groups every post by year, newest first, with type markers and feed titles" do
      html get "/archive.html"
      years = document.query_selector_all(".archive h2").map { _1.text.to_i }
      expect(years).must_equal years.sort.reverse
      expect(years.last).must_equal 2003
      expect(document.query_selector_all(".archive li").size).must_equal site.collections.posts.resources.size

      newest = site.collections.posts.resources.max_by(&:date)
      typed = site.collections.posts.resources.count { PostType.for_resource(_1) != "article" }
      expect(document.query_selector_all(".archive li .type").size).must_equal typed
      expect(document.query_selector_all(".archive li .type").map(&:text).uniq).wont_include "article"

      first = document.query_selector(".archive li a")
      expect(first["href"]).must_equal newest.relative_url
      text = first.text
      html get newest.relative_url # its <title> comes from feed_title too
      expect(document.query_selector("title").text).must_equal "#{text} \u2014 Jordan Brock"
    end

    it "about page has the bio from the old sidebar" do
      html get "/about/"
      text = document.query_selector("main").text
      expect(text).must_include "Ruby developer who works for"
      expect(text).must_include "I play cricket, and I volunteer at Subiaco-Floreat Cricket Club"
      expect(document.query_selector("main a[href='https://streem.com.au']")).wont_be_nil
    end

    it "notes and links pages list exactly the posts of their type" do
      %w[note link].each do |type|
        html get "/#{type}s/"
        expected = posts_of(type).map(&:relative_url).sort
        expect(document.query_selector_all(".archive li a").map { _1["href"] }.sort).must_equal expected
        expect(document.query_selector(".archive ul")).must_be_nil if expected.empty?
      end
    end

    it "photos page shows a lazy grid of every photo post" do
      photos = posts_of("photo").tap { skip("no photo posts") if _1.empty? }
      html get "/photos/"
      links = document.query_selector_all(".photo-grid a")
      expect(links.map { _1["href"] }.sort).must_equal photos.map(&:relative_url).sort
      links.each do |a|
        img = a.query_selector("picture img")
        expect(img["loading"]).must_equal "lazy"
        expect(img["sizes"]).must_match(/13rem/)
      end
    end

    it "every tag link resolves to a built tag page" do
      hrefs = Dir[File.expand_path("../output/**/*.html", __dir__)].flat_map do |file|
        File.read(file, encoding: "UTF-8").scan(%r{href="(/tags/[^"]*)"}).flatten
      end.uniq
      expect(hrefs).wont_be_empty
      hrefs.each { expect(File.file?(output(_1))).must_equal true, "missing tag page for #{_1}" }
    end

    it "builds a tag page for each tag on enough posts, listing exactly those posts, and no others" do
      by_tag = site.collections.posts.resources.flat_map { |post| Array(post.data.tags).map { [_1.to_s.downcase.strip, post] } }
                   .group_by(&:first).transform_values { _1.map(&:last) }
      by_tag.each do |tag, posts|
        path = "/tags/#{Bridgetown::Utils.slugify(tag)}/"
        if posts.size >= TagPages::MIN_POSTS
          html get path
          expect(document.query_selector_all(".stream > *").size).must_equal posts.size, path
        else
          expect(File.exist?(output(path))).must_equal false, "#{path} has only #{posts.size} posts"
        end
      end
      built = Dir[File.expand_path("../output/tags/*/index.html", __dir__)].size
      expect(built).must_equal by_tag.count { _2.size >= TagPages::MIN_POSTS }
    end

    it "post meta links only tags that have a page" do
      Bridgetown::Current.site = site
      post = site.collections.posts.resources.first
      stub = Struct.new(:site, :relative_url, :date, :data).new(site, "/x/", post.date, Struct.new(:tags).new([" Rails ", "never-used", "!!!"]))
      html = PostMeta.new(resource: stub, show_type: false).render_in(Bridgetown::ERBView.new(post))
      expect(html.scan(%r{href="/tags/[^"]*"})).must_equal [%(href="/tags/rails/")]
      expect(html).must_include "#never-used"
      expect(html).must_include "#!!!"
    end

    it "sitemap lists the static pages" do
      doc = REXML::Document.new(File.read(File.expand_path("../output/sitemap.xml", __dir__)))
      locs = REXML::XPath.match(doc, "//loc").map(&:text)
      %w[/ /archive.html /notes/ /links/ /photos/ /about/].each { expect(locs).must_include "#{site.config.url}#{_1}" }
    end

    it "masthead nav links resolve" do
      html get "/"
      document.query_selector_all(".masthead nav a").each { expect(File.file?(output(_1["href"]))).must_equal true, _1["href"] }
    end
  end
end
