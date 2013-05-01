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
