require "minitest_helper"
require "rexml/document"
require "cgi"
require_relative "../plugins/post_type"

class TestSite < Bridgetown::Test
  FEED = File.expand_path("../output/atom.xml", __dir__)
  def self.feed_doc = @feed_doc ||= REXML::Document.new(File.read(FEED))
  def feed_doc = TestSite.feed_doc

  describe "feeds" do
    it "atom.xml is well-formed with 20 entries" do
      expect(REXML::XPath.match(feed_doc, "//entry").size).must_equal 20
    end

    it "atom.xml escapes exactly once" do
      entries = REXML::XPath.match(feed_doc, "//entry")
      entries.each do |entry|
        title = entry.elements["title"].text.to_s
        %w[&amp; &quot; &lt;].each { |bad| expect(title).wont_include bad }
      end
      expect(entries.first.elements["content"].text.to_s).must_match(/\A\s*</)
    end

    it "lists the 20 newest posts, newest first, with unchanged ids" do
      ids = REXML::XPath.match(feed_doc, "//entry/id").map(&:text)
      expected = PostType.posts(site.collections.posts.resources).first(20)
      expect(ids).must_equal expected.map { "http://jordanbrock.com#{_1.relative_url}" }
      # Golden ids: these must never change, or feed readers re-show old posts.
      expect(REXML::XPath.first(feed_doc, "/feed/id").text).must_equal "http://jordanbrock.com/"
      expect(ids).must_include "http://jordanbrock.com/2023/06/05/new-job"
      expect(ids).must_include "http://jordanbrock.com/2012/04/17/vagrant-chef-and-openphoto/"
    end

    it "sitemap.xml is well-formed and lists every post" do
      doc = REXML::Document.new(File.read("output/sitemap.xml"))
      expect(REXML::XPath.match(doc, "//url").size).must_be :>=, site.collections.posts.resources.size
    end
  end

  describe "feed content" do
    it "the newest link, photo and note posts are in the feed, led by FeedEntry.lead" do
      entries = REXML::XPath.match(feed_doc, "//entry")
      %w[link photo note].each do |type|
        post = PostType.posts(site.collections.posts.resources, type).first
        expect(post).wont_be_nil("no #{type} posts")
        entry = entries.find { _1.elements["id"].text == "http://jordanbrock.com#{post.relative_url}" }
        expect(entry).wont_be_nil("newest #{type} post #{post.relative_url} is not in the feed")
        lead = FeedEntry.lead(post, photos: site.data.photos, base_url: site.config.url)
        expect(lead.empty?).must_equal(type == "note", type)
        expect(entry.elements["content"].text).must_match(/\A#{Regexp.escape(lead)}<p>/)
        expect(entry.elements["title"].text.to_s.strip).wont_be_empty
      end
    end
  end

  describe "helpers" do
    def view = Bridgetown::ERBView.new(site.collections.posts.resources.first)

    it "page_title escapes a page title once" do
      page = Struct.new(:collection, :data).new(nil, Struct.new(:title).new("A & B"))
      expect(view.page_title(page)).must_equal "A &amp; B &mdash; Jordan Brock"
    end

    it "feed_html drops html_safe so the template escapes exactly once" do
      out = view.feed_html("<p>a &amp; b</p>".html_safe)
      expect(out.html_safe?).must_equal false
      expect(out).must_equal "<p>a &amp; b</p>"
    end

    it "PostUrl ignores a permalink with unexpanded placeholders" do
      stub = Struct.new(:data, :relative_url)
      expect(PostUrl.for(stub.new(Struct.new(:permalink).new("/:year/:slug/"), "/2026/x/"))).must_equal "/2026/x/"
      expect(PostUrl.for(stub.new(Struct.new(:permalink).new("/2023/a.html"), "/2023/a"))).must_equal "/2023/a.html"
      expect(PostUrl.for(stub.new(Struct.new(:permalink).new(nil), "/2023/a"))).must_equal "/2023/a"
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

  def first_of(type) # the newest post of type
    PostType.posts(site.collections.posts.resources, type).first or skip("no #{type} posts")
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
      bad = Posts::Link.new(resource: stub.call("javascript:alert(1)"), mode: :full)
      expect(bad.url).must_equal "#"
      expect(bad.domain).must_equal PostType.link_domain("javascript:alert(1)") # matches feed_title, not "#"
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
      err = expect { Picture.new(image: "2026/missing.jpg", alt: "x") }.must_raise PhotoProcessor::MissingError
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
    def posts_of(type) = PostType.posts(site.collections.posts.resources, type)
    def output(path) = File.expand_path("../output#{path}#{"index.html" if path.end_with?("/")}", __dir__)

    it "archive groups every post by year, newest first, with type markers and feed titles" do
      html get "/archive.html"
      years = document.query_selector_all(".archive h2").map { _1.text.to_i }
      expect(years).must_equal years.sort.reverse
      expect(years.last).must_equal 2003
      expect(document.query_selector_all(".archive li").size).must_equal site.collections.posts.resources.size

      typed = site.collections.posts.resources.count { PostType.for_resource(_1) != "article" }
      expect(document.query_selector_all(".archive li .type").size).must_equal typed
      expect(document.query_selector_all(".archive li .type").map(&:text).uniq).wont_include "article"

      links = document.query_selector_all(".archive li a")
      expected = PostType.posts(site.collections.posts.resources)
      expect(links.map { _1["href"] }).must_equal expected.map { PostUrl.for(_1) }
      expect(links.map { _1["href"] }).must_include "/2023/06/05/new-job.html"
      text = links.first.text
      html get PostUrl.for(expected.first) # its <title> comes from feed_title too
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
        expected = posts_of(type).map { PostUrl.for(_1) }
        expect(document.query_selector_all(".archive li a").map { _1["href"] }).must_equal expected
        expect(document.query_selector(".archive ul")).must_be_nil if expected.empty?
      end
    end

    it "photos page shows a lazy grid of every photo post" do
      photos = posts_of("photo").tap { skip("no photo posts") if _1.empty? }
      html get "/photos/"
      links = document.query_selector_all(".photo-grid a")
      expect(links.map { _1["href"] }).must_equal photos.map { PostUrl.for(_1) }
      links.each do |a|
        img = a.query_selector("picture img")
        expect(img["loading"]).must_equal "lazy"
        expect(img["alt"].to_s.strip).wont_be_empty
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
        path = "/tags/#{Bridgetown::Utils.slugify(tag, mode: site.config.slugify_mode)}/"
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
      TagPages.prune!(site) # normally a pre_render hook; the test site is not rendered
      post = site.collections.posts.resources.first
      stub = Struct.new(:site, :relative_url, :date, :data).new(site, "/x/", post.date, Struct.new(:tags, :permalink).new([" Rails ", "never-used", "!!!"], nil))
      html = PostMeta.new(resource: stub, show_type: false).render_in(Bridgetown::ERBView.new(post))
      expect(html.scan(%r{href="/tags/[^"]*"})).must_equal [%(href="/tags/rails/")]
      expect(html).must_include "#never-used"
      expect(html).must_include "#!!!"
    end

    it "sitemap lists the static pages, the tag pages and each post at its linked URL" do
      doc = REXML::Document.new(File.read(File.expand_path("../output/sitemap.xml", __dir__)))
      locs = REXML::XPath.match(doc, "//loc").map(&:text)
      tag_pages = Dir[File.expand_path("../output/tags/*/index.html", __dir__)].map { "/tags/#{File.basename(File.dirname(_1))}/" }
      expect(tag_pages).wont_be_empty
      paths = %w[/ /archive.html /notes/ /links/ /photos/ /about/] + tag_pages + site.collections.posts.resources.map { PostUrl.for(_1) }
      expect(locs.sort).must_equal paths.map { "#{site.config.url}#{_1}" }.sort
    end

    it "pages carry a canonical link" do
      { "/2023/06/05/new-job.html" => "/2023/06/05/new-job.html", "/archive.html" => "/archive.html",
        "/tags/rails/" => "/tags/rails/", "/" => "/" }.each do |path, canonical|
        html get path
        expect(document.query_selector("link[rel=canonical]")["href"]).must_equal "https://jordanbrock.com#{canonical}", path
      end
    end

    it "masthead nav links resolve" do
      html get "/"
      document.query_selector_all(".masthead nav a").each { expect(File.file?(output(_1["href"]))).must_equal true, _1["href"] }
    end
  end
end
