require 'login.rb'

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

	def account
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

	def signup(params=nil, errors=nil)
		if params
			@name = params["name"]
			@TimeZoneId = params["TimeZoneId"]
			@email = params["email"]
			@password = params["password"]
			@errorMsg = errors[0].to_s
		end
		@timezones = Database.timezones
		erb :signup
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
	erb :home, :locals => { :login => (partial_erb :login) }
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
	unless user.verify_password? password
		return bad_username_or_password
	end
	login user.id
	redirect to('/account.html')
end

get '/logout.html' do
	logout
	redirect to('/login.html')
end

get '/signup.html' do
	signup
end

post '/signup.html' do
	user = ClientUser.new params
	if user.valid?
		duser = user.create!
		puts duser
		login duser.id
		redirect to('/account.html')
	else
		params.delete "password"
		signup params, user.errors
	end
end


get '/account.html', :auth => :user do
	account
end

post '/account.html', :auth => :user do
	timezone = params["timezone"] or raise 'timezone missing'
	if timezone and timezone != @current_user.timezone
	    @current_user.timezone = timezone
 		@current_user.save!
 	end
 	account
end

post '/payment.html', :auth => :user do
	"TODO"
end

class EmptyClientTime < DatabaseReminderTime
	def initialize
		super({})
	end
	def enabled
		false
	end
	def days
		[]
	end
end
class EmptyClientReminder < DatabaseReminder
	def initialize
		super({})
	end
	def times
		@times ||= [EmptyClientTime.new, EmptyClientTime.new]
	end
	def phone
		nil
	end
end
get '/scheduled.html', :auth => :user do
	def pad_reminders! reminders
		# Pad with empty space to fill in
		for r in reminders
			r.times.push EmptyClientTime.new
		end
		reminders.push EmptyClientReminder.new
	end

	@reminders = @current_user.reminders
	pad_reminders! @reminders

	@daysOfWeek = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
	@beginTimesOfDay = TimeOfDay.all[0..-2]
	@endTimesOfDay = TimeOfDay.all[1..-1]
	@defaultPhone = "+1 (555) 555-5555"
	erb :scheduled
end

post '/scheduled.html', :auth => :user do
	"TODO"
end

get '/results.html', :auth => :user do
	results = @current_user.all_communications
	@reminders = results.group_by { |x| x["reminder_id"] }.map do |reminder_id, messages|
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
