## Global utilities

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
	# stop IE caching userdata query
	jQuery.ajaxSetup { cache: false }
			
	$(document).foundation()
	# set moment library to british english
	moment.lang "en-gb",
		months: "January_February_March_April_May_June_July_August_September_October_November_December".split("_")
		monthsShort: "Jan_Feb_Mar_Apr_May_Jun_Jul_Aug_Sep_Oct_Nov_Dec".split("_")
		weekdays: "Sunday_Monday_Tuesday_Wednesday_Thursday_Friday_Saturday".split("_")
		weekdaysShort: "Sun_Mon_Tue_Wed_Thu_Fri_Sat".split("_")
		weekdaysMin: "Su_Mo_Tu_We_Th_Fr_Sa".split("_")
		longDateFormat:
			LT: "HH:mm"
			L: "DD/MM/YYYY"
			LL: "Do MMMM YYYY"
			LLL: "Do MMMM YYYY LT"
			LLLL: "dddd, Do MMMM YYYY LT"
	
		calendar:
			sameDay: "[Today at] LT"
			nextDay: "[Tomorrow at] LT"
			nextWeek: "dddd [at] LT"
			lastDay: "[Yesterday at] LT"
			lastWeek: "[Last] dddd [at] LT"
			sameElse: "L"
	
		relativeTime:
			future: "in %s"
			past: "%s ago"
			s: "a few seconds"
			m: "a minute"
			mm: "%d minutes"
			h: "an hour"
			hh: "%d hours"
			d: "a day"
			dd: "%d days"
			M: "a month"
			MM: "%d months"
			y: "a year"
			yy: "%d years"
	
		ordinal: (number) ->
			b = number % 10
			output = (if (~~(number % 100 / 10) is 1) then "th" else (if (b is 1) then "st" else (if (b is 2) then "nd" else (if (b is 3) then "rd" else "th"))))
			number + output
	
		week:
			dow: 1 # Monday is the first day of the week.
			doy: 4 # The week that contains Jan 4th is the first week of the year.

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
		# IE suffers transient connection errors that don't actually break the connection, so just log instead of reconnecting
		console.log 'error emitted from socket ', e 
	)



