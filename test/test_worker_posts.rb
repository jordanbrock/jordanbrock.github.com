require "minitest/autorun"
require "bridgetown"
require_relative "../plugins/post_type"
require_relative "../plugins/feed_entry"
require_relative "../plugins/post_photos"
require_relative "../plugins/photo_processor"

# The posting Worker (worker/) writes posts like these fixtures; its Vitest
# suite keeps them identical to its output. This checks the site reads each
# one as the intended post type, with usable photos and links.
class TestWorkerPosts < Minitest::Test
  DIR = File.expand_path("../worker/test/fixtures", __dir__)

  NOW = Time.utc(2026, 11, 11, 6, 3, 9) # what the fixtures were built at

  # Just enough of a resource for PostType, PostPhotos and FeedEntry.
  Post = Struct.new(:attrs, :content) do
    def model = Struct.new(:attributes).new(attrs)
    def data = Struct.new(:image, :alt, :link).new(attrs["image"], attrs["alt"], attrs["link"])
    def relative_path = "_posts/fixture.md"
    def date = Bridgetown::Utils.parse_date(attrs["date"])
  end

  # Read with Bridgetown's own front matter loader, as the site does.
  def fixture(name)
    result = Bridgetown::FrontMatter::Loaders::YAML.new(nil).read(File.read(File.join(DIR, "#{name}.md"), encoding: "UTF-8"))
    Post.new(result.front_matter.transform_keys(&:to_s), result.content)
  end

  ALL = %w[note link link-preview photo album awkward].freeze

  def test_link_with_preview
    post = fixture("link-preview")
    assert_equal "link", PostType.for_resource(post)
    preview = post.attrs["preview"]
    assert_equal 'A story: "the long version"', preview["title"]
    assert_equal "What happened & why", preview["description"]
    assert_equal "Example News", preview["site"]
    PhotoProcessor.validate!(preview["image"])
    assert_equal [], PostPhotos.for(post), "preview images stay off the Photos page"
    assert_equal [[post, { image: "2026/a-story-preview.jpg", alt: "", caption: nil, index: nil }]], PostPhotos.previews([post])
  end

  # The site's template_engine is "erb", which Bridgetown runs on every post
  # whose front matter doesn't name another engine. Posted bodies must not run.
  def test_every_fixture_turns_off_erb
    config = Bridgetown::Configuration.new("template_engine" => "erb")
    erb = Bridgetown::Converters::ERBTemplates.new(config)
    ALL.each do |name|
      post = fixture(name)
      assert_equal "none", post.attrs["template_engine"], name
      refute erb.determine_template_engine(Struct.new(:data).new(post.attrs)), name
    end
    assert erb.determine_template_engine(Struct.new(:data).new({})), "a post without template_engine would run ERB"
  end

  def test_erb_tags_stay_verbatim
    content = fixture("awkward").content
    assert_includes content, "<%= x %>"
    assert_includes content, "<%# y %>"
  end

  def test_every_fixture_has_a_perth_date
    ALL.each do |name|
      assert_equal NOW, fixture(name).date.utc, name
    end
  end

  def test_photo_paths_are_valid
    %w[photo album awkward].each do |name|
      PostPhotos.for(fixture(name)).each { PhotoProcessor.validate!(_1[:image]) }
    end
  end

  def test_awkward_values_stay_strings
    post = fixture("awkward")
    assert_equal "album", PostType.for_resource(post)
    assert_equal 'No: really, "yes" # not a comment', post.attrs["title"]
    assert_equal ["null", "on"], post.attrs["tags"]
    assert_equal [String, String], post.attrs["tags"].map(&:class)
    photos = post.attrs["photos"]
    assert_equal ["yes", "no"], photos.map { _1["alt"] }
    assert_kind_of String, photos[0]["alt"]
    assert_equal "2026-01-01", photos[0]["caption"]
    assert_kind_of String, photos[0]["caption"]
    assert_includes post.content.lines.map(&:chomp), "---"
    assert_includes post.content, "Caf\u00e9 \u00fcber \u{1F426}"
    assert_includes post.content, "After the rule."
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
