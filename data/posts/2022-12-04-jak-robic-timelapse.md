---
layout:                 post
title:                  "Jak robić filmiki poklatkowe (timelapse)"
subtitle:               ""
desc:                   ""
keywords:               []
date:                   2022-12-04 17:00:00
#finished_at:            2100-02-09 12:00:00
author:                 "Aleksander Kwiatkowski"
categories:             article
image_filename:         2022_11_19__14_46_PB191343.jpg
image_position:         50% 60%
tags:                   [article, todo]


---

[pentax-tether]: https://pktriggercord.melda.info/

## Wstęp

Jednym (z wielu) pobocznych projektów które mnie ciekawiło jest tworzenie
filmów poklatkowych. One są zawsze ciekawe jednak większość jest dosyć krótka -
przedstawia jakiś krajobraz przez maksymalnie kilka godzin.

Ja chciałem zrobić coś "lepszego"

## Szczegóły

### Brinno

Szczycą się produkcją kamer do timelapse które mają bardzo małe zużycie energii.
Żaden inny aparat nie zrobi więcej zdjęć przy takim zasilaniu.

Niestety rozdzielczość 720p to jakieś nieporozumienie. Najnowsze modele posiadają
rozdzielczość 1080p co, w mojej ocenie, teraz jest minimum. Jakość obrazu jednak
nie powala patrząc na koszt.

Podsumowując: **Gopro ma znacznie lepszą jakość obrazu niż Brinno.**

### Gopro

### Normalny aparat

#### Pentax K5



Okazało się, że Pentax K5 idealnie współpracowuje z

#### Olympus M1m2

`gphoto2` to bardzo dobre narzędzie. W teorii. W praktyce okazuje się, że
większość aparatów jakie mam się średnio nadaje.

```
> gphoto2 --auto-detect
Model                          Port                                            
----------------------------------------------------------
Olympus E-M1                   usb:001,028

> gphoto2 --camera "Olympus E-M1" --list-files
There is no file in folder '/'.

> gphoto2 --camera "Olympus E-M1" --capture-image-and-download
# długie czekanie i pozytywny rezultat
New file is in location /store_00010001/DCIM/194OLYMP/_1120004.JPG on the camera
Saving file as _1120004.JPG
Deleting file /store_00010001/DCIM/194OLYMP/_1120004.JPG on the camera
New file is in location /store_00010001/DCIM/194OLYMP/_1120004.ORF on the camera
Saving file as _1120004.ORF
Deleting file /store_00010001/DCIM/194OLYMP/_1120004.ORF on the camera
```

Nie bardzo rozumiem dlaczego po każdym wykonaniu `gphoto2` musi ono
wykonał długotrwałe wyszukiwanie podłączonego aparatu. Na plus - działa. Wykonało
poprawnie zdjęcie.

Istnieje nakładka 'gtkam' które może trochę ułatwia ale nadal detekcja
trwa tam bardzo długo. Natomiast "live view" działa dosyć sprawnie i po kliknięciu
zdjęcie pobiera szybko. Wskazuje to na to, że można by lepiej używać `gphoto2`.

Aparat musi być ustawiony w tryb tetheringu (ikonka aparatu podłączona do PC).
Najlepiej jak to się ustawi domyślnie w opcjach.

#### Olympus M1m3

Jeżeli dobrze pamiętam to ten aparat obsługuje ładowanie przez USB-C. Nie jestem
pewien czy ładowanie będzie działać automatycznie razem z obsługą aparatu przez
serwer.

```
gphoto2 --auto-detect
# działa

gphoto2 --camera "Olympus E-M1" --capture-image-and-download
# również, ale jakby dłużej niż M1m2
```

#### Sony A7III

Zdecydowanie nie będę umieszczał pełnej klatki

```
gphoto2 --auto-detect
Model                          Port                                            
----------------------------------------------------------
Sony Alpha-A7 III (PC Control) usb:001,037  

gphoto2 --camera "Sony Alpha-A7 III (PC Control)" --capture-image-and-download
```

Również działa. Na "szczęście" nie na tyle lepiej, że myślałbym o umieszczeniu
tego aparatu do robienia zdjęć do timelapse'a.

### Fotopułapka Suntek HC-900LTE

Wybrałem tą fotopułapkę gdyż:

1. była dostępna używana prawie 200zł tańsza
2. wersje 2G uniemożliwia wysyłanie zdjęć dobrej jakości
3. dostępna wersja PRO jest bardzo droga, nie chciałem tyle wydawać

Trochę czasu trwało aż zainstalowałem. Kamera była niedeterministyczna, a raczej
nie działała tak jak powinna. Pierwszym problemem było skończenie się ważności
karty SIM (głupi ja). Po tym odsyłała ona informacje o statusie (polecenie `*520*`).

Gdy odpaliłem testowo w Poznaniu to odsyłało krótkie filmiki (`*500*` i chyba `*505*`)
jednak gdy zainstalowałem w miejscu docelowym już nie wysyłało pomimo również
zasięgu 4G. Ostatecznie gdy następnym razem wróciłem kamerka zrobiła kilka
zdjęć i po kilku dniach się wyładowała.

#### Gdy zaczęła działać

Postanowiłem olać detektor PIR i przełączyć na timelapse. Większość fotopułapek
może robić zdjęcia co 5 minut. Fotopułapki Browning'a mogą chyba nawet co minutę
ale, jak się nie mylę, one nie mają modułu łączności komórkowej oraz ich
cena jest wysoka.

