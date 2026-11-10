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

  def test_accepts_symbol_keys
    assert_equal "link", t(link: "https://example.com")
  end
end
