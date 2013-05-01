require 'sinatra'
require 'sinatra/session'
require 'ruby-debug'
require 'model.rb'
require 'database.rb'
require 'controller.rb'
#require 'rack-flash'

#TODO: add logging
#TODO: add asset compilers
#TODO?: add tests

configure do
	# Sinatra Defaults
	# set :root, File.dirname(__FILE__)
	# set :public_folder, Proc.new { File.join(root, "public") }
	set :views, Proc.new { File.join(root, "views") }

	# Sessions
	set :session_fail, '/login.html'
	set :session_secret, '8bc5a4f3fc2d27837b1f22dd2241ef9d'
	set :session_expire, 60 * 60

	set :app_name, "Test App Name"

	# Doesn't work?
	set :port, 9001
end