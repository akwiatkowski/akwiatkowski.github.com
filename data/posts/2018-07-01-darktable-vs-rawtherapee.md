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
chociaż nie oznacza to, że wszystko jest oczywiste.

`rawtherapee` jest bardziej surowy, "nieludzki", daje pełniejszą kontrolę
gdyż koncentruje się nad parametrami. Parametry te można łatwiej wpisywać
ręcznie.

## Darktable

### Kolejka

Na ten moment nie ma kolejki do przetwarzania. Można zedytować wszystkie pliki
a następnie zaznaczyć nieedytowane i odwrócić zaznaczenie.

### Zmiana parametrów

`darktable` korzysta ze specjalnej kontrolki do zmiany parametrów
zmiennoprzecinkowych. Umożliwia to dokładniejsze ustawienie niż korzystanie z
suwaka.

TODO nie można wpisać ręcznie?

### Usuwanie szumu

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

### Korekcja geometri zdjęcia

#### Prostowanie

W `darktable` można prostować wybierając moduł `crop and rotate` i przeciągając
prawym przyciskiem myszy przeciągnąć linię prostą, analogicznie jak w `rawtherapee`.

#### Perspektywa

Jest automatyczne narzędzie które wykrywa i zrównuje zakrzywienia `keystone`.
Działa ono bardzo dobrze. Wykrywa ono linie poziome i pionowe. Lewym przyciskiem
myszy zaznacza się istotne linie, a prawy przestawia na nieistotne.

Algorytm nie radzi sobie z niektórymi dachami z jednolitym wzorcu pod kątem 45
stopni.

[perspective_correction]: https://www.darktable.org/usermanual/en/correction_group.html#perspective_correction

### Korekcta obiektywu

Istnieje biblioteka `lensfun`, która zajmuje się korekcją niedoskonałości
obiektywów. W przypadku systemu Pentaksa nie było to takim dużym problemem
dla mnie i nawet nie wiedziałem o istnieniu narzędzi do tego.
Dystorsja była "pod kontrolą" i nawet sie tym nie przejmowałem.
Winietowanie poprawiałem ręcznie "na oko".

System M43 zakłada istnienie dystorsji, która będzie następnie programowo poprawiana.
W przypadku Olympusa 9-18mm dystorsja ta jest niejednorodna i rezultaty korekcji
(np. horyzont morza) nie były dobrze poprawiane.

Zauważyłem, że brakowało mi `lensfun` w systemie (GNU/Linux Debian). Zainstalowałem ją
przez `apt-get install liblensfun-bin liblensfun-data-v1 liblensfun1` a następnie
należa zaktualizować bazę uruchamiając `lensfun-update-data`.
Po tym restart `darktable`, przeładowanie
modułu korekcji i wszystko zaczęło działać idealnie! Zakładam że `rawtherapee`
również tak dobrze powinien korzystać z tego narzędzia.

### Usuwanie brudów matrycy

`darktable` ma specjalny moduł do tego chociaż jeszcze nie testowałem go.

TODO muszę to sprawdzić

### Cienie i światła

Ten moduł jest rewelacyjny. Wystarczy przesunąć suwakiem tyle, ile się chce i
rezultaty widzi się od razu. Mam wrażenie, że działa to lepiej niż w `rawtherapee`.

[shadows_and_highlights]: https://www.darktable.org/usermanual/en/modules.html#shadows_and_highlights

### Korekcja perspektywy

### Equalizer

https://www.darktable.org/usermanual/en/correction_group.html#equalizer

TODO jak to działa?

## Rawtherapee - kiedy jest lepsze

### Presety

Teoretycznie da się operować na nich, ale w praktyce jest to bardzo toporne.
Presety są per moduł. Można je łączyć, ale to muszę jeszcze sprawdzić
dokładniej.

### Kolejka

Twórcy `darktable` olewają wprowadzenie kolejki. Wydawało mi się, że ja czegoś
nie wiem, ale faktycznie twórcy ignorują potrzebę możliwości dodania eksportu
pliku do kolejki.

W tym momencie edytuję wszystkie pliki i po skończonej edycji wybieram
"zaznacz nieedytowane", a następnie "odwróć zaznaczenie". Powoduje to konwersje
zdjęć, które tylko otworzyłem raz. Mam domyślnie ustawiony zestaw modułów,
które w większości sytuacji tworzy już zdjęcie wyjściowe.

TODO
