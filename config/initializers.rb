Bridgetown.configure do |config|
  url "https://jordanbrock.com"
  template_engine "erb"
  timezone "Australia/Perth"
  exclude ["photos"]

  # Notes, links and photos have no layout in their front matter.
  config.defaults = [{ "scope" => { "collection" => "posts" }, "values" => { "layout" => "post" } }]

  collections do
    posts do
      permalink "/:year/:month/:day/:slug/"
    end
  end

  pagination do
    enabled true
  end
end
