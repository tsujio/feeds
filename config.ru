require './app'

# HTTP Authentication
use Rack::Auth::Basic, 'Feeds' do |username, password|
  _username = ENV['FEEDS_AUTH_USERNAME'] || 'admin'
  _password = ENV['FEEDS_AUTH_PASSWORD'] || 'admin'

  username == _username and password == _password
end

run Sinatra::Application
