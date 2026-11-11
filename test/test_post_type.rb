require "minitest/autorun"
require_relative "../plugins/post_type"

class TestPostType < Minitest::Test
  def t(data) = PostType.for(data)

  def test_explicit_type_wins
    assert_equal "note", t("type" => "note", "title" => "Has a title")
  end

  def test_image_means_photo
    assert_equal "photo", t("image" => "2026/x.jpg", "link" => "https://a", "title" => "T")
  end

  def test_link_means_link
    assert_equal "link", t("link" => "https://example.com", "title" => "T")
  end

  def test_title_means_article
    assert_equal "article", t("title" => "Hello")
  end

  def test_nothing_means_note
    assert_equal "note", t({})
  end

  def test_blank_title_is_ignored
    assert_equal "note", t("title" => "  ")
  end

  def test_unknown_explicit_type_raises
    assert_raises(ArgumentError) { t("type" => "video") }
  end

  def test_for_resource_names_the_file_on_unknown_type
    resource = Struct.new(:model, :relative_path).new(Struct.new(:attributes).new({ "type" => "video" }), "_posts/x.md")
    err = assert_raises(ArgumentError) { PostType.for_resource(resource) }
    assert_includes err.message, "Unknown post type: video"
    assert_includes err.message, "_posts/x.md"
  end

  def test_accepts_symbol_keys
    assert_equal "link", t(link: "https://example.com")
  end

  def test_for_resource_ignores_slug_derived_title_and_underscore_keys
    attrs = { "_id_" => "x", "_content_" => "body" }
    resource = Struct.new(:model).new(Struct.new(:attributes).new(attrs))
    assert_equal "note", PostType.for_resource(resource)
    attrs["title"] = "Real"
    assert_equal "article", PostType.for_resource(resource)
  end

  def stub_resource(attrs) = Struct.new(:model).new(Struct.new(:attributes).new(attrs))

  def test_title_reads_real_front_matter_only
    assert_equal "", PostType.title(stub_resource("link" => "https://a.com", "_id_" => "x"))
    assert_equal "Hi", PostType.title(stub_resource("title" => " Hi "))
  end

  def test_link_domain
    assert_equal "example.com", PostType.link_domain("https://www.example.com/x")
    assert_equal "not a url", PostType.link_domain("not a url")
  end

  def test_safe_link_allows_only_http
    assert_equal "https://a.com/x", PostType.safe_link(" https://a.com/x ")
    assert_equal "http://a.com", PostType.safe_link("http://a.com")
    assert_equal "#", PostType.safe_link("javascript:alert(1)")
    assert_equal "#", PostType.safe_link("data:text/html,x")
    assert_equal "#", PostType.safe_link("http://a b")
    assert_equal "#", PostType.safe_link("http:foo")
    assert_equal "#", PostType.safe_link("https://")
    assert_equal "#", PostType.safe_link(nil)
  end

  def test_photos_list_means_album
    assert_equal "album", t("photos" => [{ "image" => "2026/a.jpg" }], "link" => "https://a", "title" => "T")
  end

  def test_empty_photos_list_is_ignored
    assert_equal "article", t("photos" => [], "title" => "T")
  end

  def test_explicit_album_type
    assert_equal "album", t("type" => "album")
  end

  def test_image_and_photos_together_raise
    err = assert_raises(ArgumentError) { t("image" => "2026/a.jpg", "photos" => [{ "image" => "2026/b.jpg" }]) }
    assert_includes err.message, "either image or photos"
  end

  def test_non_list_photos_still_means_album # PostPhotos rejects it later
    assert_equal "album", t("photos" => "2026/a.jpg")
  end

  def test_image_with_empty_photos_is_photo
    assert_equal "photo", t("image" => "2026/a.jpg", "photos" => [])
  end
end
