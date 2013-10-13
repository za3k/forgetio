helpers do
	def account options={}
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
		if options.key? :errorMsg
			@errorMsg = options[:errorMsg]
		end
		if options.key? :successMsg
			@errorMsg = options[:successMsg]
		end
		erb :account, :locals => { 
			:warningLevel => :warningLevel,
			:payment => payment_page
		}
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
