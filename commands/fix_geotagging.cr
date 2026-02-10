# Posts with routes (GPX/JSON) categorized by GPS geotag status.
# Generated 2026-02-10 from env/full EXIF cache.
#
# Categories:
#   all_missing       - every photo in the post has no GPS (highest priority)
#   partial_missing   - 2+ photos missing GPS but not all
#   only_header_missing - exactly 1 photo missing GPS (likely header image)
#   all_present       - all photos have GPS (no action needed)

# to copy gpx from external server
# find /Volumes/Multimedia/zdjecia/ -iname "*.gpx" -exec cp {} /Users/olek/projects/self/odkrywajacpolske/tmp/gpx/ \; 2>&1

# Usage:
#   crystal run commands/fix_geotagging.cr                    # dry run (default)
#   crystal run commands/fix_geotagging.cr -- --write         # actually write GPS tags
#   crystal run commands/fix_geotagging.cr -- --offset=3600   # manual timezone offset (seconds)

require "xml"

GEOTAGGING_STATUS = {
  all_missing: [
    "2013-07-20-z-wielkiej-raczy-na-rycerzowa",
    "2014-03-29-petla-wokol-murowanej-gosliny",
    "2014-11-11-wokol-jeziora-kierskiego",
    "2015-08-09-do-gluszynki",
    "2016-08-20-mialy-byc-pagorki-a-pozniej-morze",
    "2016-10-20-radojewo-i-okolice-warty",
    "2018-01-20-trudno-trafic-na-zimowy-zachod-slonca",
    "2018-07-07-plasko-zle-gory-zle",
    "2018-07-08-wschodnie-przedgorze-sudeckie",
    "2018-07-09-opuszczajac-nyse-na-polnoc",
    "2018-07-29-okolica-jankowa-dolnego",
  ],
  partial_missing: [
    "2012-05-03-krotka-trasa-przez-ropki",
    "2013-03-02-z-pttk-odrodzenia-pod-dom-slaski",
    "2013-07-19-podejscie-ze-zwardonia-na-wielka-racze",
    "2013-07-21-zejscie-z-rycerzowej-do-rajczy",
    "2013-07-22-z-miedzylesia-do-schroniska-pod-snieznikiem",
    "2013-07-24-zejscie-do-miedzygorza-przez-czarna-gore",
    "2013-10-19-fotowarsztaty-w-gorach-stolowych",
    "2013-11-11-fotowarsztaty-w-bieszczadach",
    "2013-11-30-pierwsze-wejscie-na-sniezke",
    "2013-12-01-zejscie-przez-samotnie-do-karpacza",
    "2014-01-03-okolice-gluszycy",
    "2014-07-14-z-sianozet-do-dabek",
    "2014-07-15-z-dabek-do-ustki",
    "2014-10-19-fotowarsztaty-w-gorach-stolowych",
    "2015-02-01-drugie-zimowe-wejscie-na-sniezke",
    "2015-08-22-z-rebusza-do-cieszyno",
    "2015-12-30-poczatek-sylwestra-w-maciejowej",
    "2015-12-31-przechadzka-na-turbacz",
    "2016-07-23-rowerem-przez-pieniny",
    "2016-08-25-pagorkami-ze-strzelina-do-zarowa",
    "2016-08-26-powrot-z-przedgorza-sudeckiego",
    "2016-09-03-zachodnie-okolice-dobiegniewa",
    "2016-09-25-ze-skokow-do-janikowa",
    "2017-04-16-paluckie-pagorki",
    "2017-07-28-z-krempnej-do-jaslisk",
    "2017-10-22-palac-w-kamiencu-zabkowickim",
    "2018-01-07-mewia-lacha",
    "2018-01-08-wschod-nad-baltykiem",
    "2018-02-03-fokarium-na-helu",
    "2018-02-04-orlowskie-kamyczki",
    "2018-04-29-swornegacie-i-zaborski-park-krajobrazowy",
    "2018-05-01-poludniowe-kaszuby-i-kociewie",
    "2018-05-02-dojazd-na-kociewie",
    "2018-05-03-wzdluz-brdy-do-rytla",
    "2018-05-05-petla-wokol-jezior-wdzydzkich",
    "2018-05-06-petla-wokol-jeziora-borzechowskiego",
    "2018-05-19-przez-wioski-do-kruszwicy",
    "2018-05-31-dojazd-do-trzciela",
    "2018-05-31-trzciel-miasto-kotow-i-starych-domow",
    "2018-06-01-upalny-piaszczysty-dojazd-do-pszczewa",
    "2018-06-02-w-strone-miedzyrzecza",
    "2018-06-03-lubuskie-pagorki-do-sieniawy",
    "2018-06-14-zachod-w-kolobrzegu",
    "2018-07-15-eksplorujac-puszcze-notecka",
    "2018-07-23-parowozem-do-suwalk",
    "2018-08-04-przez-piaski-do-kruszynian",
    "2018-08-05-swisloczany-i-granica-z-bialorusia",
    "2018-08-06-pod-wiatr-do-sokolki",
    "2018-08-08-jadac-wzdluz-biebrzy",
    "2018-08-09-jeszcze-wiekszy-upal-wiec-tylko-do-osowca",
    "2018-08-11-co-mozna-robic-w-tykocinie-gdy-pada-deszcz",
    "2018-08-12-narwianski-park-narodowy-w-remoncie",
    "2018-08-21-sladami-zlikwidowanej-linii-z-wagrowca-do-bydgoszczy",
    "2018-08-27-dwa-dni-nostalgii-kolejowej",
    "2018-09-22-proba-obserwacji-ptakow-przy-rzece-postomia",
    "2018-10-06-zakonczenie-sezonu-rowerowego-w-2018",
    "2018-10-08-wieczor-w-wojanowie",
    "2018-11-04-wioski-na-zachod-od-bystrzycy",
    "2018-12-09-kiedy-nie-jechac-w-gory",
    "2019-02-17-polowanie-na-koty",
    "2019-02-23-pierwsze-dzikie-foki",
    "2019-02-24-dwa-wschody-w-sopocie",
    "2019-06-01-male-labedzie-w-lubniewicach",
    "2019-06-02-przez-trzy-rzeki",
    "2019-06-15-okolice-promna",
    "2019-07-03-lodz-i-linia-tramwajowa-41",
    "2019-07-13-okolice-drawskiego-parku-krajobrazowego",
    "2019-07-21-pelna-klatka-na-szosie",
    "2019-07-28-eksploracja-jezior-mogilna",
    "2019-08-24-dojazd-w-inski-park-krajobrazowy",
    "2019-08-24-wieczor-w-insko",
    "2019-09-28-z-kobylnicy-do-kicina",
    "2019-10-06-jesienne-okolice-puszczy-zielonki",
    "2019-10-11-mgielek-nie-bylo",
    "2019-10-12-wietrzny-grzbiet-karkonoszy",
    "2019-10-24-taka-wiosenna-jesien",
    "2019-11-17-drezyna-do-chrzypska-wielkiego",
    "2020-10-09-swietokrzyskie-koleja",
    "2020-11-14-niepoznane-okolice-kruszwicy",
    "2021-05-01-zimna-majowka",
    "2021-05-11-z-murowanej-gosliny-do-sokolowa-budzynskiego",
    "2021-05-22-najlepsze-co-w-wielkopolsce",
    "2021-05-30-centrum-gniezna",
    "2021-05-30-pociagiem-z-wagrowca-do-gniezna",
    "2021-06-05-tutaj-nie-ma-nic",
    "2021-08-27-wokol-jeziora-rydzowka",
    "2021-09-11-rezerwat-jezioro-czarne",
    "2021-09-12-poludniowy-brzeg-jeziora-kowalskiego",
    "2022-09-03-lednogora-i-okolice",
    "2023-10-18-mgielki-w-pobiedziskach",
  ],
  only_header_missing: [
    "2012-10-09-poludniowe-rudawy-janowickie-oraz-skalnik",
    "2013-02-09-okolice-szrenicy-i-labskiego-szczytu",
    "2013-03-01-ze-szrenicy-do-pttk-odrodzenie",
    "2013-05-02-male-pieniny-bez-wysokiej",
    "2013-05-04-centralne-i-zachodnia-czesc-gorcow",
    "2013-08-04-w-strone-skokow-po-raz-1-szy",
    "2014-04-25-wieczorna-przejazdzka-z-poznania-do-szamotul",
    "2014-06-20-przez-jakuszyce-i-stog-izerski",
    "2014-07-13-z-dziwnowka-do-sianozet",
    "2015-06-04-okolice-harrachowa-i-wielkiej-mumlawy",
    "2015-06-06-ze-szklarskiej-poreby-do-janowic-wielkich",
    "2015-07-13-z-kordowca-przez-radziejowa-do-przehyby",
    "2015-07-25-zachodnia-czesc-doliny-baryczy-od-zmigrodu",
    "2015-10-18-wejscie-na-ostrzyce",
    "2016-01-16-wschod-slonca-na-sniezniku",
    "2016-02-22-narty-w-zielencu",
    "2016-05-08-pieszo-przez-wielkopolski-park-narodowy",
    "2016-07-19-wejscie-na-kondracka-kope",
    "2016-07-20-drugie-wejscie-na-trzydniowianski-wierch",
    "2016-07-21-grania-tatr-zachodnich-na-wolowiec",
    "2016-09-16-zdjecia-o-wschodzie-i-zachodzie-slonca-nad-baltykiem",
    "2016-10-25-mgliste-rudawy-janowickie",
    "2016-12-26-kujawskie-okolice-noteci",
    "2016-12-29-skalny-stol-i-kosciol-w-mala-upa",
    "2017-01-11-wschod-slonca-na-sokoliku",
    "2017-04-30-ze-swierzawy-do-gryfowa-slaskiego",
    "2017-05-02-pociagiem-pierscien-i-granica",
    "2017-05-13-punkt-widokowy-w-dusznie-i-paluki-rowerem",
    "2017-05-27-okolice-powidzkiego-parku-krajobrazowego",
    "2017-06-15-pociagiem-do-kruszwicy",
    "2017-06-24-pochmurny-krajenski-park-krajobrazowy",
    "2017-07-24-cieply-wilgotny-dojazd-do-hanczowej",
    "2017-07-29-do-zrodla-jasiolki",
    "2017-07-30-powrot-przez-pieklo",
    "2017-08-05-petla-przez-skorzecin",
    "2017-09-09-spacer-w-okolicy-rzeki-samicy",
    "2017-09-19-krotka-ucieczka-w-strone-obornik",
    "2017-09-24-przemecki-park-krajobrazowy-po-sezonie",
    "2017-10-17-jesienne-pilchowice",
    "2017-12-29-dotarcie-do-pasterki",
    "2017-12-31-wokol-szczelinca-wielkiego",
    "2018-02-02-plaza-w-sopocie-noca",
    "2018-02-04-stare-miasto-w-gdansku",
    "2018-02-05-wschod-slonca-w-sopocie",
    "2018-04-04-pierwszy-dzien-lata-tej-wiosny",
    "2018-04-28-dojazd-na-majowke-na-kaszubach",
    "2018-05-04-przez-trzy-wojewodztwa-do-krajenskiego-parku",
    "2018-06-09-zachodnie-mazury-nie-sa-takie-plaskie",
    "2018-08-07-polnocne-okolice-sokolki",
    "2018-08-10-dojazd-do-tykocina-przed-burza",
    "2018-09-02-jezioro-kowalskie-i-obrzeza-puszczy-zielonki",
    "2018-09-06-pagorki-pod-pelplinem",
    "2018-09-23-warta-z-kamienia-malego",
    "2018-10-09-jesienne-ciechanowice-i-marciszow",
    "2018-10-09-lasery-z-sokolika",
    "2019-04-25-okolice-kornika-wiosna",
    "2019-06-08-kaszubskie-pagorki-i-pomorskie-lasy",
    "2019-08-10-petla-kolejowa-z-jesionika-do-olomunca",
    "2019-08-25-zakamarki-inskiego-parku",
    "2019-10-11-wschodnie-rudawy-janowickie",
    "2020-01-17-dotarcie-do-szczawna-zdroj",
    "2020-02-29-podmokle-tereny-wielkopolski",
    "2020-05-31-nieprzyjazne-okolice-kostrzyna",
    "2020-06-07-powrot-przez-mokry-las",
    "2020-07-24-kowalewo-pomorskie-i-linia-do-golubia",
    "2021-02-20-pandemiczna-sniezka",
    "2021-02-27-uroczyska-puszczy-zielonki",
    "2021-04-24-szukajac-wiosny",
    "2021-05-12-przed-i-po-burzy",
    "2021-05-15-okolica-jeziora-zarnickiego",
    "2021-07-11-brakujacy-fragment-na-mapie",
    "2021-08-28-przerwa-w-ilawie",
    "2021-09-09-z-pobiedzisk-do-wagrowca",
    "2022-04-14-szukajac-wiosny-w-okolicy-kornika",
    "2024-03-03-wschodnia-wielkopolska-przed-wiosna",
    "2024-04-09-poranna-eksploracja-leszna",
    "2024-04-21-siedlecin-i-okolice",
    "2024-07-14-lekko-wokol-pobiedzisk",
    "2024-08-04-zablokowany-przez-rosliny",
    "2025-02-20-prawdziwa-zima-w-dolinie-cybiny",
    "2025-03-08-jak-zawsze-na-wiosne",
    "2025-04-21-park-promno",
    "2025-04-27-pociagiem-do-nietoperka",
    "2025-04-27-pociagiem-do-wierzbna",
    "2025-05-25-rowerem-do-kiszkowa",
    "2025-06-22-turostowo-i-skrzetuszewo",
    "2025-06-25-glebokie-elektrykiem",
    "2025-07-05-drawsko-pomorskie-to-odkrycie",
    "2025-07-06-kolekcjonujac-wirtualne-bilety-kolejowe",
    "2025-07-12-pod-granice-z-rosja",
    "2025-07-13-i-zaczely-sie-zniwa",
    "2025-07-13-opuszczajac-bartoszyce",
    "2025-07-22-trudne-wakacje",
    "2025-08-02-kocialkowa-gora-pieszo",
    "2025-08-06-podarzewo-i-latalice",
    "2025-08-21-test-zasiegu-roweru",
    "2025-09-21-pagorki-okolic-trzemeszna",
    "2025-10-23-kamienna-gora-wieczorem",
    "2025-10-23-przelecz-redzinska",
    "2025-10-24-lwia-gora",
  ],
  all_present: [
    "2012-04-15-orlowa-i-rownica-w-beskidzie-slaskim",
    "2012-04-29-regietow-i-powrot-przez-kozie-zebro",
    "2012-04-30-wyzynami-od-hanczowej-do-losie",
    "2012-08-11-z-janowic-wielkich-do-pttk-szwajcarka",
    "2012-08-12-kolorowe-jeziorka",
    "2012-10-10-z-leszczynca-na-skalny-stol",
    "2012-12-10-na-lesista-wielka",
    "2012-12-11-bukowiec-i-andrzejowka",
    "2013-02-07-ze-swieradowa-zdroju-do-chatki-gorzystow",
    "2013-02-08-z-chatki-gorzystow-do-jakuszyc",
    "2013-05-01-biala-woda",
    "2013-05-03-wschodnia-czesc-gorcow",
    "2013-05-05-zejscie-z-maciejowej-do-rabki",
    "2013-07-23-snieznik-jaskinia-niedzwiedzia-i-kopalnia-uranu-w-kletnie",
    "2013-08-24-przez-puszcze-zielonke-do-biskupic",
    "2013-08-25-w-strone-skokow-po-raz-2-gi",
    "2013-09-08-95km-rowerem-z-biskupic-do-lakiego",
    "2013-11-29-nocne-dojscie-do-strzechy-akademickiej",
    "2014-01-04-przez-wielka-sowe-do-kamionek",
    "2014-01-05-przez-przelecz-jugowska-powrot-do-schroniska-orzel",
    "2014-01-06-powrot-do-gluszycy",
    "2014-03-09-powrot-szlakiem-nadwarcianskim-z-obornik",
    "2014-03-30-do-puszczykowa",
    "2014-04-06-przejazdzka-na-dziewicza-gore",
    "2014-04-28-nadwarcianskim-szlakiem-rowerowym-oborniki-wronki",
    "2014-05-01-przejazdzka-do-kornika",
    "2014-05-23-przez-puszcze-zielonke",
    "2014-05-31-zachodnia-czesc-beskidu-malego",
    "2014-06-01-centralna-czesc-beskidu-malego",
    "2014-06-02-opuszczenie-beskidu-malego",
    "2014-06-19-do-jakuszyc-i-rzut-oka-na-osade-jizerke",
    "2014-06-21-ze-szklarskiej-poreby-przez-karpacz-do-jeleniej-gory",
    "2014-07-02-w-strone-skokow-po-raz-3-ci",
    "2014-07-12-z-miedzyzdrojow-do-dziwnowka",
    "2014-08-24-petla-przez-dziewicza-gore",
    "2014-08-31-powrot-z-rogozna-do-poznania",
    "2015-03-18-w-strone-skokow-po-raz-4-ty",
    "2015-04-18-kolko-przez-poligon-w-biedrusku",
    "2015-05-02-z-szamotul-do-trzcianki-zielonym",
    "2015-05-22-w-strone-skokow-po-raz-5",
    "2015-05-24-w-strone-sremu-ale-bez-niego",
    "2015-05-30-pierwsza-wizyta-w-wielkopolskim-parku-narodowym",
    "2015-06-05-wokol-jeleniej-gory",
    "2015-06-27-zachod-od-poznania-do-opalenicy",
    "2015-07-11-z-muszyny-na-hale-labowska",
    "2015-07-12-z-hali-labowskiej-przez-rytro-do-kordowca",
    "2015-07-14-zejscie-z-przehyby-do-starego-sacza",
    "2015-07-18-dokonczenie-trasy-z-opalenicy-do-zbaszynia",
    "2015-07-26-do-milicza-trasa-dawnej-kolei-waskotorowej",
    "2015-08-01-przez-powidz-i-granice-dwoch-wojewodztw",
    "2015-08-02-szybki-kurs-do-janikowa",
    "2015-08-23-z-cieszyno-do-szczecinka",
    "2015-09-01-z-lednogory-do-skokow-krecac-sie-wokol-jezior",
    "2015-10-17-petla-po-pogorzu-kaczawskim",
    "2016-01-01-przejscie-do-rdzawki",
    "2016-01-02-noworoczne-opuszczenie-gorcow",
    "2016-01-17-spacer-po-okolicy-miedzylesia",
    "2016-04-03-z-mosiny-do-kosciana",
    "2016-04-04-na-wschod-od-sierakowskiego-parku-krajobrazowego",
    "2016-04-15-wyjazd-z-poznania-w-kierunku-poludniowo-wschodnim",
    "2016-04-17-wloczac-sie-wokol-skokow",
    "2016-04-23-druga-proba-w-kierunku-srody-wielkopolskiej",
    "2016-04-24-walka-z-wiatrem-w-okolicy-jarocina",
    "2016-04-29-dojazd-na-majowke-do-klodzka",
    "2016-04-30-przez-srebrna-gore-do-henrykowa",
    "2016-05-01-z-klodzka-do-gluszycy",
    "2016-05-02-powrot-z-kudowy-zdroju-przez-gory-stolowe",
    "2016-05-03-powrot-z-majowki-rowerowej-z-okolic-klodzka",
    "2016-05-10-okolice-noteci-miedzy-krzyzem-a-santokiem",
    "2016-05-21-z-przysieczyna-obok-wagrowca-do-pily",
    "2016-05-22-z-jarocina-do-slupcy",
    "2016-05-26-beskid-niski-rowerem-po-raz-pierwszy",
    "2016-05-27-petla-do-klimkowki",
    "2016-05-28-z-krempnej-do-jaslisk-dwoma-trasami",
    "2016-06-11-wokol-jezior-wolsztyna",
    "2016-06-12-ze-zbaszynia-do-krzyza-wielkopolskiego",
    "2016-07-10-przez-pagorki-do-stargardu",
    "2016-07-16-najkrotszy-dojazd-do-sierakowa",
    "2016-07-18-dotarcie-do-zakopanego",
    "2016-07-22-spacer-po-okolicy-maniowy",
    "2016-07-30-z-pily-do-bydgoszczy-przez-bagdad",
    "2016-08-06-przejazd-pociagiem-do-czarnkowa",
    "2016-08-08-krotkie-popoludnie-w-swieradowie",
    "2016-08-09-mokry-dzien-w-okolicy-jeleniej-gory",
    "2016-08-10-aby-nie-czekac-za-pociagiem-w-zielonej-gorze",
    "2016-08-10-ze-swieradowa-przez-gryfow-slaski-w-strone-lubania",
    "2016-08-25-rowerem-po-centrum-wroclawia",
    "2016-09-10-z-pily-do-krzyza",
    "2016-09-17-ze-swinoujscia-do-zachodnich-przyjaciol",
    "2016-09-18-petla-przez-wolinski-park-narodowy",
    "2016-09-19-szukajac-szlaku-na-karsiborze",
    "2016-10-24-wejscie-na-sokolik",
    "2016-10-26-opuszczajac-jesienne-rudawy-janowickie",
    "2016-11-13-dojscie-tylko-do-kamienczyka",
    "2016-11-14-polowanie-na-wschod-i-zachod-w-okolicy-szrenicy",
    "2016-11-27-przez-pola-w-okolicy-kiekrza",
    "2016-12-28-podejscie-na-okraj",
    "2016-12-30-wejscie-na-sniezke-z-przeleczy-okraj",
    "2017-01-10-zimowe-okolice-wojanowa",
    "2017-01-12-opuszczenie-zimowych-rudaw-janowickich",
    "2017-01-18-biale-radojewo",
    "2017-01-19-spacer-w-steszewie",
    "2017-01-29-zimowa-okolica-rzeki-gluszynki",
    "2017-02-09-przywitanie-z-karkonoszami",
    "2017-02-10-poszukiwanie-pogody-obok-samotni",
    "2017-02-12-opuszczenie-bialej-krainy",
    "2017-02-26-wokol-jeziora-chomiaskiego",
    "2017-03-04-do-rozpoczecie-sezonu-niedaleko-promna",
    "2017-03-25-z-kosciana-przez-dolsk-w-strone-jarocina",
    "2017-04-01-z-leszna-przez-przemecki-park-krajobrazowy-do-opalenicy",
    "2017-04-11-pociagiem-przez-paluki",
    "2017-04-21-wysiadajac-stacje-wczesniej-przed-zmigrodem",
    "2017-04-22-przez-punkty-widokowe-na-wschod-od-milicza",
    "2017-04-23-zachodnie-okolice-rudy-sulowskiej",
    "2017-05-01-dolina-palacow",
    "2017-05-03-przyjemny-zjazd-przez-chrosnice",
    "2017-05-14-z-nowego-tomysla-przez-okolice-sierakowa-do-wronek",
    "2017-05-21-z-sulechowa-przez-wschowe-do-bojanowa",
    "2017-05-22-wieczor-w-rosnowku",
    "2017-06-03-lubuskie-jeziora",
    "2017-06-04-wzdluz-jeziora-dymaszewskiego",
    "2017-06-09-podmiejskie-kaszuby",
    "2017-06-10-zulawy-wislane-po-deszczu",
    "2017-06-25-dojazd-do-tucholi",
    "2017-07-01-szybka-wizyta-w-dolinie-baryczy",
    "2017-07-06-popoludniowa-ucieczka-do-szamotul",
    "2017-07-08-pomorska-petla-kolejowa",
    "2017-07-16-okolice-jeziora-kamienieckiego",
    "2017-07-18-krotka-ucieczka-do-lopuchowa",
    "2017-07-25-deszcz-w-wysowie",
    "2017-07-26-z-hanczowej-do-krempnej",
    "2017-07-27-na-polnoc-od-krepnej",
    "2017-07-28-sladami-opuszczonych-wiosek",
    "2017-08-06-wzdluz-jeziora-pakoskiego",
    "2017-08-08-z-kosciana-do-opalenicy",
    "2017-08-14-z-pily-do-zlocienca",
    "2017-08-15-prawie-nad-morze",
    "2017-08-26-z-gniezna-do-srody-wielkopolskiej",
    "2017-10-01-okolice-wschodniej-puszczy-noteckiej",
    "2017-10-18-wzdluz-kamiennej-do-jagniatkowa",
    "2017-10-19-chwila-w-witkowie",
    "2017-10-19-jesienny-poranek-na-sokoliku",
    "2017-10-20-delikatne-mgly-z-sokolika",
    "2017-10-21-pociagiem-przez-gory-sowie",
    "2017-10-22-najlepszy-widok-na-bardo",
    "2017-11-04-poludniowo-zachodnia-sypialnia-poznania",
    "2017-11-05-lesne-okolice-lopuchowa",
    "2017-11-18-pociagiem-z-wroclawia-do-rzepina",
    "2017-12-30-wschod-na-szczelincu-wielkim",
    "2018-01-02-jak-wydostac-sie-z-gor-stolowych",
    "2018-03-04-oksywie-i-srodmiescie-gdyni",
    "2018-03-11-rozpoczecie-sezonu-rowerowego-w-2018",
    "2018-03-21-prawie-wiosna-w-radojewie",
    "2018-03-25-z-bojanowa-do-kosciana",
    "2018-04-07-lasami-z-nekli-do-promna",
    "2018-04-08-na-polnoc-do-chrzypska-wielkiego",
    "2018-04-15-petla-przez-wiezyce",
    "2018-04-16-pociagiem-z-koscierzyny-do-gniezna",
    "2018-04-21-wiosenne-okolice-stargardu",
    "2018-04-30-na-polnoc-od-serocka",
    "2018-05-21-z-jarocina-przez-krobie-do-rydzyny",
    "2018-06-10-wojewodztwo-pomorskie-tez-ma-gorki",
    "2018-06-15-czluchow-i-jezioro-buszewskie",
    "2018-06-16-prawdopodobnie-ostatni-pociag-do-przechlewa",
    "2018-08-03-dwa-swiaty-podlasia",
    "2018-08-13-opuszczenie-podlasia",
    "2018-10-21-wzdluz-jezior-wroczynskich-i-steszewskiego",
    "2018-11-05-spacer-na-przedmiescia",
    "2018-11-29-wietrzny-hel",
    "2018-12-30-warstwy-zimy-pod-snieznikiem",
    "2018-12-31-kiedy-nie-jechac-do-pragi",
    "2019-01-10-dotarcie-do-strzechy-akademickiej",
    "2019-01-11-pierwszy-wschod-na-sniezce",
    "2019-01-12-przez-snieg-do-pielgrzymow",
    "2019-02-24-gdansk-po-zmroku",
    "2019-03-17-trojanowo-przed-wiosna",
    "2019-03-23-z-pleszewa-do-konina",
    "2019-03-24-krotki-spacer-w-gluszynie",
    "2019-03-30-okolice-opalenicy",
    "2019-03-31-kokoryczkowe-wzgorze",
    "2019-04-06-zachodnie-okolice-skokow",
    "2019-04-07-okolice-lednogory-i-pobiedzisk",
    "2019-04-18-ucieczka-do-wpn",
    "2019-04-22-kolejny-dojazd-do-opalenicy",
    "2019-04-30-zolte-pola-w-okolicy-ilawy",
    "2019-05-01-pierwsza-setka-na-pierwszego-maja",
    "2019-05-02-ucieczka-przed-zimnem",
    "2019-05-11-najbardziej-zielona-wiosna",
    "2019-05-12-tunel-do-piechowic",
    "2019-05-19-z-trzemeszna-do-poznania",
    "2019-06-01-przez-lubuskie-wioski-do-lubniewic",
    "2019-06-09-pomorska-dziura-transportowa",
    "2019-06-16-okolice-murowanej-gosliny",
    "2019-06-20-parowozem-przez-pile-do-stargardu",
    "2019-06-23-z-pleszewa-do-rawicza",
    "2019-07-07-wyjatkowo-zimny-weekend-tego-lata",
    "2019-07-14-omijajac-drogi-gruntowe",
    "2019-08-03-suche-i-mokre-zachodniopomorskie",
    "2019-08-07-wielkopolska-balonem",
    "2019-08-09-wejscie-na-praded",
    "2019-08-10-spacer-w-olomuncu",
    "2019-08-11-zlaty-chlum-i-wschodnie-okolice-jesionika",
    "2019-08-12-elektrownia-dlouhe-strane",
    "2019-09-07-kolejowa-okolica-zagania",
    "2019-10-05-przez-mokry-las",
    "2019-12-01-eksploracja-warmii-samochodem",
    "2019-12-28-stronie-slaskie-i-okolica",
    "2020-01-01-wschody-i-zachody-na-sniezniku",
    "2020-01-02-opuszczenie-snieznika",
    "2020-01-18-prawie-zima-na-trojgarbie",
    "2020-01-19-wokol-zbiornika-bukowka",
    "2020-02-08-polaczenie-rzek-welny-i-flinty",
    "2020-02-22-wyjatkowa-zima-w-sniezycowym-jarze",
    "2020-03-21-pagorki-w-okolicy-puszczy-zielonki",
    "2020-03-28-tlumy-przy-warcie",
    "2020-04-20-jak-wyjscie-z-wiezienia",
    "2020-04-23-wiosenna-gluszyna",
    "2020-04-25-okolica-wierzonki-rowerem",
    "2020-04-26-nadwarcianskie-lasy-radojewa",
    "2020-05-01-wiosenny-wpn",
    "2020-05-08-setka-w-czasie-zarazy",
    "2020-05-09-dzikie-okolice-mosiny",
    "2020-05-10-okolice-wiatrowa",
    "2020-05-16-dzien-zmiany-planow",
    "2020-05-17-zachodnie-okolice-lopuchowa",
    "2020-05-22-dojazd-do-sierakowa-przez-puszcze",
    "2020-05-22-polnocno-zachodnie-okolice-sierakowa",
    "2020-05-23-kraina-stu-jezior",
    "2020-05-24-puszcza-notecka-i-mialy",
    "2020-05-30-wioski-na-zachod-od-poznania",
    "2020-06-04-myslalem-ze-bedzie-ladniej",
    "2020-06-05-myslalem-ze-bedzie-padalo-pozniej",
    "2020-06-06-mialo-by-ladnie-i-bylo",
    "2020-06-12-odwrotna-pomorska-500",
    "2020-06-13-pierwsza-upalna-ucieczka",
    "2020-06-14-w-poszukiwaniu-makow",
    "2020-06-24-susza-i-deszcz",
    "2020-07-04-poludniowe-okolice-krajenskiego-parku",
    "2020-07-11-jezioro-lubowko-i-zagorze",
    "2020-07-11-nadnoteckimi-wsiami-do-drezdenka",
    "2020-07-11-wieczorne-drezdenko",
    "2020-07-12-puszcza-i-laka-notecka",
    "2020-07-21-szukajac-zboza-przed-zniwami",
    "2020-07-25-pociagiem-do-skandawy-i-bartoszyc",
    "2020-07-26-polnocno-wschodni-kraniec-kolejowy",
    "2020-07-27-odciete-stacje-kolejowe",
    "2020-07-27-pociagiem-do-lidzbarku",
    "2020-08-01-suche-okolice-lagowa",
    "2020-08-02-lubuskie-miejsca-rekreacji",
    "2020-08-16-logika-polaczen-intercity",
    "2020-08-17-pogarda-dla-przyrody",
    "2020-08-18-deszczowa-rzepedka",
    "2020-08-19-wsie-na-krancu-beskidu-niskiego",
    "2020-08-20-popoludnie-w-beskidzie-niskim",
    "2020-08-20-wejscie-na-tokarnie",
    "2020-08-21-bieszczadzka-kolej-lesna",
    "2020-08-21-jeziora-duszatynskie",
    "2020-08-21-mgly-nad-rzepedzia",
    "2020-08-22-lopienka-i-zachodnie-bieszczady",
    "2020-09-05-na-wschod-od-ostrzeszowa",
    "2020-09-06-lodzkie-zakamarki-i-stare-domy",
    "2020-09-12-nekielskie-lasy",
    "2020-09-22-ostatnie-podrygi-lata",
    "2020-10-03-szybki-przejazd-zachodnia-wielkopolska",
    "2020-10-10-kolejowe-roztocze-i-okolice-przemysla",
    "2020-10-11-kolejowe-bieszczady",
    "2020-10-17-spacer-do-bielawy",
    "2020-10-18-sowie-wioski",
    "2020-11-01-okolica-jeziora-brzezno",
    "2020-11-03-jesien-w-okolicach-dobiegniewa",
    "2020-11-07-szary-listopad",
    "2020-11-15-piekna-wiosna-tej-jesieni",
    "2020-11-22-fale-w-kolobrzegu",
    "2021-01-16-prawdziwa-zima",
    "2021-01-17-szukajac-idealnego-zachodu",
    "2021-02-06-nie-warto-bylo",
    "2021-03-19-lekka-zamiec-w-prudniku",
    "2021-03-19-miedzy-strzelinem-a-nysa",
    "2021-03-20-wejscie-na-biskupia-kope",
    "2021-03-21-deszczowa-eksploracja-opolskiego",
    "2021-03-31-przedwiosnie-obok-zielonki",
    "2021-04-11-koniec-lenistwa",
    "2021-05-09-pociagiem-do-lomzy",
    "2021-05-10-ucieczka-do-kobylnicy",
    "2021-05-28-warszawa-modlin-i-lazienki",
    "2021-05-31-eksploracja-przyrody-przy-warcie",
    "2021-06-03-pociagiem-z-kutna-do-wierzchucina",
    "2021-06-11-zulawskie-wioski",
    "2021-06-12-mokra-warmia",
    "2021-06-13-warmia-jest-piekna",
    "2021-06-29-zachod-w-juracie",
    "2021-06-30-hel-na-spokojnie",
    "2021-07-03-z-nowego-tomysla-do-czempinia",
    "2021-07-04-zakamarki-pobiedzisk",
    "2021-07-18-pagorki-przed-zniwami",
    "2021-07-24-w-trakcie-zniw",
    "2021-07-31-trzy-razy-wystarczy",
    "2021-08-07-jak-sie-robi-male-motylki",
    "2021-08-08-gdzie-dzikie-laki-sa",
    "2021-08-14-tam-gdzie-woda-tam-tlumy",
    "2021-08-17-miedzy-stryszawa-a-zawoja",
    "2021-08-18-wejscie-na-babia-gore",
    "2021-08-19-wejscie-na-jalowiec",
    "2021-08-20-okolice-zawoi",
    "2021-08-22-stare-juchy-do-ketrzyna",
    "2021-08-23-szukajac-spokojnej-drogi",
    "2021-08-24-polnocne-okolice-korsza",
    "2021-08-25-blisko-granicy-z-rosja",
    "2021-08-26-krotki-spacer-w-stawkach",
    "2021-08-29-petla-po-polsce",
    "2021-09-05-poludniowy-brzeg-jeziora-steszewskiego",
    "2021-09-19-wzgorza-trzebnickie",
    "2021-09-26-rowerem-wokol-jeziora-kowalskiego",
    "2021-10-02-nie-ten-rower-co-trzeba",
    "2021-10-03-juz-sie-mi-nie-chcialo",
    "2021-10-09-okolice-jeziora-folusz",
    "2021-10-10-dolina-rzeki-trojanki",
    "2021-10-20-jesien-awaryjna",
    "2021-10-25-jesien-nieudana",
    "2021-11-11-polowanie-na-mgielki-cz-2",
    "2021-12-05-zamiec",
    "2021-12-12-zimowa-mgla",
    "2021-12-13-resztka-zimy",
    "2021-12-19-szare-owinska",
    "2021-12-25-wschod-w-lososincu",
    "2021-12-27-zachod-slonca-w-dusznie",
    "2022-01-10-co-jest-ciekawego-w-lesie",
    "2022-01-22-zima-nad-warta",
    "2022-02-05-wzgorza-pobiedzisk",
    "2022-02-13-wokol-jeziora-wierzbiczanskiego",
    "2022-03-05-wokol-jeziora-witoslawskiego",
    "2022-03-13-rowerowe-rozpoczecie-sezonu",
    "2022-04-08-mokry-kampinos",
    "2022-04-09-rezerwat-przelom-witkowki",
    "2022-04-10-pociagiem-do-ciechocinka",
    "2022-04-18-eksploracja-potulic",
    "2022-04-23-notec-i-polnocna-wielkopolska",
    "2022-04-29-spokoj-i-pagorki",
    "2022-04-30-kocie-lby-i-piaski",
    "2022-05-01-szybko-do-dobiegniewa",
    "2022-05-02-poludniowe-okolice-stargardu",
    "2022-05-03-opuszczenie-majowki-do-choszczna",
    "2022-05-07-nie-trzeba-jechac-daleko",
    "2022-05-14-okolice-welny-z-wiatrem",
    "2022-06-05-zlot-m43",
    "2022-06-13-szukajac-makow",
    "2022-06-16-okolice-rzeki-cybiny",
    "2022-06-18-okolice-brodnicy",
    "2022-06-24-przed-upalem",
    "2022-07-02-pomorskimi-lasami",
    "2022-07-03-z-bialogardu-do-szczecinka",
    "2022-07-04-poludniowe-okolice-szczecinka",
    "2022-07-16-okolice-miedzyrzecza-przed-zniwami",
    "2022-07-17-motyle-przy-obrze",
    "2022-07-22-pole-podczas-zachodu",
    "2022-07-23-zaskoczony-przez-pogode",
    "2022-07-31-bardo-wieczorem",
    "2022-08-01-przygoda-z-elektrykiem",
    "2022-08-02-arboretum-wojslawice",
    "2022-08-20-okolice-starego-bukowca",
    "2022-08-23-wzdluz-warty",
    "2022-08-27-goracy-poranek-obok-gniezna",
    "2022-08-28-brzezno-wioska-kotow",
    "2022-10-12-nadwarcianskie-mgly",
    "2022-10-16-jesien-minimalna",
    "2022-10-30-jesien-rowerowa",
    "2022-10-31-mgla-w-wagrowcu",
    "2022-11-01-las-niedaleko-lopuchowa",
    "2022-12-18-zdazyc-przed-koncem-zimy",
    "2023-02-04-jezioro-tomickie",
    "2023-03-18-okolice-jeziora-kowalskiego",
    "2023-04-16-podejrzane-chmury",
    "2023-04-21-testujac-rower-i-drona",
    "2023-04-30-jak-to-z-ta-wiosna",
    "2023-05-01-majowki-w-tym-roku-nie-ma",
    "2023-05-07-miedzy-tucznem-a-jerzykowem",
    "2023-05-27-piaszczysta-puszcza-zielonka",
    "2023-05-28-cieply-poranek",
    "2023-05-28-warta-zachod-slonca-dron",
    "2023-06-25-szukajac-pofalowanych-pol",
    "2023-07-07-przed-fala-upalow",
    "2023-07-21-jak-sie-dostac-do-miedzychodu",
    "2023-08-05-jedna-z-ladniejszych-wiosek",
    "2024-01-09-nadeszla-zima",
    "2024-01-17-jeszcze-lepsza-zima",
    "2024-05-03-dawno-nie-bylo-tak-ciezko",
    "2024-10-21-okolica-zagorza-slaskiego",
    "2024-10-21-swidnica-miasto",
    "2024-10-22-aby-wykorzystac-wczesniejszy-powrot",
  ],
}

