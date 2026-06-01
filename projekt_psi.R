

# 1. Pakiety ----
library(tm)           # Przetwarzanie tekstu
library(cluster)      # Klastrowanie
library(wordcloud)    # Chmury słów
library(factoextra)   # Wizualizacje klastrów
library(RColorBrewer) # Kolory
library(ggplot2)      # Wykresy
library(dplyr)        # Przetwarzanie danych
library(DT)           # Interaktywne tabele
library(stopwords)    # Słowniki stopwords (w tym polski)
library(hunspell)     # Polski stemming / lemmatyzacja

# 2. Wczytanie danych tekstowych ----
# text folder to przykładowa nazwa folderu z wypowiedziami 
docs <- DirSource("textfolder")
corpus <- VCorpus(docs)

# Podgląd korpusu
inspect(corpus)

# 3. Przetwarzanie i oczyszczanie tekstu ----

# Zapewnienie kodowania UTF-8 dla polskich znaków
corpus <- tm_map(corpus, content_transformer(function(x) iconv(x, to = "UTF-8", sub = "byte")))

# Zamiana na małe litery
corpus <- tm_map(corpus, content_transformer(tolower))

# Usunięcie liczb i interpunkcji
corpus <- tm_map(corpus, removeNumbers)
corpus <- tm_map(corpus, removePunctuation)

# Definicja polskich stopwords + słów specyficznych dla Sejmu, można dodać więcej
polskie_stopwords <- stopwords("pl", source = "stopwords-iso")
sejmowe_stopwords <- c("pan", "pani", "panie", "posle", "poseł", "marszałku", 
                       "wysoka", "izbo", "sejm", "projekt", "ustawy", "projekcie", 
                       "tej", "tego", "tylko", "bardzo", "jest", "nie", "tak")
wszystkie_stopwords <- c(polskie_stopwords, sejmowe_stopwords)

# Usunięcie stopwords
corpus <- tm_map(corpus, removeWords, wszystkie_stopwords)
corpus <- tm_map(corpus, stripWhitespace)


# 4. POLSKI STEMMING (przy użyciu hunspell) bo steaming ten co na zajęciach nie ma polskiego słownika i by nie działo----

# Funkcja sprowadzająca słowa do rdzeni
polski_stemmer <- function(text) {
  slowa <- unlist(strsplit(text, "\\s+"))
  rdzenie <- sapply(slowa, function(w) {
    # Szukamy rdzenia w polskim słowniku
    wynik <- hunspell_stem(w, dict = dictionary("pl_PL"))[[1]]
    if (length(wynik) > 0) {
      return(wynik[1]) # Zwraca pierwszy dopasowany rdzeń
    } else {
      return(w)        # Jeśli brak w słowniku, zostawia oryginał
    }
  })
  paste(rdzenie, collapse = " ")
}

# Zastosowanie polskiego stemmera na korpusie
corpus_stemmed <- tm_map(corpus, content_transformer(polski_stemmer))
corpus_stemmed <- tm_map(corpus_stemmed, stripWhitespace)


# 5. Macierz Document-Term Matrix (DTM) ----
# Dokumenty = wiersze, Tokeny = kolumny
dtm <- DocumentTermMatrix(corpus_stemmed)
dtm_m <- as.matrix(dtm)

# Podgląd macierzy
dtm_m[1:min(5, nrow(dtm_m)), 1:min(5, ncol(dtm_m))]


# 6. Globalna chmura słów ----
# Częstości wszystkich słów w korpusie
v_global <- sort(colSums(dtm_m), decreasing = TRUE)
dtm_df <- data.frame(word = names(v_global), freq = v_global)

set.seed(1234)
wordcloud(words = dtm_df$word, freq = dtm_df$freq, min.freq = 2, 
          max.words = 50, colors = brewer.pal(8, "Dark2"))


# 7. Klastrowanie k-średnich (k-means) ----

# Ustawienie liczby klastrów
k <- 3 
set.seed(123) # Ziarno losowe dla powtarzalności wyników [cite: 6]
klastrowanie <- kmeans(dtm_m, centers = k)

# Wizualizacja klastrów na płaszczyźnie 2D
fviz_cluster(list(data = dtm_m, cluster = klastrowanie$cluster),
             geom = "point",
             main = "Wizualizacja klastrów wypowiedzi polityków")


# 8. Analiza klastrów (Chmury słów i interaktywne tabele) ----

# Chmury słów dla każdego z klastrów
par(mfrow = c(1, k)) # Ułożenie wykresów obok siebie
for (i in 1:k) {
  cluster_docs_idx <- which(klastrowanie$cluster == i)
  
  if(length(cluster_docs_idx) > 0) {
    cluster_docs <- dtm_m[cluster_docs_idx, , drop = FALSE]
    word_freq <- colSums(cluster_docs)
    
    wordcloud(names(word_freq), freq = word_freq, 
              max.words = 20, colors = brewer.pal(8, "Dark2"), scale=c(3,0.5))
    title(paste("Klaster", i))
  }
}
par(mfrow = c(1, 1)) # Powrót do domyślnego układu

# Przygotowanie danych do interaktywnej tabeli
cluster_info <- lapply(1:k, function(i) {
  cluster_docs_idx <- which(klastrowanie$cluster == i)
  if(length(cluster_docs_idx) > 0) {
    cluster_docs <- dtm_m[cluster_docs_idx, , drop = FALSE]
    word_freq <- sort(colSums(cluster_docs), decreasing = TRUE)
    top_words <- paste(names(word_freq)[1:5], collapse = ", ")
    data.frame(
      Klaster = i,
      Liczba_dokumentow = length(cluster_docs_idx),
      Top_5_slow = top_words,
      stringsAsFactors = FALSE
    )
  }
})

cluster_info_df <- do.call(rbind, cluster_info)
document_names <- names(corpus)

documents_clusters <- data.frame(
  Dokument = document_names,
  Klaster = klastrowanie$cluster,
  stringsAsFactors = FALSE
)

# Połączenie danych i wyświetlenie interaktywnej tabeli
documents_clusters_z_info <- left_join(documents_clusters, cluster_info_df, by = "Klaster")
datatable(documents_clusters_z_info,
          caption = "Przypisanie dokumentów do klastrów i najczęstsze słowa",
          rownames = FALSE,
          options = list(pageLength = 10))

# 9. Wizualizacja częstości przypisania do klastrów (ggplot2) ----
documents_clusters$Klaster <- as.factor(documents_clusters$Klaster)

ggplot(documents_clusters, aes(x = reorder(Dokument, as.numeric(Klaster)), fill = Klaster)) +
  geom_bar(stat = "count", width = 0.7) +
  coord_flip() +
  labs(title = "Przypisanie poszczególnych polityków do klastrów",
       x = "Dokument (Polityk)",
       y = "Liczba przypisań",
       fill = "Klaster") +
  theme_minimal(base_size = 13)

# =====================================================================