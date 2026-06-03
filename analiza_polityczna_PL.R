# ============================================================
# ANALIZA SENTYMENTU I LICZEBNOŚCI SŁÓW
# Wypowiedzi polityków PiS i PO – władza vs. opozycja
# ============================================================
#
# JAK UŻYWAĆ TEGO SKRYPTU:
#
#  1. Zainstaluj pakiety (sekcja 1) – tylko przy pierwszym uruchomieniu
#  2. Ustaw ścieżkę do folderu roboczego (sekcja 2)
#  3. Wstaw ścieżki do plików z wypowiedziami (sekcja 3)
#     – szukaj komentarzy: # <== WSTAW TUTAJ
#  4. Uruchom cały skrypt (Ctrl+Shift+Enter w RStudio)
#
# WYMAGANA STRUKTURA PLIKÓW:
#   Każdy plik .txt = jedna wypowiedź jednego polityka
#   Kodowanie: UTF-8
#   Przykładowe nazwy: kaczynski_2016.txt, tusk_2010.txt
#
# ============================================================



# ============================================================
# 1. PAKIETY ----
# ============================================================

# Odkomentuj i uruchom raz przy pierwszym użyciu:
# install.packages(c("udpipe", "tidyverse", "ggplot2", "ggthemes",
#                   "wordcloud", "RColorBrewer", "stringr", "tm"))

library(udpipe)      # lematyzacja po polsku
library(tidyverse)
library(ggplot2)
library(ggthemes)
library(wordcloud)
library(RColorBrewer)
library(stringr)
library(tm)



# ============================================================
# 2. KONFIGURACJA ----
# ============================================================

# Ustaw katalog roboczy – folder gdzie masz ten skrypt i słownik:
# setwd("C:/Users/Lenovo/Desktop/projekt_PSI")   # Windows


# Wczytaj słownik sentymentu (plik musi być w katalogu roboczym):
slownik <- read.csv("slownik_polityczny_pl.csv",
                    stringsAsFactors = FALSE,
                    encoding = "UTF-8")

# Podgląd słownika:
cat("Słownik wczytany:", nrow(slownik), "słów\n")
cat("Pozytywnych:", sum(slownik$sentyment == "pozytywny"), "\n")
cat("Negatywnych:", sum(slownik$sentyment == "negatywny"), "\n")



# ============================================================
# 3. MODEL LEMATYZACJI (udpipe) ----
# ============================================================

# Przy pierwszym uruchomieniu pobierz model (ok. 80 MB, tylko raz):
 udpipe_download_model(language = "polish-lfg")

# Wczytaj model (podaj ścieżke pobranego pliku z 67 wiersza (consola powinna podac ścieżke)):
model_pl <- udpipe_load_model("C:/Users/Lenovo/Documents/polish-lfg-ud-2.5-191206.udpipe")

# Jeśli nazwa pliku modelu jest inna, sprawdź:
# list.files(pattern = "\\.udpipe$")



# ============================================================
# 4. POLSKIE STOP WORDS ----
# ============================================================

stopwords_pl <- c(
  "pani", "pan", "panie", "panu", "panią",
  "wysoka", "izba", "izbo", "izbie",
  "marszałek", "marszałku", "marszałkiem",
  "premier", "premierze", "premiera",
  "poseł", "posłowie", "posła",
  "klub", "klubu", "klubów",
  "sejm", "sejmu", "sejmie",
  "który", "która", "które", "którą", "których", "którym",
  "ten", "ta", "to", "tego", "tej", "temu", "tą", "tę",
  "się", "że", "jak", "co", "czy", "oraz", "czyli",
  "właśnie", "jednak", "tylko", "bardzo", "jeszcze",
  "jego", "jej", "ich", "im", "go", "nas", "nam",
  "przed", "przez", "przy", "pod", "po", "ze", "nad",
  "oklaski", "dzwonek", "wesołość", "sali", "głos",  # adnotacje stenogramów
  "powiedzieć", "mówić", "stwierdzić", "zaznaczyć"   # czasowniki metatekstowe
)
stopwords_pl <- unique(stopwords_pl)



# ============================================================
# 5. FUNKCJE POMOCNICZE ----
# ============================================================

