require "digest"
require "fileutils"
require "json"
require "image_processing/vips"

# Resizes one original photo into several widths (WebP + JPEG), stripping metadata.
# Results are cached by source SHA256 so rebuilds only touch new or changed photos.
class PhotoProcessor
  class GpsError < StandardError; end
  class MissingError < StandardError; end

  WIDTHS = [480, 960, 1600, 2400].freeze
  FORMATS = { "webp" => { quality: 80 }, "jpg" => { quality: 82 } }.freeze
  STRIP_HINT = "run bin/bridgetown photos:strip".freeze

  attr_reader :cache_dir

  def initialize(source_dir:, cache_dir:)
    @source_dir = source_dir
    @cache_dir = cache_dir
  end

  # Raise if any original under source_dir carries GPS EXIF, whatever its extension.
  def check_gps!
    offenders = Dir.glob(File.join(@source_dir, "**", "*")).select { File.file?(_1) && gps?(_1) }
    return if offenders.empty?

    names = offenders.sort.map { relative(_1) }
    raise GpsError, "Photos contain GPS location data (#{STRIP_HINT}): #{names.join(", ")}"
  end

  # Returns { widths:, width:, height:, base: } (symbol keys, cached or fresh);
  # base is the relative path without its extension.
  def process(relative, guard: true)
    src = File.join(@source_dir, relative)
    raise MissingError, "Photo not found: #{relative}" unless File.file?(src)
    raise GpsError, "Photo contains GPS location data (#{STRIP_HINT}): #{relative}" if guard && gps?(src)

    base = relative.sub(/\.[^.\/]+\z/, "")
    manifest = File.join(@cache_dir, "#{base}.json")
    digest = Digest::SHA256.file(src).hexdigest
    cached = read_manifest(manifest)
    return cached.except(:digest) if cached && cached[:digest] == digest && outputs_exist?(cached)

    result = resize(src, base)
    File.write(manifest, JSON.generate(result.merge(digest:)), encoding: "UTF-8")
    result
  end

  def output_paths(info)
    info[:widths].flat_map { |w| FORMATS.keys.map { |ext| "#{info[:base]}-#{w}.#{ext}" } }
  end

  private

  def resize(src, base)
    image = Vips::Image.new_from_file(src, revalidate: true).autorot
    widths = WIDTHS.select { _1 <= image.width }
    widths = [image.width] if widths.empty?
    FileUtils.mkdir_p(File.dirname(File.join(@cache_dir, base)))

    widths.each do |w|
      FORMATS.each do |ext, opts|
        ImageProcessing::Vips.source(image)
                             .resize_to_limit(w, nil)
                             .convert(ext)
                             .saver(**opts, keep: :none)
                             .call(destination: File.join(@cache_dir, "#{base}-#{w}.#{ext}"))
      end
    end

    largest = Vips::Image.new_from_file(File.join(@cache_dir, "#{base}-#{widths.max}.jpg"), revalidate: true)
    { widths:, width: largest.width, height: largest.height, base: }
  end

  def read_manifest(path)
    return unless File.file?(path)

    JSON.parse(File.read(path, encoding: "UTF-8"), symbolize_names: true)
  rescue JSON::ParserError
    nil
  end

  def outputs_exist?(info) = output_paths(info).all? { File.file?(File.join(@cache_dir, _1)) }

  def gps?(path)
    Vips::Image.new_from_file(path, revalidate: true).get_fields.any? { _1.start_with?("exif-ifd3-") }
  rescue Vips::Error => e
    raise GpsError, "Cannot read #{relative(path)} to check it for GPS data: #{e.message.lines.first.to_s.strip}"
  end

  def relative(path) = path.delete_prefix("#{@source_dir}/")
end
