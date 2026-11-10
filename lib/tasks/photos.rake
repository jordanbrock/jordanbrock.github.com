namespace :photos do
  desc "Strip GPS and other metadata from originals in src/photos that have GPS (in place, keeps ICC); a path forces one file"
  task :strip, [:path] do |_t, args|
    require_relative "../../plugins/photo_processor"
    checker = PhotoProcessor.new(source_dir: "src/photos", cache_dir: "tmp/photos")
    files = args[:path] ? [args[:path]] : Dir["src/photos/**/*"].select { File.file?(_1) }
    files.each do |f|
      begin
        unless args[:path] || checker.gps?(f)
          puts "clean #{f}"
          next
        end
      rescue PhotoProcessor::GpsError # gps? raises this for files vips can't read
        puts "skip #{f}: unreadable"
        next
      end

      ext = File.extname(f)
      opts = { keep: :icc }
      opts[:Q] = 95 if ext.match?(/\A\.(jpe?g|webp)\z/i)
      img = Vips::Image.new_from_file(f, revalidate: true).autorot
      tmp = "#{f}.tmp#{ext}"
      img.write_to_file(tmp, **opts)
      File.rename(tmp, f)
      puts "stripped #{f}"
    end
  end
end
