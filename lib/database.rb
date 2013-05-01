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
	def self.connect(&block)
		connection = PG.connect(dbname: 'notify')
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

	def self.find_user_by_email email
		query_params("SELECT * FROM users WHERE email = $1", [email]) do |results|
			raise "Too many users found for email" if results.num_tuples > 1
			return nil if results.num_tuples == 0
			return results[0]
		end
	end

	def self.find_user_by_id id
		query_params("SELECT * FROM users WHERE id = $1", [id]) do |results|
			raise "Too many users found for id" if results.num_tuples > 1
			return nil if results.num_tuples == 0
			return results[0]
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
		query_params("SELECT * FROM reminders WHERE reminders.id = $1",
			[user.id]) do |result|
			return result.map { |reminder| DatabaseReminder.new reminder }
		end
	end

	def self.current_reminders_for_user user
		reminders = all_reminders_for_user user
		reminders.reject do |reminder|
			reminders.any? do |other_reminder|
				other_reminder.newer_version_of_same_reminder? reminder
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
end
