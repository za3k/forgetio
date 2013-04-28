require 'login.rb'

helpers do
	alias_method :raw_erb, :erb

	def partial_erb(page, options={})
		raw_erb page, (options.merge :layout => false)
	end

	def erb(page, options={})
		@page = page
		extra_options = {
			:layout_options => {
				:locals => {
					:navbar => (partial_erb :navbar, :locals => { :page => page})
				}
			}
		}
		raw_erb page, (options.merge extra_options)
	end

	def bad_username_or_password
		login_page
	end

	def login_page
		@email = request["email"]
		erb :login
	end

	def signup_page
		erb :signup
	end

	def stripe_payment_key
		if settings.development?
	   		"pk_test_0vJgMvmOAjwiSDQQ8X2XP4Ky"
	  	elsif settings.test? or settings.production?
	    	"pk_live_YHP6pm3l1Ub76WbOyhJASvU0"
	    else
	    	raise "environment not found"
	  	end
	end

	def payment_page
		@stripe_payment_key = stripe_payment_key
		@text_messages_per_credit = 1
		partial_erb :payment
	end
end

get '/users', :auth => :admin do
	stream do |out|
		Database.all_users.each do |user|
			out << user.to_s
			out << "\n"
		end
	end
end

get %r{/(?:|home.html|index.html?)$} do
	erb :home, :locals => { :login => (partial_erb :login) }
end

get '/login.html' do
	login_page
end

post '/login.html' do
	email = request["email"]
	password = request["password"]
	if email.nil? or password.nil?
		redirect to('/login.html')
	end
	user = Database.find_user :email => email
	unless user
		return bad_username_or_password
	end
	unless (User.new user).verify_password? password
		return bad_username_or_password
	end
	login user["id"]
	redirect to('/account.html')
end

get '/logout.html' do
	logout
	redirect to('/login.html')
end

get '/signup.html' do
	signup_page
end

post '/signup.html' do
	"TODO"
end

get '/account.html', :auth => :user do
	def warningLevel daysLeft
		if daysLeft < 1
	    	"alert alert-error"
		elsif 1 <= daysLeft and daysLeft < 7
	    	"alert"
	  	else
	      	"alert alert-info"
	  	end
	end

	@user = @current_user
	@timezones = Database.timezones
	erb :account, :locals => { 
		:warningLevel => :warningLevel,
		:payment => payment_page
	 }
end

post '/account.html', :auth => :user do
	"TODO"
end

post '/payment.html', :auth => :user do
	"TODO"
end

# getRemindersForUser = (user, final_cb) ->
#   errorHandler = (step, error) ->
#     console.log("There was an error")
#     console.log(error)
#   steps = [
#     (step) ->
#       user.getReminders().success( (reminders) ->
#         step.data.reminders = reminders
#         step.next()
#       ).failure((err)->
#         step.data.getReminderErr = err
#         step.next()
#       )
#     (step) ->
#       if step.data.getReminderErr?
#         throw step.data.getReminderErr
#       step.next()
#     (step) ->
#       reminders = step.data.reminders
#       step.data.reminders = []
#       for r in reminders
#         cb = step.spawn()
#         processReminder r, errorHandler, (reminder) ->
#           step.data.reminders.push(reminder)
#           cb()
#       step.next()
#     (step) ->
#       common.logger.debug(JSON.stringify(step.data))
#       for r in step.data.reminders
#         if !r.parent_id?
#           r.parentId = r.id
#       step.data.reminders = step.data.reminders.filter (reminder) ->
#         for r in step.data.reminders
#           if r.parent_id == reminder.parent_id and r.version > reminder.version
#             return false
#         return true
#       step.next()
#   ]
#   last = (step) ->
#     final_cb(step.data.reminders)
#   ctrl(steps, {errorHandler: errorHandler}, last)

# processTime = (time) ->
#   time.start = time.start * 60 * 60 # seconds since midnight
#   time.end = time.end * 60 * 60
#   time.days = (x in time.days for x in ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"])
#   d = 0
#   while time.days.length > 0
#     d *= 2
#     d += time.days.pop()
#   time.days = d
#   check(time.frequency, "Please enter a number for frequency").notEmpty().isDecimal()
#   time


class EmptyClientTime < DatabaseReminderTime
	def initialize
		super({})
	end
	def enabled
		true
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
# putReminderForUser = (reminder, user, success, failure) ->
#   errorHandler = (step, err) ->
#     common.logger.error("There was an error")
#     if err?.message
#       err = err.message
#     common.logger.error(err)
#     failure(err)

#   steps = [
#     (step) ->
#       common.logger.debug("Putting reminder: " + reminder)
#       step.next()
#     (step) ->
#       reminder.user_id = user.id
#       step.next()
#     (step) ->
#       check(reminder.message,"Message was blank").notEmpty()
#       check(reminder.phone, "Phone number was blank").len(7,64)
#       step.next()
#     (step) ->
#       common.logger.debug("Stripping out invalid times")
#       reminder.times = reminder.times.filter (time) ->
#         if !time.frequency
#             return false
#         return true
#       step.next()
#     (step) ->
#       for time in reminder.times
#         if time.frequency != ""
#           processTime time
#       step.next()
#   ]
#   last = (step) ->
#     trans = transaction.createSaveReminderTran(reminder)
#     transaction.runTran(trans, success)
#   ctrl(steps, {errorHandler: errorHandler}, last)

# exports.scheduledPost = (req, res) ->
#   user = req.user.getUser()
#   console.log(req.body)
#   json = JSON.parse(req.body.json)
#   for reminder in json.reminders
#     putReminderForUser(reminder, user, () ->
#       exports.scheduled(req, res, {successMsg: "Successfully updated."})
#     (errMsg) ->
#       exports.scheduled(req, res, {errorMsg: errMsg}))

end

get '/results.html', :auth => :user do
	results = @current_user.all_communications
	@reminders = results.group_by { |x| x["reminder_id"] }.map do |reminder_id, messages|
		{
	        text: messages[0]["message"],
	        id: reminder_id,
	        replies: messages.map do |message|
        		{
        			date: message["scheduled"],
        			reply: unless message["server_received"].nil? 
        				{
	        				text: message["received_body"],
	        				time: message["server_received"]
	        			}
		        	end
		        }
	        end
	    }
    end
    erb :results
end

get %r{/results(?:|/all)$}, :auth => :user do
	@lines = @current_user.all_communications
	content_type :txt
	erb :csvResults, :layout => false
end

get '/results/:id', :auth => :user do |id|
	@lines = @current_user.all_communications.find_all { |line| line["reminder_id"] == id}
	content_type :txt
	erb :csvResults, :layout => false
end
