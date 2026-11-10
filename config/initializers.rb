Bridgetown.configure do |config|
  url "https://jordanbrock.com"
  template_engine "liquid"
  timezone "Australia/Perth"

  pagination do
    enabled true
  end
end
