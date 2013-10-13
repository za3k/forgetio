helpers do
	def bad_username_or_password
		login_page "Bad username or password."
	end

	def missing_password
		login_page "Password was empty."
	end

	def login_page error=nil
		@errorMsg = error
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
	if email.nil? or email.empty?
		redirect to('/login.html')
	end
	if password.nil? or password.empty?
		return missing_password
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

get '/reset', :auth => :admin do
	email = request["email"]
	user = Database.find_user :email => email
	password = request["password"]
	user.set_password! password
	user.save!
end