# --- Geotagging logic ---

record TrackPoint, time : Time, lat : Float64, lon : Float64, ele : Float64?, atemp : Float64?

GPX_DIR      = "tmp/gpx"
IMAGES_DIR   = "env/full/data/images"
EXIF_CACHE   = "env/full/cache/exifs"
WARSAW       = Time::Location.load("Europe/Warsaw")
MAX_DIFF     = 3600  # max seconds between photo time and nearest trackpoint
OFFSET_TRIES = [-7200.0, -3600.0, 0.0, 3600.0, 7200.0] # timezone offset candidates

WRITE_MODE = ARGV.includes?("--write")

# Manual timezone offset override (seconds)
MANUAL_OFFSET = ARGV.find(&.starts_with?("--offset=")).try { |a| a.split("=")[1].to_f64 }

# --- GPX parsing ---

private def parse_gpx(path : String) : Array(TrackPoint)
  points = [] of TrackPoint
  doc = XML.parse(File.read(path))
  root = doc.root
  return points unless root
  collect_trkpts(root, points)
  points
rescue ex
  STDERR.puts "  Warning: #{File.basename(path)}: #{ex.message}"
  [] of TrackPoint
end

private def collect_trkpts(node : XML::Node, result : Array(TrackPoint))
  if node.name == "trkpt"
    lat = node["lat"]?.try(&.to_f64?)
    lon = node["lon"]?.try(&.to_f64?)
    time_text : String? = nil
    ele : Float64? = nil
    atemp : Float64? = nil
    node.children.each do |child|
      case child.name
      when "time"
        time_text = child.text.try(&.strip)
      when "ele"
        ele = child.text.try(&.strip.to_f64?)
      when "extensions"
        # Search for atemp in Garmin extensions (gpxtpx:atemp)
        atemp = find_atemp(child)
      end
    end
    if lat && lon && time_text && !time_text.empty?
      time = Time.parse_iso8601(time_text)
      result << TrackPoint.new(time: time, lat: lat, lon: lon, ele: ele, atemp: atemp)
    end
  else
    node.children.each { |child| collect_trkpts(child, result) }
  end
