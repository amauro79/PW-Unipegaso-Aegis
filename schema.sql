-- AlfaServizi S.r.l. - Registro Asset/Servizi per profili ACN (NIS2)
-- Target RDBMS: PostgreSQL 14+
-- Note: schema normalizzato (>=3NF) con versioning SCD2 via stored procedures.
-- Convenzione: ogni entità "versionata" ha:
--   - <entity>_id (PK surrogata)
--   - business_key (identificativo logico stabile)
--   - version_no, valid_from, valid_to, is_current

BEGIN;

CREATE SCHEMA IF NOT EXISTS acn;
SET search_path TO acn;

-- ---------- Reference / enums ----------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'criticality_level') THEN
    CREATE TYPE criticality_level AS ENUM ('LOW','MEDIUM','HIGH','CRITICAL');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'asset_category') THEN
    CREATE TYPE asset_category AS ENUM ('HARDWARE','SOFTWARE','DATA','FACILITY','OTHER');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'dependency_type') THEN
    CREATE TYPE dependency_type AS ENUM ('RUNS_ON','USES','STORES','PRODUCES','CONNECTS_TO','HOSTED_BY','MAINTAINED_BY','SUPPLIED_BY');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'contact_type') THEN
    CREATE TYPE contact_type AS ENUM ('ASSET_OWNER','SERVICE_OWNER','SERVICE_MANAGER','SECURITY_CONTACT','DPO','SUPPLIER_CONTACT','OTHER');
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS organization (
  org_id          BIGSERIAL PRIMARY KEY,
  org_name        TEXT NOT NULL UNIQUE,
  vat_code        TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS location (
  location_id     BIGSERIAL PRIMARY KEY,
  org_id          BIGINT NOT NULL REFERENCES organization(org_id) ON DELETE CASCADE,
  location_name   TEXT NOT NULL,
  address         TEXT,
  city            TEXT,
  country         TEXT DEFAULT 'IT',
  UNIQUE (org_id, location_name)
);
CREATE INDEX IF NOT EXISTS idx_location_org ON location(org_id);

CREATE TABLE IF NOT EXISTS person (
  person_id       BIGSERIAL PRIMARY KEY,
  org_id          BIGINT NOT NULL REFERENCES organization(org_id) ON DELETE CASCADE,
  full_name       TEXT NOT NULL,
  email           TEXT NOT NULL,
  phone           TEXT,
  department      TEXT,
  UNIQUE (org_id, email)
);
CREATE INDEX IF NOT EXISTS idx_person_org ON person(org_id);

-- Ruoli "catalogo" (non versionati)
CREATE TABLE IF NOT EXISTS role (
  role_id         BIGSERIAL PRIMARY KEY,
  role_code       TEXT NOT NULL UNIQUE, -- e.g., IT_MGR, CISO, DPO
  role_name       TEXT NOT NULL
);

-- Assegnazioni ruolo-persona (storico semplice)
CREATE TABLE IF NOT EXISTS person_role (
  person_role_id  BIGSERIAL PRIMARY KEY,
  person_id       BIGINT NOT NULL REFERENCES person(person_id) ON DELETE CASCADE,
  role_id         BIGINT NOT NULL REFERENCES role(role_id) ON DELETE RESTRICT,
  valid_from      DATE NOT NULL DEFAULT CURRENT_DATE,
  valid_to        DATE,
  CHECK (valid_to IS NULL OR valid_to >= valid_from)
);
CREATE INDEX IF NOT EXISTS idx_person_role_person ON person_role(person_id);
CREATE INDEX IF NOT EXISTS idx_person_role_role ON person_role(role_id);

-- ---------- Suppliers ----------
CREATE TABLE IF NOT EXISTS supplier (
  supplier_id     BIGSERIAL PRIMARY KEY,
  business_key    TEXT NOT NULL,
  org_id          BIGINT NOT NULL REFERENCES organization(org_id) ON DELETE CASCADE,
  supplier_name   TEXT NOT NULL,
  supplier_type   TEXT,  -- cloud, connectivity, maintenance, managed service...
  contract_ref    TEXT,
  criticality     criticality_level NOT NULL DEFAULT 'MEDIUM',
  valid_from      TIMESTAMPTZ NOT NULL DEFAULT now(),
  valid_to        TIMESTAMPTZ,
  is_current      BOOLEAN NOT NULL DEFAULT TRUE,
  version_no      INTEGER NOT NULL DEFAULT 1,
  CHECK (valid_to IS NULL OR valid_to > valid_from),
  UNIQUE (org_id, business_key, version_no)
);
CREATE INDEX IF NOT EXISTS idx_supplier_org_current ON supplier(org_id, is_current);
CREATE INDEX IF NOT EXISTS idx_supplier_bk_current ON supplier(org_id, business_key, is_current);

-- ---------- Services ----------
CREATE TABLE IF NOT EXISTS service (
  service_id        BIGSERIAL PRIMARY KEY,
  business_key      TEXT NOT NULL,
  org_id            BIGINT NOT NULL REFERENCES organization(org_id) ON DELETE CASCADE,
  service_name      TEXT NOT NULL,
  service_desc      TEXT,
  criticality       criticality_level NOT NULL DEFAULT 'MEDIUM',
  availability_sla  TEXT,     -- es. 99.9%
  rto_hours         INTEGER,  -- recovery time objective
  rpo_hours         INTEGER,  -- recovery point objective
  valid_from        TIMESTAMPTZ NOT NULL DEFAULT now(),
  valid_to          TIMESTAMPTZ,
  is_current        BOOLEAN NOT NULL DEFAULT TRUE,
  version_no        INTEGER NOT NULL DEFAULT 1,
  CHECK (valid_to IS NULL OR valid_to > valid_from),
  UNIQUE (org_id, business_key, version_no)
);
CREATE INDEX IF NOT EXISTS idx_service_org_current ON service(org_id, is_current);
CREATE INDEX IF NOT EXISTS idx_service_bk_current ON service(org_id, business_key, is_current);

-- ---------- Assets ----------
CREATE TABLE IF NOT EXISTS asset (
  asset_id        BIGSERIAL PRIMARY KEY,
  business_key    TEXT NOT NULL,
  org_id          BIGINT NOT NULL REFERENCES organization(org_id) ON DELETE CASCADE,
  asset_name      TEXT NOT NULL,
  category        asset_category NOT NULL,
  asset_desc      TEXT,
  criticality     criticality_level NOT NULL DEFAULT 'MEDIUM',
  location_id     BIGINT REFERENCES location(location_id) ON DELETE SET NULL,
  serial_or_tag   TEXT,
  owner_person_id BIGINT REFERENCES person(person_id) ON DELETE SET NULL,
  valid_from      TIMESTAMPTZ NOT NULL DEFAULT now(),
  valid_to        TIMESTAMPTZ,
  is_current      BOOLEAN NOT NULL DEFAULT TRUE,
  version_no      INTEGER NOT NULL DEFAULT 1,
  CHECK (valid_to IS NULL OR valid_to > valid_from),
  UNIQUE (org_id, business_key, version_no)
);
CREATE INDEX IF NOT EXISTS idx_asset_org_current ON asset(org_id, is_current);
CREATE INDEX IF NOT EXISTS idx_asset_bk_current ON asset(org_id, business_key, is_current);
CREATE INDEX IF NOT EXISTS idx_asset_owner ON asset(owner_person_id);

-- ---------- Contacts (points of contact) ----------
-- Contatti collegabili a servizi, asset o supplier (polimorfico via nullable FKs, con vincolo XOR)
CREATE TABLE IF NOT EXISTS contact_point (
  contact_id      BIGSERIAL PRIMARY KEY,
  org_id          BIGINT NOT NULL REFERENCES organization(org_id) ON DELETE CASCADE,
  contact_kind    contact_type NOT NULL,
  person_id       BIGINT NOT NULL REFERENCES person(person_id) ON DELETE RESTRICT,
  service_id      BIGINT REFERENCES service(service_id) ON DELETE CASCADE,
  asset_id        BIGINT REFERENCES asset(asset_id) ON DELETE CASCADE,
  supplier_id     BIGINT REFERENCES supplier(supplier_id) ON DELETE CASCADE,
  note            TEXT,
  CHECK (
    (service_id IS NOT NULL)::int +
    (asset_id   IS NOT NULL)::int +
    (supplier_id IS NOT NULL)::int = 1
  )
);
CREATE INDEX IF NOT EXISTS idx_contact_service ON contact_point(service_id);
CREATE INDEX IF NOT EXISTS idx_contact_asset ON contact_point(asset_id);
CREATE INDEX IF NOT EXISTS idx_contact_supplier ON contact_point(supplier_id);

-- ---------- Dependencies ----------
-- Relazione Service -> Asset (dipendenza interna)
CREATE TABLE IF NOT EXISTS service_asset_dependency (
  dep_id          BIGSERIAL PRIMARY KEY,
  org_id          BIGINT NOT NULL REFERENCES organization(org_id) ON DELETE CASCADE,
  service_id      BIGINT NOT NULL REFERENCES service(service_id) ON DELETE CASCADE,
  asset_id        BIGINT NOT NULL REFERENCES asset(asset_id) ON DELETE CASCADE,
  dep_type        dependency_type NOT NULL,
  is_critical_dep BOOLEAN NOT NULL DEFAULT FALSE,
  note            TEXT,
  UNIQUE (service_id, asset_id, dep_type)
);
CREATE INDEX IF NOT EXISTS idx_sad_service ON service_asset_dependency(service_id);
CREATE INDEX IF NOT EXISTS idx_sad_asset ON service_asset_dependency(asset_id);

-- Relazione Service -> Supplier (dipendenza terze parti)
CREATE TABLE IF NOT EXISTS service_supplier_dependency (
  dep_id          BIGSERIAL PRIMARY KEY,
  org_id          BIGINT NOT NULL REFERENCES organization(org_id) ON DELETE CASCADE,
  service_id      BIGINT NOT NULL REFERENCES service(service_id) ON DELETE CASCADE,
  supplier_id     BIGINT NOT NULL REFERENCES supplier(supplier_id) ON DELETE CASCADE,
  dep_type        dependency_type NOT NULL DEFAULT 'SUPPLIED_BY',
  is_critical_dep BOOLEAN NOT NULL DEFAULT FALSE,
  note            TEXT,
  UNIQUE (service_id, supplier_id, dep_type)
);
CREATE INDEX IF NOT EXISTS idx_ssd_service ON service_supplier_dependency(service_id);
CREATE INDEX IF NOT EXISTS idx_ssd_supplier ON service_supplier_dependency(supplier_id);

-- Relazione Service -> Service (dipendenze fra servizi)
CREATE TABLE IF NOT EXISTS service_service_dependency (
  dep_id          BIGSERIAL PRIMARY KEY,
  org_id          BIGINT NOT NULL REFERENCES organization(org_id) ON DELETE CASCADE,
  upstream_service_id   BIGINT NOT NULL REFERENCES service(service_id) ON DELETE CASCADE,
  downstream_service_id BIGINT NOT NULL REFERENCES service(service_id) ON DELETE CASCADE,
  dep_type        dependency_type NOT NULL DEFAULT 'USES',
  note            TEXT,
  CHECK (upstream_service_id <> downstream_service_id),
  UNIQUE (upstream_service_id, downstream_service_id, dep_type)
);
CREATE INDEX IF NOT EXISTS idx_sssd_up ON service_service_dependency(upstream_service_id);
CREATE INDEX IF NOT EXISTS idx_sssd_down ON service_service_dependency(downstream_service_id);

-- ---------- Versioning helpers ----------
CREATE OR REPLACE FUNCTION acn._close_current_version(p_table regclass, p_org_id bigint, p_business_key text)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  q text;
BEGIN
  q := format('UPDATE %s SET valid_to = now(), is_current = FALSE
              WHERE org_id = $1 AND business_key = $2 AND is_current = TRUE', p_table);
  EXECUTE q USING p_org_id, p_business_key;
END $$;

-- Upsert/versioning for SERVICE
CREATE OR REPLACE FUNCTION acn.upsert_service(
  p_org_id bigint,
  p_business_key text,
  p_service_name text,
  p_service_desc text,
  p_criticality criticality_level,
  p_availability_sla text,
  p_rto_hours int,
  p_rpo_hours int
) RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
  v_old service%ROWTYPE;
  v_new_id bigint;
  v_next_ver int;
BEGIN
  SELECT * INTO v_old
  FROM acn.service
  WHERE org_id = p_org_id AND business_key = p_business_key AND is_current = TRUE
  ORDER BY version_no DESC
  LIMIT 1;

  IF NOT FOUND THEN
    INSERT INTO acn.service (business_key, org_id, service_name, service_desc, criticality,
                             availability_sla, rto_hours, rpo_hours)
    VALUES (p_business_key, p_org_id, p_service_name, p_service_desc, COALESCE(p_criticality,'MEDIUM'),
            p_availability_sla, p_rto_hours, p_rpo_hours)
    RETURNING service_id INTO v_new_id;
    RETURN v_new_id;
  END IF;

  -- Close previous current version
  PERFORM acn._close_current_version('acn.service', p_org_id, p_business_key);

  v_next_ver := v_old.version_no + 1;

  INSERT INTO acn.service (business_key, org_id, service_name, service_desc, criticality,
                           availability_sla, rto_hours, rpo_hours, version_no, valid_from)
  VALUES (p_business_key, p_org_id, p_service_name, p_service_desc, COALESCE(p_criticality, v_old.criticality),
          p_availability_sla, p_rto_hours, p_rpo_hours, v_next_ver, now())
  RETURNING service_id INTO v_new_id;

  RETURN v_new_id;
END $$;

-- Upsert/versioning for ASSET
CREATE OR REPLACE FUNCTION acn.upsert_asset(
  p_org_id bigint,
  p_business_key text,
  p_asset_name text,
  p_category asset_category,
  p_asset_desc text,
  p_criticality criticality_level,
  p_location_id bigint,
  p_serial_or_tag text,
  p_owner_person_id bigint
) RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
  v_old asset%ROWTYPE;
  v_new_id bigint;
  v_next_ver int;
BEGIN
  SELECT * INTO v_old
  FROM acn.asset
  WHERE org_id = p_org_id AND business_key = p_business_key AND is_current = TRUE
  ORDER BY version_no DESC
  LIMIT 1;

  IF NOT FOUND THEN
    INSERT INTO acn.asset (business_key, org_id, asset_name, category, asset_desc, criticality,
                           location_id, serial_or_tag, owner_person_id)
    VALUES (p_business_key, p_org_id, p_asset_name, p_category, p_asset_desc, COALESCE(p_criticality,'MEDIUM'),
            p_location_id, p_serial_or_tag, p_owner_person_id)
    RETURNING asset_id INTO v_new_id;
    RETURN v_new_id;
  END IF;

  PERFORM acn._close_current_version('acn.asset', p_org_id, p_business_key);

  v_next_ver := v_old.version_no + 1;

  INSERT INTO acn.asset (business_key, org_id, asset_name, category, asset_desc, criticality,
                         location_id, serial_or_tag, owner_person_id, version_no, valid_from)
  VALUES (p_business_key, p_org_id, p_asset_name, p_category, p_asset_desc, COALESCE(p_criticality, v_old.criticality),
          p_location_id, p_serial_or_tag, p_owner_person_id, v_next_ver, now())
  RETURNING asset_id INTO v_new_id;

  RETURN v_new_id;
END $$;

-- Upsert/versioning for SUPPLIER
CREATE OR REPLACE FUNCTION acn.upsert_supplier(
  p_org_id bigint,
  p_business_key text,
  p_supplier_name text,
  p_supplier_type text,
  p_contract_ref text,
  p_criticality criticality_level
) RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
  v_old supplier%ROWTYPE;
  v_new_id bigint;
  v_next_ver int;
BEGIN
  SELECT * INTO v_old
  FROM acn.supplier
  WHERE org_id = p_org_id AND business_key = p_business_key AND is_current = TRUE
  ORDER BY version_no DESC
  LIMIT 1;

  IF NOT FOUND THEN
    INSERT INTO acn.supplier (business_key, org_id, supplier_name, supplier_type, contract_ref, criticality)
    VALUES (p_business_key, p_org_id, p_supplier_name, p_supplier_type, p_contract_ref, COALESCE(p_criticality,'MEDIUM'))
    RETURNING supplier_id INTO v_new_id;
    RETURN v_new_id;
  END IF;

  PERFORM acn._close_current_version('acn.supplier', p_org_id, p_business_key);

  v_next_ver := v_old.version_no + 1;

  INSERT INTO acn.supplier (business_key, org_id, supplier_name, supplier_type, contract_ref, criticality, version_no, valid_from)
  VALUES (p_business_key, p_org_id, p_supplier_name, p_supplier_type, p_contract_ref, COALESCE(p_criticality, v_old.criticality),
          v_next_ver, now())
  RETURNING supplier_id INTO v_new_id;

  RETURN v_new_id;
END $$;

-- ---------- FNCS / NIST CSF controls (per "profilo" ACN) ----------
-- Obiettivo: rappresentare Function/Category/Subcategory e lo stato di implementazione (Current/Target),
-- collegando i controlli agli asset (e, opzionalmente, ai servizi).

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'fncs_profile_type') THEN
    CREATE TYPE fncs_profile_type AS ENUM ('CURRENT','TARGET');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'implementation_level') THEN
    CREATE TYPE implementation_level AS ENUM ('NOT_IMPLEMENTED','PARTIAL','IMPLEMENTED');
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS control_function (
  function_id   BIGSERIAL PRIMARY KEY,
  code          TEXT NOT NULL UNIQUE, -- ID, PR, DE, RS, RC
  name          TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS control_category (
  category_id   BIGSERIAL PRIMARY KEY,
  function_id   BIGINT NOT NULL REFERENCES control_function(function_id) ON DELETE CASCADE,
  code          TEXT NOT NULL UNIQUE, -- es. ID.AM
  name          TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_ctrl_cat_fn ON control_category(function_id);

CREATE TABLE IF NOT EXISTS control_subcategory (
  subcategory_id BIGSERIAL PRIMARY KEY,
  category_id    BIGINT NOT NULL REFERENCES control_category(category_id) ON DELETE CASCADE,
  code           TEXT NOT NULL UNIQUE, -- es. ID.AM-1
  description    TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_ctrl_sub_cat ON control_subcategory(category_id);

-- Profilo (Current / Target) per organizzazione: consente versioni multiple nel tempo
CREATE TABLE IF NOT EXISTS control_profile (
  profile_id    BIGSERIAL PRIMARY KEY,
  org_id        BIGINT NOT NULL REFERENCES organization(org_id) ON DELETE CASCADE,
  profile_type  fncs_profile_type NOT NULL,
  profile_name  TEXT NOT NULL, -- es. "Profilo Attuale 2026-02"
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (org_id, profile_type, profile_name)
);
CREATE INDEX IF NOT EXISTS idx_ctrl_profile_org ON control_profile(org_id, profile_type);

-- Stato di implementazione della subcategory nel profilo (Current/Target)
CREATE TABLE IF NOT EXISTS control_assessment (
  assessment_id        BIGSERIAL PRIMARY KEY,
  profile_id           BIGINT NOT NULL REFERENCES control_profile(profile_id) ON DELETE CASCADE,
  subcategory_id       BIGINT NOT NULL REFERENCES control_subcategory(subcategory_id) ON DELETE CASCADE,
  implementation       implementation_level NOT NULL,
  evidence             TEXT,
  assessed_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  owner_person_id      BIGINT REFERENCES person(person_id) ON DELETE SET NULL,
  UNIQUE (profile_id, subcategory_id)
);
CREATE INDEX IF NOT EXISTS idx_ctrl_assess_profile ON control_assessment(profile_id);
CREATE INDEX IF NOT EXISTS idx_ctrl_assess_sub ON control_assessment(subcategory_id);

-- Mappatura controllo ↔ asset (quali asset sono coperti/impattati dalla subcategory)
CREATE TABLE IF NOT EXISTS asset_control (
  asset_control_id BIGSERIAL PRIMARY KEY,
  org_id           BIGINT NOT NULL REFERENCES organization(org_id) ON DELETE CASCADE,
  asset_id         BIGINT NOT NULL REFERENCES asset(asset_id) ON DELETE CASCADE,
  subcategory_id   BIGINT NOT NULL REFERENCES control_subcategory(subcategory_id) ON DELETE CASCADE,
  applicable       BOOLEAN NOT NULL DEFAULT TRUE,
  note             TEXT,
  UNIQUE (asset_id, subcategory_id)
);
CREATE INDEX IF NOT EXISTS idx_asset_ctrl_asset ON asset_control(asset_id);
CREATE INDEX IF NOT EXISTS idx_asset_ctrl_sub ON asset_control(subcategory_id);

-- (Opzionale) Mappatura controllo ↔ servizio
CREATE TABLE IF NOT EXISTS service_control (
  service_control_id BIGSERIAL PRIMARY KEY,
  org_id             BIGINT NOT NULL REFERENCES organization(org_id) ON DELETE CASCADE,
  service_id         BIGINT NOT NULL REFERENCES service(service_id) ON DELETE CASCADE,
  subcategory_id     BIGINT NOT NULL REFERENCES control_subcategory(subcategory_id) ON DELETE CASCADE,
  applicable         BOOLEAN NOT NULL DEFAULT TRUE,
  note               TEXT,
  UNIQUE (service_id, subcategory_id)
);
CREATE INDEX IF NOT EXISTS idx_service_ctrl_service ON service_control(service_id);
CREATE INDEX IF NOT EXISTS idx_service_ctrl_sub ON service_control(subcategory_id);

-- ---------- "ACN profile" export views ----------
-- View: elenco asset critici con owner + servizi che li usano
CREATE OR REPLACE VIEW acn.v_assets_critical_current AS
SELECT
  o.org_name,
  a.business_key AS asset_code,
  a.asset_name,
  a.category,
  a.criticality,
  l.location_name,
  p.full_name AS owner_name,
  p.email     AS owner_email
FROM acn.asset a
JOIN acn.organization o ON o.org_id = a.org_id
LEFT JOIN acn.location l ON l.location_id = a.location_id
LEFT JOIN acn.person p ON p.person_id = a.owner_person_id
WHERE a.is_current = TRUE AND a.criticality IN ('HIGH','CRITICAL');

-- View: dipendenze terze parti per servizi
CREATE OR REPLACE VIEW acn.v_service_third_party_deps AS
SELECT
  o.org_name,
  s.business_key AS service_code,
  s.service_name,
  s.criticality AS service_criticality,
  sup.business_key AS supplier_code,
  sup.supplier_name,
  sup.supplier_type,
  ssd.dep_type,
  ssd.is_critical_dep,
  sup.criticality AS supplier_criticality
FROM acn.service_supplier_dependency ssd
JOIN acn.service s ON s.service_id = ssd.service_id AND s.is_current = TRUE
JOIN acn.supplier sup ON sup.supplier_id = ssd.supplier_id AND sup.is_current = TRUE
JOIN acn.organization o ON o.org_id = ssd.org_id;

-- View: export "minimo" in forma tabellare (facile da CSV)
CREATE OR REPLACE VIEW acn.v_acn_profile_min AS
SELECT
  o.org_name,
  s.business_key AS service_code,
  s.service_name,
  s.criticality AS service_criticality,
  COALESCE(cp_mgr.full_name, cp_owner.full_name) AS primary_contact_name,
  COALESCE(cp_mgr.email, cp_owner.email)         AS primary_contact_email,
  a.business_key AS asset_code,
  a.asset_name,
  a.category AS asset_category,
  a.criticality AS asset_criticality,
  sup.business_key AS supplier_code,
  sup.supplier_name,
  sup.supplier_type,
  ssd.is_critical_dep AS supplier_dep_critical
FROM acn.service s
JOIN acn.organization o ON o.org_id = s.org_id
LEFT JOIN LATERAL (
  SELECT p.full_name, p.email
  FROM acn.contact_point c
  JOIN acn.person p ON p.person_id = c.person_id
  WHERE c.service_id = s.service_id AND c.contact_kind = 'SERVICE_MANAGER'
  LIMIT 1
) cp_mgr ON TRUE
LEFT JOIN LATERAL (
  SELECT p.full_name, p.email
  FROM acn.contact_point c
  JOIN acn.person p ON p.person_id = c.person_id
  WHERE c.service_id = s.service_id AND c.contact_kind = 'SERVICE_OWNER'
  LIMIT 1
) cp_owner ON TRUE
LEFT JOIN acn.service_asset_dependency sad ON sad.service_id = s.service_id
LEFT JOIN acn.asset a ON a.asset_id = sad.asset_id AND a.is_current = TRUE
LEFT JOIN acn.service_supplier_dependency ssd ON ssd.service_id = s.service_id
LEFT JOIN acn.supplier sup ON sup.supplier_id = ssd.supplier_id AND sup.is_current = TRUE
WHERE s.is_current = TRUE;

-- ---------- FNCS profile export views ----------
-- View: dettaglio profilo (Current/Target) per subcategory con evidenze e asset associati
CREATE OR REPLACE VIEW acn.v_fncs_profile_detail AS
SELECT
  o.org_name,
  cp.profile_type,
  cp.profile_name,
  f.code  AS function_code,
  c.code  AS category_code,
  sc.code AS subcategory_code,
  sc.description AS subcategory_description,
  ca.implementation,
  ca.evidence,
  ca.assessed_at,
  po.full_name AS control_owner_name,
  po.email     AS control_owner_email,
  string_agg(DISTINCT a.business_key, ', ' ORDER BY a.business_key) AS related_assets
FROM acn.control_profile cp
JOIN acn.organization o ON o.org_id = cp.org_id
JOIN acn.control_assessment ca ON ca.profile_id = cp.profile_id
JOIN acn.control_subcategory sc ON sc.subcategory_id = ca.subcategory_id
JOIN acn.control_category c ON c.category_id = sc.category_id
JOIN acn.control_function f ON f.function_id = c.function_id
LEFT JOIN acn.person po ON po.person_id = ca.owner_person_id
LEFT JOIN acn.asset_control ac ON ac.org_id = cp.org_id AND ac.subcategory_id = sc.subcategory_id AND ac.applicable = TRUE
LEFT JOIN acn.asset a ON a.asset_id = ac.asset_id AND a.is_current = TRUE
GROUP BY
  o.org_name, cp.profile_type, cp.profile_name, f.code, c.code, sc.code, sc.description,
  ca.implementation, ca.evidence, ca.assessed_at, po.full_name, po.email;

-- View: riepilogo numerico (quante subcategory implementate/partial/non) per profilo
CREATE OR REPLACE VIEW acn.v_fncs_profile_summary AS
SELECT
  o.org_name,
  cp.profile_type,
  cp.profile_name,
  ca.implementation,
  count(*) AS n_subcategories
FROM acn.control_profile cp
JOIN acn.organization o ON o.org_id = cp.org_id
JOIN acn.control_assessment ca ON ca.profile_id = cp.profile_id
GROUP BY o.org_name, cp.profile_type, cp.profile_name, ca.implementation
ORDER BY o.org_name, cp.profile_type, cp.profile_name, ca.implementation;

COMMIT;
