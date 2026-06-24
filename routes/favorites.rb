class CampusTextbookAPI
  get '/api/favorites' do
    svc = favorite_service
    { textbooks: svc.enrich_collection(svc.list) }.to_json
  end

  post '/api/textbooks/:id/favorite' do
    svc = favorite_service
    success, favorite, textbook, error_msg = svc.add(params[:id])

    if success
      status 201
      { message: '收藏成功', favorited: true, textbook: svc.enrich(textbook.as_json, textbook) }.to_json
    else
      status 422
      { error: error_msg }.to_json
    end
  end

  delete '/api/textbooks/:id/favorite' do
    svc = favorite_service
    _destroyed, favorite, textbook = svc.remove(params[:id])

    if favorite
      { message: '已取消收藏', favorited: false, textbook: textbook.as_json }.to_json
    else
      status 404
      { error: '未收藏该教材' }.to_json
    end
  end
end
