class CampusTextbookAPI
  helpers AuthHelper

  get '/api/favorites' do
    textbooks = current_user.favorite_textbooks.includes(:seller)
    { textbooks: textbooks.map { |t| t.as_json(current_user: current_user) } }.to_json
  end

  post '/api/textbooks/:id/favorite' do
    textbook = Textbook.find(params[:id])
    favorite = current_user.favorites.new(textbook_id: textbook.id)
    if favorite.save
      status 201
      { message: '收藏成功', favorited: true, textbook: textbook.as_json(current_user: current_user) }.to_json
    else
      status 422
      { error: favorite.errors.full_messages.join(', ') }.to_json
    end
  end

  delete '/api/textbooks/:id/favorite' do
    textbook = Textbook.find(params[:id])
    favorite = current_user.favorites.find_by(textbook_id: textbook.id)
    if favorite
      favorite.destroy
      { message: '已取消收藏', favorited: false, textbook: textbook.as_json(current_user: current_user) }.to_json
    else
      status 404
      { error: '未收藏该教材' }.to_json
    end
  end
end
