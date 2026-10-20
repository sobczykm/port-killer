# port-killer

Aplikacja w pasku menu: pokazuje, co słucha na portach TCP (`localhost:3000`, `8080`, …), z czytelnym opisem, co to za proces i z którego projektu, oraz pozwala go ubić jednym kliknięciem.

## Status

**pomysł (priorytet)** — nic nie zaimplementowane.

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

- [ ] lsof vs libproc (zacząć od lsof, zmierzyć czas)
