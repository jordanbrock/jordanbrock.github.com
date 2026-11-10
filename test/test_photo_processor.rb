require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "vips"
require_relative "../plugins/photo_processor"

class TestPhotoProcessor < Minitest::Test
  GPS_FIXTURE = File.expand_path("fixtures/gps.jpg", __dir__)

  def setup
    @dir = Dir.mktmpdir
    @src = File.join(@dir, "src")
    @cache = File.join(@dir, "cache")
    FileUtils.mkdir_p(File.join(@src, "2026"))
    Vips::Image.black(2000, 1500).add(90).cast(:uchar).write_to_file(File.join(@src, "2026", "beach.jpg"))
  end

  def teardown = FileUtils.rm_rf(@dir)

  def processor = PhotoProcessor.new(source_dir: @src, cache_dir: @cache)

  def test_makes_widths_up_to_original_in_webp_and_jpeg
    result = processor.process("2026/beach.jpg")
    assert_equal [480, 960, 1600], result[:widths]
    %w[webp jpg].each do |ext|
      [480, 960, 1600].each { assert File.exist?(File.join(@cache, "2026", "beach-#{_1}.#{ext}")), "#{_1}.#{ext}" }
    end
    refute File.exist?(File.join(@cache, "2026", "beach-2400.jpg"))
  end

  def test_records_dimensions_of_largest_and_base
    result = processor.process("2026/beach.jpg")
    assert_equal({ width: 1600, height: 1200, base: "2026/beach" }, result.slice(:width, :height, :base))
  end

  def test_small_original_keeps_its_own_width
    FileUtils.cp(GPS_FIXTURE, File.join(@src, "2026", "small.jpg"))
    assert_equal [64], processor.process("2026/small.jpg", guard: false)[:widths]
  end

  def test_outputs_have_no_exif
    FileUtils.cp(GPS_FIXTURE, File.join(@src, "2026", "small.jpg"))
    assert Vips::Image.new_from_file(GPS_FIXTURE).get_fields.any? { _1.start_with?("exif-ifd3-") }, "fixture lacks GPS"
    # bypass the guard to check stripping on its own
    processor.process("2026/small.jpg", guard: false)
    %w[jpg webp].each do |ext|
      out = Vips::Image.new_from_file(File.join(@cache, "2026", "small-64.#{ext}"))
      assert_empty out.get_fields.grep(/\Aexif-/), ext
    end
  end

  def test_gps_guard_raises_with_filename
    FileUtils.cp(GPS_FIXTURE, File.join(@src, "2026", "home.jpg"))
    err = assert_raises(PhotoProcessor::GpsError) { processor.check_gps! }
    assert_includes err.message, "2026/home.jpg"
  end

  def test_gps_guard_checks_every_file_whatever_its_extension
    FileUtils.cp(GPS_FIXTURE, File.join(@src, "2026", "odd.jpe"))
    err = assert_raises(PhotoProcessor::GpsError) { processor.check_gps! }
    assert_includes err.message, "2026/odd.jpe"
  end

  def test_process_guards_by_default
    FileUtils.cp(GPS_FIXTURE, File.join(@src, "2026", "home.jpg"))
    assert_raises(PhotoProcessor::GpsError) { processor.process("2026/home.jpg") }
  end

  def test_gps_guard_passes_clean_files
    processor.check_gps!
  end

  def test_missing_source_raises
    err = assert_raises(PhotoProcessor::MissingError) { processor.process("2026/nope.jpg") }
    assert_includes err.message, "2026/nope.jpg"
  end

  def test_cache_hit_skips_regeneration
    processor.process("2026/beach.jpg")
    path = File.join(@cache, "2026", "beach-480.jpg")
    mtime = File.mtime(path)
    sleep 0.01
    processor.process("2026/beach.jpg")
    assert_equal mtime, File.mtime(path)
  end

  def test_cache_hit_returns_same_shape_as_fresh
    fresh = processor.process("2026/beach.jpg")
    cached = PhotoProcessor.new(source_dir: @src, cache_dir: @cache).process("2026/beach.jpg")
    assert_equal fresh, cached
    assert_equal %i[widths width height base], cached.keys
  end

  def test_changed_source_is_regenerated
    processor.process("2026/beach.jpg")
    Vips::Image.black(1000, 500).cast(:uchar).write_to_file(File.join(@src, "2026", "beach.jpg"))
    assert_equal({ widths: [480, 960], width: 960, height: 480 }, processor.process("2026/beach.jpg").slice(:widths, :width, :height))
  end
end