end

private def find_atemp(node : XML::Node) : Float64?
  if node.name == "atemp"
    return node.text.try(&.strip.to_f64?)
  end
  node.children.each do |child|
    if val = find_atemp(child)
      return val
    end
  end
  nil
end

# Build date-indexed trackpoints from all GPX files
private def build_index : Hash(String, Array(TrackPoint))
  index = Hash(String, Array(TrackPoint)).new { |h, k| h[k] = [] of TrackPoint }
  files = Dir.glob(File.join(GPX_DIR, "*.gpx"))
  puts "Loading #{files.size} GPX files..."
  total = 0
  files.each_with_index do |path, i|
    pts = parse_gpx(path)
    pts.each { |pt| index[pt.time.to_s("%Y-%m-%d")] << pt }
    total += pts.size
    print "\r  #{i + 1}/#{files.size} files, #{total} trackpoints" if (i + 1) % 100 == 0
  end
  puts "\r  #{files.size} files, #{total} trackpoints across #{index.size} days"
  index.each_value(&.sort_by!(&.time))
  index
end

# --- EXIF reading ---

# Read EXIF DateTimeOriginal and check GPS presence in a single exiv2 call
private def read_exif(path : String) : {Time?, Bool}
  stdout = IO::Memory.new
  Process.run("exiv2",
    ["-g", "Exif.Photo.DateTimeOriginal", "-g", "Exif.GPSInfo.GPSLatitude", path],
    output: stdout, error: Process::Redirect::Close)
  output = stdout.to_s
  has_gps = output.includes?("GPSLatitude")
  time : Time? = nil
  if output =~ /DateTimeOriginal\s+\w+\s+\d+\s+(\d{4}:\d{2}:\d{2} \d{2}:\d{2}:\d{2})/
    time = Time.parse($1, "%Y:%m:%d %H:%M:%S", WARSAW)
  end
  {time, has_gps}
