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

viewmodel = new ViewModel

status = ["Accepted", "In progress", "Needs response"]
statusCSS = ["secondary", "success", "alert"]

ticketIterator = (ticket) -> 
	ticket.friendlyDate = ko.observable( moment(+ticket.modified).fromNow() or null )
	ticket.friendlyStatus = status[ +ticket.status ] or null
	ticket.friendlyStatusCSS = statusCSS[ +ticket.status ] or null
	return ticket

# initial ticket get
getMessages = ->
	# get tickets via socket.io
	socket.emit 'getMessages', urlvars.id, (err, ticket, messages) ->
		if err
			console.log err
		else
			viewmodel.ticket ticketIterator(ticket)
			viewmodel.messages(messages)
			console.log messages
			ko.applyBindings viewmodel

## once all code loaded, get to work!
$(document).ready ->
	# get user data
	$.ajax(url: "/node/getuser").done (userdata) ->
		unless userdata
			# not logged in, redirect to login
			window.location.replace "/node/google"
		else
			viewmodel.user(userdata)
			getUrlVars()
			# check we have an id
			if urlvars?.id
				getMessages()
