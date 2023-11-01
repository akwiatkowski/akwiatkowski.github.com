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

### Gopro 6

Zakupiłem 33Ah akumulator LIFEPO4 (a później 60Ah gdy ceny spadły). Początkowo
plan wykorzystania był "różny" jednak jako etap pośredni pojawił
się pomysł wykorzystania Gopro 6 do nagrywania timelapse'ów.

Przygotowałem odpowiednie miejsce na zewnątrz do montażu kamerki i przeprowadziłem
lekkie testy.

TODO: filmik wrzucić tutaj

Kupiłem gniazdo zapalniczki z wyjściem USB i zmontowałem duży "powerbank".
Według moich obliczeń akumulator LIFEPO4 10Ah powinien wystarczać na 2 dni, a 33Ah
na prawie tydzień. Przyjąłem stały pobór prądu 0.1A, który zauważyłem sprawdzając
ile pobiera podłączona kamerka. Jest to możliwe, że większośc tej energii
idzie na podładowywanie akumulatorka w Gopro. Nie zauważyłem wzrostu zużycia
energii podczas wykonywania zdjęcia.

Planuję na początku kwietnia zainstalowanie "powerbank'u" i instalacja
kamerki na południowy-zachód ustawiając dość krótki interwal (2-4s). **Jedno zdjęcie
zajmuje ok 2.5MB** co oznacza, że **robiąc zdjęcie co 2s będę potrzebował 100GB
dziennie**. Jest to sporo dlatego bezpieczną wartością będzie przyjęcie interwału
4s.

2023-04-02 - zainstalowałem 33Ah "powerbank" i ustawiłem interwał 10s. Ustawiłem
płaskie kolory, automatyczną ekspozycje, ISO 100-1600 i stały balans bieli.
Zobaczymy co z tego wyjdzie.

2023-04-04 - ok 17:20, przyszedłęm sprawdzić jak działa. Akumulator ma 13V i gopro
zrobiło 69GB zdjęć. Zauważyłem, że zdjęcia są zbyt mocno doświetlone i muszę zmienić
jasność. Trochę nie rozumiem tego jak kamerka dopasowuje się do jasności. Możliwe
że "protune" jakoś inaczej te zdjęcia zapisuje.

2023-04-12 - ok 15-tej przyszedłem zabrać akumulator i kamerkę z kartą. Nic nie wybuchło.
Kamerka była wyłączona ale cały czas była podtrzymywana. Na akumulatorze było 12.1V
czyli ok 10% pojemności. Na karcie SD zostało prawie 30GB wolnego. Nie wiem dlaczego
kamerka przestała robić zdjęcia. Możliwe, że jest jakaś określona ilość zdjęć jaką jest
w stanie zrobić albo się zawiesiła.

Byłem kilka razy i nie ma sensu opowiadać o każdej sytuacji. Kamerka po pewnym czasie
(1-3 dni) się wyłączała bez powodu. Możliwe, że przyczyną była temperatura.

Po zmianie interwału na 20s nie było problemu z duplikacją zdjęć jednak kamerka
się częściej zawieszała.

Ustawiłem nagrywanie timelapse w formie filmiku z interwałem 2s. Rezultat był ciekawy.
Kamerka nagrała 3 filmiki 4GB. Niestety w nocy przy tym interwale nic nie widać.

#### DJI Action 3

Przetestowałem również kamerkę od DJI.

### Normalny aparat

#### Pentax K5

Okazało się, że Pentax K5 idealnie współpracowuje z GNU/linuksem.

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

### Raspberry Pi

2023-03-14 dowiedziałem się, że są ciekawe kamery do Raspberry Pi. Jakość
nie jest wyjątkowa, obiektyw szerokokątny 6mm jest dość słaby ale obiektywy tele
ponoć są stosunkowo dobre. Zaletą jest bardzo łatwa integracja gdyż zdjęcia
robi się wprost z konsoli linuksowej. Do tego koniecznie potrzebowałbym jakąś
szczelną obudowę a jeszcze jej nie znalazłem.

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

Przez ten czas (13 dni) kamerka wysłała trochę poniżej 3400 zdjęć. Wychodzi to
2mAh (12V) na zdjęcie, czyli **1 zdjęcie kosztuje 20mW energii**
(w odstępie 5 minutowym), czyli około **0.5Ah dziennie** przy 12V.

Ostatniego dnia (2023-01-11) gdy poziom baterii spadł poniżej 100%
oscylował on 30-80%. Dopiero po zmroku spadł do 1% i 2-3 godziny później
kamerka padła.

