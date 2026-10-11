# Blackwater — La radura sommersa

Prototipo grafico locale per un RPG fantasy oscuro in ASCII, realizzato in Godot 4.7.2. Nessuna funzionalità MMO è implementata in questa fase.

## Avvio

Aprire `project.godot` in Godot e premere **F5**. La scena principale è `scenes/glade.tscn`. L'ambiente è generato deterministicamente all'avvio da `scripts/glade.gd`: nell'editor, prima di avviare il gioco, non appare la geometria generata.

## Comandi

| Comando | Funzione |
| --- | --- |
| WASD / frecce | Movimento relativo alla camera |
| Shift | Corsa |
| Rotella | Zoom |
| Q / E | Rotazione della camera |
| C | Vista ravvicinata del personaggio, con camera che lo segue |
| F | Confronto ASCII / 3D |
| + / - | Aumenta / riduce la dimensione dei caratteri |
| 1 / 2 / 3 | Erba rada / normale / fitta |
| H | Nasconde / mostra l'interfaccia |
| R | Riporta personaggio e camera alla posizione iniziale |

## Rendering

- Scena 3D ortografica in un SubViewport da 1440 × 900.
- Atlante di 96 caratteri generato da SystemFont (Consolas, DejaVu Sans Mono o monospace di sistema). Non sono inclusi font commerciali; la resa può variare tra sistemi.
- Il renderer dello studio 02 usa glifi nel mondo: le superfici ricevono caratteri nelle coordinate dell'oggetto (proiezione secondo la normale dominante), illuminati dalla scena. I simboli si spostano con il personaggio e seguono i piani delle rovine. Il compositing finale applica soltanto la vignettatura.
- Erba in MultiMesh di piccoli cartellini con glifi `/`, `\\` e `|`, ancorati al terreno e orientati alla camera. La distribuzione per macchie e il sentiero vuoto sono intenzionali. Vento GPU e tre densità selezionabili; vegetazione e rovine statiche unite per materiale.
- Atlante con mipmap generate una sola volta e filtraggio anisotropico sulle superfici oblique. Interfaccia separata per mantenerne la leggibilità.
- Riflessi planari tramite una seconda scena specchiata a metà risoluzione. Include rovine, alberi e personaggio; erba e lucciole sono escluse. Illuminazione specchiata approssimata e increspature stilizzate.
- Geometria, materiali e composizione originali procedurali; nessuna immagine delle reference viene usata come texture.

## Stato del prototipo

Lo studio 02 sostituisce la griglia uniforme del primo prototipo con densità e caratteri specifici dei materiali, ombre profonde e superfici leggibili. Conserva un tenue fondo continuo all'interno delle silhouette: è una scelta stilistica, non un terminale ASCII puro. Il vecchio postprocess rimane in `shaders/legacy_ascii.gdshader` come riferimento, senza essere usato.

Non è una dimostrazione di equivalenza qualitativa alle reference. Varietà degli alberi e aliasing dei simboli molto piccoli restano da rifinire. Collisioni semplificate a cerchi per tronchi e muratura; acqua interamente guadabile; nessun combattimento, audio, salvataggio o rete.

## Locomozione del viandante

`scripts/wanderer_rig.gd` costruisce un rig procedurale con torso, testa, braccia, mantello posteriore, cosce, ginocchia, stinchi e stivali. Il mantello aperto lascia visibili le gambe. Sono presenti riposo con respirazione, camminata, corsa e transizioni di velocità. Lanterna e spada seguono le mani; l'oscillazione della lanterna compensa il movimento del braccio.

Il ciclo avanza in base alla distanza effettivamente percorsa. Durante l'appoggio il piede rimane ancorato nel mondo; durante il passo segue un arco, con soluzione a due segmenti per il ginocchio. Il movimento si arresta contro gli ostacoli senza camminare sul posto. La quota del personaggio segue il piano di terreno a -0,13 e il fondale semplificato dello stagno. Anche la copia riflessa riceve tutte le trasformazioni delle articolazioni.

È una prima locomozione stilizzata, non un sistema completo per terreno irregolare: non include salti, scale, arrampicata o animazioni di combattimento.

Per ripetere la verifica dal gioco avviato tramite Godot AI `game_eval`: `return load("res://tests/locomotion_probe.gd").new().run_checks(get_tree().current_scene)`. Il controllo simula camminata, corsa, arresto e collisione e ripristina il personaggio. Nell'ultima verifica: nessuno scivolamento durante gli appoggi rettilinei, contatto con il suolo entro tolleranza numerica, stinchi di lunghezza costante, arresto del ciclo al riposo e riflesso coerente. Verificata anche una posa ravvicinata nel framebuffer.

Validazione effettuata con Godot AI MCP: avvio, log del gioco, catture del framebuffer, movimento e comandi di visualizzazione. Le prestazioni osservate valgono solo per questa macchina e questa scena.

Verifica dello studio 02: catture da due angolazioni; cambio ASCII/3D; propagazione della scala dei glifi ai materiali; tre densità (9.259 / 17.361 / 23.149 istanze d'erba nell'intera scena); presenza effettiva delle mipmap; nessun nuovo errore nei log dell'ultima esecuzione. Circa 100 FPS osservati con finestra 1280 × 800 e rendering interno 1440 × 900, circa 255 draw call. Non è un benchmark su hardware differenti.
