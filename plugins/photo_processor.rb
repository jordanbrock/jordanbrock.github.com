require "digest"
require "fileutils"
require "json"
require "vips"

# Resizes one original photo into several widths (WebP + JPEG): upright, sRGB,
# metadata stripped. Results are cached by source SHA256 plus a fingerprint of
# the settings, so rebuilds only touch new or changed photos.
class PhotoProcessor
  class Error < StandardError; end
  class GpsError < Error; end
  class MissingError < Error; end
  class InvalidError < Error; end
  class CollisionError < Error; end

  PIPELINE_VERSION = 2 # bump when resize/save behaviour changes
  WIDTHS = [480, 960, 1600, 2400].freeze
  FORMATS = { "webp" => { Q: 80 }, "jpg" => { Q: 82 } }.freeze
  SEGMENT = /\A[A-Za-z0-9._-]+\z/
  STRIP_HINT = "run bin/bridgetown photos:strip".freeze
  FALLBACK_WIDTH = 960 # the single JPEG for old browsers and feeds

  def self.fingerprint(version: PIPELINE_VERSION, widths: WIDTHS, formats: FORMATS)
    Digest::SHA256.hexdigest(JSON.generate([version, widths, formats]))
  end

  FINGERPRINT = fingerprint

  # keep: needs libvips 8.15; older versions silently ignore it and leak EXIF.
  def self.require_libvips!(ok = Vips.at_least_libvips?(8, 15))
    ok or raise Error, "libvips >= 8.15 required (found #{Vips.version_string})"
  end

  # Public URL path of one processed size.
  def self.url_path(info, width, ext) = "/photos/#{info[:base]}-#{width}.#{ext}"

  # The widest JPEG no wider than max (or the narrowest, if all are wider).
  def self.jpeg_path(info, max: FALLBACK_WIDTH)
    url_path(info, info[:widths].select { _1 <= max }.max || info[:widths].min, "jpg")
  end

  def self.srcset(info, ext) = info[:widths].map { "#{url_path(info, _1, ext)} #{_1}w" }.join(", ")

  # The registry entry (site.data.photos) for image, or a clear error naming
  # the image and, when known, the post.
  def self.lookup!(registry, image, post: nil)
    where = post ? " in #{post}" : ""
    raise InvalidError, "Photo post has no image#{where}" if image.to_s.strip.empty?

    registry&.[](image.to_s.strip) or
      raise MissingError, "No processed photo for #{image}#{where}; is it the image of a photo post?"
  end

  def self.base_for(relative) = relative.sub(/\.[^.\/]+\z/, "")

  # Raise if two different originals would share output files (dup.jpg, dup.png).
  # Case-insensitive, as APFS is: Dup.jpg and dup.png collide too.
  def self.check_collisions!(images)
    images.uniq.group_by { base_for(_1).downcase }.each do |base, group|
      raise CollisionError, "Photos #{group.join(" and ")} would both publish as #{base}-*" if group.size > 1
    end
  end

  # Raise unless relative is a plain path inside src/photos.
  def self.validate!(relative)
    relative = relative.to_s
    raise InvalidError, "Photo post has no image" if relative.strip.empty?
    if relative.start_with?("/", "photos/")
      raise InvalidError, "Image path must be relative to src/photos (no leading / or photos/): #{relative}"
    end
    return if relative.split("/", -1).all? { _1.match?(SEGMENT) && _1 != "." && _1 != ".." }

    raise InvalidError, "Unsafe image path #{relative.inspect}: use only A-Z a-z 0-9 . _ - in each part"
  end

  attr_reader :cache_dir

  def initialize(source_dir:, cache_dir:)
    self.class.require_libvips!
    @source_dir = source_dir
    @cache_dir = cache_dir
  end

  # Raise if any original under source_dir carries GPS data, whatever its extension.
  def check_gps!
    offenders = Dir.glob(File.join(@source_dir, "**", "*")).select { File.file?(_1) && gps?(_1) }
    return if offenders.empty?

    names = offenders.sort.map { relative(_1) }
    raise GpsError, "Photos contain GPS location data (#{STRIP_HINT}): #{names.join(", ")}"
  end

  # True if the file has EXIF GPS tags or GPS fields in its XMP.
  def gps?(path)
    image = Vips::Image.new_from_file(path, revalidate: true)
    fields = image.get_fields
    return true if fields.any? { _1.start_with?("exif-ifd3-") }

    fields.include?("xmp-data") && image.get("xmp-data").to_s.b.match?(/GPS(Latitude|Longitude)/)
  rescue Vips::Error => e
    # Fail closed: a file vips can't read can't be shown to be GPS-free.
    raise GpsError, "Cannot read #{relative(path)} to check it for GPS data: #{e.message.lines.first.to_s.strip}"
  end

  # Returns { widths:, width:, height:, base: } (symbol keys, cached or fresh);
  # base is the relative path without its extension.
  def process(relative, guard: true)
    self.class.validate!(relative)
    src = File.join(@source_dir, relative)
    raise MissingError, "Photo not found: #{relative}" unless File.file?(src)
    raise GpsError, "Photo contains GPS location data (#{STRIP_HINT}): #{relative}" if guard && gps?(src)

    base = self.class.base_for(relative)
    manifest = File.join(@cache_dir, "#{base}.json")
    digest = Digest::SHA256.file(src).hexdigest
    cached = read_manifest(manifest)
    if cached && cached[:digest] == digest && cached[:fingerprint] == FINGERPRINT && outputs_exist?(cached)
      return cached.except(:digest, :fingerprint)
    end

    result = resize(src, base)
    File.write(manifest, JSON.generate(result.merge(digest:, fingerprint: FINGERPRINT)), encoding: "UTF-8")
    result
  end

  def output_paths(info)
    info[:widths].flat_map { |w| FORMATS.keys.map { |ext| "#{info[:base]}-#{w}.#{ext}" } }
  end

  private

  # thumbnail_buffer (not a filename) so vips' file cache can't serve a stale original.
  def resize(src, base)
    buffer = File.binread(src)
    original = Vips::Image.new_from_buffer(buffer, "").autorot.width
    widths = WIDTHS.select { _1 <= original }
    widths << original if original < WIDTHS.max && !widths.include?(original)
    FileUtils.mkdir_p(File.dirname(File.join(@cache_dir, base)))

    widths.each do |w|
      thumb = Vips::Image.thumbnail_buffer(buffer, w, height: 100_000, size: :down, export_profile: "srgb").copy_memory # saved twice
      thumb.write_to_file(File.join(@cache_dir, "#{base}-#{w}.webp"), **FORMATS["webp"], keep: :none)
      thumb = thumb.flatten(background: [255, 255, 255]) if thumb.has_alpha?
      thumb.write_to_file(File.join(@cache_dir, "#{base}-#{w}.jpg"), **FORMATS["jpg"], keep: :none)
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

  def relative(path) = path.delete_prefix("#{@source_dir}/")
end
