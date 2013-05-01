helpers do
	def bad_username_or_password
		login_page
	end

	def login_page
		@email = request["email"]
		erb :login
	end
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