Akumulator wyciągnąłem 2023-01-20 gdyż nie miałem czasu podjechać. Nie spieszyłem
się jakoś mocno z naładowaniem jego i zacząłem to robić 2023-01-23.
Podłączyłem do inteligentnej ładowarki (prostownik to uwłaczające określenie
do tych urządzeń) Volt dla akumulatorów kwasowych
i... nie ładował. Napięcie wynosiło 6V więc oznacza to niezły problem z
12V akumulatorem żelowym. Musiałem użyć ładowarki do LIFEPO4 aby "zastartować".
Napięcie wzrosło do okolic 12V i wtedy już prostownik zaczął normalnie
ładować i "naprawiać".

### Akumulator LIFEPO4

Nigdzie nie widziałem informacji o tym czy kamerka będzie działać na 12.8V
ale sądzę, że nie powinno to być problemem.

2022-01-20 zainstalowałem akumulator LIFEPO4 Moretti 7Ah
i okazało się, że kamerka działa bez problemu.

Zauważyłem, że różnica temperatury podczas wykonywania
zdjęć nocnych z podświetlaniem IR jest znacznie bardziej widoczna niż
dla akumulatora żelowego. Fotopułapka
zapisuje temperaturę na każdym zdjęciu i gdy w nocy włącza podświetlanie
IR temperatura zawsze spadała.

Po drugiej podmianie na akumulator 10Ah zauważyłem, że przez 16 dni fotopułapka
zużyła połowę energii.
W przypadku akumulatora LIFEPO4 7Ah wychodzi, że kamerka wytrzyma prawie
14 dni - więc **0.5Ah na dzień**. Patrząc na akumulator 10Ah można przyjąć, że 50%
jego pojemności zostało zużyte przez 16 dni. I tu mi nie pasuje gdyż
10Ah * 50% = 5Ah i z tego wychodzi **dzienne zużycie 0.3Ah** (5Ah / 16 dni).
Może faktycznie akumulator był bardziej rozładowany, a może wyższe temperatury
mniej wpłynęły na akumulator.

* 2023-01-20 16:26 - instalacja
* 2023-02-03 9:00 - podmiana akumulatora na 10Ah. Napięcie na 7Ah wynosiło 10.5V
  co oznacza naładowanie z 5-8% - więc już trochę przesadziłem z rozładowaniem.
* 2023-02-19 13:00 - wymieniłem akumulator na zapasowy 10Ah. Napięcie na 10Ah wynosiło 13.05V
  co oznacza, że niby zostało ok 50% energii
* planowany czas następnej wymiany to 20 dni od 2023-02-19 czyli 2023-03-12
* 2023-03-14 3:40 - pojawiła się informacja o nie 100% naładowaniu baterii. Oznacza to
  bardzo mocne rozładowanie akumulatora LIFEPO4.
* 2023-03-14 4:37 - otrzymałem mailem ostatnie zdjęcie z kamerki
* 2023-03-14 9:26 - ostatnie zdjęcie jakie zostało zapisane na karcie. Jest to
  ciekawe, że pomimo zaprzestania wysyłania zdjęć mailem,
  kamerka jeszcze chwilę pracowała.
* 2023-03-14 15:00 - instalacja naładowanego akumulatora 10Ah (możliwe, że nie 100%)
* planowany czas następnej wymiany to za 19 dni, czyli 2 kwietnia. Przeniosłem
  16GB zdjęć zostawiając czystą kartę pamięci.
* 2023-04-02 15:00 - instalacja naładowanego akumulatora 10Ah. Przeniosłem około 4870
  zdjęć. Akumulator został wyładowany do 12.94V co oznacza że
  **zostało ok. 30% energii**
* 2023-04-26 14:50 - otrzymałem ostatnie zdjęcie mailem. Przewidywałem wyładowanie
  baterii około 21 dni, czyli 2023-04-23 ale bateria wytrzymała dłużej gdyż
  mniej używała
* 2023-05-11 19:00 - akurat miałem okazję podjechać ze sprzętem i zabrałem naładowany
  akumulator. Używany miał 13.14V czyli **zostało ok 60% energii**. Do tego czasu zrobił
  ok 3500 zdjęć - 12GB.
* 2023-05- ?? - skrzynka pocztową którą używałem do podsyłania zdjęć postanowiła
  się zablokować bo jednocześnie wysyłałem zdjęcia przez SMTP przez
  internet mobilny Orange i odbierałem przez POP3 w internecie stacjonarnym w innym
  miejscu. Zmiana konfiguracji karty przekonała mnie do zmiany również akumulatora.
  Aktualny miał 13.14V czyli **zostało ok 60% energii**
