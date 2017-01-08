// Generated by CoffeeScript 1.10.0
var bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

this.TodoRoute = (function() {
  function TodoRoute() {
    this.loadRoutes = bind(this.loadRoutes, this);
    this.executeFilter = bind(this.executeFilter, this);
    this.route_destination = [];
  }

  TodoRoute.prototype.start = function() {
    return $.ajax({
      url: "/payload.json",
      success: (function(_this) {
        return function(data) {
          _this.data = data;
          return _this.loadRoutes();
        };
      })(this)
    });
  };

  TodoRoute.prototype.executeFilter = function() {
    var filter_route_both, filter_route_from, filter_route_less, filter_route_more, filter_route_to, filter_route_total_cost, filter_route_transport_cost;
    $(".todo_route").show();
    filter_route_from = $("#filter-route-from").val();
    filter_route_to = $("#filter-route-to").val();
    filter_route_both = $("#filter-route-both").val();
    filter_route_less = $("#filter-distance-less-than").val();
    filter_route_more = $("#filter-distance-more-than").val();
    filter_route_total_cost = $("#filter-total-cost-less-than").val();
    filter_route_transport_cost = $("#filter-transport-cost-less-than").val();
    if (filter_route_from.length > 1) {
      $(".todo_route").each((function(_this) {
        return function(index, todo_route) {
          if ($(todo_route).data("route-from") !== filter_route_from) {
            return $(todo_route).hide();
          }
        };
      })(this));
    }
    if (filter_route_to.length > 1) {
      $(".todo_route").each((function(_this) {
        return function(index, todo_route) {
          if ($(todo_route).data("route-to") !== filter_route_to) {
            return $(todo_route).hide();
          }
        };
      })(this));
    }
    if (filter_route_both.length > 1) {
      $(".todo_route").each((function(_this) {
        return function(index, todo_route) {
          if (($(todo_route).data("route-to") !== filter_route_both) && ($(todo_route).data("route-from") !== filter_route_both)) {
            return $(todo_route).hide();
          }
        };
      })(this));
    }
    if (filter_route_less.length > 1) {
      $(".todo_route").each((function(_this) {
        return function(index, todo_route) {
          if (parseInt($(todo_route).data("route-distance")) > parseInt(filter_route_less)) {
            return $(todo_route).hide();
          }
        };
      })(this));
    }
    if (filter_route_more.length > 1) {
      $(".todo_route").each((function(_this) {
        return function(index, todo_route) {
          if (parseInt($(todo_route).data("route-distance")) < parseInt(filter_route_more)) {
            return $(todo_route).hide();
          }
        };
      })(this));
    }
    if (filter_route_total_cost.length > 1) {
      $(".todo_route").each((function(_this) {
        return function(index, todo_route) {
          if (parseFloat($(todo_route).data("route-total-cost") * 60.0) > parseFloat(filter_route_total_cost)) {
            return $(todo_route).hide();
          }
        };
      })(this));
    }
    if (filter_route_transport_cost.length > 1) {
      return $(".todo_route").each((function(_this) {
        return function(index, todo_route) {
          var c;
          c = 0;
          if ($(todo_route).data("route-from-cost").length > 1) {
            c += parseFloat($(todo_route).data("route-from-cost"));
          }
          if ($(todo_route).data("route-to-cost").length > 1) {
            c += parseFloat($(todo_route).data("route-to-cost"));
          }
          console.log(c);
          if (c > parseFloat(filter_route_transport_cost)) {
            return $(todo_route).hide();
          }
        };
      })(this));
    }
  };

  TodoRoute.prototype.loadRoutes = function() {
    var i, len, ref, route_element_name;
    $(".todo_route").each((function(_this) {
      return function(index, todo_route) {
        var route_from, route_to;
        route_from = $(todo_route).data("route-from");
        route_to = $(todo_route).data("route-to");
        if (_this.route_destination.indexOf(route_from) < 0) {
          _this.route_destination.push(route_from);
        }
        if (_this.route_destination.indexOf(route_to) < 0) {
          return _this.route_destination.push(route_to);
        }
      };
    })(this));
    this.route_destination = this.route_destination.sort();
    ref = this.route_destination.sort();
    for (i = 0, len = ref.length; i < len; i++) {
      route_element_name = ref[i];
      $("#filter-route-from").append($("<option>", {
        value: route_element_name,
        text: route_element_name
      }));
      $("#filter-route-to").append($("<option>", {
        value: route_element_name,
        text: route_element_name
      }));
      $("#filter-route-both").append($("<option>", {
        value: route_element_name,
        text: route_element_name
      }));
    }
    return $(".route-filter-field").on("change", (function(_this) {
      return function() {
        return _this.executeFilter();
      };
    })(this));
  };

  return TodoRoute;

})();