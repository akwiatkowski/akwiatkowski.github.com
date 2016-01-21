// Generated by CoffeeScript 1.10.0
var bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

Date.prototype.dayOfYear = function() {
  var j1;
  j1 = new Date(this);
  j1.setMonth(0, 0);
  return Math.round((this - j1) / 8.64e7);
};

this.BlogPlanner = (function() {
  function BlogPlanner() {
    this.processPosts = bind(this.processPosts, this);
    this.processLands = bind(this.processLands, this);
  }

  BlogPlanner.prototype.start = function() {
    this.lands_posts = {};
    this.lands = [];
    this.land_outputs = [];
    return $.ajax({
      url: "/payload.json",
      success: (function(_this) {
        return function(data) {
          _this.data = data;
          _this.processLands();
          _this.processPosts();
          return _this.startPlanner();
        };
      })(this)
    });
  };

  BlogPlanner.prototype.processLands = function() {
    var i, land, len, post, ref, results, s;
    ref = this.data["lands"];
    results = [];
    for (i = 0, len = ref.length; i < len; i++) {
      land = ref[i];
      if (land["type"] === "mountain") {
        s = land["slug"];
        if (this.lands_posts[s] === void 0) {
          this.lands.push(land);
          this.lands_posts[s] = [];
        }
        results.push((function() {
          var j, len1, ref1, results1;
          ref1 = this.data["posts"];
          results1 = [];
          for (j = 0, len1 = ref1.length; j < len1; j++) {
            post = ref1[j];
            if (indexOf.call(post["lands"], s) >= 0) {
              results1.push(this.lands_posts[s].push(post));
            } else {
              results1.push(void 0);
            }
          }
          return results1;
        }).call(this));
      } else {
        results.push(void 0);
      }
    }
    return results;
  };

  BlogPlanner.prototype.processPosts = function() {
    var currentDate, date, dayMs, diff, diffDays, h, i, j, k, l, land, len, len1, len2, len3, lo, minPoints, monthMs, months_since, points, post, posts, ref, ref1, ref2, results, s, visit_count, visit_months_since, visit_within_1_months, visit_within_2_months, visit_within_3_months, weekMs, yearMs;
    currentDate = new Date();
    dayMs = 24 * 3600 * 1000;
    monthMs = 30 * dayMs;
    weekMs = 7 * dayMs;
    yearMs = 365 * dayMs;
    ref = this.lands;
    for (i = 0, len = ref.length; i < len; i++) {
      land = ref[i];
      s = land["slug"];
      posts = this.lands_posts[s];
      visit_count = 0;
      visit_within_1_months = 0;
      visit_within_2_months = 0;
      visit_within_3_months = 0;
      visit_months_since = Infinity;
      points = 0;
      for (j = 0, len1 = posts.length; j < len1; j++) {
        post = posts[j];
        visit_count += 1;
        date = new Date(post["date"]);
        diff = date.dayOfYear() - currentDate.dayOfYear();
        diffDays = Math.round(Math.abs((date.getTime() - currentDate.getTime()) / dayMs));
        diff = diffDays % 365;
        if (diff <= 30) {
          visit_within_1_months += 1;
          points -= 6;
        }
        if (diff <= 61) {
          visit_within_2_months += 1;
          points -= 4;
        }
        if (diff <= 91) {
          visit_within_3_months += 1;
          points -= 2;
        }
        months_since = Math.round(diffDays / 30);
        if (months_since < visit_months_since) {
          visit_months_since = months_since;
        }
      }
      points -= visit_count * 2;
      points -= land["train_time_poznan"] * 3;
      if (visit_months_since !== Infinity && visit_months_since !== null && visit_months_since > 0 && visit_months_since <= 100) {
        points += Math.sqrt(visit_months_since);
      } else {
        points += 10.0;
      }
      h = {};
      h["slug"] = s;
      h["name"] = land["name"];
      h["visit_count"] = visit_count;
      h["visit_within_1_months"] = visit_within_1_months;
      h["visit_within_2_months"] = visit_within_2_months;
      h["visit_within_3_months"] = visit_within_3_months;
      if (visit_months_since !== Infinity) {
        h["visit_months_since"] = visit_months_since;
      } else {
        h["visit_months_since"] = null;
      }
      h["access_time"] = land["train_time_poznan"];
      h["points"] = points;
      this.land_outputs.push(h);
    }
    minPoints = 0.0;
    ref1 = this.land_outputs;
    for (k = 0, len2 = ref1.length; k < len2; k++) {
      lo = ref1[k];
      if (minPoints > lo["points"]) {
        minPoints = lo["points"];
      }
    }
    ref2 = this.land_outputs;
    results = [];
    for (l = 0, len3 = ref2.length; l < len3; l++) {
      lo = ref2[l];
      lo["points"] -= minPoints;
      results.push(lo["points"] = Math.round(lo["points"]));
    }
    return results;
  };

  BlogPlanner.prototype.startPlanner = function() {
    var data, i, klass, len, lo, main_object, ref, results, s;
    $("#content").html("");
    main_object = $("<table>", {
      id: "planner-table",
      "class": "planner-table"
    }).appendTo("#content");
    s = "<tr>";
    s += "<th>Nazwa</th>";
    s += "<th>Wizyt [dni]</th>";
    s += "<th>1msc</th>";
    s += "<th>2msc</th>";
    s += "<th>3msc</th>";
    s += "<th>Miesięcy temu</th>";
    s += "<th>Dojazd [h]</th>";
    s += "<th>Punkty</th>";
    s += "</tr>";
    $(s).appendTo(main_object);
    ref = this.land_outputs;
    results = [];
    for (i = 0, len = ref.length; i < len; i++) {
      lo = ref[i];
      s = "<tr>";
      s += "<td>" + lo["name"] + "</td>";
      if (lo["visit_count"] > 10) {
        klass = "planner-visited-often";
      } else if (lo["visit_count"] > 4) {
        klass = "planner-visited-sometime";
      } else if (lo["visit_count"] > 1) {
        klass = "planner-visited-few";
      } else if (lo["visit_count"] === 1) {
        klass = "planner-visited-once";
      } else {
        klass = "planner-unvisited";
      }
      s += "<td class=\"" + klass + "\">" + lo["visit_count"] + "</td>";
      klass = "";
      if (lo["visit_within_1_months"] > 0) {
        klass = "planner-frequent-visit";
      }
      s += "<td class=\"" + klass + "\">" + lo["visit_within_1_months"] + "</td>";
      klass = "";
      if (lo["visit_within_2_months"] > 0) {
        klass = "planner-frequent-visit";
      }
      s += "<td class=\"" + klass + "\">" + lo["visit_within_2_months"] + "</td>";
      klass = "";
      if (lo["visit_within_3_months"] > 0) {
        klass = "planner-frequent-visit";
      }
      s += "<td class=\"" + klass + "\">" + lo["visit_within_3_months"] + "</td>";
      klass = "";
      if (lo["visit_months_since"] > 24) {
        klass = "planner-last-visit-long-ago";
      } else if (lo["visit_months_since"] > 12) {
        klass = "planner-last-visit-year-ago";
      } else if (lo["visit_months_since"] > 6) {
        klass = "planner-last-visit-half-year";
      } else {
        klass = "planner-last-visit-near";
      }
      data = lo["visit_months_since"];
      if (data === null) {
        data = "";
        klass = "planner-last-visit-long-ago";
      }
      s += "<td class=\"" + klass + "\">" + data + "</td>";
      klass = "planner-access-time-10-or-more";
      data = parseInt(lo["access_time"]);
      if (data < 10) {
        klass = "planner-access-time-" + data;
      }
      if (lo["access_time"] === "") {
        data = "";
        klass = "";
      }
      s += "<td class=\"" + klass + "\">" + data + "</td>";
      klass = "";
      s += "<td class=\"" + klass + "\">" + lo["points"] + "</td>";
      s += "</tr>";
      results.push($(s).appendTo(main_object));
    }
    return results;
  };

  return BlogPlanner;

})();