# --- 5a. Lematyzacja i czyszczenie jednego pliku ---
lematyzuj_plik <- function(sciezka, model) {

  tekst <- paste(readLines(sciezka, encoding = "UTF-8", warn = FALSE),
                 collapse = " ")

  # Usunięcie adnotacji stenograficznych w nawiasach: (Oklaski), (Dzwonek) itp.
  tekst <- gsub("\\([^)]*\\)", " ", tekst)

  # Lematyzacja przez udpipe
  anotacja <- udpipe_annotate(model, x = tekst, trace = FALSE)
  df       <- as.data.frame(anotacja)

  # Zachowujemy tylko lematy słów (bez interpunkcji, liczb, symboli)
  lematy <- df %>%
    filter(upos %in% c("NOUN", "VERB", "ADJ", "ADV")) %>%
    pull(lemma) %>%
    tolower() %>%
    str_trim()

  # Usunięcie stop words i bardzo krótkich tokenów
  lematy <- lematy[!(lematy %in% stopwords_pl)]
  lematy <- lematy[nchar(lematy) > 2]
  lematy <- lematy[!is.na(lematy)]

  return(lematy)
}


# --- 5b. Tabela częstości z metadanymi ---
czestosci <- function(lematy, partia, status) {
  if (length(lematy) == 0) return(NULL)
  freq <- table(lematy)
  data.frame(
    word   = names(freq),
    freq   = as.numeric(freq),
    partia = partia,
    status = status,
    grupa  = paste(partia, "–", status),
    stringsAsFactors = FALSE
  ) %>% arrange(desc(freq))
}


# --- 5c. Przetwarza listę plików i zwraca połączoną tabelę ---
przetworz_liste <- function(lista_plikow, partia, status, model) {
  wszystkie <- lapply(lista_plikow, function(p) {
    cat("  Przetwarzam:", basename(p), "\n")
    lematy <- tryCatch(
      lematyzuj_plik(p, model),
      error = function(e) { warning(e$message); return(character(0)) }
    )
    czestosci(lematy, partia, status)
  })
  bind_rows(wszystkie) %>%
    group_by(word, partia, status, grupa) %>%
    summarise(freq = sum(freq), .groups = "drop") %>%
    arrange(desc(freq))
}



# ============================================================
# 6. WCZYTANIE PLIKÓW Z WYPOWIEDZIAMI ----
# ============================================================
#
# Wstaw ścieżki do swoich plików poniżej.
# Możesz podać:
#   - pojedynczy plik:  c("sciezka/plik1.txt")
#   - wiele plików:     c("plik1.txt", "plik2.txt", "plik3.txt")
#   - cały folder:      list.files("folder/", pattern="\\.txt$", full.names=TRUE)
#


cat("\n=== PRZETWARZANIE DANYCH ===\n")

# -- PiS u WŁADZY --
cat("\nPiS – władza:\n")
pis_wladza_pliki <- c(
  # <== WSTAW TUTAJ ścieżki do plików wypowiedzi PiS gdy byli u władzy
  # Przykład: "dane/pis_wladza/kaczynski_2016.txt",
  #           "dane/pis_wladza/szydlo_2017.txt"
)
dane_pis_wladza <- przetworz_liste(pis_wladza_pliki, "PiS", "władza", model_pl)


# -- PiS w OPOZYCJI --
cat("\nPiS – opozycja:\n")
pis_opozycja_pliki <- c(
  # <== WSTAW TUTAJ ścieżki do plików wypowiedzi PiS gdy byli w opozycji
  # Przykład: "dane/pis_opozycja/kaczynski_2011.txt",
  #           "dane/pis_opozycja/szydlo_2012.txt"
)
dane_pis_opozycja <- przetworz_liste(pis_opozycja_pliki, "PiS", "opozycja", model_pl)


# -- PO u WŁADZY --
cat("\nPO – władza:\n")
po_wladza_pliki <- c(
  # <== WSTAW TUTAJ ścieżki do plików wypowiedzi PO gdy byli u władzy
  # Przykład: "dane/po_wladza/tusk_2010.txt",
  #           "dane/po_wladza/kopacz_2014.txt"
)
dane_po_wladza <- przetworz_liste(po_wladza_pliki, "PO", "władza", model_pl)


# -- PO w OPOZYCJI --
cat("\nPO – opozycja:\n")
po_opozycja_pliki <- c(
  # <== WSTAW TUTAJ ścieżki do plików wypowiedzi PO gdy byli w opozycji
  # Przykład: "dane/po_opozycja/tusk_2017.txt",
  #           "dane/po_opozycja/schetyna_2018.txt"
)
dane_po_opozycja <- przetworz_liste(po_opozycja_pliki, "PO", "opozycja", model_pl)


