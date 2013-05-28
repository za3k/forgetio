class ClientReminderTime < ClientModelBase
	def initialize hash
		@frequency = hash["frequency"]
		@days = hash["days"]
		@start_time = hash["start"]
		@end_time = hash["end"]
		super
	end
	def verify!
		add_error "Missing frequency" if frequency.nil? or frequency.empty?
		# TODO: Make sure frequency is a number
		add_error "Missing days" if days.nil?
		add_error "Missing start time" if start_time.nil? or start_time.empty?
		add_error "Missing end time" if end_time.nil? or end_time.empty?
	end
	def start_seconds
		start_time.to_i * 3600
	end
	def end_seconds
		start_time.to_i * 3600
	end
	def days_to_i
		d = 0
		for day in ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"].reverse
			d *= 2
			if days.include? day
				d += 1
			end
		end
		d
	end
	def to_s
		{
			frequency: frequency,
			days: days,
			start_time: start_time,
			end_time: end_time
		}.to_s
	end
	attr_reader :frequency, :days, :start_time, :end_time
end