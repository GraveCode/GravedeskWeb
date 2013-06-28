# defined variables

user = {}
ViewModel = {}
mapping = 
	'open': 
		create: (options) ->
			date = moment(+options.data.value.modified).fromNow()
			options.data.value.friendlyDate = ko.observable(date)
			return options.data
	'closed': 
		create: (options) ->
			date = moment(+options.data.value.modified).format('Do MMMM YYYY')
			options.data.value.friendlyDate = date
			return options.data


# initial ticket get
getTickets = ->
	# get tickets via socket.io
	socket.emit 'getMyTickets', user.emails[0].value, (err, open, closed) ->
		if err
			console.log err
		else
			model = 
				open: open
				closed: closed
			
			ViewModel = ko.mapping.fromJS(model, mapping)
			ViewModel.displayname = 'Tickets from ' + user.displayName
			ko.applyBindings ViewModel

# update friendlyDates in viewmodel
updateDates = ->
	iterator = (item, callback) ->
		date = moment(+item.value.modified).fromNow()
		item.value.friendlyDate(date)
		callback null

	async.each ViewModel.open(), iterator, (err) ->
		if err
			console.log err

$(document).ready ->

	# get user data
	$.ajax(url: "/node/getuser").done (userdata) ->
		unless userdata
			# not logged in
			window.location.replace "/node/google"
		else
			user = userdata
			getTickets()
			# update friendly date every 30 seconds
			window.setInterval ->
				updateDates()
			, (1000*30)

