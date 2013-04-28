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