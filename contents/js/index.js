// Generated by CoffeeScript 1.6.3
(function() {
  var ViewModel, getTickets, mapping, status, statusCSS, updateDates, user;

  user = {};

  ViewModel = {};

  status = ["Accepted", "In progress", "Needs response"];

  statusCSS = ["secondary", "success", "alert"];

  mapping = {
    'open': {
      create: function(options) {
        var date, statusCSStext, statustext;
        date = moment(+options.data.value.modified).fromNow() || null;
        options.data.value.friendlyDate = ko.observable(date);
        statustext = status[+options.data.value.status] || null;
        options.data.value.friendlyStatus = statustext;
        statusCSStext = statusCSS[+options.data.value.status] || null;
        options.data.value.statusCSS = statusCSStext;
        return options.data;
      }
    },
    'closed': {
      create: function(options) {
        var date;
        date = moment(+options.data.value.modified).format('Do MMMM YYYY');
        options.data.value.friendlyDate = date;
        return options.data;
      }
    }
  };

  getTickets = function() {
    return socket.emit('getMyTickets', user.emails[0].value, function(err, open, closed) {
      var model;
      if (err) {
        return console.log(err);
      } else {
        model = {
          open: open,
          closed: closed
        };
        ViewModel = ko.mapping.fromJS(model, mapping);
        ViewModel.displayname = 'Tickets from ' + user.displayName;
        return ko.applyBindings(ViewModel);
      }
    });
  };

  updateDates = function() {
    var iterator;
    iterator = function(item, callback) {
      var date;
      date = moment(+item.value.modified).fromNow();
      item.value.friendlyDate(date);
      return callback(null);
    };
    return async.each(ViewModel.open(), iterator, function(err) {
      if (err) {
        return console.log(err);
      }
    });
  };

  $(document).ready(function() {
    return $.ajax({
      url: "/node/getuser"
    }).done(function(userdata) {
      if (!userdata) {
        return window.location.replace("/node/google");
      } else {
        user = userdata;
        getTickets();
        return window.setInterval(function() {
          return updateDates();
        }, 1000 * 30);
      }
    });
  });

}).call(this);
