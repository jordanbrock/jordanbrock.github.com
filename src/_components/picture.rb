# <picture> with WebP and JPEG srcsets for a photo processed by Builders::Photos.
class Picture < Bridgetown::Component
  # Photos fill .wrap (max 56rem, 1.25rem padding each side), so at most 53.5rem.
  SIZES = "(min-width: 56rem) 53.5rem, calc(100vw - 2.5rem)".freeze

  def initialize(image:, alt:, eager: false, sizes: SIZES)
    @info = PhotoProcessor.lookup!(Bridgetown::Current.site.data.photos, image)
    @alt = alt
    @eager = eager
    @sizes = sizes
  end

  def srcset(ext) = PhotoProcessor.srcset(@info, ext)
  def fallback = PhotoProcessor.jpeg_path(@info)
end
