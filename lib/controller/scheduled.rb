class EmptyClientTime < DatabaseReminderTime
	def initialize
		super({})
	end
	def enabled
		false
	end
	def days
		[]
	end
end
class EmptyClientReminder < DatabaseReminder
	def initialize
		super({})
	end
	def times
		@times ||= [EmptyClientTime.new, EmptyClientTime.new]
	end
	def phone
		nil
	end
end
get '/scheduled.html', :auth => :user do
	def pad_reminders! reminders
		# Pad with empty space to fill in
		for r in reminders
			r.times.push EmptyClientTime.new
		end
		reminders.push EmptyClientReminder.new
	end

	@reminders = @current_user.reminders
	pad_reminders! @reminders

	@daysOfWeek = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
	@beginTimesOfDay = TimeOfDay.all[0..-2]
	@endTimesOfDay = TimeOfDay.all[1..-1]
	@defaultPhone = "+1 (555) 555-5555"
	erb :scheduled
end

post '/scheduled.html', :auth => :user do
	"TODO"
end
