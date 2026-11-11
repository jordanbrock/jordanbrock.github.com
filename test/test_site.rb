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
      expect(ids).must_equal expected.map { FeedEntry.id(_1) }
      expect(REXML::XPath.first(feed_doc, "/feed/id").text).must_equal "http://jordanbrock.com/"
    end

    it "keeps the legacy Atom ids, with and without a trailing slash" do
      # Golden ids: these must never change, or feed readers re-show old posts.
      { "_posts/2012-04-17-vagrant-chef-and-openphoto.markdown" => "http://jordanbrock.com/2012/04/17/vagrant-chef-and-openphoto/",
        "_posts/2023-06-05-new-job.markdown" => "http://jordanbrock.com/2023/06/05/new-job" }.each do |path, id|
        post = site.collections.posts.resources.find { _1.relative_path.to_s == path }
        expect(post).wont_be_nil(path)
        expect(FeedEntry.id(post)).must_equal id
      end
    end

    it "sitemap.xml is well-formed and lists every post" do
      doc = REXML::Document.new(File.read("output/sitemap.xml"))
      expect(REXML::XPath.match(doc, "//url").size).must_be :>=, site.collections.posts.resources.size
    end
  end

  describe "feed content" do
    it "every entry starts with its post's FeedEntry.lead and has a title" do
      posts = PostType.posts(site.collections.posts.resources).first(20)
      entries = REXML::XPath.match(feed_doc, "//entry")
      expect(entries.size).must_equal posts.size
      posts.zip(entries).each do |post, entry|
        expect(entry.elements["id"].text).must_equal FeedEntry.id(post)
        lead = FeedEntry.lead(post, photos: site.data.photos, base_url: site.config.url)
        expect(entry.elements["content"].text.to_s.start_with?(lead)).must_equal true, post.relative_url
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

    it "page_title drops the site name when the title already starts with it" do
      page = ->(title) { Struct.new(:collection, :data).new(nil, Struct.new(:title).new(title)) }
      expect(view.page_title(page.call("Jordan Brock (Page 2)"))).must_equal "Jordan Brock (Page 2)"
      expect(view.page_title(page.call("Jordan Brock"))).must_equal "Jordan Brock"
      html get "/page2/"
      expect(document.query_selector("title").text).must_equal "Jordan Brock (Page 2)"
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
    it "album helpers pick the cover, a strip of up to four, and the hidden count" do
      stub = lambda do |n|
        photos = (1..n).map { { "image" => "2026/a#{_1}.jpg", "alt" => "A#{_1}" } }
        Struct.new(:model, :relative_path).new(Struct.new(:attributes).new({ "photos" => photos }), "_posts/x.md")
      end
      one = Posts::Album.new(resource: stub.call(1), mode: :summary)
      expect(one.cover[:index]).must_equal 1
      expect(one.strip).must_equal []
      expect(one.more).must_equal 0
      seven = Posts::Album.new(resource: stub.call(7), mode: :summary)
      expect(seven.strip.map { _1[:index] }).must_equal [2, 3, 4, 5]
      expect(seven.more).must_equal 2
      expect(Posts::Album.new(resource: stub.call(5), mode: :summary).more).must_equal 0
      two = Posts::Album.new(resource: stub.call(2), mode: :summary)
      expect(two.strip.size).must_equal 1
      expect(two.more).must_equal 0
      expect(Posts::Album.new(resource: stub.call(6), mode: :summary).more).must_equal 1
      expect(PostPhotos.anchor(seven.strip_target(3))).must_equal "#photo-6"
      expect(seven.strip_label(3)).must_include "(and 2 more)"
      expect(seven.strip_label(0)).must_be_nil
      five = Posts::Album.new(resource: stub.call(5), mode: :summary)
      expect(PostPhotos.anchor(five.strip_target(3))).must_equal "#photo-5"
      expect(five.strip_label(3)).must_be_nil
    end

    it "renders each type with its own class" do
      html get "/"
      classes = document.query_selector_all(".stream > *").map { _1["class"] }
      expect(classes).wont_be_empty
      expect(classes.all? { _1 =~ /\b(article|note|link|photo|album)\b/ }).must_equal true
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
      expected = PostType.front_matter(post).dig("preview", "site").to_s.strip
      expected = PostType.link_domain(post.data.link) if expected.empty?
      expect(expected).wont_be_empty
      expect(document.query_selector(".link-card .meta").text).must_include expected
    end

    it "a title-less note renders as a note with a body-derived title" do
      post = first_of("note")
      html get PostUrl.for(post)
      expect(document.query_selector("main .note")).wont_be_nil
      first_word = FeedEntry.title(post).split.first
      expect(document.query_selector("title").text).must_include first_word
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

    it "link previews: the card reads image, description and site name, and ignores a bad preview" do
      stub = lambda do |attrs|
        model = Struct.new(:attributes).new(attrs)
        data = Struct.new(:link).new(attrs["link"])
        Struct.new(:model, :data).new(model, data)
      end
      link = Posts::Link.new(resource: stub.call({ "link" => "https://www.example.com/x", "preview" => { "image" => " 2026/x-preview.jpg ", "description" => " About x ", "site" => "Example" } }), mode: :full)
      expect(link.preview_image).must_equal "2026/x-preview.jpg"
      expect(link.preview_description).must_equal "About x"
      expect(link.source).must_equal "Example"
      plain = Posts::Link.new(resource: stub.call({ "link" => "https://www.example.com/x" }), mode: :full)
      expect(plain.preview_image).must_be_nil
      expect(plain.preview_description).must_equal ""
      expect(plain.source).must_equal "example.com"
      bad = Posts::Link.new(resource: stub.call({ "link" => "https://www.example.com/x", "preview" => "oops" }), mode: :full)
      expect(bad.preview_image).must_be_nil
    end

    it "link posts with a preview image show it in the card" do
      post = site.collections.posts.resources.find { |p| PostType.for_resource(p) == "link" && PostType.front_matter(p)["preview"].respond_to?(:to_hash) && PostType.front_matter(p)["preview"]["image"] }
      skip "no link posts with a preview image" unless post
      html get post.relative_url
      expect(document.query_selector(".link-card__image picture img")).wont_be_nil
      expect(document.query_selector(".link-card__image img")["alt"]).must_equal ""
    end

    describe "rendering the link card" do
      # Replaces the post's own preview, so {} means none whatever the post has.
      def render_card(preview)
        post = first_of("link")
        c = Posts::Link.new(resource: post, mode: :full)
        c.define_singleton_method(:preview) { preview }
        Bridgetown::Current.site = site
        Nokolexbor::Document.parse(c.render_in(Bridgetown::ERBView.new(post)))
      end

      it "shows the image as decorative, the site name, and escapes the description" do
        key = site.data.photos&.keys&.first or skip("no processed photos")
        doc = render_card({ "image" => key, "description" => "<b>x</b>", "site" => "Ex" })
        expect(doc.query_selector('a.link-card__image[tabindex="-1"][aria-hidden="true"] picture img[alt=""]')).wont_be_nil
        expect(doc.query_selector(".meta").text).must_include "Ex"
        p = doc.query_selector("p.link-card__description")
        expect(p.text).must_equal "<b>x</b>"
        expect(p.query_selector("b")).must_be_nil
      end

      it "without a preview shows no image or description, and the domain" do
        doc = render_card({})
        expect(doc.query_selector(".link-card__image")).must_be_nil
        expect(doc.query_selector(".link-card__description")).must_be_nil
        expect(doc.query_selector(".meta").text).must_include PostType.link_domain(first_of("link").data.link)
      end
    end

    it "photo captions join paragraphs with a space and add no separator" do
      resource = Struct.new(:content).new("<p>One.</p>\n<p>Two.</p>\n")
      expect(Posts::Photo.new(resource:, mode: :full).caption_html).must_equal "One. Two."
      post = first_of("photo")
      html get post.relative_url
      expect(document.query_selector(".photo figcaption").inner_html).wont_match(/(\u00b7|&middot;)\s*<div/)
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

    it "stream photos link to their post for the lightbox; the photo page has no link" do
      post = first_of("photo")
      html get "/"
      link = document.query_selector(".stream .photo figure > a.lightbox")
      expect(link["href"]).must_equal PostUrl.for(post) # the home page's first photo is the newest
      expect(link.query_selector("picture img")).wont_be_nil
      expect(document.query_selector("script[src='/js/lightbox.js'][defer]")).wont_be_nil
      expect(File.file?(File.expand_path("../output/js/lightbox.js", __dir__))).must_equal true

      html get post.relative_url
      expect(document.query_selector(".photo a.lightbox")).must_be_nil
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

  describe "albums" do
    it "the album page has its heading and shows every photo with an anchor, caption and lazy loading after the first" do
      post = first_of("album")
      photos = PostPhotos.for(post)
      title = PostType.title(post)
      html get PostUrl.for(post)
      h1 = document.query_selector(".album h1")
      title.empty? ? expect(h1).must_be_nil : expect(h1.text).must_equal(title)
      figures = document.query_selector_all(".album > figure")
      expect(figures.map { _1["id"] }).must_equal photos.map { "photo-#{_1[:index]}" }
      expect(figures.map { _1.query_selector("img")["alt"] }).must_equal photos.map { _1[:alt] }
      photos.zip(figures).each do |photo, fig|
        caption = fig.query_selector("figcaption")
        photo[:caption] ? expect(caption.text).must_equal(photo[:caption]) : expect(caption).must_be_nil
      end
      expect(figures.first.query_selector("img")["loading"]).must_be_nil
      figures.drop(1).each { expect(_1.query_selector("img")["loading"]).must_equal "lazy" }
    end

    it "the stream shows the cover and a strip of up to four; the last tile links to the first hidden photo" do
      post = first_of("album")
      skip("newest album is not on page 1") unless PostType.posts(site.collections.posts.resources).first(10).include?(post)
      photos = PostPhotos.for(post)
      url = PostUrl.for(post)
      html get "/"
      album = document.query_selector(".stream > .album")
      expect(album).wont_be_nil
      title = PostType.title(post)
      link = album.query_selector("h2 a")
      title.empty? ? expect(link).must_be_nil : (expect(link["href"]).must_equal(url); expect(link.text).must_equal(title))
      expect(album.query_selector(".album__cover")["href"]).must_equal url
      expect(album.query_selector(".album__cover img")["alt"]).must_equal photos.first[:alt]

      strip = photos[1, 4].to_a
      hidden = photos.size > 5
      hrefs = strip.map { "#{url}#photo-#{_1[:index]}" }
      hrefs[-1] = "#{url}#photo-6" if hidden
      tiles = album.query_selector_all(".album__strip a")
      expect(tiles.map { _1["href"] }).must_equal hrefs
      labels = tiles.map { _1["aria-label"] }
      expect(labels).must_equal(Array.new(strip.size) { |i| hidden && i == strip.size - 1 ? "#{strip.last[:alt]} (and #{photos.size - 5} more)" : nil })
      more = album.query_selector(".album__more")
      hidden ? expect(more.text).must_equal("+#{photos.size - 5}") : expect(more).must_be_nil
    end

    it "/photos/ links each album photo to its anchor" do
      post = first_of("album")
      html get "/photos/"
      hrefs = document.query_selector_all(".photo-grid a").map { _1["href"] }
      PostPhotos.for(post).each { expect(hrefs).must_include "#{PostUrl.for(post)}#photo-#{_1[:index]}" }
    end

    it "the feed entry carries every album photo and caption" do
      post = first_of("album")
      skip("album not in the 20 newest") unless PostType.posts(site.collections.posts.resources).first(20).include?(post)
      entry = REXML::XPath.match(feed_doc, "//entry").find { _1.elements["id"].text == FeedEntry.id(post) }
      expect(entry).wont_be_nil
      content = entry.elements["content"].text.to_s
      PostPhotos.for(post).each do |photo|
        expect(content).must_include %(alt="#{CGI.escapeHTML(photo[:alt])}")
        expect(content).must_include "<p>#{CGI.escapeHTML(photo[:caption])}</p>" if photo[:caption]
      end
    end

    it "the archive marks albums" do
      post = first_of("album")
      html get "/archive.html"
      link = document.query_selector_all(".archive li a").find { _1["href"] == PostUrl.for(post) }
      expect(link).wont_be_nil
      expect(link.parent.query_selector(".type")&.text).must_equal "album"
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

    it "archive links to the notes and links pages" do
      html get "/archive.html"
      hrefs = document.query_selector_all("main > p a").map { _1["href"] }
      expect(hrefs).must_equal %w[/notes/ /links/]
    end

    it "has a 404 page for GitHub Pages to serve" do
      html get "/404.html"
      expect(document.query_selector("main h1").text).must_equal "Not found"
      expect(document.query_selector("main a[href='/archive.html']")).wont_be_nil
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

    it "photos page shows a lazy grid of every photo and album photo" do
      tiles = PostPhotos.tiles(site.collections.posts.resources).tap { skip("no photo posts") if _1.empty? }
      html get "/photos/"
      links = document.query_selector_all(".photo-grid a")
      expect(links.map { _1["href"] }).must_equal tiles.map { |post, photo| "#{PostUrl.for(post)}#{PostPhotos.anchor(photo)}" }
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

    it "stubs only the legacy /pageN/ URLs that pagination no longer makes" do
      real = site.generated_pages.map(&:relative_url).grep(%r{\A/page\d+/\z})
      expect(real).wont_be_empty
      expect(LegacyPagination.missing(site)).must_equal LegacyPagination.urls - real
      LegacyPagination.urls.each { expect(File.file?(output(_1))).must_equal true, _1 }
    end

    it "legacy pagination stubs point readers and crawlers at the archive" do
      stubs = LegacyPagination.missing(site).tap { skip("pagination covers every legacy page") if _1.empty? }
      stubs.each do |path|
        html get path
        expect(document.query_selector("main h1").text).must_equal "This page has moved"
        expect(document.query_selector("main a[href='/archive.html']")).wont_be_nil
        expect(document.query_selector("meta[http-equiv=refresh]")["content"]).must_equal "0; url=/archive.html"
        expect(document.query_selector("link[rel=canonical]")["href"]).must_equal "https://jordanbrock.com/archive.html"
      end
      html get "/page2/" # a real page: no redirect
      expect(document.query_selector("meta[http-equiv=refresh]")).must_be_nil
      expect(document.query_selector_all(".stream > *").size).must_equal 10
    end

    it "masthead nav links resolve" do
      html get "/"
      document.query_selector_all(".masthead nav a").each { expect(File.file?(output(_1["href"]))).must_equal true, _1["href"] }
    end
  end
end
