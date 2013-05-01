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