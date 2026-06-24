class CampusTextbookAPI
  post '/api/orders' do
    data = JSON.parse(request.body.read)
    textbook = Textbook.find(data['textbook_id'])
    halt 403, { error: '不能购买自己发布的教材' }.to_json if textbook.seller_id == current_user.id

    order = Order.new(
      textbook_id: textbook.id,
      buyer_id: current_user.id,
      seller_id: textbook.seller_id
    )
    if order.save
      status 201
      { message: '下单成功', order: order.as_json }.to_json
    else
      status 422
      { error: order.errors.full_messages.join(', ') }.to_json
    end
  end

  get '/api/orders' do
    orders = Order.where('buyer_id = ? OR seller_id = ?', current_user.id, current_user.id)
    { orders: orders.as_json }.to_json
  end

  get '/api/orders/:id' do
    order = Order.find(params[:id])
    halt 403, { error: '无权查看此订单' }.to_json unless [order.buyer_id, order.seller_id].include?(current_user.id)
    order.to_json
  end

  post '/api/orders/:id/buyer_confirm' do
    order = Order.find(params[:id])
    halt 403, { error: '只有买方可以确认收货' }.to_json unless order.buyer_id == current_user.id
    begin
      order.buyer_confirm!
      { message: order.status == 'completed' ? '双方已确认，订单完成' : '买方已确认收货，等待卖方确认', order: order.as_json }.to_json
    rescue => e
      status 422
      { error: e.message }.to_json
    end
  end

  post '/api/orders/:id/seller_confirm' do
    order = Order.find(params[:id])
    halt 403, { error: '只有卖方可以确认发货' }.to_json unless order.seller_id == current_user.id
    begin
      order.seller_confirm!
      { message: order.status == 'completed' ? '双方已确认，订单完成' : '卖方已确认发货，等待买方确认', order: order.as_json }.to_json
    rescue => e
      status 422
      { error: e.message }.to_json
    end
  end

  post '/api/orders/:id/reviews' do
    order = Order.find(params[:id])
    halt 403, { error: '无权对此订单评价' }.to_json unless [order.buyer_id, order.seller_id].include?(current_user.id)
    halt 422, { error: '订单未完成，不能评价' }.to_json unless order.status == 'completed'
    halt 422, { error: '您已对此订单评价过' }.to_json if order.reviews.exists?(reviewer_id: current_user.id)

    data = JSON.parse(request.body.read)
    reviewee_id = current_user.id == order.buyer_id ? order.seller_id : order.buyer_id

    review = Review.new(
      order_id: order.id,
      reviewer_id: current_user.id,
      reviewee_id: reviewee_id,
      rating: data['rating'],
      comment: data['comment']
    )
    if review.save
      status 201
      { message: '评价成功', review: review.as_json }.to_json
    else
      status 422
      { error: review.errors.full_messages.join(', ') }.to_json
    end
  end

  get '/api/orders/:id/reviews' do
    order = Order.find(params[:id])
    { reviews: order.reviews.includes(:reviewer, :reviewee).as_json }.to_json
  end
end
