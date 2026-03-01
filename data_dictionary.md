# Data dictionary (schema `acn`) – AlfaServizi S.r.l.

> Scopo: registro centralizzato per catalogare asset, servizi, dipendenze, responsabilità e contatti utili ai profili ACN (NIS2).

## Convenzioni di versioning (SCD2)
Le tabelle **service**, **asset**, **supplier** sono versionate:
- `business_key`: identificativo logico stabile (es. `SVC-CRM`, `AST-DB-01`, `SUP-AWS`)
- `version_no`: progressivo versione
- `valid_from`, `valid_to`: intervallo di validità della versione
- `is_current`: `TRUE` per la versione attiva

Gli aggiornamenti **non sovrascrivono** la riga corrente: la chiudono (`valid_to`, `is_current=FALSE`) e inseriscono una nuova versione.

---

## organization
- `org_id` (PK): identificativo azienda
- `org_name` (UNIQUE): nome
- `vat_code`: P.IVA (facoltativa)
- `created_at`: timestamp creazione

## location
- `location_id` (PK)
- `org_id` (FK → organization)
- `location_name`: nome sede/DC (UNIQUE per org)
- `address`, `city`, `country`: dati logistici

## person
- `person_id` (PK)
- `org_id` (FK → organization)
- `full_name`: nominativo
- `email` (UNIQUE per org): contatto principale
- `phone`, `department`: metadati organizzativi

## role / person_role
- `role`: catalogo ruoli (CISO, DPO, IT Manager, ecc.)
- `person_role`: associazione persona↔ruolo con storico (`valid_from`, `valid_to`)

## supplier (versionata)
- `supplier_id` (PK)
- `business_key`: codice fornitore
- `org_id` (FK → organization)
- `supplier_name`
- `supplier_type`: tipologia (cloud, connectivity, ecc.)
- `contract_ref`: riferimento contratto
- `criticality`: impatto della dipendenza
- campi SCD2: `valid_from`, `valid_to`, `is_current`, `version_no`

## service (versionata)
- `service_id` (PK)
- `business_key`: codice servizio
- `org_id` (FK → organization)
- `service_name`, `service_desc`
- `criticality`
- `availability_sla`, `rto_hours`, `rpo_hours`
- campi SCD2: `valid_from`, `valid_to`, `is_current`, `version_no`

## asset (versionata)
- `asset_id` (PK)
- `business_key`: codice asset
- `org_id` (FK → organization)
- `asset_name`, `asset_desc`
- `category`: HARDWARE/SOFTWARE/DATA/FACILITY/OTHER
- `criticality`
- `location_id` (FK → location, nullable)
- `serial_or_tag`: inventario/seriale
- `owner_person_id` (FK → person, nullable)
- campi SCD2: `valid_from`, `valid_to`, `is_current`, `version_no`

## contact_point
Punti di contatto collegati **a un solo oggetto** (vincolo XOR).
- `contact_id` (PK)
- `org_id` (FK → organization)
- `contact_kind`: tipo contatto (SERVICE_MANAGER, ASSET_OWNER, DPO, ecc.)
- `person_id` (FK → person)
- `service_id` (FK → service) **oppure**
- `asset_id` (FK → asset) **oppure**
- `supplier_id` (FK → supplier)
- `note`: note operative

## service_asset_dependency
Dipendenza interna servizio→asset.
- `dep_id` (PK)
- `org_id` (FK → organization)
- `service_id` (FK → service)
- `asset_id` (FK → asset)
- `dep_type`: RUNS_ON/USES/STORES/…
- `is_critical_dep`: dipendenza “bloccante”
- `note`

## service_supplier_dependency
Dipendenza servizio→fornitore terzo.
- `dep_id` (PK)
- `org_id` (FK → organization)
- `service_id` (FK → service)
- `supplier_id` (FK → supplier)
- `dep_type`: HOSTED_BY/CONNECTS_TO/MAINTAINED_BY/…
- `is_critical_dep`
- `note`

## service_service_dependency
Dipendenza tra servizi (upstream/downstream).
- `dep_id` (PK)
- `org_id` (FK → organization)
- `upstream_service_id` (FK → service)
- `downstream_service_id` (FK → service)
- `dep_type`
- `note`

---

## FNCS / NIST CSF (profilo con controlli e subcategory)

Per supportare la compilazione del **profilo (Current/Target)** secondo il Framework Nazionale per la Cybersecurity
(struttura Function → Category → Subcategory), lo schema include le seguenti tabelle:

- `control_function`: funzioni (ID, PR, DE, RS, RC)
- `control_category`: categorie (es. `ID.AM`, `PR.AC`)
- `control_subcategory`: subcategory (es. `ID.AM-1`)
- `control_profile`: profilo per organizzazione e tipo (`CURRENT`/`TARGET`)
- `control_assessment`: stato di implementazione della subcategory nel profilo + evidenza + owner
- `asset_control`: associazione subcategory ↔ asset (asset interessati/controllati)
- `service_control` (opzionale): associazione subcategory ↔ servizio

### Note operative
- Il profilo è modellato come **snapshot** (es. “Profilo Attuale 2026-02”): consente storicizzazione dei profili nel tempo.
- `control_assessment` contiene il livello di implementazione e un campo `evidence` per indicare l’evidenza disponibile.
- `asset_control` consente di legare esplicitamente gli asset ai controlli (richiesto dal docente nella prevalutazione del PW: “gli asset vanno associati ai controlli”).
