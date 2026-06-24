class FavoriteService
  def initialize(user)
    @user = user
  end

  def list
    @user.favorite_textbooks.includes(:seller)
  end

  def add(textbook_id)
    textbook = Textbook.find(textbook_id)
    favorite = @user.favorites.new(textbook_id: textbook.id)
    [favorite.save, favorite, textbook]
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
