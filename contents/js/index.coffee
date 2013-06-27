$(document).ready ->

	ViewModel = 
		tickets: ko.observableArray()

	# check if we're logged in or not, get user data
	async.waterfall([
		(callback) ->
			# get user account data
			$.ajax(url: "/node/getuser").done (userdata) ->
				unless userdata
					window.location.replace "/node/google"
				else
					callback null, userdata

		, (userdata, callback) ->
			# get tickets via socket.io
			usermail = userdata.emails[0].value
			socket.emit 'getMyTickets', usermail, callback

		, (results, callback) ->
			# clean up results
			iterator = (item,cb) ->
				item.value.moment = moment(item.value.modified).fromNow()
				cb null, item.value

			async.map results, iterator, callback

		, (tickets, callback) ->
			ViewModel.tickets tickets
			ko.applyBindings ViewModel
	])