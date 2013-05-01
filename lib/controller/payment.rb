helpers do
	def stripe_payment_key
		if settings.development?
	   		"pk_test_0vJgMvmOAjwiSDQQ8X2XP4Ky"
	  	elsif settings.test? or settings.production?
	    	"pk_live_YHP6pm3l1Ub76WbOyhJASvU0"
	    else
	    	raise "environment not found"
	  	end
	end

	def payment_page
		@stripe_payment_key = stripe_payment_key
		@text_messages_per_credit = 1
		partial_erb :payment
	end
end

post '/payment.html', :auth => :user do
	"TODO"
end