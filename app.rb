ENV['RACK_ENV'] ||= 'development'

require 'sinatra'
require 'sinatra/json'
require 'sinatra/activerecord'
require 'bcrypt'
require 'json'

set :database, { adapter: 'sqlite3', database: 'db/campus_textbook.db' }
set :show_exceptions, false

Dir[File.join(File.dirname(__FILE__), 'models', '*.rb')].each { |f| require f }
Dir[File.join(File.dirname(__FILE__), 'helpers', '*.rb')].each { |f| require f }
Dir[File.join(File.dirname(__FILE__), 'services', '*.rb')].each { |f| require f }

class CampusTextbookAPI < Sinatra::Base
  register Sinatra::ActiveRecordExtension

  set :database, { adapter: 'sqlite3', database: 'db/campus_textbook.db' }
  set :show_exceptions, false

  helpers AuthHelper

  before do
    content_type :json
  end

  before '/api/textbooks' do
    pass if request.get?
    authenticate!
    authorize_verified!
  end

  before '/api/textbooks/*' do
    pass if request.get?
    authenticate!
    authorize_verified!
  end

  before '/api/orders' do
    authenticate!
  end

  before '/api/orders/*' do
    authenticate!
  end

  before %r{/api/(favorites|textbooks/\d+/favorite)} do
    authenticate!
    authorize_verified!
  end

  error ActiveRecord::RecordNotFound do
    status 404
    { error: '资源不存在' }.to_json
  end

  error ActiveRecord::RecordInvalid do |e|
    status 422
    { error: e.record.errors.full_messages.join(', ') }.to_json
  end
end

Dir[File.join(File.dirname(__FILE__), 'routes', '*.rb')].each { |f| require f }

CampusTextbookAPI.run! if __FILE__ == $0