# Połączenie wszystkich grup:
dane_wszystkie <- bind_rows(
  dane_pis_wladza, dane_pis_opozycja,
  dane_po_wladza,  dane_po_opozycja
)

cat("\nDane wczytane. Łączna liczba unikalnych lematów:", nrow(dane_wszystkie), "\n")



# ============================================================
# 7. ANALIZA LICZEBNOŚCI SŁÓW ----
# ============================================================

cat("\n=== LICZEBNOŚĆ SŁÓW ===\n")

# Top 20 najczęstszych słów w każdej grupie
top_slowa <- dane_wszystkie %>%
  group_by(grupa) %>%
  slice_max(order_by = freq, n = 20) %>%
  ungroup() %>%
  mutate(word2 = reorder_within(word, freq, grupa))

ggplot(top_slowa, aes(x = word2, y = freq, fill = grupa)) +
  geom_col(show.legend = FALSE) +
  facet_wrap(~grupa, scales = "free") +
  coord_flip() +
  scale_x_reordered() +
  scale_fill_manual(values = c(
    "PiS – władza"    = "navy",
    "PiS – opozycja"  = "steelblue",
    "PO – władza"     = "firebrick",
    "PO – opozycja"   = "tomato"
  )) +
  labs(
    title = "Top 20 najczęstszych słów (po lematyzacji)",
    x = NULL, y = "Liczba wystąpień"
  ) +
  theme_gdocs()



# ============================================================
# 8. ANALIZA SENTYMENTU ----
# ============================================================

cat("\n=== ANALIZA SENTYMENTU ===\n")

# Połączenie ze słownikiem (dopasowanie po lemacie)
sentyment_dane <- dane_wszystkie %>%
  inner_join(slownik, by = "word")

# Podsumowanie – łączna liczba wystąpień słów pos/neg w każdej grupie
podsumowanie <- sentyment_dane %>%
  group_by(grupa, partia, status, sentyment) %>%
  summarise(laczna_czestsc = sum(freq), .groups = "drop")

print(podsumowanie)


# -- Wykres 1: Bezwzględna liczba słów nacechowanych --
ggplot(podsumowanie, aes(x = grupa, y = laczna_czestsc, fill = sentyment)) +
  geom_col(position = "dodge") +
  scale_fill_manual(values = c("pozytywny" = "darkolivegreen4",
                               "negatywny" = "firebrick")) +
  labs(
    title    = "Liczba słów nacechowanych wg grupy",
    subtitle = "Suma wystąpień słów z dopasowaniem w słowniku",
    x = NULL, y = "Łączna liczba wystąpień", fill = "Sentyment"
  ) +
  theme_gdocs() +
  theme(axis.text.x = element_text(angle = 15, hjust = 1))


# -- Wykres 2: Proporcja pozytywny vs negatywny --
podsumowanie %>%
  group_by(grupa) %>%
  mutate(udzial = laczna_czestsc / sum(laczna_czestsc)) %>%
  ggplot(aes(x = grupa, y = udzial, fill = sentyment)) +
  geom_col() +
  geom_hline(yintercept = 0.5, linetype = "dashed", color = "gray40") +
  scale_fill_manual(values = c("pozytywny" = "darkolivegreen4",
                               "negatywny" = "firebrick")) +
  scale_y_continuous(labels = scales::percent) +
  labs(
    title    = "Proporcja sentymentu pozytywnego i negatywnego",
    subtitle = "Wyżej = bardziej pozytywny język",
    x = NULL, y = "Udział", fill = "Sentyment"
  ) +
  theme_gdocs() +
  theme(axis.text.x = element_text(angle = 15, hjust = 1))



# ============================================================
# 9. KTÓRE SŁOWA NAPĘDZAJĄ SENTYMENT ----
# ============================================================

# Top 10 słów dla każdej grupy i każdego sentymentu
top_sentyment <- sentyment_dane %>%
  group_by(grupa, sentyment) %>%
  slice_max(order_by = freq, n = 10) %>%
  ungroup() %>%
  mutate(word2 = reorder_within(word, freq, interaction(grupa, sentyment)))

