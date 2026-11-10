require "minitest/autorun"
require_relative "../plugins/tag_normalizer"

class TestTagNormalizer < Minitest::Test
  def test_normalize_lowercases_trims_and_maps
    assert_equal %w[rails travel], TagNormalizer.normalize(["Ruby on Rails", " Travel ", "rubyonrails"])
  end

  def test_normalize_drops_blank
    assert_equal [], TagNormalizer.normalize(["", nil, "  "])
  end

  def test_keep_only_tags_used_min_times
    posts = { "a" => %w[rails web], "b" => %w[rails], "c" => %w[rails web], "d" => %w[cats] }
    kept = TagNormalizer.apply_threshold(posts, min: 2)
    assert_equal({ "a" => %w[rails web], "b" => %w[rails], "c" => %w[rails web], "d" => [] }, kept)
  end
end
