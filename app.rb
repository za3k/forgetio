require 'sinatra'
require 'sinatra/session'
require 'ostruct'
require 'pg'
#require 'rack-flash'

configure do
	# Sinatra Defaults
	# set :public_folder, File.dirname(__FILE__) + '/public'

	# Sessions
	set :session_fail, '/login.html'
	set :session_secret, '8bc5a4f3fc2d27837b1f22dd2241ef9d'
	set :session_expire, 60 * 60
end

# Model

class User
	def initialize(loggedIn)
		@loggedIn = loggedIn
	end
	attr_reader :loggedIn
	attr_writer :loggedIn
end

class Database
	def connect(&block)
		connection = PG.connect(dbname: 'notify')
		block.call connection
		connection.close
	end

	def find_user email
		connect  do |conn|
			conn.exec("SELECT * FROM users") do |result|
				result.each do |user|
					if user["email"] == email
						return user 
					end
				end
			end
		end
	end
end

# Controller

class SimpleRequest
	def initialize
		@config = { appName: "Test App Name" }
		def @config.method_missing(n)
			self[n]
		end
		@user = User.new true
	end
	attr_reader :config
	attr_reader :user
end

def logged_in?
	session? and session[:id]
end

def login id
	if session?
		logout
	end
	session_start!
	session["id"] = id
end

def logout
	session_end!
end

def authenticate!
	unless logged_in?
		redirect to('/login.html')
	end
end

before do
	@req = (SimpleRequest.new)
end

helpers do
	alias_method :raw_erb, :erb

	def partial_erb(page, options={})
		raw_erb page, (options.merge :layout => false)
	end

	def erb(page, options={})
		@page = page
		extra_options = {
			:layout_options => {
				:locals => {
					:navbar => (partial_erb :navbar, :locals => { :page => page})
				}
			}
		}
		raw_erb page, (options.merge extra_options)
	end

	def home
		erb :home, :locals => {:login => (partial_erb :login)}
	end

	def bad_username_or_password
		login_page
	end

	def login_page
		@email = request["email"]
		erb :login
	end

	def signup_page
		erb :signup
	end
end

get '/' do
	conn = PG.connect(dbname: 'notify')
	out = ""
	conn.exec("SELECT * FROM users") do |result|
		result.each do |user|
			out <<  user.to_s + "\n"
		end
	end
	out
end

get '/home.html' do
	home
end

get '/index.html' do
	home
end

get '/login.html' do
	login_page
end

post '/login.html' do
	email = request["email"]
	password = request["password"]
	if email.nil? or password.nil?
		redirect to('/login.html')
	end
	user = Database.new.find_user email
	unless user
		return bad_username_or_password
	end
	unless user["password"] == password
		return bad_username_or_password
	end
	login user["id"]
end

post '/logout.html' do
	logout
end

get '/logout.html' do
	logout
end

get '/signup.html' do
	signup_page
end

post '/signup.html' do
end

get '/scheduled.html' do
	authenticate!
	"HELLO"
end

get '/scheduled.html' do
	"GOODBYE"
end

#app.all('*.html', routes.ensureLogin) # everything below this requires login
#app.get('/account.html', routes.account)
#app.post('/account.html', routes.accountPost)
#app.post('/payment.html', routes.paymentPost)
#app.get('/scheduled.html', routes.scheduled)
#app.post('/scheduled.html', routes.scheduledPost)
#app.get('/results.html', routes.results)
#app.get('/results/all', routes.csvExportAllReminders)
#app.get('/results/:id', routes.csvExportSingleReminder)
#app.get('/logout.html', routes.logout)
