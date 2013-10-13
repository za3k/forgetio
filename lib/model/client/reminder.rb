class ClientReminder < ClientModelBase
	def initialize hash, user
		@times = hash["times"].map { |time| ClientReminderTime.new time }
		@times = valid_times
		@message = hash["message"]
		@phone_number = hash["phone"]
		@id = hash["id"]
		@version = hash["version"]
		@user_id = user.id
		super
	end
	def verify!
		add_error "Message was empty" if message.nil? or message.empty?
		add_error "Version missing" if version.nil? or version.empty?
		add_error "Phone missing" if phone_number.nil? or phone_number.empty? or phone_number.length < 7
		unless exists_in_db?
			add_error "No valid times" unless any_valid_times?
		end
	end
	def any_valid_times?
		not valid_times.empty?
	end
	def valid_times
		times.find_all { |time| time.valid? }
	end
	def exists_in_db?
		not (id.nil? or id.empty?)
	end
	def update!
		Database.update_reminder! self
	end
	def create!
		Database.create_reminder! self
	end
	def save!
		if exists_in_db?
			update!
		else
			create!
		end
	end
	def user_has_permission?
		if exists_in_db?
			existing_reminder = Database.find_reminder id
			raise "Couldn't find existing reminder" unless existing_reminder
			existing_reminder.user_id == @user_id
		else
			true
		end
	end
	def to_s
		{
			id: id,
			version: version,
			message: message,
			phone_number: phone_number,
			times: times.map {|x| x.to_s}
		}.to_s
	end

	attr_reader :times, :id, :version, :phone_number, :message, :user_id
end