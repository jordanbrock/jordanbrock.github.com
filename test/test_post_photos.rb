require "minitest/autorun"
require_relative "../plugins/post_type"
require_relative "../plugins/feed_entry"
require_relative "../plugins/post_photos"

class TestPostPhotos < Minitest::Test
  # Just enough of a resource: front matter, data, body, date, path.
  class Post
    DataStub = Struct.new(:image, :alt, keyword_init: true)
    attr_reader :content, :date, :relative_path

    def initialize(attrs, date: Time.utc(2026, 11, 7), path: "_posts/2026-11-07-x.md")
      @attrs = attrs
      @content = ""
      @date = date
      @relative_path = path
    end

    def model = Struct.new(:attributes).new(@attrs)
    def data = DataStub.new(**@attrs.transform_keys(&:to_sym).slice(:image, :alt))
  end

  def album(*photos, **opts) = Post.new({ "photos" => photos }, **opts)

  def test_album_entries_are_numbered_from_one_with_stripped_values
    post = album({ "image" => " 2026/a.jpg ", "alt" => " A ", "caption" => " Cap " }, { "image" => "2026/b.jpg", "alt" => "B" })
    assert_equal [{ image: "2026/a.jpg", alt: "A", caption: "Cap", index: 1 },
                  { image: "2026/b.jpg", alt: "B", caption: nil, index: 2 }], PostPhotos.for(post)
  end

  def test_alt_falls_back_to_caption
    assert_equal "Cap", PostPhotos.for(album({ "image" => "2026/a.jpg", "caption" => "Cap" })).first[:alt]
  end

  def test_symbol_keys_work
    assert_equal "2026/a.jpg", PostPhotos.for(album({ image: "2026/a.jpg", alt: "A" })).first[:image]
  end

  def test_missing_image_names_the_post_and_position
    err = assert_raises(ArgumentError) { PostPhotos.for(album({ "image" => "2026/a.jpg", "alt" => "A" }, { "alt" => "B" })) }
    assert_includes err.message, "Album photo has no image (in _posts/2026-11-07-x.md, photo 2)"
  end

  def test_missing_alt_and_caption_names_the_post_and_position
    err = assert_raises(ArgumentError) { PostPhotos.for(album({ "image" => "2026/a.jpg", "caption" => "  " })) }
    assert_includes err.message, "Album photo needs alt text or a caption (in _posts/2026-11-07-x.md, photo 1)"
  end

  def test_photos_that_is_not_a_list_raises
    err = assert_raises(ArgumentError) { PostPhotos.for(Post.new({ "type" => "album", "photos" => "2026/a.jpg" })) }
    assert_includes err.message, "Album photos must be a list of mappings with image and alt or caption (in _posts/2026-11-07-x.md)"
  end

  def test_empty_album_raises
    err = assert_raises(ArgumentError) { PostPhotos.for(Post.new({ "type" => "album", "photos" => [] })) }
    assert_includes err.message, "Album has no photos (in _posts/2026-11-07-x.md)"
  end

  def test_entry_that_is_not_a_mapping_raises
    err = assert_raises(ArgumentError) { PostPhotos.for(album("2026/a.jpg")) }
    assert_includes err.message, "Album photo must be a mapping with image and alt or caption (in _posts/2026-11-07-x.md, photo 1)"
  end

  def test_nested_list_entry_raises_argument_error
    err = assert_raises(ArgumentError) { PostPhotos.for(album(["2026/a.jpg", "A"])) }
    assert_includes err.message, "Album photo must be a mapping with image and alt or caption (in _posts/2026-11-07-x.md, photo 1)"
  end

  def test_photo_post_image_is_stripped
    post = Post.new({ "image" => " 2026/a.jpg ", "alt" => "A" })
    assert_equal "2026/a.jpg", PostPhotos.for(post).first[:image]
  end

  def test_photo_post_is_one_entry_without_index
    post = Post.new({ "image" => "2026/a.jpg", "alt" => "A" })
    assert_equal [{ image: "2026/a.jpg", alt: "A", caption: nil, index: nil }], PostPhotos.for(post)
  end

  def test_other_types_have_no_photos
    assert_equal [], PostPhotos.for(Post.new({ "title" => "T" }))
  end

  def test_anchor_and_where
    assert_equal "#photo-3", PostPhotos.anchor({ index: 3 })
    assert_equal "", PostPhotos.anchor({ index: nil })
    post = Post.new({})
    assert_equal "(in _posts/2026-11-07-x.md, photo 3)", PostPhotos.where(post, { index: 3 })
    assert_equal "(in _posts/2026-11-07-x.md)", PostPhotos.where(post, { index: nil })
  end

  def test_tiles_are_newest_post_first_then_album_order
    old_photo = Post.new({ "image" => "2026/p.jpg", "alt" => "P" }, date: Time.utc(2026, 1, 1), path: "_posts/p.md")
    new_album = album({ "image" => "2026/a.jpg", "alt" => "A" }, { "image" => "2026/b.jpg", "alt" => "B" },
                      date: Time.utc(2026, 2, 1), path: "_posts/a.md")
    note = Post.new({}, path: "_posts/n.md")
    tiles = PostPhotos.tiles([old_photo, note, new_album])
    assert_equal %w[2026/a.jpg 2026/b.jpg 2026/p.jpg], tiles.map { _2[:image] }
    assert_equal [new_album, new_album, old_photo], tiles.map(&:first)
  end

  def test_previews_lists_link_posts_with_a_preview_image
    with = Post.new({ "link" => "https://example.com/a", "preview" => { "image" => " 2026/a-preview.jpg ", "title" => "A" } })
    without = Post.new({ "link" => "https://example.com/b", "preview" => { "title" => "B" } }, path: "_posts/2026-11-07-b.md")
    plain = Post.new({ "link" => "https://example.com/c" }, path: "_posts/2026-11-07-c.md")
    photo = Post.new({ "image" => "2026/p.jpg", "alt" => "P", "preview" => { "image" => "2026/x.jpg" } }, path: "_posts/2026-11-07-p.md")
    assert_equal [[with, { image: "2026/a-preview.jpg", alt: "", caption: nil, index: nil }]], PostPhotos.previews([with, without, plain, photo])
  end

  def test_previews_ignores_a_preview_that_isnt_a_mapping
    post = Post.new({ "link" => "https://example.com/a", "preview" => "oops" })
    assert_equal [], PostPhotos.previews([post])
  end

  def test_preview_images_are_not_tiles
    post = Post.new({ "link" => "https://example.com/a", "preview" => { "image" => "2026/a-preview.jpg" } })
    assert_equal [], PostPhotos.tiles([post])
  end
end
