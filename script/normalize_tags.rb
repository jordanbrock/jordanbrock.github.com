#!/usr/bin/env ruby
# One-off: rewrite front matter `categories`/`tags` into normalised `tags`,
# dropping tags used on fewer than MIN posts. Re-runnable (idempotent).
Encoding.default_external = Encoding::UTF_8
require "yaml"
require "date"
require_relative "../plugins/tag_normalizer"

MIN = 3
FM = /\A---\n(.*?)^---\n/m # head keeps its trailing newline (and any blank line before ---)

files = Dir["src/_posts/*.{md,markdown}"].sort
parsed = files.to_h do |f|
  text = File.read(f)
  fm = YAML.safe_load(text[FM, 1], permitted_classes: [Date, Time]) || {}
  [f, TagNormalizer.normalize(Array(fm["categories"]) + Array(fm["tags"]))]
end

kept = TagNormalizer.apply_threshold(parsed, min: MIN)

files.each do |f|
  text = File.read(f)
  head = text[FM, 1]
  body = text.sub(FM, "")
  # Strip existing categories/tags blocks (inline or list form), keep everything else verbatim.
  lines = head.lines
  out = []
  skipping = false
  lines.each do |line|
    if line =~ /\A(categories|tags):/
      skipping = true
      next
    end
    if skipping && line =~ /\A\s*-\s/
      next
    end
    skipping = false
    out << line
  end
  out << "tags: [#{kept[f].join(", ")}]\n" if kept[f].any?
  File.write(f, "---\n#{out.join}---\n#{body}")
end

puts "Tags kept: #{kept.values.flatten.tally.sort_by { -_2 }.map { "#{_1}(#{_2})" }.join(" ")}"
