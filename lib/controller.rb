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
	@reminders = [] # TODO
	erb :scheduled
	erb "TODO"
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