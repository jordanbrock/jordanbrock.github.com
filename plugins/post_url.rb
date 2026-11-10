# The URL a post (or page) is linked at. Legacy posts keep their old .html
# permalink in front matter; relative_url drops the extension, so prefer the
# permalink.
module PostUrl
  def self.for(resource) = resource.data.permalink || resource.relative_url
end
