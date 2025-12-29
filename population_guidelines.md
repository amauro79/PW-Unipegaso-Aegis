# Linee guida per il popolamento e la manutenzione dati

## 1) Identificativi (business_key)
Definire una convenzione stabile e leggibile:
- Servizi: `SVC-<sigla>` (es. `SVC-CRM`, `SVC-SIEM`)
- Asset: `AST-<categoria>-<progressivo>` o `AST-<sigla>` (es. `AST-DB-01`)
- Fornitori: `SUP-<sigla>` (es. `SUP-AWS`, `SUP-TIM`)

Il `business_key` **non deve cambiare** nel tempo: quando cambiano attributi (criticità, descrizione, owner, ecc.) si crea una **nuova versione**.

## 2) Inserimento/aggiornamento (versioning)
Per tabelle versionate usare **solo** le funzioni:
- `acn.upsert_service(...)`
- `acn.upsert_asset(...)`
- `acn.upsert_supplier(...)`

Motivo: assicurano chiusura della versione corrente e inserimento della nuova (storico).

Se un oggetto non è più attivo:
- creare una nuova versione con attributi aggiornati (es. `criticality=LOW`) **oppure**
- gestire “decommissioning” aggiungendo un campo dedicato (estensione futura). Nel PW si mantiene semplice: l’oggetto resta consultabile ma non è “critico”.

## 3) Qualità dati minima consigliata
Per ogni **servizio**:
- nome, descrizione sintetica, criticità
- contatto primario (almeno `SERVICE_MANAGER` o `SERVICE_OWNER`)
- dipendenze: almeno 1 asset o 1 fornitore se applicabile

Per ogni **asset**:
- categoria, criticità
- owner tecnico (se noto)
- collocazione (location) se fisico/on-prem

Per ogni **fornitore**:
- tipologia e riferimento contrattuale
- criticità della dipendenza

## 4) Dipendenze: regole pratiche
- `service_asset_dependency`: usare `RUNS_ON` per infrastruttura/VM/host, `USES` per componenti applicative, `STORES` per data store.
- `service_supplier_dependency`: usare `HOSTED_BY` per cloud/hosting, `CONNECTS_TO` per connettività, `MAINTAINED_BY` per manutenzione/managed service.
- valorizzare `is_critical_dep=TRUE` quando la dipendenza è “single point of failure” o impedisce l’erogazione.

## 5) Responsabilità e punti di contatto
- Le responsabilità “operative” si modellano con `contact_point` (servizio/asset/fornitore).
- I ruoli organizzativi “trasversali” (CISO, DPO) si modellano con `role` + `person_role`.

## 6) Export per profilo ACN (CSV)
La view `acn.v_acn_profile_min` è pensata per un export immediato:
- da **psql**: `\copy (SELECT ... ) TO 'file.csv' CSV HEADER;`
- da strumenti ETL/BI: consumare la view come sorgente.

## 7) Controlli e manutenzione
- verificare periodicamente che per i servizi critici esista un contatto primario
- verificare che `is_current=TRUE` sia unico per (org_id, business_key) nelle tabelle versionate (garantito dalla logica di upsert)
- aggiungere indici in base ai filtri più frequenti (org_id, is_current, business_key)
