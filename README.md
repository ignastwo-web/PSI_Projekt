# PSI_Projekt
Projekt końcowy z przedmiotu Projektowanie Systemów Informacyjnych

Na projekt składa się skrypt w języku R.

Jako benchmark testowy umieściliśmy test dla wypowiedzi Leszka Milera. 
Analiza opiera się na autorskim słowniku sentymentu politycznego. (Plik: slownik_polityczny_pl) Lub można zmienić na szerszy slownik_polityczny_lematy
Do analizy użyliśmy lematyzacji, żeby kod brał pod uwagę słowa odmienione np. dobro/dobry jako ten sam sentyment.

---Jak uruchomić---

Pobrać pliki:
analiza_polityczna_v2.R
slownik_polityczny_Pl.csv lub slownik_polityczny_lematy
Pliki (.txt) do analizy -> w kodzie jest wektor tekstów, więc możesz ich ładować aż miło

Wszystkie powyższe pliki najlepiej trzymaj w jednym pliku - np. projekt_PSI

Walka z kodem:

1. Zainstaluj pakiety (28 i 29 linijka kodu): 
install.packages(c("udpipe", "tidyverse", "ggplot2", "ggthemes",
                   "wordcloud", "RColorBrewer", "stringr", "tm"))
   
2.Pobierz model języka polskiego, wcześniej wczytaj biblioteke library(udpipe)[wiersz 67]:

udpipe_download_model(language = "polish-lfg")

3. W konsoli pojawi się komunikat z informacją gdzie plik się pobrał, np.:
model stored at 'C:/Users/TwojeImie/Documents/polish-lfg-ud-2.5-191206.udpipe'
Skopiuj tę ścieżkę — będzie potrzebna w następnym kroku.

4.Ustaw ścieżkę do modelu w skrypcie:
Znajdź wiersz 70 (sekcja 3) i wklej tam skopiowaną ścieżkę:
rmodel_pl <- udpipe_load_model("C:/Users/TwojeImie/Documents/polish-lfg-ud-2.5-191206.udpipe")
Zamień C:/Users/Documents/... na ścieżkę którą skopiowałeś.

5. Możesz zakomentować wiersz 67, żeby model języka polskiego nie pobierał sie za każdym razem.

6.Ustaw katalog roboczy: wiersz 47 zmień na adres twojego katalogu.

7. W sekcji 6 skryptu (wiersze 184–219) są cztery miejsca oznaczone komentarzem # <== WSTAW TUTAJ. W każdym miejscu wpisz ścieżki do plików .txt dla danej grupy.

8.Uruchom Kod.

9*. W sekcji 12 znajduje się test, na którym sprawdzisz czy pipeline 

Efekty:
sekcja    co pokazuje
7           top 20 najczęstrzysz słow w każdej grupie
8           liczba słów pozytywnych i negatywnych  / proporcje
9           które konkretne słowa napędzają sentyment
10          porównanie wskaźnika pozytywności władza vs opozycja
11          chmury słów dla każdej grupy

