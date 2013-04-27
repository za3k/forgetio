require 'sinatra'
require 'sinatra/session'
require 'ostruct'
require 'pg'
require 'ruby-debug'
#require 'rack-flash'

configure do
	# Sinatra Defaults
	# set :root, File.dirname(__FILE__)
	# set :public_folder, Proc.new { File.join(root, "public") }
	# set :views, Proc.new { File.join(root, "views") }

	# Sessions
	set :session_fail, '/login.html'
	set :session_secret, '8bc5a4f3fc2d27837b1f22dd2241ef9d'
	set :session_expire, 60 * 60

	# Doesn't work: set :port, 9001
	set :app_name, "Test App Name"
end

# Model

# Monkey-patch database module to let us store results after the connection
module PG
	class PG::Result
		def hashes
			hashes = Array.new
			self.each {|row| hashes.push row }
			hashes
		end
	end
end

class User
	def initialize(userObj, loggedIn)
		@user = userObj
		@loggedIn = loggedIn
	end
	def has_role? role
		roles.include? role
	end
	def method_missing(n)
		@user[n.to_s]
	end
	def roles
		roles = [:user]
		roles.push :admin if admin?
		roles
	end
	def admin?
		["vanceza@gmail.com"].include? email
	end
	def logged_in?
		@loggedIn
	end
	def to_s
		@user.to_s
	end
	def credit
		@user["credit"].to_i
	end
	def lowerTimeEstimate
		credit / 10
	end
	def upperTimeEstimate
		credit / 5
	end
	def timezone
		@user["timezone_id"]
	end
	def all_communications
		@_all_communications ||= Database.all_communications self
	end
	def messages_received_sent
		all_communications.partition { |comm| not comm["server_received"].nil? }
	end
	def messages_received
		received, sent = messages_received_sent
		received
	end
	def messages_sent
		received, sent = messages_received_sent
		sent
	end
end

class Timezone
	def initialize tzData
		@tzData = tzData
	end
	def id
		@tzData["id"]
	end
	def text
		seconds = @tzData["offset"].to_i
		return @tzData["text"] if seconds == 0
		hours = (seconds / 3600).floor if seconds > 0
		hours = (seconds / 3600).ceil if seconds < 0
		minutes = ((seconds % 3600) / 60).abs.floor
		minutes = "0#{minutes}" if minutes < 10
		"(UTC #{ hours }:#{ minutes }) #{ @tzData["text"] }"
	end
end

