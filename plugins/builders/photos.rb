require "fileutils"

module Builders
  # Resizes the images of photo and album posts, and link posts' previews,
  # before render (so templates know their sizes) and copies the results into
  # output/photos after write. Originals in src/photos are excluded from the
  # build and never published.
  class Photos < SiteBuilder
    def build
      generator :process_photos
      hook :site, :post_write, :copy_photos
    end

    def processor
      @processor ||= PhotoProcessor.new(
        source_dir: site.in_source_dir("photos"),
        cache_dir: File.join(site.root_dir, "tmp", "photos") # outside .bridgetown-cache, which clean deletes
      )
    end

    # Registry: image path from front matter => { widths:, width:, height:, base: }.
    # site.data wraps it in HashWithDotAccess (indifferent keys); readers use symbols.
    # An image used by several posts is processed once.
    def process_photos
      processor.check_gps!
      posts = site.collections.posts.resources
      entries = PostPhotos.tiles(posts) + PostPhotos.previews(posts)
      PhotoProcessor.check_collisions!(entries.map { |_post, entry| entry[:image] })
      registry = {}
      entries.each do |post, entry|
        registry[entry[:image]] ||= processor.process(entry[:image], guard: false)
      rescue PhotoProcessor::Error, Vips::Error => e
        raise PhotoProcessor::Error, "#{e.message.strip} #{PostPhotos.where(post, entry)}"
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
