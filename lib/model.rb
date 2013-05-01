require 'ostruct'

class Hash
	def has_keys? keys
		keys.all? do |key|
			has_key? key
		end
	end
end

class DatabaseUser
	def initialize hash
		@data = hash
	end
	def has_role? role
		roles.include? role
	end
	def method_missing(n)
		@data[n.to_s]
	end
	def to_s
		@data.to_s
	end
	def credit
		@data["credit"].to_i
	end
	def lowerTimeEstimate
		credit / 10
	end
	def upperTimeEstimate
		credit / 5
	end
	def timezone
		@data["timezone_id"]
	end
	def timezone= tz
		@data["timezone_id"] = tz
	end
	def all_communications
		@_all_communications ||= Database.all_communications self
	end
	def messages_received_sent
		all_communications.partition { |comm| not comm["server_received"].nil? }
	end
	def messages_received
		received, sent = messages_received_sent
		received
	end
	def messages_sent
		received, sent = messages_received_sent
		sent
	end
	def reminders
		Database.current_reminders_for_user self
	end
	def save!
		Database.update_user! self
	end
	def password_hash
		@data["password"]
	end
end

class ClientUser
	def initialize hash
		@errors = []
		@password = hash["password"]
		@name = hash["name"]
		@timezone = hash["TimeZoneId"]
		@email = hash["email"]
		verify!
	end
	def add_error message
		errors.push message
	end
	def verify!
		add_error "Missing name" if @name.nil? or @name.empty?
		add_error "Missing timezone" if @timezone.nil? or @timezone.empty?
		add_error "Missing email" if @email.nil? or @email.empty?
		add_error "Missing password" if @password.nil? or @password.empty?
		add_error "Invalid email" unless valid_email?
		add_error "Invalid timezone" unless valid_timezone?
	end
	def valid?
		errors.empty?
	end
	def valid_email?
		return false unless @email.match /@/
		return false unless (Database.find_user_by_email @email).nil?
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
	attr_reader :errors, :password, :name, :timezone, :email
end

class Timezone
	def initialize tzData
		@tzData = tzData
	end
	def id
		@tzData["id"]
	end
	def text
		seconds = @tzData["offset"].to_i
		return @tzData["text"] if seconds == 0
		hours = (seconds / 3600).floor if seconds > 0
		hours = (seconds / 3600).ceil if seconds < 0
		minutes = ((seconds % 3600) / 60).abs.floor
		minutes = "0#{minutes}" if minutes < 10
		"(UTC #{ hours }:#{ minutes }) #{ @tzData["text"] }"
	end
end

class TimeOfDay
	def initialize timeOfDay
		@timeOfDay = timeOfDay
	end
	def self.all
		(0..24).map { |v| self.new v }
	end
	def value
		@timeOfDay
	end
	def text
	    if [0,24].include? value
	        "Midnight"
	    elsif value == 12
	        "Noon"
	    elsif value < 12
	        "#{value}:00am"
	    else
	        "#{value-12}:00pm"
	    end
	end
	def to_s
		{ value: value, text: text }.to_s
	end
end

class DatabaseReminder
	def initialize hash
		@data = hash
	end
	def times
		@times ||= Database.times_for_reminder self
	end
	def phone
		Database.phone_for_reminder(self)
	end
	def id
		@data["id"]
	end
	def error
		nil
	end
	def version
		@data["version"]
	end
	def message
		@data["message"]
	end
	def phone_id
		@data["phone_id"]
	end
	def raw_parent_id
		@data["parent_id"]
	end
	def parent_id
		raw_parent_id or id
	end
	def same_parent? other
		parent_id == other.parent_id
	end
	def newer_version_of_same_reminder? other
		same_parent? other and version > other.version
	end
end

class DatabaseReminderTime
	def initialize hash
		@frequency = hash["frequency"]
		@start = secondsToHours hash["start"].to_i
		@end = secondsToHours hash["end"].to_i
		@days = convertDays hash["days"].to_i
	end
	def enabled
		true
	end
	def secondsToHours s
		return s / 60 / 60
	end
	def convertDays d
		days = []
		for day in ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
			if (d % 2) == 1
				days.push day
				d -= 1
			end
			d /= 2
		end
		raise 'Too many days' if d > 0
		days
	end
	attr_reader :frequency, :start, :end, :days
end

class DatabasePhoneNumber
	def initialize hash
		@data = hash
	end
	def [] x
		@data[x]
	end
	def number
		@data["number"]
	end
end