class Database
	def self.connect(&block)
		connection = PG.connect(dbname: 'notify')
		block.call connection
		connection.close
	end

	def self.find_user_by_email email
		connect do |conn|
			conn.exec("SELECT * FROM users WHERE email = $1", [email]) do |results|
				raise "Too many users found for email" if results.num_tuples > 1
				return nil if results.num_tuples == 0
				return results[0]
			end
		end
	end

	def self.find_user_by_id id
		connect do |conn|
			conn.exec("SELECT * FROM users WHERE id = $1", [id]) do |results|
				raise "Too many users found for id" if results.num_tuples > 1
				return nil if results.num_tuples == 0
				return results[0]
			end
		end
	end

	def self.find_user params
		return find_user_by_id params[:id] if params.key? :id
		return find_user_by_email params[:email] if params.key? :email
	end

	def self.all_users
		connect do |conn|
			conn.exec("SELECT * FROM users") do |result|
				return result.hashes
			end
		end
	end

	def self.timezones
		connect do |conn|
			conn.exec("SELECT * FROM timezones") do |result|
				return result.hashes.map { |tz | Timezone.new tz }
			end
		end
	end

	def self.all_communications user=nil
		if user.nil?
			connect do |conn|
				conn.exec("SELECT 
					reminders.id AS reminder_id, reminders.version, 
					reminder_times.id AS reminder_time_id, users.id AS user_id, 
					reminders.message, sent_messages.scheduled, 
					sent_messages.cancelled, received_messages.server_received, 
					received_messages.body as received_body, 
					sent_messages.body as sent_body, sent_messages.to AS sent_to, 
					received_messages.from_ as received_from FROM 
					users,reminders,reminder_times,sent_messages LEFT JOIN 
					received_messages ON (sent_messages.id = 
					received_messages.in_response_to) WHERE (
					users.id = reminders.user_id AND 
					reminders.id = reminder_times.reminder_id AND 
					sent_messages.sent_for_reminder_time_id = reminder_times.id 
					AND sent_messages.cancelled = false) 
					ORDER BY scheduled DESC") do |result|
						return result.hashes
				end
			end
		else
			connect do |conn|
				conn.exec("SELECT 
					reminders.id AS reminder_id, reminders.version, 
					reminder_times.id AS reminder_time_id, users.id AS user_id, 
					reminders.message, sent_messages.scheduled, 
					sent_messages.cancelled, received_messages.server_received, 
					received_messages.body as received_body, 
					sent_messages.body as sent_body, sent_messages.to AS sent_to, 
					received_messages.from_ as received_from FROM 
					users,reminders,reminder_times,sent_messages LEFT JOIN 
					received_messages ON (sent_messages.id = 
					received_messages.in_response_to) WHERE (
					users.id = $1 AND 
					users.id = reminders.user_id AND 
					reminders.id = reminder_times.reminder_id AND 
					sent_messages.sent_for_reminder_time_id = reminder_times.id 
					AND sent_messages.cancelled = false) 
					ORDER BY scheduled DESC", [user.id]) do |result|
						return result.hashes
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
	session[:id] = id
end

def logout
	session_end!
end

def authenticate!
	unless logged_in?
		redirect to('/login.html')
	end
end

def current_user
	if logged_in?
		Database.find_user :id => session[:id]
	end
end

before do
	@req = (SimpleRequest.new)
	if logged_in?
		@current_user = User.new current_user, true
	end
end

set(:auth) do |*roles|   # <- notice the splat here
  condition do
  	authenticate!
	unless roles.all? {|role| @current_user.has_role? role }
	  halt 401, "NOT AUTHORIZED"
	end
  end
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

	def stripe_payment_key
		if settings.development?
	   		"pk_test_0vJgMvmOAjwiSDQQ8X2XP4Ky"
	  	elsif settings.test? or settings.production?
	    	"pk_live_YHP6pm3l1Ub76WbOyhJASvU0"
	    else
	    	raise "environment not found"
	  	end
	end

	def payment_page
		@stripe_payment_key = stripe_payment_key
		@text_messages_per_credit = 1
		partial_erb :payment
	end
end

get '/users', :auth => :admin do
	stream do |out|
		Database.all_users.each do |user|
			out << user.to_s
			out << "\n"
		end
	end
end

get %r{/(?:|home.html|index.html?)$} do
	@current_user.to_s
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
	user = Database.find_user :email => email
	unless user
		return bad_username_or_password
	end
	#TODO
	#unless user["password"] == password
	#	return bad_username_or_password
	#end
	login user["id"]
	redirect to('/account.html')
end

get '/logout.html' do
	logout
end

get '/signup.html' do
	signup_page
	"TODO"
end

post '/signup.html' do
	"TODO"
end

get '/account.html', :auth => :user do
	def warningLevel daysLeft
		if daysLeft < 1
	    	"alert alert-error"
		elsif 1 <= daysLeft and daysLeft < 7
	    	"alert"
	  	else
	      	"alert alert-info"
	  	end
	end

	@user = @current_user
	@timezones = Database.timezones
	erb :account, :locals => { 
		:warningLevel => :warningLevel,
		:payment => payment_page
	 }
end

post '/account.html', :auth => :user do
	"TODO"
end

post '/payment.html', :auth => :user do
	"TODO"
end

get '/scheduled.html', :auth => :user do
	"TODO"
end

post '/scheduled.html', :auth => :user do
	"TODO"
end

get '/results.html', :auth => :user do
	results = @current_user.all_communications
	@reminders = results.group_by { |x| x["reminder_id"]}.map do |reminder_id, messages|
		{
	        text: messages[0]["message"],
	        id: reminder_id,
	        replies: messages.map do |message|
        		{
        			date: message["scheduled"],
        			reply: unless message["server_received"].nil? 
        				{
	        				text: message["received_body"],
	        				time: message["server_received"]
	        			}
		        	end
		        }
	        end
	    }
    end
    erb :results
end

get %r{/results(?:|/all)$}, :auth => :user do
	@lines = @current_user.all_communications
	content_type :txt
	erb :csvResults, :layout => false
end

get '/results/:id', :auth => :user do |id|
	@lines = @current_user.all_communications.find_all { |line| line["reminder_id"] == id}
	content_type :txt
	erb :csvResults, :layout => false
end