require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "json"
require "vips"
require_relative "../plugins/photo_processor"

class TestPhotoProcessor < Minitest::Test
  GPS_FIXTURE = File.expand_path("fixtures/gps.jpg", __dir__)

  # Counts real resizes, so cache hits can't pass by accident.
  class SpyProcessor < PhotoProcessor
    def resizes = @resizes.to_i

    private

    def resize(*)
      @resizes = resizes + 1
      super
    end
  end

  def setup
    @dir = Dir.mktmpdir
    @src = File.join(@dir, "src")
    @cache = File.join(@dir, "cache")
    FileUtils.mkdir_p(File.join(@src, "2026"))
    write_image("2026/beach.jpg", 2000, 1500)
  end

  def teardown = FileUtils.rm_rf(@dir)

  def processor = PhotoProcessor.new(source_dir: @src, cache_dir: @cache)
  def spy = SpyProcessor.new(source_dir: @src, cache_dir: @cache)
  def src(rel) = File.join(@src, rel)
  def cached(rel) = Vips::Image.new_from_file(File.join(@cache, rel))
  def write_image(rel, w, h, value = 90) = Vips::Image.black(w, h).add(value).cast(:uchar).write_to_file(src(rel))

  def assert_pixel_near(expected, actual, tolerance, msg = nil)
    expected.zip(actual).each { |e, a| assert_in_delta e, a, tolerance, msg || "#{expected} vs #{actual}" }
  end

  def test_makes_list_widths_plus_odd_original_in_webp_and_jpeg
    result = processor.process("2026/beach.jpg")
    assert_equal [480, 960, 1600, 2000], result[:widths]
    %w[webp jpg].each do |ext|
      result[:widths].each { assert File.exist?(File.join(@cache, "2026", "beach-#{_1}.#{ext}")), "#{_1}.#{ext}" }
    end
    refute File.exist?(File.join(@cache, "2026", "beach-2400.jpg"))
  end

  def test_odd_width_between_entries_becomes_largest
    write_image("2026/mid.jpg", 1500, 1000)
    assert_equal [480, 960, 1500], processor.process("2026/mid.jpg")[:widths]
  end

  def test_wide_original_stops_at_2400
    write_image("2026/wide.jpg", 3000, 1000)
    assert_equal [480, 960, 1600, 2400], processor.process("2026/wide.jpg")[:widths]
  end

  def test_records_dimensions_of_largest_and_base
    result = processor.process("2026/beach.jpg")
    assert_equal({ width: 2000, height: 1500, base: "2026/beach" }, result.slice(:width, :height, :base))
  end

  def test_small_original_keeps_its_own_width
    FileUtils.cp(GPS_FIXTURE, src("2026/small.jpg"))
    assert_equal [64], processor.process("2026/small.jpg", guard: false)[:widths]
  end

  def test_outputs_have_no_exif
    FileUtils.cp(GPS_FIXTURE, src("2026/small.jpg"))
    assert Vips::Image.new_from_file(GPS_FIXTURE).get_fields.any? { _1.start_with?("exif-ifd3-") }, "fixture lacks GPS"
    # bypass the guard to check stripping on its own
    processor.process("2026/small.jpg", guard: false)
    %w[jpg webp].each { assert_empty cached("2026/small-64.#{_1}").get_fields.grep(/\A(exif|xmp)-/), _1 }
  end

  def test_display_p3_is_converted_to_srgb
    p3 = Vips::Image.black(600, 400).add([10, 200, 30]).cast(:uchar).copy(interpretation: :srgb).icc_transform("p3")
    p3.write_to_file(src("2026/p3.png"))
    input = Vips::Image.new_from_file(src("2026/p3.png"))
    assert_includes input.get_fields, "icc-profile-data"
    expected = input.icc_transform("srgb").getpoint(10, 10)
    refute_in_delta expected[0], input.getpoint(10, 10)[0], 20, "fixture is not visibly different in P3"
    processor.process("2026/p3.png")
    %w[jpg webp].each { assert_pixel_near expected, cached("2026/p3-480.#{_1}").getpoint(10, 10)[0, 3], 4, _1 }
  end

  def test_alpha_is_flattened_onto_white_for_jpeg_and_kept_for_webp
    red = Vips::Image.black(600, 400).new_from_image([255, 0, 0])
    alpha = Vips::Image.black(600, 400).draw_rect(255, 0, 0, 300, 400, fill: true)
    red.bandjoin(alpha).cast(:uchar).copy(interpretation: :srgb).write_to_file(src("2026/alpha.png"))
    processor.process("2026/alpha.png")
    jpg = cached("2026/alpha-480.jpg")
    assert_equal 3, jpg.bands
    assert_pixel_near [255, 0, 0], jpg.getpoint(50, 10), 4
    assert_pixel_near [255, 255, 255], jpg.getpoint(430, 10), 4
    assert cached("2026/alpha-480.webp").has_alpha?
  end

  def test_gps_guard_raises_with_filename
    FileUtils.cp(GPS_FIXTURE, src("2026/home.jpg"))
    err = assert_raises(PhotoProcessor::GpsError) { processor.check_gps! }
    assert_includes err.message, "2026/home.jpg"
  end

  def test_gps_guard_checks_every_file_whatever_its_extension
    FileUtils.cp(GPS_FIXTURE, src("2026/odd.jpe"))
    err = assert_raises(PhotoProcessor::GpsError) { processor.check_gps! }
    assert_includes err.message, "2026/odd.jpe"
  end

  def test_gps_only_in_xmp_is_caught
    xmp = %(<x:xmpmeta xmlns:x="adobe:ns:meta/"><rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">) +
          %(<rdf:Description xmlns:exif="http://ns.adobe.com/exif/1.0/" exif:GPSLatitude="31,57.0S" exif:GPSLongitude="115,51.6E"/>) +
          %(</rdf:RDF></x:xmpmeta>)
    img = Vips::Image.black(64, 48).add(128).cast(:uchar).copy
    img.set_type(Vips::BLOB_TYPE, "xmp-data", xmp)
    img.write_to_file(src("2026/xmp.jpg"))
    written = Vips::Image.new_from_file(src("2026/xmp.jpg"))
    assert_empty written.get_fields.grep(/\Aexif-ifd3-/), "fixture should have no EXIF GPS"
    assert processor.gps?(src("2026/xmp.jpg"))
    refute processor.gps?(src("2026/beach.jpg"))
  end

  def test_process_guards_by_default
    FileUtils.cp(GPS_FIXTURE, src("2026/home.jpg"))
    assert_raises(PhotoProcessor::GpsError) { processor.process("2026/home.jpg") }
  end

  def test_gps_guard_passes_clean_files
    processor.check_gps!
  end

  def test_missing_source_raises
    err = assert_raises(PhotoProcessor::MissingError) { processor.process("2026/nope.jpg") }
    assert_includes err.message, "2026/nope.jpg"
  end

  def test_rejects_unsafe_or_empty_image_paths
    ["", "  ", nil, "/2026/beach.jpg", "photos/2026/beach.jpg", "../beach.jpg", "2026/../beach.jpg",
     "2026//beach.jpg", "2026/my beach.jpg", "2026/b\"each.jpg", "2026/./beach.jpg"].each do |bad|
      assert_raises(PhotoProcessor::InvalidError, bad.inspect) { processor.process(bad) }
    end
    err = assert_raises(PhotoProcessor::InvalidError) { processor.process("2026/my beach.jpg") }
    assert_includes err.message, "2026/my beach.jpg"
    PhotoProcessor.validate!("2026/Beach_1-a.v2.jpg")
  end

  def test_base_collisions_raise
    err = assert_raises(PhotoProcessor::CollisionError) { PhotoProcessor.check_collisions!(%w[a/dup.jpg a/dup.png]) }
    assert_includes err.message, "a/dup.jpg"
    assert_includes err.message, "a/dup.png"
    PhotoProcessor.check_collisions!(%w[a/dup.jpg a/dup.jpg b/dup.jpg])
  end

  def test_requires_libvips_8_15
    err = assert_raises(PhotoProcessor::Error) { PhotoProcessor.require_libvips!(false) }
    assert_includes err.message, "libvips >= 8.15 required"
    assert PhotoProcessor.require_libvips!
  end

  def test_cache_hit_skips_regeneration
    s = spy
    s.process("2026/beach.jpg")
    s.process("2026/beach.jpg")
    assert_equal 1, s.resizes
  end

  def test_cache_hit_returns_same_shape_as_fresh
    fresh = processor.process("2026/beach.jpg")
    s = spy
    hit = s.process("2026/beach.jpg")
    assert_equal 0, s.resizes
    assert_equal fresh, hit
    assert_equal %i[widths width height base], hit.keys
  end

  def test_settings_change_invalidates_cache
    processor.process("2026/beach.jpg")
    manifest = File.join(@cache, "2026", "beach.json")
    data = JSON.parse(File.read(manifest))
    assert_equal PhotoProcessor::FINGERPRINT, data["fingerprint"]
    File.write(manifest, JSON.generate(data.merge("fingerprint" => "old-settings")))
    s = spy
    s.process("2026/beach.jpg")
    assert_equal 1, s.resizes
    refute_equal PhotoProcessor.fingerprint, PhotoProcessor.fingerprint(widths: [480])
    refute_equal PhotoProcessor.fingerprint, PhotoProcessor.fingerprint(formats: { "jpg" => { Q: 90 } })
    refute_equal PhotoProcessor.fingerprint, PhotoProcessor.fingerprint(version: PhotoProcessor::PIPELINE_VERSION + 1)
  end

  def test_changed_source_is_regenerated
    processor.process("2026/beach.jpg")
    write_image("2026/beach.jpg", 1000, 500, 0)
    assert_equal({ widths: [480, 960, 1000], width: 1000, height: 500 }, processor.process("2026/beach.jpg").slice(:widths, :width, :height))
  end
end
