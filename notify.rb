#!/user/bin/env ruby
require 'yaml'
require 'sinatra'
require 'sinatra/session'
require 'model.rb'
require 'database.rb'
require 'controller.rb'
#require 'rack-flash'

#TODO: add logging
#TODO: add asset compilers
#TODO?: add tests
#TODO: Add something to create the database, and reset it for dev?
# => What's a rakefile?  Can I use that to run stuff and do databases?

configure do
	# Sinatra Defaults
	# set :root, File.dirname(__FILE__)
	# set :public_folder, Proc.new { File.join(root, "public") }
	set :views, Proc.new { File.join(root, "views") }

	# Sessions
	set :session_fail, '/login.html'
	set :session_secret, '8bc5a4f3fc2d27837b1f22dd2241ef9d'
	set :session_expire, 60 * 60

	# Database
	Database.dbname = 'notify'

	set :app_name, "Forget"

	# Doesn't work?
	set :port, 9001

    yaml = YAML.load_file("config.yaml")
    yaml.each_pair do |key, value|
        set(key.to_sym, value)
    end

	if Database.timezones.empty?
		Database.create_timezones!
	end
end
