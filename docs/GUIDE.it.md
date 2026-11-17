# SincronizzaFoto - Guida utente

> **Solo Android.** Questo programma copia i file dai telefoni **Android** tramite cavo USB. iPhone e iPad non sono supportati.

## 1. Cosa fa

SincronizzaFoto copia foto, video e altri file dal tuo telefono Android al PC.

- Copia solo i file **nuovi**. Puoi lanciarlo quante volte vuoi: i file già presenti sul PC vengono saltati.
- **Non cancella mai** nulla dal telefono e non sovrascrive mai un file sul tuo PC.
- Non si installa niente, né sul telefono né sul PC: è una semplice cartella da aprire con un doppio clic.

## 2. Prima di iniziare (30 secondi)

1. Collega il telefono al PC con un cavo USB. Usa un cavo che trasmette dati, non solo corrente.
2. **Sblocca il telefono.**
3. Sul telefono apri la notifica che dice qualcosa come *Ricarica del dispositivo tramite USB* e scegli **Trasferimento file** (su alcuni telefoni si chiama *MTP*).
4. Fai doppio clic su **Start.bat**. Il nome del telefono compare accanto a **Telefono**. Se non compare, premi **Aggiorna**.

> Se il telefono chiede *Consentire l'accesso ai dati?*, tocca **Consenti**.

## 3. La prima volta: usa il Setup rapido

Quando non ci sono ancora regole, il programma ti propone il **Setup rapido**. Puoi aprirlo quando vuoi con il pulsante **Setup rapido...**.

1. Scegli una **cartella base** sul PC, per esempio `D:\Telefono`.
2. Spunta cosa vuoi copiare. *Fotocamera* e *Screenshot* sono già spuntati.
3. Scegli come organizzare i file (vedi la sezione 5: è la scelta più importante).
4. Premi **Crea regole**, poi **Avvia copia**.

Ogni voce spuntata diventa una **regola**: *"prendi i file da questa cartella del telefono e mettili in quella cartella del PC"*. Puoi modificare o aggiungere regole quando vuoi. L'interruttore di ogni regola la attiva o la disattiva.

## 4. Una regola, passo per passo

Fai doppio clic su una regola (oppure sulla matita, o **Aggiungi regola...** per una nuova). L'editor ha sei passi.

### 1. Nome

Quello che vuoi. Serve solo a riconoscere la regola nell'elenco.

### 2. Cartella sul telefono

Il percorso della cartella **dentro la memoria interna del telefono**. Il modo più semplice è il pulsante **Sfoglia telefono...**: apri le cartelle e scegli quella che ti serve. (Il telefono deve essere collegato.)

Cartelle comuni di Android:

- `DCIM\Camera` - foto e video scattati con la fotocamera.
- `Pictures\Screenshots` - screenshot.
- `Android\media\com.whatsapp\WhatsApp\Media\WhatsApp Images` - foto di WhatsApp (Android 11 e successivi). Sui telefoni più vecchi: `WhatsApp\Media\WhatsApp Images`.
- `Android\media\com.whatsapp\WhatsApp\Media\WhatsApp Video` - video di WhatsApp.
- `Download`, `Documents`, `Movies`, `Music`, `Recordings` - quello che dicono i nomi.

Non tutti i telefoni usano esattamente gli stessi nomi. Se il programma dice che la cartella non è stata trovata, usa **Sfoglia telefono...**.

### 3. Salva in

La cartella del PC dove andranno i file. Viene creata se non esiste. Le cartelle dentro la tua cartella utente vengono salvate come `%USERPROFILE%\...`, così le regole funzionano anche su un altro PC.

### 4. Cosa copiare

- **Tutto quello che c'è nella cartella** - tutti i file.
- **Solo questi tipi di file** - spunta Foto, Video, Audio e/o Documenti. Puoi aggiungere altre estensioni, per esempio `pdf, zip, apk`.

### 5. Copia anche le sottocartelle

Spuntalo quando la cartella del telefono contiene altre cartelle che vuoi copiare (per esempio *Download*, oppure la cartella *Sent* dentro WhatsApp Images). Per la fotocamera di solito si lascia spento.

### 6. Come organizzare i file sul PC

Decide **dove, dentro la cartella di destinazione**, viene salvato ogni file. L'editor mostra un percorso di esempio che cambia mentre scegli.

## 5. Scegliere l'organizzazione (la parte che tutti chiedono)

