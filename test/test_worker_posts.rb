require "minitest/autorun"
require "yaml"
require_relative "../plugins/post_type"
require_relative "../plugins/feed_entry"
require_relative "../plugins/post_photos"

# The posting Worker (worker/) writes posts like these fixtures; its Vitest
# suite keeps them identical to its output. This checks the site reads each
# one as the intended post type, with usable photos and links.
class TestWorkerPosts < Minitest::Test
  DIR = File.expand_path("../worker/test/fixtures", __dir__)

  # Just enough of a resource for PostType, PostPhotos and FeedEntry.
  Post = Struct.new(:attrs, :content) do
    def model = Struct.new(:attributes).new(attrs)
    def data = Struct.new(:image, :alt, :link).new(attrs["image"], attrs["alt"], attrs["link"])
    def relative_path = "_posts/fixture.md"
    def date = Time.utc(2026, 11, 11)
  end

  def fixture(name)
    _, yaml, body = File.read(File.join(DIR, "#{name}.md")).split(/^---\n/, 3)
    Post.new(YAML.safe_load(yaml) || {}, body.to_s)
  end

  def test_every_fixture_has_a_perth_date
    %w[note link photo album].each do |name|
      assert_equal "2026-11-11 14:03:09 +0800", fixture(name).attrs["date"], name
    end
  end

  def test_note
    post = fixture("note")
    assert_equal "note", PostType.for_resource(post)
    assert_equal ["birds"], post.attrs["tags"]
    assert_includes post.content, "And a second paragraph."
  end

  def test_link
    post = fixture("link")
    assert_equal "link", PostType.for_resource(post)
    assert_equal "https://example.com/a?b=1", PostType.safe_link(post.data.link)
    assert_equal "An example", PostType.title(post)
  end

  def test_photo
    post = fixture("photo")
    assert_equal "photo", PostType.for_resource(post)
    entries = PostPhotos.for(post)
    assert_equal [{ image: "2026/heron.jpg", alt: "A heron in the shallows" }], entries.map { _1.slice(:image, :alt) }
    assert_equal "Heron.", post.content.strip
  end

  def test_album
    post = fixture("album")
    assert_equal "album", PostType.for_resource(post)
    entries = PostPhotos.for(post)
    assert_equal ["2026/lake-walk/01.jpg", "2026/lake-walk/02.jpg"], entries.map { _1[:image] }
    assert_equal ["A heron", "An egret"], entries.map { _1[:alt] }
    assert_equal ["Heron", nil], entries.map { _1[:caption] }
  end
end
