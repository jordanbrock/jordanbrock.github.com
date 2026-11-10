namespace :check do
  desc "Fail if any legacy URL is missing from output/"
  task :urls do
    missing = File.readlines("test/fixtures/legacy_urls.txt", chomp: true).reject do |path|
      file = path.end_with?("/") ? "output#{path}index.html" : "output#{path}"
      File.file?(file)
    end
    abort "Missing #{missing.size} legacy URLs:\n#{missing.join("\n")}" if missing.any?
    puts "All legacy URLs present"
  end
end
