
$(document).ready ->

	# define the viewmodel object
	ViewModel = ko.validatedObservable(
		priorityOptions: ko.observableArray(gd.priority)
		priority: ko.observable(gd.priority[1])
		isAdmin: ko.observable false
		alert: ko.observable null
		success: ko.observable false
		email: ko.observable('').extend { email: true, required: true }
		name: ko.observable('')
		subject: ko.observable('').extend { required: true } 
		team: ko.observable('')
		description: ko.observable('').extend { required: true }

		addTicket: (formElement) ->
			self = @
			form = 
				email: @email()
				name: @name() 
				subject: @subject()
				team: @team()
				priority: gd.priority.indexOf @priority()
				description: @description()

			ViewModel().alert "Adding ticket..."
			socket.emit 'addTicket', form, (err, msg) ->
				if err
					ViewModel().alert err
					ViewModel().success false
				else
					ViewModel().alert msg 
					ViewModel().success true
					ViewModel().subject ''
					ViewModel().subject.isModified false
					ViewModel().description ''
					ViewModel().description.isModified false
					
					if !self.isAdmin() 
						setTimeout ( ->
							window.location.replace "/"
						), 2000
	)

	# check if we're logged in or not, get user data
	async.series([
		(callback) ->
			$.ajax(url: "/node/getuser").done (userdata) ->
				unless userdata
					window.location.replace "/login/"
				else
					callback null, userdata

		, (callback) ->
			socket.emit 'isAdmin', callback

	], (err, results)->
		ViewModel().email results[0].emails[0].value
		ViewModel().name results[0].displayName
		ViewModel().isAdmin results[1] 
		ko.applyBindings ViewModel
	)




