---
layout:                 post
title:                  "Darktable vs Rawtherapee"
subtitle:               "porównanie programów do przetwarzania raw'ów"
desc:                   "Dość długo używałem Rawtherapee i byłem z niego raczej zadowolony. Z ciakawości postanowiłem spróbować Darktable. Bardzo mi się spodobało i postanowiłem nauczyć się korzystać z niego. W tym momencie wydaje mi się, że lepsze rezultaty mogę osiągać w Darktable. Ten wpis będę aktualizował na bieżąco aż do momentu, kiedy będę mógł powiedzieć że dobrze poznałem oba programy."
keywords:               [raw, linux, debian, rawtherapee, darktable, presety, odszumianie]
date:                   2018-07-01 20:00:00
finished_at:            2018-12-26 00:00:00
header_nogallery:       true
author:                 "Aleksander Kwiatkowski"
categories:             article
image_filename:         P6240189_dark1.jpg.jpg
tags:                   [article, main]
towns:                  []

---

[perspective_correction]: https://www.darktable.org/usermanual/en/correction_group.html#perspective_correction
[profiled-denoise]: https://www.darktable.org/usermanual/en/correction_group.html#denoise_profiled
[shadows_and_highlights]: https://www.darktable.org/usermanual/en/modules.html#shadows_and_highlights
[equalizer]: https://www.darktable.org/usermanual/en/correction_group.html#equalizer

## Wstęp

Przez dłuższy czas korzystałem z `rawtherapee`. Wydaję mi się, że jestem juz w nim
dość doświadczony. W tym momencie odkrywam `darktable` i zaczyna mi się ono podobać.

Artykuł nie zamierzam oznaczać jako gotowy do momentu osiągnięcia biegłości w
`darktable`.
Postaram się później powrócić do `rawtherapee` i jeszcze porównać.

Tekst ten będzie wyraźnie subiektywny, bazując bardziej na wrażeniach z pracy
oraz ostatecznego efektu. Nie będę obiektywnie określał który (przykładowo)
ma lepszy algorytm usuwający szumy.

### Gotowy?

Mniej więcej oznaczam ten artykuł jako gotowy. Udało mi się uzyskać
biegłość i teraz korzystam wyłącznie z `darktable`.

## TL;DR

`darktable` przypomina bardziej Lighrooma, opiera się na określonym sposobie
pracy. Jest bardziej "wizualny". Parametry użytkownik zmienia do momentu
uzyskania odpowiedniego efektu. Ma **warstwy**, które dają ogrom możliwości.
Poznałem je niedawno (2018-10-10).

`rawtherapee` jest bardziej surowy, "nieludzki", daje pełniejszą kontrolę
gdyż koncentruje się nad parametrami. Parametry te można łatwiej wpisywać
ręcznie. Jakby użytkownik lepiej wiedział jak działają algorytmy i jakie
parametry będą najlepsze.

## Darktable

### Filmiki, tutoriale

