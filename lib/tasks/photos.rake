namespace :photos do
  desc "Strip GPS and other metadata from originals in src/photos (in place, keeps ICC)"
  task :strip, [:path] do |_t, args|
    require "vips"
    files = args[:path] ? [args[:path]] : Dir["src/photos/**/*"].select { File.file?(_1) }
    files.each do |f|
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
