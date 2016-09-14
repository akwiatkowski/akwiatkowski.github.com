---
layout: post
title: "Tagi"
subtitle: "lista wszystkich tagów"
permalink: /tags/
header-ext-img: https://drscdn.500px.org/photo/108958627/m%3D2048/11298784dfc9b54b1c430165add677d9
---

Tagi
----

<ul>
{% for tag in site.data.tags %}
  <li>
    <a href="/tag/{{tag.slug}}">
      <strong>
        {{ tag.name }}
      </strong>
    </a><br>
  </li>
{% endfor %}
</ul>
