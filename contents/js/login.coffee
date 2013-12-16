viewmodel =
	showProgress: ko.observable(false)
	login: () ->
		@showProgress(true)
		window.location.replace "/node/google"


## once all code loaded, get to work!
$(document).ready ->

	# get user data
	$.ajax(url: "/node/getuser").done (userdata) ->
		if userdata
			# already logged in with a google account; kick to next stage
			window.location.replace "/node/google/"
		else
			ko.applyBindings viewmodel
			