require 'stripe'

before do
	Stripe.api_key = secret_key
end

helpers do
	def publishable_key
		if settings.development?
	   		"pk_test_0vJgMvmOAjwiSDQQ8X2XP4Ky"
	  	elsif settings.test? or settings.production?
	    	"pk_live_YHP6pm3l1Ub76WbOyhJASvU0"
	    else
	    	raise "environment not found"
	  	end
	end

	def secret_key
		if settings.development?
            settings.twilio_development_secret_key
	  	elsif settings.test? or settings.production?
            settings.twilio_production_secret_key
	    else
	    	raise "environment not found"
	  	end
	end

	def payment_page
		@stripe_publishable_key = publishable_key
		@text_messages_per_credit = 1
		partial_erb :payment
	end
end

post '/payment.html', :auth => :user do
	def fail errorMsg
		account :errorMsg => errorMsg
	end

	def success successMsg
		account :successMsg => successMsg
	end

	stripeToken = params["stripeToken"]
	unless stripeToken and not stripeToken.empty?
		puts 'Stripe token missing on payment form' 
		return fail "Payment information missing."
	end
	credits = params["credits"].to_i
	unless credits and credits >= 50 and credits <= 100000
		puts 'Credits were invalid'
		return fail "There was a server error with the form submission."
	end
	money = credits * 2
	userPayment = Database.create_user_payment! credits, money, stripeToken

	begin
		charge = Stripe::Charge.create(
		    :amount      => money,
		    :currency    => 'usd',
		    :card 	     => stripeToken,
		    :description => "Buying #{credits.to_s} for account: #{@current_user.email}"
	  	)
	rescue Stripe::CardError => e
	  # A decline
	  body = e.json_body
	  err  = body[:error]

	  puts "Status is: #{e.http_status}"
	  puts "Type is: #{err[:type]}"
	  puts "Code is: #{err[:code]}"
	  # param is '' in this case
	  puts "Param is: #{err[:param]}"
	  puts "Message is: #{err[:message]}"
	  return fail err[:message]
	rescue Stripe::InvalidRequestError => e
	  puts "Bad request"
	  puts e.message
	  puts e.json_body[:message]
	  return fail "There was a server error with the form submission."
	rescue Stripe::AuthenticationError => e
	  puts "Bad API key"
	  puts e.message
	  return fail "There was a server error with the form submission."
	rescue Stripe::APIConnectionError => e
	  puts e.json_body[:message]
	  return fail "There was an intermittent problem talking to Stripe.  Please try again in a couple minutes."
	rescue Stripe::StripeError => e
	  puts e.json_body[:message]
	  return fail "There was a server error with the form submission."
	end

	unless charge.paid==true
		return fail "Payment on this credit card was declined for the given amount"
	end

	fee = charge.fee
	id = charge.id

	@current_user.credit += credits
	@current_user.save!

	userPayment.fee = fee
	userPayment.stripe_charge = id
	userPayment.save!
	return success "#{credits} credits were successfully added to your account. Thank you for keeping forget.io running!"
end
