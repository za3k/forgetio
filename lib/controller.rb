require 'login.rb'
require 'controller/account.rb'
require 'controller/home.rb'
require 'controller/login.rb'
require 'controller/payment.rb'
require 'controller/results.rb'
require 'controller/scheduled.rb'
require 'controller/signup.rb'

helpers do
	alias_method :raw_erb, :erb

	def partial_erb(page, options={})
		raw_erb page, (options.merge :layout => false)
	end

	def erb(page, options={})
		@page = page
		extra_options = {
			:layout_options => {
				:locals => {
					:navbar => (partial_erb :navbar, :locals => { :page => page})
				}
			}
		}
		raw_erb page, (options.merge extra_options)
	end
end

get '/users', :auth => :admin do
	stream do |out|
		Database.all_users.each do |user|
			out << user.to_s
			out << "\n"
		end
	end
end