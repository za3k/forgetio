jQuery ->
    $(".save").click ->
      try
        json = {reminders:[]}
        $(this).parents(".reminder").each ->
            reminder = {times:[]}
            $(".time", this).each ->
                time = {days:[]}
                time.frequency = $(".frequency", this).get(0).value
                time.start = $(".start-time", this).get(0).value
                time.end = $(".end-time", this).get(0).value
                $(".day > :checkbox", this).each ->
                    if this.checked
                        time.days.push(this.name)
                reminder.times.push(time)
            reminder.message = $(".message", this).get(0).value
            reminder.phone = $(".phone", this).get(0).value
            $(".id", this).each ->
                reminder.id = this.value
            $(".version", this).each ->
                reminder.version = this.value
            json.reminders.push(reminder)
        console.log(json)
        $(this).parents("form").find(".output").val(JSON.stringify(json))
        false
      catch error
        alert("Oops, an error has occured. Please let the admin know. The error was: " + error)
        false
    $(".send-checkbox").click ->
      if this.checked
        $(this).parents(".time").find(".checkbox-toggles").removeClass("muted")
      else
        $(this).parents(".time").find(".checkbox-toggles").addClass("muted")