Byłem zaskoczony gdy zdjęcia zaczęły do mnie przychodzić co 5 minut na maila.
Fotopułapka nie wysyłała zdjęć na polecenie `*505*` w formie MMS a tylko w formie
maila teraz.

##### Pojemność karty SD

Zainstalowałem 32GB kartę SD. Zdjęcia dostaję maile w roździelczości 1280x720.
Każde takie zdjęcie zajmuje około 150kB.

2023-01-20 przeniosłem zdjęcia z karty SD i ją wyczyściłem. Było wtedy prawie 29GB.
2023-01-24, o tej samej porze co instalacja, było 26.13GB wolnego. Oznacza to,
że po 4 dniach zostało wygenerowane ok. 2.8GB zdjęć - czyli kamerka
**dziennie generuje ok 750MB zdjęć**. Oznacza to, że
**kartę 32GB trzeba będzie opróźniać co ok 38 dni**. 

### Eneloop białe

Na początku użyłem akumulatorków Eneloop (białe)

* 2022-12-04 16:20 - instalacja
* 2022-12-06 18:49 - 94% baterii podczas nocnych zdjęć
* 2022-12-06 21:10 - stan baterii zaczął spadać do ok 70-40%
* 2022-12-06 23:41 - bateria ok 4%
* 2022-12-06 03:25 - bateria ok 2% i utrzymuje się
* 2022-12-06 07:14 - po wyłączeniu podświetlania IR stan baterii wrócił do 100%
* 2022-12-06 16:19 - stan baterii spada do 1% po wejściu w tryb nocny, za dnia 100%
* 2022-12-08 18:36 - ostatnie wysłane zdjęcie

Jak widać najwięcej energii jest potrzebna na oświetlanie diodami IR - wtedy
stan baterii zaczyna spadać. Fotopułapka padła, można powiedzieć, bez
ostrzeżenia gdyż za dnia stan zawsze wynosił 100%.

Zastanawiałem się czy napięcie akumulatorków (8 * 1.2V) może być przyczyną.
Zgodnie z instrukcją urządzenie wymaga 12V. Postanowiłem wymienić baterie

### Energizer +50%

Pomyślałem, że warto by było sprawdzić jak będzie działać z jednorazowymi
bateriami. Wtedy fotopułapka dostaje 12V więc powinna wytrzymać dłużej,
a przynajmniej być bardziej deterministyczna.

* 2022-12-09 15:19 - instalacja
* 2022-12-11 06:42 - po raz pierwszy (w nocy) pojawił się spadek stanu baterii
* 2022-12-11 07:51 - o dziwo za dnia pojawił się spadek stanu baterii (71%)
* 2022-12-11 12:50 - stan oscyluje w okolicy 25-30%
* 2022-12-11 16:09 - po przełączeniu w tryb nocny oczywiście stan baterii spadł na 1%
* 2022-12-11 22:05 - ostatnie wysłane zdjęcie

Przez ten czas kamerka wysłała trochę ponad 600 zdjęć.

Wniosek jest prosty - lepiej używać akumulatorków Eneloop jednak jest to
mało sensowne rozwiązanie. W obu przypadkach kamerka działa tylko kilka dni.

### Akumulator żelowy

Postanowiłem kupić specjalny akumulator żelowy (7Ah) z dedykowanym złączem do
fotopułapki.

* 2022-12-29 14:07 - instalacja
* 2023-01-05 08:50 - nadal 100% nawet w nocy
* 2023-01-11 11:07 - pierwszy raz gdy poziom baterii nie wynosił 100%
* 2023-01-11 19:28 - ostatnie zdjęcie jakie otrzymałem

Przez ten czas kamerka wysłała trochę poniżej 3400 zdjęć. Wychodzi to
2mAh (12V) na zdjęcie, czyli **1 zdjęcie kosztuje 20mW energii**
(w odstępie 5 minutowym).

Ostatniego dnia (2023-01-11) gdy poziom baterii spadł poniżej 100%
oscylował on 30-80%. Dopiero po zmroku spadł do 1% i 2-3 godziny później
kamerka padła.

Akumulator wyciągnąłem 2023-01-20 gdyż nie miałem czasu podjechać. Nie spieszyłem
się jakoś mocno z naładowaniem jego i zacząłem to robić 2023-01-23.
Podłączyłem do inteligentneh ładowarki (prostownik to uwłaczająceo określenie
do tych urządzeń) Volt dla akumulatorów kwasowych
i... nie ładował. Napięcie wynosiło 6V więc oznacza to niezły problem z
12V akumulatorem żelowym. Muiałem użyć ładowarki do LIFEPO4 aby "zastartować".
Napięcie wzrosło do okolic 12V i wtedy już prostownik zaczął normalnie
ładować i "naprawiać".

### Akumulator LIFEPO4

Nigdzie nie widziałem informacji o tym czy kamerka będzie działać na 12.8V
ale sądzę, że nie powinno to być problemem.

2022-01-20 zainstalowałem akumulator LIFEPO4 Moretti
(nie pamiętam jego pojemności ale jest to albo 7Ah albo 6Ah)
i okazało się, że kamerka
działa bez problemu.

Zauważyłem, że różnica temperatury podczas wykonywania
zdjęć nocnych z podświetlaniem IR jest znacznie bardziej widoczna niż
dla akumulatora żelowego. Fotopułapka
zapisuje temperaturę na każdym zdjęciu i gdy w nocy włącza podświetlanie
IR temperatura zawsze spadała.

* 2023-01-20 16:26 - instalacja
