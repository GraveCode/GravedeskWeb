## defined variables and functions


status = ["Recorded", "In progress", "Needs response", "Awaiting 3rd party"]
statusCSS = ["secondary", "success", "alert", "secondary"]


urlvars = {}

getUrlVars = ->
	window.location.href.replace(/[?&]+([^=&]+)=([^&]*)/g, (m, key, value) ->
		urlvars[key] = value
	)

class ViewModel
	constructor: ->
		@alert = ko.observable()
		@user = ko.observable() 
		@ticket = ko.observable()
		@messages = ko.observableArray()
		@isAdmin = ko.observable()
		@userMsg = ko.observable()
		@adminMsg = ko.observable()
		@adminMsgPrivate = ko.observable(true)

	addAdminMsg: ->
		self = @
		timestamp = Date.now()
		names = @ticket().names
		names[@user().emails[0].value] = @user().displayName
		message =
				type: 'message'
				date: timestamp
				from: @user().emails[0].value
				recipients: @ticket().recipients
				names: names
				private: @adminMsgPrivate()
				text: @adminMsg()
				fromuser: false
				ticketid: @ticket()._id

		socket.emit 'addMessage', message, (err, changedMessage, changedTicket) ->
			if err 
				console.log err
				self.alert err
				setTimeout ( ->
					viewmodel.alert null
				), 5000
			else
				self.adminMsg(null)
				self.adminMsgPrivate(true)
				messageIterator changedMessage, (err, result) ->
					self.messages.push result	
				viewmodel.ticket ticketIterator(changedTicket) 


viewmodel = new ViewModel

ticketIterator = (ticket) -> 
	ticket.friendlyDate = ko.observable( moment(+ticket.modified).fromNow() or null )
	ticket.friendlyStatus = status[ +ticket.status ] or null
	ticket.friendlyStatusCSS = statusCSS[ +ticket.status ] or null
	return ticket

messageIterator = (message, callback) ->
	message.friendlyDate = ko.observable( moment(+message.date).fromNow() or null )
	message.displayName = message.names[message.from] or message.from
	message.Colour = ko.computed( ->
		if message.fromuser
			return "fromuser"
		else if message.private
			return "private"
		else
			return "fromadmin"
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

	socket.on('messageAdded', (id, message) ->
		# check if message is relevent to me
		if id is viewmodel.ticket()._id
			messageIterator message, (err, result) ->
				viewmodel.messages.push result
	)

	socket.on('ticketUpdated', (id, ticket) ->
		# check if ticket is relevent to me
		if id is viewmodel.ticket()._id
			viewmodel.ticket ticketIterator(ticket) 

	)
