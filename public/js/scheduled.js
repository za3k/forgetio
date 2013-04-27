(function() {

  jQuery(function() {
    $(".save").click(function() {
      var json;
      try {
        json = {
          reminders: []
        };
        $(this).parents(".reminder").each(function() {
          var reminder;
          reminder = {
            times: []
          };
          $(".time", this).each(function() {
            var time;
            time = {
              days: []
            };
            time.frequency = $(".frequency", this).get(0).value;
            time.start = $(".start-time", this).get(0).value;
            time.end = $(".end-time", this).get(0).value;
            $(".day > :checkbox", this).each(function() {
              if (this.checked) {
                return time.days.push(this.name);
              }
            });
            return reminder.times.push(time);
          });
          reminder.message = $(".message", this).get(0).value;
          reminder.phone = $(".phone", this).get(0).value;
          $(".id", this).each(function() {
            return reminder.id = this.value;
          });
          $(".version", this).each(function() {
            return reminder.version = this.value;
          });
          return json.reminders.push(reminder);
        });
        console.log(json);
        return $(this).parents("form").find(".output").val(JSON.stringify(json));
      } catch (error) {
        alert("Oops, an error has occured. Please let the admin know. The error was: " + error);
        return false;
      }
    });
    return $(".send-checkbox").click(function() {
      if (this.checked) {
        return $(this).parents(".time").find(".checkbox-toggles").removeClass("muted");
      } else {
        return $(this).parents(".time").find(".checkbox-toggles").addClass("muted");
      }
    });
  });

}).call(this);
