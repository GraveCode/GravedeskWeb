
$(document).ready ->

	ko.bindingHandlers.fadeVisible =
		update: (element, valueAccessor) ->
			# Whenever the value subsequently changes, slowly fade the element in or out
			value = valueAccessor()
			(if ko.utils.unwrapObservable(value) then $(element).fadeIn() else $(element).fadeOut())

	# define the viewmodel object
	ViewModel = ko.validatedObservable(
		isAdmin: ko.observable false
		alert: ko.observable null
		success: ko.observable true
		from: ko.observable('').extend { email: true, required: true }
		subject: ko.observable('').extend { required: true } 
		team: ko.observable('')
		description: ko.observable('').extend { required: true }
		addTicket: (formElement) ->
			form = 
				from: @from()
				subject: @subject()
				team: @team()
				description: @description()
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
					
					setTimeout ( ->
						ViewModel().alert null
					), 3000
	)

	# check if we're logged in or not, get user data
	async.series([
		(callback) ->
			$.ajax(url: "/node/getuser").done (userdata) ->
				unless userdata
					window.location.replace "/node/google"
				else
					callback null, userdata

		, (callback) ->
			socket.emit 'isAdmin', (res) ->
				callback null, res

	], (err, results)->
		ViewModel().from results[0].emails[0].value
		ViewModel().isAdmin results[1] 
		ko.applyBindings ViewModel
	)




