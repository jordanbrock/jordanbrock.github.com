# Pure helpers for turning old WordPress categories into a tidy tag set.
module TagNormalizer
  MAP = {
    "ruby on rails" => "rails",
    "rubyonrails" => "rails",
    "ruby-on-rails" => "rails",
    "websites" => "web",
    "website" => "web",
    "movie" => "movies",
    "film" => "movies",
    "programming" => "development"
  }.freeze

  def self.normalize(tags)
    Array(tags).filter_map do |tag|
      t = tag.to_s.strip.downcase
      next if t.empty?

      MAP.fetch(t, t)
    end.uniq.sort
  end

  # posts: { id => [tags] } → same shape with rare tags removed
  def self.apply_threshold(posts, min:)
    counts = posts.values.flatten.tally
    posts.transform_values { |tags| tags.select { counts[_1] >= min } }
  end
end
