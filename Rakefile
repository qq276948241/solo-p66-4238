require 'sinatra/activerecord'
require 'sinatra/activerecord/rake'

namespace :db do
  task :load_config do
    ActiveRecord::Base.configurations = {
      'development' => { adapter: 'sqlite3', database: 'db/campus_textbook.db' }
    }
    ActiveRecord::Base.establish_connection :development
    Dir[File.join(File.dirname(__FILE__), 'models', '*.rb')].each { |f| require f }
  end
end
