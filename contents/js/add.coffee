
$(document).ready ->

	socket = io.connect(location.host,
		resource: "node/socket.io"
	)

	# define the viewmodel object
	ViewModel =
		subject: ko.observable()
		team: ko.observable()
		description: ko.observable()
		from: ko.observable()
		addTicket: (formElement) ->
			console.log @from()
			console.log @subject()
			console.log @team()
			console.log @description()


	# check if we're logged in or not
	$.ajax(url: "/node/getuser").done (userdata) ->
		unless userdata
			window.location.replace "/node/google"
		else
			ko.applyBindings ViewModel
			ViewModel.from(userdata.emails[0].value)




