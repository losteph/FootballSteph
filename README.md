# ⚽ Football Steph

**Football Steph** è un'applicazione mobile e web sviluppata in Flutter dedicata alla gestione completa di partite amatoriali di calcetto. Permette di gestire il database atleti con statistiche in stile card collezionabili, bilanciare automaticamente le formazioni in base ai ruoli e all'OVR, tracciare il tabellino live minuto per minuto e consultare cronaca, MVP e pagellini automatici delle partite scorse.

---

## 🚀 Funzionalità Principali

### 👥 Database Atleti
- **Schede Stile FUT**: Valutazione complessiva (OVR) calcolata su voti da `C-` ad `A+` con fasce Oro, Argento e Bronzo.
- **Ruoli Differenziati**: Gestione Portieri (POR), Difensori (DIF), Centrocampisti (CEN) e Attaccanti (ATT) con codici colore dedicati.
- **Ricerca & Filtri**: Filtra per nome, ruolo e tier.
- **Backup & Ripristino**: Esportazione e importazione tramite file JSON senza sovrascrittura distruttiva (merge intelligente).

### ⚖️ Squad Builder & Bilanciamento Automatico
- **Vincolo Numerico Rigido**: Distribuzione perfettamente simmetrica dei convocati.
- **Separazione dei Portieri**: Assegnazione equa dei portieri tra le due squadre.
- **Algoritmo a Scambi Intra-Ruolo**: Minimizzerà lo scarto di OVR medio scambiando esclusivamente atleti con lo stesso ruolo.
- **Scambio Manuale Rapido**: Pulsante rapido per invertire (eventualmente) dei giocatori tra le due formazioni prima dell'inizio.

### ⏱️ Scoreboard Live & Cronaca
- **Gestione Tempi**: 1° Tempo, 2° Tempo, Supplementari e Sequenza Rigori di spareggio.
- **Tracking Eventi**: Gol, Assist, Autogol, Ammonizioni, Espulsioni, Rigori Parati/Sbagliati, Falli e Big Chance Missed.
- **Timer & Cronometro**: Monitoraggio in tempo reale del minutaggio complessivo e del tempo da portiere per ogni atleta.

### 📊 Storico, Pagelle & Marcatori
- **Pagelline Automatiche**: Algoritmo che calcola il voto finale (scala 1.0 - 10.0) combinando risultato di squadra, minutaggio, gol, assist e malus disciplinari/difensivi.
- **Design a Colori**: 
  - 🟢 Verde per voti $\ge 6.0$
  - 🔴 Rosso per voti $< 6.0$
  - 🔵 Blu Elettrico con badge dedicato per l'**MVP**
  - ⚫ Grigio per i Senza Voto (`S.V.`)
- **Protezione Fase Rigori**: La lotteria dei rigori non altera i voti delle pagelle definiti nei tempi regolamentari.
- **Dettaglio Match a Schede**: Visualizzazione a due tab tra *Formazioni & Voti* e *Cronaca Saliente*.
- **Classifica Marcatori Assoluta**: Classifica aggregata automatica di tutti i giocatori ordinata per Gol e, a parità, per Assist.

---

## 🛠️ Stack Tecnologico

- **Framework**: [Flutter](https://flutter.dev/) (Canale Stable)
- **Linguaggio**: Dart
- **Persistenza Dati**: `shared_preferences` (archiviazione locale JSON)
- **Gestione File**: `file_picker` per import/export multipiattaforma
- **Piattaforme Supportate**: Web, Android, iOS

---

Per suggerimenti su come assegnare i voti ai giocatori/amici in maniera oggettiva per provare a rendere l'app quanto più equilibrata possibile e non farsi guidare dal sentimento ho provato a stilare questa [guida](guida-voti.md), sperando possa essere di aiuto e buona (ancora la devo testare). 
