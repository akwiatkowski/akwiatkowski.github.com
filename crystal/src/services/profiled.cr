require "./profiler"

module Profiled
  macro included
    macro finished
      \{% for method in @type.methods %}
        \{% ann = method.annotation(::Profile) %}
        \{% if ann %}
          \{% vis = method.visibility.stringify == ":private" ? "private ".id : "".id %}
\{{ vis }}def \{{ method.name }}(\{{ method.args.splat }})
  if Profiler.enabled?
    __start = Time.instant
    __result = previous_def
    __elapsed = (Time.instant - __start).total_milliseconds
    Profiler.record(\{{ ann[:category] || "general" }}, \{{ method.name.stringify }}, __elapsed)
    __result
  else
    previous_def
  end
end
        \{% end %}
      \{% end %}
    end
  end
end
