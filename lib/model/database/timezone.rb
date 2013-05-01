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