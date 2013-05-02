class ClientModelBase
	def initialize *rest
		@errors = []
		verify!
	end
	def verify!
	end
	def add_error message
		errors.push message
	end
	def valid?
		errors.empty?
	end
	def errors
		@errors ||= []
	end

	attr_reader :errors
end