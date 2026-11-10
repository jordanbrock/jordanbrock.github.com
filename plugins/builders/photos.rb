require "fileutils"

module Builders
  # Resizes photo-post images before render (so templates know their sizes)
  # and copies the results into output/photos after write. Originals in
  # src/photos are excluded from the build and never published.
  class Photos < SiteBuilder
    def build
      generator :process_photos
      hook :site, :post_write, :copy_photos
    end

    def processor
      @processor ||= PhotoProcessor.new(
        source_dir: site.in_source_dir("photos"),
        cache_dir: File.join(site.root_dir, ".bridgetown-cache", "photos")
      )
    end

    # Registry: image path from front matter => { widths:, width:, height:, base: }.
    # site.data wraps it in HashWithDotAccess (indifferent keys); readers use symbols.
    def process_photos
      processor.check_gps!
      registry = {}
      site.collections.posts.resources.each do |post|
        next unless PostType.for_resource(post) == "photo"

        image = post.data.image.to_s
        registry[image] = processor.process(image, guard: false)
      rescue PhotoProcessor::MissingError => e
        raise PhotoProcessor::MissingError, "#{e.message} (in #{post.relative_path})"
      end
      site.data.photos = registry
    end

    def copy_photos(_site)
      (site.data.photos || {}).each_value do |info|
        processor.output_paths(info).each do |rel|
          dest = site.in_dest_dir("photos", rel)
          FileUtils.mkdir_p(File.dirname(dest))
          FileUtils.cp(File.join(processor.cache_dir, rel), dest)
        end
      end
    end
  end
end
