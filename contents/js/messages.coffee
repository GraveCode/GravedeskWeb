## defined variables and functions

urlvars = {}

getUrlVars = ->
	window.location.href.replace(/[?&]+([^=&]+)=([^&]*)/g, (m, key, value) ->
		urlvars[key] = value
	)

class ViewModel
	constructor: ->
		@user = ko.observable() 
		@ticket = ko.observable()
		@messages = ko.observableArray()
		@user = ko.observable()
		@isAdmin = ko.observable()

viewmodel = new ViewModel

status = ["Accepted", "In progress", "Needs response"]
statusCSS = ["secondary", "success", "alert"]

ticketIterator = (ticket) -> 
	ticket.friendlyDate = ko.observable( moment(+ticket.modified).fromNow() or null )
	ticket.friendlyStatus = status[ +ticket.status ] or null
	ticket.friendlyStatusCSS = statusCSS[ +ticket.status ] or null
	return ticket

messageIterator = (message, callback) ->
	message.friendlyDate = ko.observable( moment(+message.date).fromNow() or null )
	message.Colour = ko.computed( ->
		if message.fromuser
			return "fromuser"
		else if message.private
			return "private"
		else
			return "fromsupport"
	)
	callback null, message


# initial ticket get
getMessages = ->
	async.waterfall([
		(cb) ->
			# get tickets via socket.io
			socket.emit 'getMessages', urlvars.id, cb

		, (ticket, messages, cb) ->
			# add knockout data to ticket, then add to view
			viewmodel.ticket ticketIterator(ticket)
			# add knockout data to messages array
			async.map messages, messageIterator, cb
			cb null, messages

		, (messages, cb) ->
			# replace messages in view
			viewmodel.messages messages	
			cb null

	], (err,results) ->
		console.log err if err
	)

## once all code loaded, get to work!
$(document).ready ->
	async.series([
			(cb) ->
				$.ajax(url: "/node/getuser").done (userdata) ->
					unless userdata
						window.location.replace "/node/google"
					else
						cb null, userdata
	
			, (cb) ->
				socket.emit 'isAdmin', (res) ->
					cb null, res

	], (err, results) ->
		viewmodel.user results[0]
		viewmodel.isAdmin results[1]
		getUrlVars()
		# check we have an id
		if urlvars?.id
			getMessages()
			ko.applyBindings viewmodel
	)

