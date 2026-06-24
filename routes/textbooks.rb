class CampusTextbookAPI
  get '/api/textbooks' do
    textbooks = Textbook.filter(
      course_name: params[:course_name],
      min_price: params[:min_price],
      max_price: params[:max_price]
    ).includes(:seller)

    viewer = resolve_viewer
    svc = FavoriteService.new(viewer) if viewer

    result = viewer ? svc.enrich_collection(textbooks) : textbooks.as_json
    { textbooks: result }.to_json
  end

  get '/api/textbooks/:id' do
    textbook = Textbook.find(params[:id])
    viewer = resolve_viewer
    unless textbook.status == 'available' || (viewer && textbook.seller_id == viewer.id)
      raise ActiveRecord::RecordNotFound.new('', 'Textbook')
    end

    data = textbook.as_json
    data = FavoriteService.new(viewer).enrich(data, textbook) if viewer
    data.to_json
  end

  post '/api/textbooks' do
    data = JSON.parse(request.body.read)
    textbook = Textbook.new(
      title: data['title'],
      isbn: data['isbn'],
      original_price: data['original_price'],
      selling_price: data['selling_price'],
      condition_level: data['condition_level'],
      course_name: data['course_name'],
      description: data['description'],
      seller_id: current_user.id
    )
    if textbook.save
      status 201
      { message: '教材发布成功', textbook: textbook.as_json }.to_json
    else
      status 422
      { error: textbook.errors.full_messages.join(', ') }.to_json
    end
  end

  put '/api/textbooks/:id' do
    textbook = Textbook.find(params[:id])
    halt 403, { error: '只能修改自己发布的教材' }.to_json unless textbook.seller_id == current_user.id
    halt 422, { error: '已售出的教材不能修改' }.to_json if textbook.status == 'sold'

    data = JSON.parse(request.body.read)
    if textbook.update(
      title: data.fetch('title', textbook.title),
      isbn: data.fetch('isbn', textbook.isbn),
      original_price: data.fetch('original_price', textbook.original_price),
      selling_price: data.fetch('selling_price', textbook.selling_price),
      condition_level: data.fetch('condition_level', textbook.condition_level),
      course_name: data.fetch('course_name', textbook.course_name),
      description: data.fetch('description', textbook.description)
    )
      { message: '教材更新成功', textbook: textbook.as_json }.to_json
    else
      status 422
      { error: textbook.errors.full_messages.join(', ') }.to_json
    end
  end

  delete '/api/textbooks/:id' do
    textbook = Textbook.find(params[:id])
    halt 403, { error: '只能删除自己发布的教材' }.to_json unless textbook.seller_id == current_user.id
    halt 422, { error: '已售出的教材不能删除' }.to_json if textbook.status == 'sold'

    textbook.destroy
    { message: '教材已删除' }.to_json
  end
end
