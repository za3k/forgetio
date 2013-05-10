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
	def user_id
		@data["user_id"]
	end
	def parent_id
		raw_parent_id or id
	end
	def is_parent_of? other
		id == other.parent_id
	end
	def same_parent? other
		return false if parent_id.nil?
		other.parent_id == parent_id
	end
	def is_newer_version_of? other
		if other.is_parent_of? self
			return true
		elsif same_parent? other
			other.version.to_i < version.to_i
		end
	end
end
