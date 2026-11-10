require "minitest/autorun"
require_relative "../plugins/post_type"
require_relative "../plugins/photo_processor"
require_relative "../plugins/feed_entry"

class TestFeedEntry < Minitest::Test
  # Just enough of a Bridgetown resource: front matter, data, body, date, path.
  class Post
    DataStub = Struct.new(:link, :image, :alt, keyword_init: true)

    attr_reader :content, :date, :relative_path

    def initialize(attrs, content: "", date: Time.utc(2026, 11, 7), path: "_posts/2026-11-07-x.md")
      @attrs = attrs
      @content = content
      @date = date
      @relative_path = path
    end

    def model = Struct.new(:attributes).new(@attrs)
    def data = DataStub.new(**@attrs.transform_keys(&:to_sym).slice(:link, :image, :alt))
  end

  PHOTOS = { "2026/a.jpg" => { widths: [480, 960, 1600], width: 1600, height: 1000, base: "2026/a" } }.freeze
  BASE = "https://jordanbrock.com".freeze

  def lead(post) = FeedEntry.lead(post, photos: PHOTOS, base_url: BASE)

  def test_link_leads_with_the_escaped_external_link_and_title
    post = Post.new({ "link" => "https://example.com/?a=1&b=2", "title" => "Fish & chips" })
    assert_equal %(<p><a href="https://example.com/?a=1&amp;b=2">Fish &amp; chips</a></p>), lead(post)
  end

  def test_javascript_link_becomes_hash_but_keeps_its_text_title
    post = Post.new({ "link" => "javascript:alert(1)" })
    assert_equal %(<p><a href="#">javascript:alert(1)</a></p>), lead(post)
  end

  def test_photo_leads_with_the_absolute_960_jpeg_and_escaped_alt
    post = Post.new({ "image" => "2026/a.jpg", "alt" => %(a "q" <b>) })
    assert_equal %(<p><img src="https://jordanbrock.com/photos/2026/a-960.jpg" alt="a &quot;q&quot; &lt;b&gt;"></p>), lead(post)
  end

  def test_photo_with_empty_alt_uses_the_feed_title
    post = Post.new({ "image" => "2026/a.jpg", "alt" => "  " }, content: "<p>Dusk over the river</p>")
    assert_includes lead(post), %(alt="Dusk over the river")
    assert_includes lead(Post.new({ "image" => "2026/a.jpg" })), %(alt="Photo, 7 Nov")
  end

  def test_missing_photo_names_the_image_and_post
    err = assert_raises(PhotoProcessor::MissingError) { lead(Post.new({ "image" => "2026/gone.jpg" })) }
    assert_includes err.message, "2026/gone.jpg"
    assert_includes err.message, "_posts/2026-11-07-x.md"
  end

  def test_photo_post_with_no_image_says_so
    err = assert_raises(PhotoProcessor::InvalidError) { lead(Post.new({ "type" => "photo" })) }
    assert_includes err.message, "no image"
    assert_includes err.message, "_posts/2026-11-07-x.md"
  end

  def test_notes_and_articles_have_no_lead
    assert_equal "", lead(Post.new({}, content: "<p>Hi</p>"))
    assert_equal "", lead(Post.new({ "title" => "T" }))
  end

  def test_title
    assert_equal "T & U", FeedEntry.title(Post.new({ "title" => "T & U" }))
    assert_equal "example.com", FeedEntry.title(Post.new({ "link" => "https://www.example.com/x" }))
    words = "<p>one two three four five six seven eight nine</p>"
    assert_equal "one two three four five six seven eight…", FeedEntry.title(Post.new({}, content: words))
    assert_equal "Note, 7 Nov", FeedEntry.title(Post.new({}))
  end

  def test_post_type_alt_falls_back_to_the_feed_title
    assert_equal "Own alt", PostType.alt(Post.new({ "image" => "2026/a.jpg", "alt" => " Own alt " }))
    assert_equal "Photo, 7 Nov", PostType.alt(Post.new({ "image" => "2026/a.jpg", "alt" => "" }))
  end

  def test_photo_paths
    info = PHOTOS["2026/a.jpg"]
    assert_equal "/photos/2026/a-960.jpg", PhotoProcessor.jpeg_path(info)
    assert_equal "/photos/2026/a-1600.jpg", PhotoProcessor.jpeg_path(info, max: 2000)
    assert_equal "/photos/2026/b-1200.jpg", PhotoProcessor.jpeg_path({ widths: [1200], base: "2026/b" })
    assert_equal "/photos/2026/a-480.webp 480w, /photos/2026/a-960.webp 960w, /photos/2026/a-1600.webp 1600w", PhotoProcessor.srcset(info, "webp")
  end

  def test_lookup_rejects_blank_image_and_nil_registry
    assert_raises(PhotoProcessor::InvalidError) { PhotoProcessor.lookup!(PHOTOS, " ") }
    assert_raises(PhotoProcessor::MissingError) { PhotoProcessor.lookup!(nil, "2026/a.jpg") }
    assert_equal PHOTOS["2026/a.jpg"], PhotoProcessor.lookup!(PHOTOS, "2026/a.jpg")
  end
end
