require "cgi"

# How a post is presented in feeds and lists: its id, a title for every type,
# photo alt text, and the HTML that leads its Atom entry. Plain functions of the resource, so they can be
# unit-tested with stubs; Builders::Helpers wraps them for templates.
module FeedEntry
  # The post's title; notes and photos have none, so the first 8 words of the
  # body, or "Photo, 7 Nov" when the body is empty. Plain text, not escaped.
  def self.title(resource)
    type = PostType.for_resource(resource)
    # data.title is slug-derived for untitled posts, so read the real front matter
    title = %w[article link].include?(type) ? PostType.title(resource) : ""
    title = PostType.link_domain(resource.data.link) if title.empty? && type == "link"
    return title unless title.empty?

    words = CGI.unescapeHTML(resource.content.to_s.gsub(/<[^>]+>/, " ")).split # templates escape on output
    return "#{type.capitalize}, #{resource.date.strftime("%-d %b")}" if words.empty?

    words.first(8).join(" ") + (words.size > 8 ? "…" : "")
  end

  # Atom <id>: the old site's scheme. Never change it, or feed readers
  # re-show every post.
  def self.id(resource) = "http://jordanbrock.com#{resource.relative_url}"

  # Alt text for a photo post: its own, or its title when blank.
  def self.alt(resource)
    alt = resource.data.alt.to_s.strip
    alt.empty? ? title(resource) : alt
  end

  # HTML before the body: link posts lead with the external link, photo posts
  # with their 960px JPEG (absolute, from base_url). Empty for other types.
  def self.lead(resource, photos:, base_url:)
    case PostType.for_resource(resource)
    when "link"
      %(<p><a href="#{CGI.escapeHTML(PostType.safe_link(resource.data.link))}">#{CGI.escapeHTML(title(resource))}</a></p>)
    when "photo"
      info = PhotoProcessor.lookup!(photos, resource.data.image, post: source(resource))
      src = base_url.to_s + PhotoProcessor.jpeg_path(info)
      %(<p><img src="#{CGI.escapeHTML(src)}" alt="#{CGI.escapeHTML(alt(resource))}"></p>)
    else
      ""
    end
  end

  def self.source(resource) = (resource.relative_path.to_s if resource.respond_to?(:relative_path))
  private_class_method :source
end
