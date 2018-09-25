---
layout:                 post
title:                  "Darktable vs Rawtherapee"
subtitle:               "porównanie programów do przetwarzania raw'ów"
desc:                   "Dość długo używałem Rawtherapee i byłem z niego raczej zadowolony. Z ciakawości postanowiłem spróbować Darktable. Bardzo mi się spodobało i postanowiłem nauczyć się korzystać z niego. W tym momencie wydaje mi się, że lepsze rezultaty mogę osiągać w Darktable. Ten wpis będę aktualizował na bieżąco aż do momentu, kiedy będę mógł powiedzieć że dobrze poznałem oba programy."
keywords:               [raw, linux, debian, rawtherapee, darktable, presety, odszumianie]
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
dość doświadczony. W tym momencie odkrywam `darktable` i zaczyna mi się ono podobać.


Artykuł nie zamierzam oznaczać jako gotowy do momentu osiągnięcia biegłości w
`darktable`.
Postaram się później powrócić do `rawtherapee` i jeszcze porównać.

Tekst ten będzie wyraźnie subiektywny, bazując bardziej na wrażeniach z pracy
oraz ostatecznego efektu. Nie będę obiektywnie określał który (przykładowo)
ma lepszy algorytm usuwający szumy.

## TL;DR

`darktable` przypomina bardziej Lighrooma, opiera się na określonym sposobie
pracy. Jest bardziej "wizualny". Parametry użytkownik zmienia do momentu
uzyskania odpowiedniego efektu.

`rawtherapee` jest bardziej surowy, "nieludzki", daje pełniejszą kontrolę
gdyż koncentruje się nad parametrami. Parametry te można łatwiej wpisywać
ręcznie. Jakby użytkownik lepiej wiedział jak działają algorytmy i jakie
parametry będą najlepsze.

## Darktable

### Kolejka

Na ten moment nie ma kolejki do przetwarzania. Można zedytować wszystkie pliki
a następnie zaznaczyć nieedytowane i odwrócić zaznaczenie.

### Zmiana parametrów

`darktable` korzysta ze specjalnej kontrolki do zmiany parametrów
zmiennoprzecinkowych (po kliknięciu prawym przyciskiem).
Umożliwia to dokładniejsze ustawienie niż korzystanie z suwaka.

Chyba nie można wpisywać ręcznie parametrów. Można tworzyć presety dla danego modułu.

### Presety modułów

W `darktable` można zapisywać konfiguracje modułów w presetach. Można to zrobić
do każdego, nawet najprostszego, modułu.

Aby zautomatyzować lepiej można ustawić automatyczne ładowanie presetów.
Wystarczy kliknąć prawym i "edit this preset". Dany preset zostanie
utworzony albo zmodyfikowany. Bardzo przydatne są *filtry* np. aparat, obiektyw,
iso. Ja osobiście ustawiłem inne wyostrzanie dla obiektywów "ogólnych"
a inne dla bardzo jasnych stałek.

### Usuwanie szumu

[profiled-denoise]: https://www.darktable.org/usermanual/en/correction_group.html#denoise_profiled

Jest kilka modułów do usuwania szumu.
Podstawowym jest "[profiled denoise][profiled-denoise]"
który dobiera parametry na podstawie aparatu i ISO.
Jest to najłatwiejsze rozwiązanie

Zauważyłem, że usuwając szumy algorytm usuwa również detale.
Zawsze starałem się wyciągnać maksimum szczegółów ze zdjęcia ale spróbuję teraz
przerabiając RAWy skoncentrować się na ogólnym wrażeniu zdjęcia a niekoniecznie
na ilościach detali.

### Korekcja geometri zdjęcia

#### Prostowanie

W `darktable` można prostować wybierając moduł `crop and rotate` i przeciągając
prawym przyciskiem myszy przeciągnąć linię prostą, analogicznie jak w `rawtherapee`.

#### Perspektywa

Jest automatyczne narzędzie które wykrywa i wyrównuje zakrzywienia `keystone`.
Działa ono bardzo dobrze. Wykrywa ono linie poziome i pionowe. Lewym przyciskiem
myszy zaznacza się istotne linie, a prawy przestawia na nieistotne
jeżeli algorytm nie wykrył odpowiednich linii.

Algorytm nie radzi sobie z niektórymi dachami o jednolitym wzorcu pod kątem 45
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

<!-- TODO muszę to sprawdzić -->

### Cienie i światła

Ten [moduł][shadows_and_highlights] jest rewelacyjny. Wystarczy przesunąć suwakiem tyle, ile się chce i
rezultaty widzi się od razu. Mam wrażenie, że działa to lepiej niż w `rawtherapee`.

Gdy przesunie się ponad `50` mogą pojawiać się artefakty dlatego należy modułu
tego używać z rozwagą.

[shadows_and_highlights]: https://www.darktable.org/usermanual/en/modules.html#shadows_and_highlights

### Equalizer

Jeszcze nie zrozumiałem w pełni jak dziala [ten moduł][equalizer].
Jeżeli się nie mylę to łączy on wyostrzanie (barwa i jasność) i usuwanie szumów.

[equalizer]: https://www.darktable.org/usermanual/en/correction_group.html#equalizer

### Haze removal

Tutaj polecam używać go z rozwagą.

<!-- TODO sprawdzić zamglone zdjęcia z rawtherapee -->

## Rawtherapee - kiedy jest lepsze

### Presety

Tutaj `darktable` według mnie ma istotne braki.

Teoretycznie da się operować na nich, ale w praktyce jest to bardzo toporne.
Presety są per moduł. Można je łączyć, ale to muszę jeszcze sprawdzić
dokładniej.

### Kolejka

Twórcy `darktable` olewają wprowadzenie kolejki. Wydawało mi się, że ja czegoś
nie wiem, ale faktycznie twórcy ignorują potrzebę możliwości dodania eksportu
pliku do kolejki. Kolejkę możnaby uruchomić później albo zatrzymać tak,
jak to robiłem w `rawtherapee`.

W tym momencie edytuję wszystkie pliki i po skończonej edycji wybieram
"zaznacz nieedytowane", a następnie "odwróć zaznaczenie". Powoduje to konwersje
zdjęć, które tylko otworzyłem raz.
<!-- TODO -->
Nie wiem jeszcze jak można cofnąć oznaczenie edycji danego zdjęcia.
Mam domyślnie ustawiony zestaw modułów,
które w większości sytuacji tworzy już zdjęcie wyjściowe.

<!-- TODO dodać o Wavelets -->
