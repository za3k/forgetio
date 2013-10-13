class DatabasePhoneNumber
	def initialize hash
		@data = hash
	end
	def [] x
		@data[x]
	end
	def number
		@data["number"]
	end
end