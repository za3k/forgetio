class User
	def roles
		roles = [:user]
		roles.push :admin if admin?
		roles
	end
	def admin?
		["vanceza@gmail.com"].include? email
	end
	def verify_password? password
		HashedPassword.verify? password, @user["password"]
	end
end

# EXACT backwards-compatibility with password-hash from nodejs
require 'digest'
require 'openssl'
class HashedPassword
	def self.generate(password, salt=generate_salt, algorithm="sha1", iterations=1)
		return nil unless algorithm == "sha1"
		return nil unless iterations == 1
		hash "sha1", generate_salt, 1, password
	end
	def self.generate_salt length=50, charset=('a'..'z').to_a
		(0...length).map{ charset[rand(charset.length)] }.join
	end
	def self.hash(algorithm, salt, iterations, password)
		return nil unless algorithm == "sha1"
		return nil unless iterations == 1
		hashed = Digest.hexencode(OpenSSL::HMAC.digest('sha1', salt, password))
		[algorithm, salt, iterations.to_s, hashed].join "$"
	end
	def self.isHashed? hashed_password
		(hashed_password.split "$").length == 4
	end
	def self.verify?(password, hashed_password)
		algorithm, salt, iterations, hashed = hashed_password.split "$"
		hashed_password == hash(algorithm, salt, iterations.to_i, password)
	end
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
	if logged_in?
		@current_user = User.new current_user
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