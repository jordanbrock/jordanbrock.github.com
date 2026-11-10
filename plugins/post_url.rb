# The URL a post (or page) is linked at. Legacy posts keep their old .html
# permalink in front matter; relative_url drops the extension, so prefer the
# permalink, unless it is an unexpanded pattern such as "/:year/:slug/".
module PostUrl
  def self.for(resource)
    # Named styles (e.g. "pretty") are not used in front matter, so are not handled.
    permalink = resource.data.permalink.to_s
    permalink.empty? || permalink.include?(":") ? resource.relative_url : permalink
  end
end
