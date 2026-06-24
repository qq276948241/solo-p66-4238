class FavoriteService
  def initialize(user)
    @user = user
  end

  def list
    @user.favorite_textbooks.includes(:seller).where(status: 'available')
  end

  def add(textbook_id)
    textbook = Textbook.find(textbook_id)
    return [false, nil, textbook, '该教材已下架，无法收藏'] unless textbook.status == 'available'
    favorite = @user.favorites.new(textbook_id: textbook.id)
    success = favorite.save
    [success, favorite, textbook, success ? nil : favorite.errors.full_messages.join(', ')]
  end

  def remove(textbook_id)
    textbook = Textbook.find(textbook_id)
    favorite = @user.favorites.find_by(textbook_id: textbook.id)
    [favorite&.destroy, favorite, textbook]
  end

  def enrich(textbook_json, textbook)
    return textbook_json unless @user
    textbook_json.merge('favorited' => favorited?(textbook))
  end

  def enrich_collection(textbooks)
    textbooks.map do |t|
      enrich(t.as_json, t)
    end
  end

  private

  def favorited?(textbook)
    Favorite.exists?(user_id: @user.id, textbook_id: textbook.id)
  end
end
