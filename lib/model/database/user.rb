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
	def credit= credits
		@data["credit"] = credits.to_s
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
