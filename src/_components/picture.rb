# <picture> with WebP and JPEG srcsets for a photo processed by Builders::Photos.
class Picture < Bridgetown::Component
  # Photos fill .wrap (max 56rem, 1.25rem padding each side), so at most 53.5rem.
  SIZES = "(min-width: 56rem) 53.5rem, calc(100vw - 2.5rem)".freeze

  def initialize(image:, alt:, eager: false, sizes: SIZES)
    @info = Bridgetown::Current.site.data.photos&.[](image) or
      raise ArgumentError, "No processed photo for #{image}; is it the image of a photo post?"
    @alt = alt
    @eager = eager
    @sizes = sizes
  end

  def srcset(ext) = @info[:widths].map { "/photos/#{@info[:base]}-#{_1}.#{ext} #{_1}w" }.join(", ")
  def fallback = self.class.fallback(@info)

  # The JPEG for browsers without srcset (and for feeds): the widest up to 960px.
  def self.fallback(info) = "/photos/#{info[:base]}-#{info[:widths].select { _1 <= 960 }.max || info[:widths].min}.jpg"
end