Immagina questi file sul telefono e una cartella di destinazione `D:\Telefono\Camera`:

```
IMG_20261117_105300.jpg      (scattata il 17 nov 2026)
IMG_20250102_101010.jpg      (scattata il 2 gen 2025)
Viaggi\mare.jpg              (dentro una sottocartella chiamata Viaggi)
```

(Gli esempi presuppongono che **Copia anche le sottocartelle** sia spuntato, altrimenti `mare.jpg` non viene copiato.)

### Tutto in una cartella (come sul telefono)

È la scelta predefinita. Tutti i file vanno direttamente nella cartella di destinazione, senza sottocartelle: esattamente come sul telefono.

```
D:\Telefono\Camera\IMG_20261117_105300.jpg
D:\Telefono\Camera\IMG_20250102_101010.jpg
D:\Telefono\Camera\mare.jpg
```

Scegli questa se vuoi solo **una copia di tutto**, o se hai già le foto in un'unica cartella.

### Una cartella per anno

```
D:\Telefono\Camera\2026\IMG_20261117_105300.jpg
D:\Telefono\Camera\2025\IMG_20250102_101010.jpg
```

Scegli questa per librerie grandi quando vuoi poche cartelle grandi.

### Una cartella per mese

```
D:\Telefono\Camera\2026-11\IMG_20261117_105300.jpg
D:\Telefono\Camera\2025-01\IMG_20250102_101010.jpg
```

Scegli questa se ti piace sfogliare per data. La data viene letta dal nome del file (`IMG_20261117_...`). Se il nome non ha una data, si usa la data di modifica del file. Se manca anche quella, il file va in una cartella chiamata *Senza data*.

### Mantieni le sottocartelle del telefono