rescue
  {nil, false}
end

# --- GPS interpolation ---

# Find interpolated position at target time (linear between two nearest trackpoints).
# Returns {lat, lon, ele, seconds_to_nearest_point} or nil.
private def find_position(points : Array(TrackPoint), target : Time) : {Float64, Float64, Float64?, Float64}?
  return nil if points.empty?
  idx = points.bsearch_index { |pt| pt.time >= target } || points.size

  # Before all points — snap to first
  if idx == 0
    p = points[0]
    return {p.lat, p.lon, p.ele, (p.time - target).total_seconds.abs}
  end

  # After all points — snap to last
  if idx >= points.size
    p = points.last
    return {p.lat, p.lon, p.ele, (target - p.time).total_seconds.abs}
  end

  # Between two points — linear interpolation
  p1 = points[idx - 1]
  p2 = points[idx]
  gap = (p2.time - p1.time).total_seconds

  if gap <= 0
    return {p1.lat, p1.lon, p1.ele, 0.0}
  end

  t = (target - p1.time).total_seconds / gap
  lat = p1.lat + (p2.lat - p1.lat) * t
  lon = p1.lon + (p2.lon - p1.lon) * t
  ele = if (e1 = p1.ele) && (e2 = p2.ele)
    e1 + (e2 - e1) * t
  else
    p1.ele || p2.ele
  end

  nearest_diff = {(target - p1.time).total_seconds, (p2.time - target).total_seconds}.min
  {lat, lon, ele, nearest_diff}
