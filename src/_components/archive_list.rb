# Posts grouped by year, newest first, one line each: date, feed title and,
# when listing every type, a type marker for anything but an article.
class ArchiveList < Bridgetown::Component
  # type: only list posts of this type (and skip the redundant marker).
  def initialize(posts:, type: nil, empty: "Nothing here yet.")
    @posts = PostType.posts(posts, type)
    @type = type
    @empty = empty
  end

  def years = @posts.group_by { _1.date.year }

  def marker(post)
    return if @type

    type = PostType.for_resource(post)
    type unless type == "article"
  end
end
