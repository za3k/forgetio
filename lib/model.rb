class User
	def initialize(userObj, loggedIn)
		@user = userObj
		@loggedIn = loggedIn
	end
	def has_role? role
		roles.include? role
	end
	def method_missing(n)
		@user[n.to_s]
	end
	def roles
		roles = [:user]
		roles.push :admin if admin?
		roles
	end
	def admin?
		["vanceza@gmail.com"].include? email
	end
	def logged_in?
		@loggedIn
	end
	def to_s
		@user.to_s
	end
	def credit
		@user["credit"].to_i
	end
	def lowerTimeEstimate
		credit / 10
	end
	def upperTimeEstimate
		credit / 5
	end
	def timezone
		@user["timezone_id"]
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
