// Generated by CoffeeScript 1.6.3
(function() {
  var ViewModel, getTickets, mapping, updateDates, user;

  user = {};

  ViewModel = {};

  mapping = {
    'open': {
      create: function(options) {
        var date;
        date = moment(+options.data.value.modified).fromNow();
        options.data.value.friendlyDate = ko.observable(date);
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
