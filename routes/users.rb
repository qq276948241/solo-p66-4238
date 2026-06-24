class CampusTextbookAPI
  helpers AuthHelper

  get '/api/schools' do
    schools = School.all
    { schools: schools.as_json(only: [:id, :name, :email_suffix]) }.to_json
  end

  post '/api/users/register' do
    data = JSON.parse(request.body.read)
    user = User.new(
      name: data['name'],
      email: data['email'],
      password: data['password'],
      password_confirmation: data['password_confirmation']
    )
    if user.save
      status 201
      {
        message: user.verified ? '注册成功，学校邮箱已自动认证' : '注册成功，但该邮箱后缀未匹配到学校，暂未认证',
        user: user.as_json(only: [:id, :name, :email, :verified, :school_id, :api_token])
      }.to_json
    else
      status 422
      { error: user.errors.full_messages.join(', ') }.to_json
    end
  end

  post '/api/users/login' do
    data = JSON.parse(request.body.read)
    user = User.authenticate(data['email'], data['password'])
    if user
      { message: '登录成功', user: user.as_json(only: [:id, :name, :email, :verified, :school_id, :api_token]) }.to_json
    else
      status 401
      { error: '邮箱或密码错误' }.to_json
    end
  end

  get '/api/users/me' do
    authenticate!
    current_user.as_json(only: [:id, :name, :email, :verified, :school_id], include: { school: { only: [:id, :name, :email_suffix] } }).to_json
  end

  get '/api/users/:id/reviews' do
    user = User.find(params[:id])
    reviews = user.received_reviews.includes(:reviewer, :order)
    { reviews: reviews.as_json }.to_json
  end
end
