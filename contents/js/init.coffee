## Global variables

# viewmodel display strings
window.gd = 
  adminstatus: ["New message", "Note added", "Waiting on user", "Awaiting 3rd party"]
  adminstatusCSS: ["alert", "success", "secondary", "secondary"]
  userstatus:["Recorded", "In progress", "Reply added", "Awaiting 3rd party"]
  userstatusCSS: ["secondary", "success", "alert", "secondary"]
  priority: ["Low", "Normal", "High"]
  priorityCSS: ["", "secondary", "alert"]
  groups: ["IT Support", "Network & Systems", "Long term"]


ko.bindingHandlers.fadeVisible =
	update: (element, valueAccessor) ->
		# Whenever the value subsequently changes, slowly fade the element in or out
		value = valueAccessor()
		if ko.utils.unwrapObservable(value) then $(element).fadeIn() else $(element).fadeOut()

ko.extenders.liveEditor = (target) ->
  target.editing = ko.observable(false)
  target.edit = ->
    target.editing true
  target.stopEditing = ->
    target.editing false
  return target

ko.bindingHandlers.liveEditor =
  init: (element, valueAccessor) ->
    observable = valueAccessor()
    observable.extend liveEditor: this

  update: (element, valueAccessor) ->
    observable = valueAccessor()
    ko.bindingHandlers.css.update element, ->
      editing: observable.editing


# a custom binding to handle the enter key (could go in a separate library)
ENTER_KEY = 13

ko.bindingHandlers.enterKey = init: (element, valueAccessor, allBindingsAccessor, data) ->
  wrappedHandler = undefined
  newValueAccessor = undefined
  
  # wrap the handler with a check for the enter key
  wrappedHandler = (data, event) ->
    valueAccessor().call this, data, event  if event.keyCode is ENTER_KEY

  # create a valueAccessor with the options that we would want to pass to the event binding
  newValueAccessor = ->
    keyup: wrappedHandler

  # call the real event binding's init function
  ko.bindingHandlers.event.init element, newValueAccessor, allBindingsAccessor, data


# wrapper to hasfocus that also selects text and applies focus async
ko.bindingHandlers.selectAndFocus =
  init: (element, valueAccessor, allBindingsAccessor) ->
    ko.bindingHandlers.hasfocus.init element, valueAccessor, allBindingsAccessor
    ko.utils.registerEventHandler element, "focus", ->
      element.focus()

  update: (element, valueAccessor) ->
    ko.utils.unwrapObservable valueAccessor() # for dependency
    # ensure that element is visible before trying to focus
    setTimeout (->
      ko.bindingHandlers.hasfocus.update element, valueAccessor
    ), 0

## socket.io handler
$(document).ready ->
      
  $(document).foundation()

	if io?
		window.socket = io.connect(location.host,
			resource: "node/socket.io"
		)
	else
		# socket.io not available, server down
		window.location.replace "/serverdown/"	

	socket.on('connect_failed', () -> 
		window.location.replace "/serverdown/"	
	)

	socket.on('reconnect_failed', () -> 
		window.location.replace "/serverdown/"	
	)

	socket.on('error', (e) -> 
		console.log 'error emitted from socket ', e 
		window.location.replace "/login/"	
	)



