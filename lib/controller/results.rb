get '/results.html', :auth => :user do
	results = @current_user.all_communications
	@reminders = results.group_by { |x| x["reminder_id"] }.map do |reminder_id, messages|
		{
	        text: messages[0]["message"],
	        id: reminder_id,
	        replies: messages.map do |message|
        		{
        			date: message["scheduled"],
        			reply: unless message["server_received"].nil? 
        				{
	        				text: message["received_body"],
	        				time: message["server_received"]
	        			}
		        	end
		        }
	        end
	    }
    end
    erb :results
end

get %r{/results(?:|/all)$}, :auth => :user do
	@lines = @current_user.all_communications
	content_type :txt
	erb :csvResults, :layout => false
end

get '/results/:id', :auth => :user do |id|
	@lines = @current_user.all_communications.find_all { |line| line["reminder_id"] == id}
	content_type :txt
	erb :csvResults, :layout => false
end