Ricrea le stesse cartelle del telefono. Richiede **Copia anche le sottocartelle** (l'editor la spunta per te).

```
D:\Telefono\Camera\IMG_20261117_105300.jpg
D:\Telefono\Camera\IMG_20250102_101010.jpg
D:\Telefono\Camera\Viaggi\mare.jpg
```

Scegli questa per *Download*, *Documenti* o WhatsApp, dove la struttura delle cartelle ha un significato.

### Quale scelgo?

- *"Lo voglio esattamente come sul telefono, tutto in una cartella."* - **Tutto in una cartella**.
- *"Voglio ritrovare le foto in base a quando le ho scattate."* - **Una cartella per mese** (o per anno se hai moltissime foto).
- *"Voglio la cartella Download in ordine com'è sul telefono."* - **Mantieni le sottocartelle del telefono**.

> **Se cambi idea dopo.** Il programma cerca le copie nel posto dove salverebbe il file (e, per le opzioni anno/mese, anche nella cartella principale). Se una regola che ha già copiato le foto in *una cartella per mese* viene cambiata in *tutto in una cartella*, le foto già dentro le cartelle dei mesi non verrebbero riconosciute e verrebbero copiate di nuovo. Per questo, quando cambi l'organizzazione di una regola o la sua cartella di destinazione, il programma ti propone di **riordinare i file già copiati**.

### Riordinare i file già copiati

Puoi avviarlo quando vuoi con l'icona **Riordina** su una regola. Prima mostra quanti file sposterebbe con qualche esempio, e non succede nulla finché non premi **Sposta i file**.

- **Sposta** soltanto file sul tuo PC. Non cancella, non sovrascrive e non tocca il telefono.
- Guarda i file nella cartella di destinazione stessa e nelle cartelle per anno o per mese (come `2026` o `2026-11`). **Ogni altra sottocartella resta com'è**, nel caso sia tua.
- Un file resta dov'è se nel nuovo posto c'è già un file con lo stesso nome. Il riepilogo ti dice quanti.
- Le cartelle di date rimaste vuote vengono rimosse.
- Non è disponibile per *Mantieni le sottocartelle del telefono*, perché le cartelle originali non si conoscono. Scegli prima un'altra organizzazione.
- Se cambi la cartella di destinazione, sposta i file dalla vecchia cartella a quella nuova, con la nuova organizzazione.

## 6. Eseguire una copia

1. Attiva le regole da eseguire (l'interruttore di ogni regola).
2. Premi **Avvia copia**.

La finestra mostra cosa sta succedendo:

- **Fase 1/2 - Lettura del telefono.** Un contatore mostra quanti elementi sono stati letti. Le cartelle grandi (WhatsApp con migliaia di foto) possono richiedere uno o due minuti.
- **Fase 2/2 - Copia in corso.** La barra di avanzamento, il file in copia e i contatori *Copiati*, *Già presenti* ed *Errori*.
- Alla fine trovi un riepilogo per ogni regola, e nell'elenco compare *ultima sync: ...*.

Puoi premere **Interrompi** in qualsiasi momento. Non si rompe nulla: la volta dopo i file già copiati vengono saltati.

### Cosa dice il log

- `Fotocamera: 1055 file trovati` - quanti file ha trovato la regola sul telefono.
- `Copio: IMG_... (3,5 MB)` - un file nuovo è in copia.
- `Esiste già un file diverso chiamato '...': salvato come '... (1).jpg'` - il programma non sovrascrive mai: sul PC c'era già un file *diverso* con lo stesso nome, quindi il nuovo ha preso un numero.
- `ERRORE (copia incompleta o scaduta)` - il telefono ha smesso di rispondere (schermo bloccato, cavo scollegato). Rilancia: vengono copiati solo i file mancanti.

Spunta **Mostra nel log anche i file già presenti** se vuoi vedere anche i file saltati.

## 7. Condividere con un amico (portatile)

- **Tutto il programma è una cartella.** Copiala su una chiavetta o comprimila in ZIP: non serve installare niente. Le tue regole sono salvate in `config.json` dentro la cartella.
- **Solo le regole:** premi **Esporta regole...**, manda il file `.json`, e il tuo amico preme **Importa regole...**. I percorsi dentro la cartella utente si adattano da soli al suo PC. Ricordati di controllare le cartelle di destinazione con la matita di ogni regola.
- Non condividere `history.json`: contiene solo *i tuoi* orari di ultima sincronizzazione.

## 8. Problemi comuni

**"Nessun telefono trovato."**
Controlla il cavo (un cavo solo per la ricarica non funziona), sblocca il telefono, scegli **Trasferimento file** nella notifica USB e premi **Aggiorna**.

**"Cartella non trovata sul telefono."**
Sul tuo telefono il percorso è diverso. Apri la regola, usa **Sfoglia telefono** e scegli la cartella. WhatsApp ha cambiato cartella con Android 11: sui telefoni più vecchi prova `WhatsApp\Media\WhatsApp Images`.

**È molto lento.**
Le cartelle con migliaia di file richiedono tempo per essere lette, e il collo di bottiglia è il telefono, non il PC. La finestra resta utilizzabile e puoi premere **Interrompi**. La seconda volta è molto più veloce perché quasi tutti i file ci sono già.

**Windows dice che ha protetto il PC / "l'esecuzione di script è disabilitata".**
Avvia il programma con **Start.bat**. Avvia PowerShell con l'opzione giusta solo per questo programma, senza cambiare nessuna impostazione di Windows. Se SmartScreen avvisa per un file scaricato, scegli *Ulteriori informazioni* e poi *Esegui comunque* (il programma è open source: puoi leggerlo).

**Alcuni file non sono stati copiati.**
Controlla che la regola sia attiva, che **Cosa copiare** non sia limitato ad alcuni tipi e che **Copia anche le sottocartelle** sia attivo se i file sono dentro sottocartelle.

**Windows mostra la sua finestra «Copia in corso...».**
Non dovrebbe: il programma legge i file direttamente. Se il tuo telefono non lo permette, il log dice *La copia diretta non è disponibile su questo telefono* e viene usata la copia di Windows, che con i video grandi può mostrare la sua finestra. Tutto funziona lo stesso.

**Ricominciare da capo.**
Elimina `config.json` (regole) e `history.json` (orari di ultima sincronizzazione) e riavvia il programma.

## 9. Da sapere

- Funzionano solo i telefoni **Android** (si collegano come dispositivi *MTP*). Gli iPhone no.
- Un file è considerato *già copiato* quando nella destinazione c'è un file con **lo stesso nome e la stessa dimensione**. Rinominare un file sul PC fa sì che il programma lo copi di nuovo.
- Non viene mai cancellato nulla dal telefono.
- Aspetto e lingua: usa il selettore **IT / EN** e il pulsante sole/luna in alto a destra (il tema segue Windows se non ne scegli uno).
- Il programma è libero e open source (licenza MIT). Fatto da GAle e Claude. WhatsApp, Android e gli altri nomi sono marchi dei rispettivi proprietari; questo progetto non è affiliato con loro.
