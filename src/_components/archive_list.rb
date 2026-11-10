# Posts grouped by year, newest first, one line each: date, feed title and,
# unless show_type is false, a type marker for anything but an article.
class ArchiveList < Bridgetown::Component
  def initialize(posts:, show_type: true, empty: "Nothing here yet.")
    @posts = posts
    @show_type = show_type
    @empty = empty
  end

  def years = @posts.sort_by(&:date).reverse.group_by { _1.date.year }

  def marker(post)
    type = PostType.for_resource(post)
    type if @show_type && type != "article"
  end
end
