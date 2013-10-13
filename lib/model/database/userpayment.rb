class DatabaseUserPayment
	def initialize hash
		@data = hash
	end
	def credits
		@data['credit']
	end
	def money
		@data['money']
	end
	def stripe_token
		@data['stripe_token']
	end
	def stripe_charge
		@data['stripe_charge']
	end
	def fee
		@data['stripe_fee']
	end
	def fee= fee
		@data['stripe_fee'] = fee
	end
	def id
		@data['id']
	end
	def stripe_charge= stripe_charge
		@data['stripe_charge'] = stripe_charge
	end
	def save!
		Database.update_user_payment! self
	end
end