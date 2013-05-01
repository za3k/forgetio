helpers do
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
