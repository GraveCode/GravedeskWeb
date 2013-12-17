viewmodel =
	logout: () ->
		window.open "https://accounts.google.com/logout"
		window.location.replace "/login/"


## once all code loaded, get to work!
$(document).ready ->
	ko.applyBindings viewmodel
			