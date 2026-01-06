# Project Work – Tema 2: Privacy e sicurezza aziendale (ACN / NIS2)

Questo repository contiene:
- `schema.sql`: creazione schema relazionale normalizzato + versioning (PostgreSQL)
- `sample_data.sql`: dataset simulato per test
- `queries.sql`: query di estrazione e view per export CSV
- `data_dictionary.md`: dizionario dati
- `population_guidelines.md`: linee guida per popolamento/manutenzione
- `ER_AlfaServizi.png`: diagramma ER (immagine)

## Deploy rapido (PostgreSQL)
1. Creare un database vuoto, poi:
   - `psql -d <db> -f schema.sql`
   - `psql -d <db> -f sample_data.sql`
   - `psql -d <db> -f queries.sql` (facoltativo, solo test)

## Export CSV (esempio)
Da psql:
\copy (SELECT * FROM acn.v_acn_profile_min WHERE org_name='AlfaServizi S.r.l.') TO 'acn_profile_min.csv' CSV HEADER;
