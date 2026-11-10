Bridgetown.configure do |config|
  url "https://jordanbrock.com"
  template_engine "erb"
  timezone "Australia/Perth"
  exclude ["photos"]

  collections do
    posts do
      permalink "/:year/:month/:day/:slug/"
    end
  end

  pagination do
    enabled true
  end
end
