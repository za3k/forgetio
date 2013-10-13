get %r{/(?:|home.html|index.html?)$} do
	erb :home, :locals => { :login => (partial_erb :login) }
end