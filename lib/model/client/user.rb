class ClientUser < ClientModelBase
	def initialize hash
		@password = hash["password"]
		@name = hash["name"]
		@timezone = hash["TimeZoneId"]
		@email = hash["email"]
		super
	end
	def verify!
		add_error "Missing name" if name.nil? or name.empty?
		add_error "Missing timezone" if timezone.nil? or timezone.empty?
		add_error "Missing email" if email.nil? or email.empty?
		add_error "Missing password" if password.nil? or password.empty?
		add_error "Password too short" if password.length < 8
		add_error "Invalid email" unless valid_email?
		add_error "Invalid timezone" unless valid_timezone?
	end
	def valid_email?
		return false unless email.match /@/
		return false unless (Database.find_user_by_email email).nil?
		true
	end
	def valid_timezone?
		Database.timezones.any? do |tz|
			tz.id == @timezone
		end
	end
	def create!
		Database.create_user name, password_hash, timezone, email
	end
	attr_reader :password, :name, :timezone, :email
end