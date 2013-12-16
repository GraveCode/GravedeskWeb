## once all code loaded, get to work!
$(document).ready ->
	cookieID = $.cookie 'ticketID'
	# came from a specific ticket with an ID prior to login
	if cookieID
		window.location.replace "/messages/?id=" + cookieID
	else
		window.location.replace "/"