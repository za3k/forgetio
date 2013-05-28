require 'pg'

# Monkey-patch database module to let us store results after the connection
module PG
	class PG::Result
		def hashes
			self.map {|row| row }
		end
	end
end

class Database
	def self.dbname= name
		@@dbname = name
	end

	def self.dbname
		@@dbname
	end

	def self.connect(&block)
		connection = PG.connect(dbname: dbname)
		block.call connection
		connection.close
	end

	def self.query(query, &block)
		connect do |conn|
			conn.exec(query, &block)
		end
	end

	def self.query_params(query, args, &block)
		connect do |conn|
			conn.exec_params(query, args, &block)
		end
	end

	def self.create_user name, password_hash, timezone_id, email
		query_params("INSERT INTO users (credit, name, password, 
			timezone_id, email, \"createdAt\", \"updatedAt\") 
			VALUES (0, $1, $2, $3, $4, 'now', 'now')", 
			[name, password_hash, timezone_id, email]) do |results|
			
			raise "INSERT USER failed" unless results.cmd_tuples == 1
			return find_user_by_email email
		end
	end

	def self.find_user_by_email email
		query_params("SELECT * FROM users WHERE email = $1", [email]) do |results|
			raise "Too many users found for email" if results.num_tuples > 1
			return nil if results.num_tuples == 0
			return DatabaseUser.new results[0]
		end
	end

	def self.find_user_by_id id
		query_params("SELECT * FROM users WHERE id = $1", [id]) do |results|
			raise "Too many users found for id" if results.num_tuples > 1
			return nil if results.num_tuples == 0
			return DatabaseUser.new results[0]
		end
	end

	def self.find_user params
		return find_user_by_id params[:id] if params.key? :id
		return find_user_by_email params[:email] if params.key? :email
	end

	def self.all_users
		query("SELECT * FROM users") do |result|
			return result.hashes
		end
	end

	def self.timezones
		query("SELECT * FROM timezones") do |result|
			return result.hashes.map { |tz | Timezone.new tz }
		end
	end

	def self.create_timezone! text, seconds
		query_params("INSERT INTO timezones (\"offset\", text, \"createdAt\", 
			\"updatedAt\") VALUES ($1, $2, 'now', 'now')", [seconds, text]) do |res|
			raise "Timezone not inserted" unless res.cmd_tuples == 1
		end
	end

	def self.create_timezones!
		for timezone in source_timezones
			create_timezone! timezone[0], (timezone[1] * 3600).to_i
		end
	end

	def self.all_communications user=nil
		if user.nil?
			query("SELECT 
				reminders.id AS reminder_id, reminders.version, 
				reminder_times.id AS reminder_time_id, users.id AS user_id, 
				reminders.message, sent_messages.scheduled, 
				sent_messages.cancelled, received_messages.server_received, 
				received_messages.body as received_body, 
				sent_messages.body as sent_body, sent_messages.to AS sent_to, 
				received_messages.from_ as received_from FROM 
				users,reminders,reminder_times,sent_messages LEFT JOIN 
				received_messages ON (sent_messages.id = 
				received_messages.in_response_to) WHERE (
				users.id = reminders.user_id AND 
				reminders.id = reminder_times.reminder_id AND 
				sent_messages.sent_for_reminder_time_id = reminder_times.id 
				AND sent_messages.cancelled = false) 
				ORDER BY scheduled DESC") do |result|
					return result.hashes
			end
		else
			query_params("SELECT 
				reminders.id AS reminder_id, reminders.version, 
				reminder_times.id AS reminder_time_id, users.id AS user_id, 
				reminders.message, sent_messages.scheduled, 
				sent_messages.cancelled, received_messages.server_received, 
				received_messages.body as received_body, 
				sent_messages.body as sent_body, sent_messages.to AS sent_to, 
				received_messages.from_ as received_from FROM 
				users,reminders,reminder_times,sent_messages LEFT JOIN 
				received_messages ON (sent_messages.id = 
				received_messages.in_response_to) WHERE (
				users.id = $1 AND 
				users.id = reminders.user_id AND 
				reminders.id = reminder_times.reminder_id AND 
				sent_messages.sent_for_reminder_time_id = reminder_times.id 
				AND sent_messages.cancelled = false) 
				ORDER BY scheduled DESC", [user.id]) do |result|
					return result.hashes
			end
		end
	end

	def self.all_reminders_for_user user
		query_params("SELECT * FROM reminders WHERE user_id = $1",
			[user.id]) do |result|
			return result.map { |reminder| DatabaseReminder.new reminder }
		end
	end

	def self.find_reminder id
		query_params("SELECT * FROM reminders WHERE id = $1",
			[id]) do |result|
			return DatabaseReminder.new result[0]
		end
	end

	def self.current_reminders_for_user user
		reminders = all_reminders_for_user user
		reminders.reject do |reminder|
			reminders.any? do |other_reminder|
				other_reminder.is_newer_version_of? reminder
			end
		end
	end

	def self.phone_for_reminder reminder
		query_params("SELECT * FROM phones where phones.id = $1",
			[reminder.phone_id]) do |result|
			return DatabasePhoneNumber.new result[0] if result.num_tuples == 1
			raise 'Reminder is missing a phone number' if result.num_tuples == 0
			raise 'Reminder has multiple phone numbers'
		end
	end

	def self.times_for_reminder reminder
		query_params("SELECT * FROM reminder_times where reminder_times.reminder_id = $1",
			[reminder.id]) do |result|
			return result.map { |time| DatabaseReminderTime.new time }
		end
	end

	def self.update_user! user
		query_params("UPDATE users SET timezone_id = $2, \"updatedAt\" = 'now' WHERE id = $1",
			[user.id, user.timezone])
	end

	def self.update_reminder! reminder
		create_reminder! reminder, reminder.version.to_i + 1, reminder.id
	end

	def self.create_reminder! reminder, version=0, parent_id=nil
		unless reminder.user_has_permission?
			raise "User does not own the reminder they are trying to save!"
		end
		connect do |conn|
			conn.transaction do |conn|
				phone_id = create_phone! reminder.user_id, reminder.phone_number, conn
				raise "No phone id" if phone_id.nil? or phone_id.empty?
				conn.exec_params("INSERT INTO reminders (version, parent_id, 
						user_id, message, phone_id, \"createdAt\", \"updatedAt\")
						VALUES ($1, $2, $3, $4, $5, 'now', 'now') RETURNING id, version",
						[version, parent_id,
						reminder.user_id, reminder.message, phone_id]) do |res|
					raise "Failed to insert reminder" unless res.cmd_tuples == 1
					new_reminder_id = res[0]["id"]
					for time in reminder.valid_times
						create_time! time, new_reminder_id, conn
					end
					new_reminder_id
				end
			end
		end
	end

	def self.create_phone! user_id, phone_number, conn 
		conn.exec_params("INSERT INTO phones (user_id, number, \"createdAt\", \"updatedAt\")
			VALUES ($1, $2, 'now', 'now') RETURNING id", [user_id, phone_number]) do |res|
			raise "Failed to add phone number" unless res.num_tuples == 1
			res[0]["id"]
		end
	end

	def self.create_time! time, reminder_id, conn
		conn.exec_params("INSERT INTO reminder_times
			(start, \"end\", frequency, days, reminder_id, \"createdAt\", \"updatedAt\") 
			VALUES ($1, $2, $3, $4, $5, 'now', 'now') RETURNING id", 
			[time.start_seconds, time.end_seconds, time.frequency, time.days_to_i, reminder_id]) do |res|
			raise "Failed to add reminder time" unless res.num_tuples == 1
			res[0]["id"]
		end
	end

	def self.create_user_payment! credits, money, stripeToken
		connect do |conn|
			conn.exec_params("INSERT INTO user_payments
				(credit, money, stripe_token, \"createdAt\", \"updatedAt\")
				VALUES ($1, $2, $3, 'now', 'now') RETURNING id, credit, money, stripe_token",
				[credits, money, stripeToken]) do |res|
				raise "Failed to add user payment" unless res.num_tuples == 1
				return DatabaseUserPayment.new res.hashes[0]
			end
		end
	end

	def self.update_user_payment! payment
		connect do |conn|
			conn.exec_params("UPDATE user_payments SET credit=$1, money=$2, stripe_token=$3,
				stripe_fee=$4, stripe_charge=$5, \"updatedAt\"='now' WHERE id=$6",
				[payment.credits, payment.money, payment.stripe_token, payment.fee,
					payment.stripe_charge, payment.id]) do |res|
				raise "Failed to update payment" unless res.cmd_tuples == 1
				return payment
			end
		end
	end

end
