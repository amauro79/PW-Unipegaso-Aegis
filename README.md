# Project Work – Tema 2: Privacy e sicurezza aziendale (ACN / NIS2)

Questo repository contiene:
- `schema.sql`: creazione schema relazionale normalizzato + versioning (PostgreSQL) **esteso con controlli FNCS/NIST CSF**
- `sample_data.sql`: dataset simulato (include esempi di profilo Current/Target e mapping controlli↔asset)
- `queries.sql`: query di estrazione e test (include viste per profilo FNCS)
- `data_dictionary.md`: dizionario dati aggiornato
- `population_guidelines.md`: linee guida per popolamento/manutenzione aggiornato
- `ER_AlfaServizi.pgerdV4.png`: diagramma ER (immagine)
- `ER_AlfaServiziV4.pgerd`: progetto diagramma ER (pgAdmin 4)

## Deploy rapido (PostgreSQL)
1. Creare un database vuoto, poi:
   - `psql -d <db> -f schema.sql`
   - `psql -d <db> -f sample_data.sql`
   - `psql -d <db> -f queries.sql` (facoltativo, solo test)

## Export CSV (esempio)
Da psql:
- Export “minimo” (asset/servizi/dipendenze):
\copy (SELECT * FROM acn.v_acn_profile_min WHERE org_name='AlfaServizi S.r.l.') TO 'acn_profile_min.csv' CSV HEADER;
- Export profilo FNCS (dettaglio Current):
\copy (SELECT * FROM acn.v_fncs_profile_detail WHERE org_name='AlfaServizi S.r.l.' AND profile_type='CURRENT') TO 'fncs_profile_current.csv' CSV HEADER;





