struct Time
  POLISH_NAMES = [
    "",
    "poniedziałek",
    "wtorek",
    "środa",
    "czwartek",
    "piątek",
    "sobota",
    "niedziela",
  ]

  def day_of_week_polish
    POLISH_NAMES[self.day_of_week.value]
  end
end
