# define the viewmodel object
viewmodel = ko.validatedObservable(
	priorityOptions: ko.observableArray()
	priority: ko.observable()
	groupOptions: ko.observableArray()
	group: ko.observable()
	isAdmin: ko.observable false
	isTech: ko.observable false
	alert: ko.observable null
	success: ko.observable false
	email: ko.observable('').extend { email: true, required: true }
	name: ko.observable('')
	subject: ko.observable('').extend { required: true } 
	description: ko.observable('').extend { required: true }

	setGroup: (entry) ->
		viewmodel().group entry
		$('button[data-dropdown="group"]').trigger('click')

	setPriority: (entry) ->
		viewmodel().priority entry
		$('button[data-dropdown="priority"]').trigger('click')		

	addTicket: (formElement) ->
		self = @
		index = @groupOptions().indexOf @group()
		form = 
			email: @email()
			name: @name() 
			subject: @subject()
			team: index
			priority: @priorityOptions().indexOf @priority()
			description: @description()

		if index == 0
			form.personal = @email()
		else
			form.personal = null

		viewmodel().alert "Adding ticket..."
		socket.emit 'addTicket', form, (err, msg) ->
			if err
				viewmodel().alert err
				viewmodel().success false
			else
				viewmodel().alert msg 
				viewmodel().success true
				viewmodel().subject ''
				viewmodel().subject.isModified false
				viewmodel().description ''
				viewmodel().description.isModified false
				
				if !self.isAdmin() 
					setTimeout ( ->
						window.location.replace "/"
					), 2000
				else
					setTimeout ( ->
						viewmodel().alert null
					), 2000
)

## once all code loaded, get to work!
$(document).ready ->
	async.series {
		userdata: (callback) ->
			$.ajax(url: "/node/getuser").done (data) ->
				unless data
					# not logged in, redirect to login
					window.location.replace "/login/"
				else
					callback null, data					

		statics: (callback) ->
			socket.emit 'getStatics', callback
							
	}, (err, results) ->
		if err
			# unable to confirm if admin or get setup data
			console.log "Startup failed."
			viewmodel.alert "Startup failed."
		else
			# populate viewmodel with static data
			viewmodel().email results.userdata.emails[0].value
			viewmodel().name results.userdata.displayName
			viewmodel().isAdmin results.statics.isAdmin
			viewmodel().isTech results.statics.isTech
			viewmodel().priorityOptions results.statics.statuses.priority
			viewmodel().groupOptions results.statics.groups
			viewmodel().priority results.statics.statuses.priority[1]
			viewmodel().group results.statics.groups[1]
			ko.applyBindings viewmodel
			console.log viewmodel()





