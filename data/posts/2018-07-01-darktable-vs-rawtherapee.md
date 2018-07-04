---
layout:                 post
title:                  "Darktable vs Rawtherapee"
subtitle:               "porównanie programów do przetwarzania raw'ów"
desc:                   ""
keywords:               [raw, linux, debian]
date:                   2018-07-01 20:00:00
#finished_at:            2100-02-09 12:00:00
author:                 "Aleksander Kwiatkowski"
categories:             article
image_filename:         P6240189_dark1.jpg.jpg
tags:                   [article, todo]
towns:                  []

---


## Wstęp

Przez dłuższy czas korzystałem z `rawtherapee`. Wydaję mi się, że jestem juz w nim
dość doświadczony. W tym momencie odkrywam `darktable` i ten artykuł będzie
bardziej poświęcony na to, co w nim bardzo fajnie zrobili.

Artykuł nie zamierzam oznaczać jako gotowy do momentu osiągnięcia biegłości w
`darktable`.
Postaram się później wrócić do `rawtherapee` i napisać, że nie jest ono wyraźnie gorsze.

Będzie on wyraźnie subiektywny, bazując bardziej na wrażeniach z pracy niż na konkretnych
porównaniach funkcji.

## TL;DR

`darktable` przypomina bardziej Lighrooma, opiera się na określonym sposobie
pracy (który w tym momencie jeszcze odkrywam). Koncentruje się nad rezultatami

`rawtherapee` jest bardziej surowy, "nieludzki", daje pełniejszą kontrolę
gdyż koncentruje się nad parametrami.

W `rawtherapee` zda

## Darktable

TODO czy można dodać na listę?

## Zmiana parametrów

`darktable` korzysta ze specjalnej kontrolki do zmiany parametrów
zmiennoprzecinkowych. Umożliwia to dokładniejsze ustawienie niż korzystanie z
suwaka.

TODO nie można wpisać ręcznie?

## Usuwanie szumu

[profiled-denoise]: https://www.darktable.org/usermanual/en/correction_group.html#denoise_profiled

Jest wiele modułów do usuwania szumu w zależności od momentu przetwarzania
jak i doświadczenia. Podstawowym jest "[profiled denoise][profiled-denoise]"
który dobiera parametry na podstawie aparatu i ISO.
Jest to najłatwiejsze rozwiązanie

Zauważyłem że usuwając szumy usuwa również pewne detale.
Zawsze starałem się wyciągnać maksimum szczegółów ale spróbuję teraz
przerabiając RAWy skoncentrować się na ogólnym wrażeniu zdjęcia a niekoniecznie
na ilościach detali.

XXX rawtherapee ma chyba tylko jedno miejsce?

### Korekcja geometri

TODO czy można użyć linii?
XXX Jest automatyczne narzędzie które wykrywa i zrównuje zakrzywienia (keystone)
TODO jak uwzględnić jego wynik bo jak zmienie na inny moduł to resetuje?

[perspective_correction]: https://www.darktable.org/usermanual/en/correction_group.html#perspective_correction

### Korekcta obiektywu

Istnieje biblioteka `lensfun`, która zajmuje się korekcją niedoskonałości
obiektywów. W przypadku systemu Pentaksa nie było to takim dużym problemem.
Dystorsja była "pod kontrolą" i nawet sie tym nie przejmowałem.

System M43 zakłada istnienie dystorsji, która będzie następnie programowo poprawiana.
W przypadku Olympusa 9-18mm dystorsja ta jest niejednorodna i rezultaty korekcji
(np. morza) nie były dobre.

Zauważyłem, że brakowało mi `lensfun` w systemie. Zainstalowałem ją
przez `apt-get install liblensfun-bin liblensfun-data-v1 liblensfun1` a następnie
należa zaktualizować `lensfun-update-data`. Po tym restart `darktable`, przeładowanie
modułu korekcji i wszystko zaczęło działać idealnie! Zakładam że `rawtherapee`
również

### Usuwanie brudów matrycy

`darktable` ma specjalny moduł do tego.

TODO muszę to sprawdzić

### Cienie i światła

Ten moduł jest rewelacyjny. Wystarczy przesunąć suwakiem tyle, ile się chce i
rezultaty widzi się od razu. Mam wrażenie, że działa to lepiej niż w `rawtherapee`.

[shadows_and_highlights]: https://www.darktable.org/usermanual/en/modules.html#shadows_and_highlights

### Korekcja perspektywy

### Equalizer

https://www.darktable.org/usermanual/en/correction_group.html#equalizer

TODO jak to działa?

## Rawtherapee

TODO
