class Timezone
	def initialize tzData
		@tzData = tzData
	end
	def id
		@tzData["id"]
	end
	def seconds
		@tzData["offset"].to_i
	end
	def text
		return @tzData["text"] if seconds == 0
		hours = (seconds / 3600).floor if seconds > 0
		hours = (seconds / 3600).ceil if seconds < 0
		minutes = ((seconds % 3600) / 60).abs.floor
		minutes = "0#{minutes}" if minutes < 10
		"(UTC #{ hours }:#{ minutes }) #{ @tzData["text"] }"
	end
end

class Database
	def self.source_timezones
		[
	    ["International Date Line West",-12],
	    ["Midway Island / Samoa",-11],
	    ["Hawaii",-10],
	    ["Marquesas Islands",-9.5],
	    ["Alaska",-9],
	    ["Pitcairn",-8],
	    ["Pacific Time (US & Canada)",-8],
	    ["Tijuana / Baja California",-8],
	    ["Chihuahua / La Paz / Mazatlan - New",-7],
	    ["Mountain Time (US & Canada)",-7],
	    ["Arizona",-7],
	    ["Central Time (US & Canada)",-6],
	    ["Central America",-6],
	    ["Guadalajara / Mexico City / Monterrey - New",-6],
	    ["Saskatchewan",-6],
	    ["Bogota / Lima / Quito / Rio Branco",-5],
	    ["Indiana (East)",-5],
	    ["Eastern Time (US & Canada)",-5],
	    ["Caracas",-4],
	    ["Georgetown",-4],
	    ["Atlantic Time (Canada)",-4],
	    ["La Paz",-4],
	    ["Manaus",-4],
	    ["Santiago",-4],
	    ["Newfoundland",-3.5],
	    ["Buenos Aires",-3],
	    ["Greenland",-3],
	    ["Montevideo",-3],
	    ["Brasilia",-3],
	    ["Mid-Atlantic",-2],
	    ["Azores",-1],
	    ["Cape Verde Is.",-1],
	    ["(UTC) Casablanca",0],
	    ["(UTC) Monrovia / Reykjavik",0],
	    ["(UTC) Greenwich Mean Time - Dublin / Edinburgh / Lisbon / London",0],
	    ["West Central Africa",1],
	    ["Windhoek",1],
	    ["Belgrade / Bratislava / Budapest / Ljubljana / Prague",1],
	    ["Amsterdam / Berlin / Bern / Rome / Stockholm / Vienna",1],
	    ["Brussels / Copenhagen / Madrid / Paris",1],
	    ["Sarajevo / Skopje / Warsaw / Zagreb",1],
	    ["Cairo",2],
	    ["Harare / Pretoria",2],
	    ["Amman",2],
	    ["Beirut",2],
	    ["Jerusalem",2],
	    ["Athens / Bucharest / Istanbul",2],
	    ["Helsinki / Kyiv / Riga / Sofia / Tallinn / Vilnius",2],
	    ["Minsk",2],
	    ["Nairobi",3],
	    ["Baghdad",3],
	    ["Kuwait / Riyadh",3],
	    ["Moscow / St. Petersburg / Volgograd",3],
	    ["Tehran",3.5],
	    ["Baku",4],
	    ["Abu Dhabi / Muscat",4],
	    ["Tbilisi",4],
	    ["Yerevan",4],
	    ["Kabul",4.5],
	    ["Islamabad / Karachi",5],
	    ["Tashkent",5],
	    ["Ekaterinburg",5],
	    ["Sri Jayawardenepura",5.5],
	    ["Chennai / Kolkata / Mumbai / New Delhi",5.5],
	    ["(UTC+05:45) Kathmandu",5.75],
	    ["Astana / Dhaka",6],
	    ["Almaty / Novosibirsk",6],
	    ["Yangon (Rangoon)",6.5],
	    ["Bangkok / Hanoi / Jakarta",7],
	    ["Krasnoyarsk",7],
	    ["Beijing / Chongqing / Hong Kong / Urumqi",8],
	    ["Irkutsk / Ulaan Bataar",8],
	    ["Kuala Lumpur / Singapore",8],
	    ["Taipei",8],
	    ["Perth",8],
	    ["Seoul",9],
	    ["Osaka / Sapporo / Tokyo",9],
	    ["Yakutsk",9],
	    ["Adelaide",9.5],
	    ["Darwin",9.5],
	    ["Vladivostok",10],
	    ["Brisbane",10],
	    ["Hobart",10],
	    ["Canberra / Melbourne / Sydney",10],
	    ["Guam / Port Moresby",10],
	    ["Lord Howe",10.5],
	    ["Magadan / Solomon Is. / New Caledonia",11],
	    ["Norfolk Islands",11.5],
	    ["Auckland / Wellington",12],
	    ["Fiji / Kamchatka / Marshall Is.",12],
	    ["Nuku'alofa",13]
		]
	end
end