Obejrzenie [tego filmiku](https://www.youtube.com/watch?v=aU8z81INOBU)
bardzo mi pomogło. Dzięki niemu zrozumiałem potęgę warstw oraz wiele
drobnych, przydatnych rzeczy.

### Warstwy

O warstwach słyszałem tylko od ludzi, którzy kupili Lightrooma/Photoshopa lub
inny płatny program. Domyślałem się ile to daje możliwości ale
dopiero patrząc na tutoriale zrozumiałem, że bywa to ogromnie ważna
rzecz.

W skrócie moduły domyślnie operują na całym zdjęciu. Można ustawić
`blend`->`drawn mask` i przykładowo wybrać gradient. Łącząc dwa gradienty
i ustawiając `invert mask` można operować tylko na fragmencie ograniczonym
przez te dwa gradienty. Nie sprawdzałem z większą ilością jeszcze.

Funkcja ta bardzo przydała mi się podczas przerabiania
zdjęć z [mgłą z Sokolika]({% post_url 2018-10-09-lasery-z-sokolika %}).

### Kolejka

Na ten moment nie ma kolejki do przetwarzania. Można zedytować wszystkie pliki
a następnie zaznaczyć nieedytowane i odwrócić zaznaczenie.

### Zmiana parametrów

`darktable` korzysta ze specjalnej kontrolki do zmiany parametrów
zmiennoprzecinkowych (po kliknięciu prawym przyciskiem).
Umożliwia to dokładniejsze ustawienie niż korzystanie z suwaka.

Po kliknięciu prawym przyciskiem można wpisywać ręcznie wpisując w tym
momencie liczbę.

### Presety modułów

W `darktable` można zapisywać konfiguracje modułów w presetach. Można to zrobić
do każdego, nawet najprostszego, modułu.

Aby zautomatyzować lepiej można ustawić automatyczne ładowanie presetów.
Wystarczy kliknąć prawym i "edit this preset". Dany preset zostanie
utworzony albo zmodyfikowany. Bardzo przydatne są *filtry* np. aparat, obiektyw,
ISO. Ja osobiście ustawiłem inne wyostrzanie dla obiektywów "ogólnych"
a inne dla bardzo jasnych stałek, przy których skupiam się na "płynnościach".

### Usuwanie szumu

Jest kilka modułów do usuwania szumu.
Podstawowym jest "[profiled denoise][profiled-denoise]"
który dobiera parametry na podstawie aparatu i ISO.
Jest to najłatwiejsze rozwiązanie

Zauważyłem, że usuwając szumy algorytm usuwa również detale.
Zawsze starałem się wyciągnać maksimum szczegółów ze zdjęcia ale spróbuję teraz
przerabiając RAWy skoncentrować się na ogólnym wrażeniu zdjęcia a niekoniecznie
na ilościach detali. Podejście to jest lepsze w przypadku druku zdjęć.

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
Działa on dość fajnie chociaż `heal` w Gimpie było według mnie łatwiejsze
w obsłudze. Tutaj należy zaznaczyć obszar "brudny" korzystajac z koła, elipsy
albo innego kształtu, i wybrać miejsce "poprawne" do pobrania obrazu.

Kluczowe jest odpowiednie dopasowanie jasności miejsca źródłowego.

### Cienie i światła

Ten [moduł][shadows_and_highlights] jest rewelacyjny. Wystarczy przesunąć suwakiem tyle, ile się chce i
rezultaty widzi się od razu. Mam wrażenie, że działa to lepiej niż w `rawtherapee`.

Gdy przesunie się ponad `50` mogą pojawiać się artefakty dlatego należy modułu
tego używać z rozwagą.

### Equalizer

Moduł [ten][equalizer] łączy operowanie na krawędziach, jasności `luma`
i kolorze `chroma` w rozróżnieniu na "ziarnistość". Jest to bardzo złe słowo
jednak polecam samemu wczytać predefiniowane ustawienia i spróbować połączyć
`clarity` z `sharpen`.

### Haze removal

Tutaj polecam używać go z rozwagą.

<!-- TODO sprawdzić zamglone zdjęcia z rawtherapee -->

### Obciążenie procesora

Wydaję mi się, że `darktable` ma znacznie większe potrzeby obliczeniowe.
Nawet zmieniając priorytet procesu system jest wyraźnie zwolniony.
Oglądanie YouTube'a staje się wtedy problematyczne.

Brak możliwości spazuwania jest dużą niedogodnością. Również w ustawieniach
jest niewiele opcji. Wypada tutaj gorzej.

<!-- TODO sprawdzić w ustawieniach -->

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

## Aktualizacja 2019-11-21

Ostatnio próbowałem przerobić RAW z Pentaksa KS-2. Pomimo już biegłości w
`darktable` nie potrafiłem uzyskać podobnego rezultatu. Usuwanie aberracji nie
było tak dobre jak i mam wrażenie, że wyostrzanie w `rawtherapee` jest
bardziej "krajobrazowe".

Również zauważyłem, że zdjęcia z Olympusa nie są na tyle soczyste. Bardzo
możliwe że błędem jest moja percepcja.

## Aktualizacja 2020-05-28

[tutorial]: https://www.youtube.com/playlist?list=PLlYWvzmJQTrRq7JrYdD7k3-8-v-uHnhK_

Znalazłem naprawdę bardzo dobry [tutorial][tutorial] dzięki któremu dowiedziałem się o:

1. Możliwości tworzenia HDR z kilku rawów - tworzy 32bitowe pliki DNG.
2. `base curve` domyślny nie zawsze jest idealny i można trochę więcej wyciągnąć z
   rawów olympusowskich jeżeli się odpowiednio go zmodyfikuje. Dla mnie to jest
   bardzo przydatna rzecz.
