# port-killer

Aplikacja w pasku menu: pokazuje, co słucha na portach TCP (`localhost:3000`, `8080`, …), z czytelnym opisem, co to za proces i z którego projektu, oraz pozwala go ubić jednym kliknięciem.

## Status

**MVP (20.10.2026)** — działa lokalnie, budowane ad-hoc.

```sh
./build.sh run                                   # build/PortKiller.app, ikona 🌐 w pasku menu
build/PortKiller.app/Contents/MacOS/PortKiller --list   # to samo w terminalu (debug)
```

Zrobione: lista portów TCP LISTEN (lsof) pogrupowana po procesie, nazwa projektu (najbliższy katalog z `.git`/`package.json`/`go.mod`, `kubectl port-forward` → cel), czas działania, 🌐 przy portach dostępnych z sieci, klik w port otwiera `http://localhost:port`, ✕ = SIGTERM, po 2 s „Wymuś” = SIGKILL, „Zatrzymaj wszystkie” z potwierdzeniem, ukrywanie procesów systemowych i helperów aplikacji z `/Applications` (przełącznik „Systemowe”). Odświeżanie przy każdym otwarciu menu.

## MVP

- Ikona w pasku menu, po kliknięciu lista nasłuchujących portów: port, nazwa procesu, PID, katalog roboczy (→ nazwa projektu, np. `maiday`), czas działania.
- „Kill” (SIGTERM, po kilku s opcja SIGKILL) i „Kill all dev” dla wybranych portów.
- Odświeżanie przy otwarciu menu (bez stałego pollingu).
- Opcjonalnie liczba zajętych portów jako badge przy ikonie.

## Notatki techniczne

- Źródło danych: `lsof -nP -iTCP -sTCP:LISTEN -F pcn` albo bez procesów zewnętrznych — `proc_listpids` + `proc_pidfdinfo` (libproc). Katalog roboczy: `proc_pidinfo(PROC_PIDVNODEPATHINFO)`.
- Procesy innych użytkowników / roota: tylko pokazać, bez kill.
- Rozpoznawanie: `node`/`bun` → nazwa z `package.json` w cwd, `go`/binarka z `go build`, `docker-proxy`/OrbStack → nazwa kontenera (później), `kubectl port-forward` → namespace/svc.

## Decyzje / TODO

- [x] lsof vs libproc → lsof do listy (~30 ms), libproc do ścieżki/cwd/startu
- [ ] start przy logowaniu (`SMAppService.mainApp`)
- [ ] ikona aplikacji, Docker/OrbStack → nazwa kontenera
- [ ] dystrybucja: **nie Mac App Store** (sandbox blokuje `lsof`/`kill` innych procesów) → Developer ID + notaryzacja, sprzedaż np. przez Paddle / Lemon Squeezy / Gumroad
