module AuthHelper
  def authenticate!
    token = request.env['HTTP_AUTHORIZATION']&.sub(/^Bearer\s+/i, '')
    halt 401, { error: '未登录，请提供有效的Token' }.to_json unless token
    @current_user = User.find_by(api_token: token)
    halt 401, { error: 'Token无效或已过期' }.to_json unless @current_user
  end

  def authorize_verified!
    unless @current_user.verified
      halt 403, { error: '您的学校邮箱未通过认证，仅可浏览教材，无法发布或购买' }.to_json
    end
  end

  def current_user
    @current_user
  end

  def resolve_viewer
    token = request.env['HTTP_AUTHORIZATION']&.sub(/^Bearer\s+/i, '')
    token ? User.find_by(api_token: token) : nil
  end

  def favorite_service(user = @current_user)
    FavoriteService.new(user)
  end
end
