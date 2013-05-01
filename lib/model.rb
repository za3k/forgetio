#require 'ostruct'
require 'model/database/phone.rb'
require 'model/database/reminder.rb'
require 'model/database/remindertime.rb'
require 'model/database/timezone.rb'
require 'model/database/user.rb'
require 'model/client/user.rb'

class Hash
	def has_keys? keys
		keys.all? do |key|
			has_key? key
		end
	end
end

class TimeOfDay
	def initialize timeOfDay
		@timeOfDay = timeOfDay
	end
	def self.all
		(0..24).map { |v| self.new v }
	end
	def value
		@timeOfDay
	end
	def text
	    if [0,24].include? value
	        "Midnight"
	    elsif value == 12
	        "Noon"
	    elsif value < 12
	        "#{value}:00am"
	    else
	        "#{value-12}:00pm"
	    end
	end
	def to_s
		{ value: value, text: text }.to_s
	end
end