ggplot(top_sentyment, aes(x = word2, y = freq, fill = sentyment)) +
  geom_col(show.legend = FALSE) +
  facet_wrap(~grupa + sentyment, scales = "free", ncol = 4) +
  coord_flip() +
  scale_x_reordered() +
  scale_fill_manual(values = c("pozytywny" = "darkolivegreen4",
                               "negatywny" = "firebrick")) +
  labs(
    title = "Słowa o najsilniejszym sentymencie wg grupy",
    x = NULL, y = "Liczba wystąpień"
  ) +
  theme_gdocs()



# ============================================================
# 10. PORÓWNANIE EFEKTU WŁADZY ----
# ============================================================

# Wskaźnik pozytywności = udział słów pozytywnych w nacechowanych
bilans <- podsumowanie %>%
  pivot_wider(names_from  = sentyment,
              values_from = laczna_czestsc,
              values_fill = 0) %>%
  mutate(
    wskaznik_pozytywnosci = pozytywny / (pozytywny + negatywny),
    bilans                = pozytywny - negatywny
  )

cat("\nBilans sentymentu:\n")
print(bilans %>% select(grupa, pozytywny, negatywny, bilans, wskaznik_pozytywnosci))

# Wykres wskaźnika pozytywności
ggplot(bilans, aes(x = status, y = wskaznik_pozytywnosci,
                   fill = partia, group = partia)) +
  geom_col(position = "dodge") +
  geom_hline(yintercept = 0.5, linetype = "dashed") +
  facet_wrap(~partia) +
  scale_fill_manual(values = c("PiS" = "navy", "PO" = "firebrick")) +
  scale_y_continuous(labels = scales::percent, limits = c(0, 1)) +
  labs(
    title    = "Wskaźnik pozytywności języka",
    subtitle = "Czy partia mówi bardziej pozytywnie będąc u władzy?",
    x = NULL, y = "Udział słów pozytywnych", fill = "Partia"
  ) +
  theme_gdocs()



# ============================================================
# 11. CHMURY SŁÓW ----
# ============================================================

generuj_chmure <- function(dane_df, tytul, paleta = "Dark2") {
  if (is.null(dane_df) || nrow(dane_df) == 0) {
    message("Brak danych dla: ", tytul); return(invisible(NULL))
  }
  wordcloud(words = dane_df$word, freq = dane_df$freq,
            min.freq = 2, max.words = 80,
            colors = brewer.pal(8, paleta), random.order = FALSE)
  title(tytul)
}

par(mfrow = c(2, 2))
generuj_chmure(dane_pis_wladza,   "PiS – władza",    "Blues")
generuj_chmure(dane_pis_opozycja, "PiS – opozycja",  "Purples")
generuj_chmure(dane_po_wladza,    "PO – władza",     "Greens")
generuj_chmure(dane_po_opozycja,  "PO – opozycja",   "Oranges")
par(mfrow = c(1, 1))



# ============================================================
# 12. TEST BENCHMARKOWY – MILLER ----
# ============================================================
# Uruchom tę sekcję osobno, żeby sprawdzić czy pipeline działa
# zanim wstawisz właściwe dane.

cat("\n=== TEST BENCHMARKOWY: MILLER ===\n")

# <== WSTAW TUTAJ ścieżkę do pliku benchmarkowego Millera:
plik_miller <- "C:/Users/Lenovo/Desktop/projekt_PSI/Miller_benchmark.txt"

lematy_miller <- lematyzuj_plik(plik_miller, model_pl)

freq_miller <- data.frame(
  word = names(table(lematy_miller)),
  freq = as.numeric(table(lematy_miller)),
  stringsAsFactors = FALSE
) %>% arrange(desc(freq))

cat("\nTop 15 lematów (Miller):\n")
print(head(freq_miller, 15))
cat("\nUnikalnych lematów:", nrow(freq_miller),
    "| Łącznie po filtracji:", sum(freq_miller$freq), "\n")

# Sentyment Millera
sentyment_miller <- freq_miller %>%
  inner_join(slownik, by = "word")

cat("\nSłowa nacechowane (Miller):\n")
print(sentyment_miller)

bilans_miller <- sentyment_miller %>%
  group_by(sentyment) %>%
  summarise(n = sum(freq), .groups = "drop")
cat("\nBilans sentymentu (Miller):\n")
print(bilans_miller)

# Chmura słów Millera
wordcloud(freq_miller$word, freq_miller$freq,
          min.freq = 1, max.words = 60,
          colors = brewer.pal(8, "Set1"), random.order = FALSE)
title("Chmura słów – Miller (benchmark)")

cat("\n=== Koniec testu benchmarkowego ===\n")