end

# Find closest single trackpoint (for timezone calibration)
private def find_closest(points : Array(TrackPoint), target : Time) : {TrackPoint, Float64}?
  return nil if points.empty?
  idx = points.bsearch_index { |pt| pt.time >= target } || points.size
  best : TrackPoint? = nil
  best_diff = Float64::INFINITY

  {idx - 1, idx}.each do |i|
    next if i < 0 || i >= points.size
    diff = (points[i].time - target).total_seconds.abs
    if diff < best_diff
      best = points[i]
      best_diff = diff
    end
  end

  best ? {best, best_diff} : nil
end

# --- Timezone offset detection ---

# Round seconds to nearest whole hour (camera clocks are typically off by whole hours)
private def round_to_hour(seconds : Float64) : Float64
  (seconds / 3600.0).round * 3600.0
end

# For partial_missing posts: calibrate offset from photos that already have GPS.
# Compares EXIF timestamps of GPS-tagged photos against nearest trackpoints.
private def detect_offset_from_gps_photos(images : Array(String), day_points : Array(TrackPoint)) : Float64
  offsets = [] of Float64
  images.each do |img|
    exif_time, has_gps = read_exif(img)
    next unless has_gps && exif_time
    target_utc = exif_time.to_utc
    result = find_closest(day_points, target_utc)
    next unless result
    pt, diff = result
    next if diff > 7200 # skip outliers
    offsets << (target_utc - pt.time).total_seconds
    break if offsets.size >= 20 # enough samples
  end
  return 0.0 if offsets.empty?
  offsets.sort!
  median = offsets[offsets.size // 2]
  round_to_hour(median)
end

# For all_missing posts: try offset candidates, pick the one with most matches.
private def detect_offset_bruteforce(images : Array(String), day_points : Array(TrackPoint)) : Float64
  # Read all EXIF times first
  exif_times = [] of Time
  images.each do |img|
    exif_time, _ = read_exif(img)
    exif_times << exif_time.not_nil!.to_utc if exif_time
  end
  return 0.0 if exif_times.empty?

  best_offset = 0.0
  best_matched = 0
  best_avg_diff = Float64::INFINITY

  OFFSET_TRIES.each do |offset|
    matched = 0
    total_diff = 0.0
    exif_times.each do |t|
      adjusted = t - offset.seconds
      result = find_closest(day_points, adjusted)
      next unless result
      _, diff = result
      if diff < MAX_DIFF
        matched += 1
        total_diff += diff
      end
    end
    next if matched == 0
    avg = total_diff / matched
    if matched > best_matched || (matched == best_matched && avg < best_avg_diff)
      best_offset = offset
      best_matched = matched
      best_avg_diff = avg
    end
  end

  best_offset
end

# --- GPS writing ---

private def write_gps(path : String, lat : Float64, lon : Float64, ele : Float64?) : Bool
  lat_ref = lat >= 0 ? "N" : "S"
  lon_ref = lon >= 0 ? "E" : "W"
  args = [
    "-GPSLatitude=#{lat.abs}",
    "-GPSLatitudeRef=#{lat_ref}",
    "-GPSLongitude=#{lon.abs}",
    "-GPSLongitudeRef=#{lon_ref}",
  ]
  if ele
    args << "-GPSAltitude=#{ele.abs}"
    args << "-GPSAltitudeRef=#{ele >= 0 ? "Above Sea Level" : "Below Sea Level"}"
  end
  args << "-overwrite_original"
  args << path

  if !WRITE_MODE
    elev = ele ? " alt=#{ele.round(1)}m" : ""
    puts "    [DRY RUN] #{File.basename(path)}: #{lat.round(6)},#{lon.round(6)}#{elev}"
    true
  else
    Process.run("exiftool", args,
      output: Process::Redirect::Close, error: Process::Redirect::Close).success?
  end
end

# Delete EXIF cache for post (forces regeneration on next render)
private def delete_exif_cache(slug : String)
  cache_path = File.join(EXIF_CACHE, "#{slug}.yml")
  if File.exists?(cache_path)
    if !WRITE_MODE
      puts "  [DRY RUN] would delete #{cache_path}"
    else
      File.delete(cache_path)
      puts "  Deleted EXIF cache: #{cache_path}"
    end
  end
end

# Get trackpoints for ±1 day around date (handles timezone edge cases)
private def get_day_points(index : Hash(String, Array(TrackPoint)), date : String) : Array(TrackPoint)
  date_utc = Time.parse(date, "%Y-%m-%d", Time::Location::UTC)
  [-1, 0, 1]
    .flat_map { |offset| index[(date_utc + offset.days).to_s("%Y-%m-%d")]? || [] of TrackPoint }
    .sort_by(&.time)
end

# Calculate mode temperature from trackpoints (most common integer value).
# Filters out extreme readings (sun heating sensor) by using the mode.
private def mode_temperature(points : Array(TrackPoint)) : Int32?
  counts = Hash(Int32, Int32).new(0)
  points.each do |pt|
    if temp = pt.atemp
      counts[temp.round.to_i] += 1
    end
  end
  return nil if counts.empty?
  counts.max_by { |_, count| count }[0]
end

# --- Main ---

puts WRITE_MODE ? "=== WRITE MODE ===" : "=== DRY RUN (use --write to apply) ==="
if offset = MANUAL_OFFSET
  puts "Manual offset: #{offset.to_i}s (#{(offset / 3600).round(1)}h)"
end
puts ""

index = build_index

# To scan all photos later, change this to: Dir.glob("env/full/data/images/**/*.jpg")
# and group by post slug.
slugs = GEOTAGGING_STATUS[:all_missing] +
        GEOTAGGING_STATUS[:partial_missing] +
        GEOTAGGING_STATUS[:only_header_missing]

all_missing_set = GEOTAGGING_STATUS[:all_missing].to_set

puts "\nProcessing #{slugs.size} posts...\n"

total_tagged = 0
total_already = 0
total_no_time = 0
total_no_match = 0
total_too_far = 0
total_photos = 0
posts_no_gpx = 0
posts_no_dir = 0
posts_changed = [] of String

slugs.each do |slug|
  year = slug[0..3]
  dir = File.join(IMAGES_DIR, year, slug)

  unless Dir.exists?(dir)
    puts "  #{slug}: image dir not found"
    posts_no_dir += 1
    next
  end

  date = slug[0..9]
  day_points = get_day_points(index, date)

  if day_points.empty?
    puts "  #{slug}: no GPX data for #{date}"
    posts_no_gpx += 1
    next
  end

  # Report mode temperature for this day's track
  if temp = mode_temperature(day_points)
    puts "  #{slug}: ~#{temp}°C"
  end

  images = Dir.glob(File.join(dir, "*.jpg")) +
           Dir.glob(File.join(dir, "*.JPG")) +
           Dir.glob(File.join(dir, "*.jpeg"))
  total_photos += images.size

  # Detect timezone offset
  offset = if mo = MANUAL_OFFSET
    mo
  elsif all_missing_set.includes?(slug)
    detect_offset_bruteforce(images, day_points)
  else
    detect_offset_from_gps_photos(images, day_points)
  end

  if offset != 0.0
    puts "  #{slug}: detected offset #{offset.to_i}s (#{(offset / 3600).round(1)}h)"
  end

  tagged = 0
  no_gps_count = 0

  images.each do |img|
    fname = File.basename(img)
    exif_time, has_gps = read_exif(img)

    if has_gps
      total_already += 1
      next
    end

    no_gps_count += 1

    unless exif_time
      total_no_time += 1
      next
    end

    # Apply timezone offset: subtract detected camera clock error
    target_utc = exif_time.to_utc - offset.seconds
    result = find_position(day_points, target_utc)

    unless result
      total_no_match += 1
      next
    end

    lat, lon, ele, diff = result
    if diff > MAX_DIFF
      puts "    #{fname}: nearest trackpoint #{diff.to_i}s away (limit #{MAX_DIFF}s)"
      total_too_far += 1
      next
    end

    elev = ele ? " alt=#{ele.not_nil!.round(1)}m" : ""
    puts "    #{fname} → #{lat.round(6)},#{lon.round(6)}#{elev} (#{diff.to_i}s)"
    if write_gps(img, lat, lon, ele)
      tagged += 1
      total_tagged += 1
    end
  end

  if tagged > 0
    posts_changed << slug
    puts "  #{slug}: #{tagged}/#{images.size} tagged (#{no_gps_count} had no GPS)"
    delete_exif_cache(slug)
  elsif no_gps_count > 0
    puts "  #{slug}: #{no_gps_count}/#{images.size} without GPS, 0 matched"
  end
end

puts "\n=== Summary ==="
puts "  Total photos:  #{total_photos}"
puts "  Already GPS:   #{total_already}"
puts "  Tagged:        #{total_tagged}"
puts "  No EXIF time:  #{total_no_time}"
puts "  No GPX match:  #{total_no_match}"
puts "  Too far:       #{total_too_far}"
puts "  Posts no GPX:  #{posts_no_gpx}"
puts "  Posts no dir:  #{posts_no_dir}"
puts "  Posts changed: #{posts_changed.size}"
if posts_changed.any?
  puts "\n  Changed posts:"
  posts_changed.each { |s| puts "    #{s}" }
end
