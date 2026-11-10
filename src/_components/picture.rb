class Picture < Bridgetown::Component
  def initialize(image:, alt:, eager: false)
    @image = image
    @alt = alt
    @eager = eager
  end

  def call = %(<img src="" alt="#{CGI.escapeHTML(@alt)}">).html_safe
end
