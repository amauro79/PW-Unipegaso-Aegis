-- Dati di test (simulati) per AlfaServizi S.r.l.
BEGIN;
SET search_path TO acn;

INSERT INTO organization (org_name, vat_code) VALUES
  ('AlfaServizi S.r.l.', 'IT12345678901')
ON CONFLICT (org_name) DO NOTHING;

-- locations
INSERT INTO location (org_id, location_name, address, city, country)
SELECT org_id, 'HQ Roma', 'Via Innovazione 10', 'Roma', 'IT'
FROM organization WHERE org_name='AlfaServizi S.r.l.'
ON CONFLICT (org_id, location_name) DO NOTHING;

INSERT INTO location (org_id, location_name, address, city, country)
SELECT org_id, 'DC Torino', 'Strada Datacenter 25', 'Torino', 'IT'
FROM organization WHERE org_name='AlfaServizi S.r.l.'
ON CONFLICT (org_id, location_name) DO NOTHING;

INSERT INTO location (org_id, location_name, address, city, country)
SELECT org_id, 'DC Milano', 'Strada Datacenter 1', 'Milano', 'IT'
FROM organization WHERE org_name='AlfaServizi S.r.l.'
ON CONFLICT (org_id, location_name) DO NOTHING;

-- roles
INSERT INTO role (role_code, role_name) VALUES
 ('CISO','Responsabile Sicurezza Informazioni'),
 ('DPO','Data Protection Officer'),
 ('IT_MGR','IT Manager'),
 ('SERV_MGR','Service Manager')
ON CONFLICT (role_code) DO NOTHING;

-- people
INSERT INTO person (org_id, full_name, email, phone, department)
SELECT org_id, 'Giulia Bianchi', 'giulia.bianchi@alfaservizi.it', '+39-06-0000001', 'IT'
FROM organization WHERE org_name='AlfaServizi S.r.l.'
ON CONFLICT (org_id, email) DO NOTHING;

INSERT INTO person (org_id, full_name, email, phone, department)
SELECT org_id, 'Marco Rossi', 'marco.rossi@alfaservizi.it', '+39-06-0000002', 'Security'
FROM organization WHERE org_name='AlfaServizi S.r.l.'
ON CONFLICT (org_id, email) DO NOTHING;

INSERT INTO person (org_id, full_name, email, phone, department)
SELECT org_id, 'Sara Verdi', 'sara.verdi@alfaservizi.it', '+39-06-0000003', 'Operations'
FROM organization WHERE org_name='AlfaServizi S.r.l.'
ON CONFLICT (org_id, email) DO NOTHING;

INSERT INTO person (org_id, full_name, email, phone, department)
SELECT org_id, 'Alberto Mauro', 'alberto.mauro@alfaservizi.it', '+39-06-0000004', 'Privacy'
FROM organization WHERE org_name='AlfaServizi S.r.l.'
ON CONFLICT (org_id, email) DO NOTHING;

-- person_role
INSERT INTO person_role (person_id, role_id, valid_from)
SELECT p.person_id, r.role_id, CURRENT_DATE
FROM person p
JOIN role r ON r.role_code='IT_MGR'
WHERE p.email='giulia.bianchi@alfaservizi.it'
ON CONFLICT DO NOTHING;

INSERT INTO person_role (person_id, role_id, valid_from)
SELECT p.person_id, r.role_id, CURRENT_DATE
FROM person p
JOIN role r ON r.role_code='CISO'
WHERE p.email='marco.rossi@alfaservizi.it'
ON CONFLICT DO NOTHING;

INSERT INTO person_role (person_id, role_id, valid_from)
SELECT p.person_id, r.role_id, CURRENT_DATE
FROM person p
JOIN role r ON r.role_code='SERV_MGR'
WHERE p.email='sara.verdi@alfaservizi.it'
ON CONFLICT DO NOTHING;

INSERT INTO person_role (person_id, role_id, valid_from)
SELECT p.person_id, r.role_id, CURRENT_DATE
FROM person p
JOIN role r ON r.role_code='DPO'
WHERE p.email='alberto.mauro@alfaservizi.it'
ON CONFLICT DO NOTHING;


-- suppliers (versioning through function)
SELECT acn.upsert_supplier(o.org_id,'SUP-AWS','Amazon Web Services','cloud','CNTR-2024-001','CRITICAL')
FROM acn.organization o WHERE o.org_name='AlfaServizi S.r.l.';

SELECT acn.upsert_supplier(o.org_id,'SUP-TIM','TIM Enterprise','connectivity','CNTR-2023-014','HIGH')
FROM acn.organization o WHERE o.org_name='AlfaServizi S.r.l.';

SELECT acn.upsert_supplier(o.org_id,'SUP-Azure','Microsoft Azure','connectivity','CNTR-2025-011','HIGH')
FROM acn.organization o WHERE o.org_name='AlfaServizi S.r.l.';

-- services
SELECT acn.upsert_service(o.org_id,'SVC-CRM','CRM Clienti','Piattaforma CRM multitenant','CRITICAL','99.9%',4,1)
FROM acn.organization o WHERE o.org_name='AlfaServizi S.r.l.';

SELECT acn.upsert_service(o.org_id,'SVC-SIEM','Security Monitoring','Raccolta log e correlazione eventi','HIGH','99.5%',8,4)
FROM acn.organization o WHERE o.org_name='AlfaServizi S.r.l.';

SELECT acn.upsert_service(o.org_id,'SVC-SW','Service Control Room','Piattaforma di monitoraggio degli allarmi','HIGH','99.9%',1,1)
FROM acn.organization o WHERE o.org_name='AlfaServizi S.r.l.';

-- assets
WITH org AS (
  SELECT org_id FROM acn.organization WHERE org_name='AlfaServizi S.r.l.'
),
loc AS (
  SELECT location_id FROM acn.location l JOIN org o ON o.org_id=l.org_id WHERE location_name='DC Torino'
),
owner AS (
  SELECT person_id FROM acn.person p JOIN org o ON o.org_id=p.org_id WHERE email='giulia.bianchi@alfaservizi.it'
)
SELECT acn.upsert_asset((SELECT org_id FROM org),'AST-DB-01','Database CRM Prod','HARDWARE','Server fisico DB','CRITICAL',
                       (SELECT location_id FROM loc),'SRV-DB-0001',(SELECT person_id FROM owner));

WITH org AS (
  SELECT org_id FROM acn.organization WHERE org_name='AlfaServizi S.r.l.'
),
loc AS (
  SELECT location_id FROM acn.location l JOIN org o ON o.org_id=l.org_id WHERE location_name='HQ Roma'
),
owner AS (
  SELECT person_id FROM acn.person p JOIN org o ON o.org_id=p.org_id WHERE email='marco.rossi@alfaservizi.it'
)
SELECT acn.upsert_asset((SELECT org_id FROM org),'AST-SIEM','SIEM Platform','SOFTWARE','Stack SIEM e log collector','HIGH',
                       (SELECT location_id FROM loc),NULL,(SELECT person_id FROM owner));

WITH org AS (
  SELECT org_id FROM acn.organization WHERE org_name='AlfaServizi S.r.l.'
),
loc AS (
  SELECT location_id FROM acn.location l JOIN org o ON o.org_id=l.org_id WHERE location_name='DC Milano'
),
owner AS (
  SELECT person_id FROM acn.person p JOIN org o ON o.org_id=p.org_id WHERE email='alberto.mauro@alfaservizi.it'
)
SELECT acn.upsert_asset((SELECT org_id FROM org),'SVC-SW','SCR Platform','SOFTWARE','Service Control Room','HIGH',
                       (SELECT location_id FROM loc),NULL,(SELECT person_id FROM owner));
-- dependencies
INSERT INTO service_asset_dependency (org_id, service_id, asset_id, dep_type, is_critical_dep, note)
SELECT o.org_id, s.service_id, a.asset_id, 'RUNS_ON', TRUE, 'CRM usa DB principale'
FROM organization o
JOIN service s ON s.org_id=o.org_id AND s.is_current AND s.business_key='SVC-CRM'
JOIN asset a ON a.org_id=o.org_id AND a.is_current AND a.business_key='AST-DB-01'
WHERE o.org_name='AlfaServizi S.r.l.'
ON CONFLICT DO NOTHING;

INSERT INTO service_supplier_dependency (org_id, service_id, supplier_id, dep_type, is_critical_dep, note)
SELECT o.org_id, s.service_id, sup.supplier_id, 'HOSTED_BY', TRUE, 'CRM in cloud'
FROM organization o
JOIN service s ON s.org_id=o.org_id AND s.is_current AND s.business_key='SVC-CRM'
JOIN supplier sup ON sup.org_id=o.org_id AND sup.is_current AND sup.business_key='SUP-AWS'
WHERE o.org_name='AlfaServizi S.r.l.'
ON CONFLICT DO NOTHING;

INSERT INTO service_supplier_dependency (org_id, service_id, supplier_id, dep_type, is_critical_dep, note)
SELECT o.org_id, s.service_id, sup.supplier_id, 'CONNECTS_TO', TRUE, 'Connettività principale'
FROM organization o
JOIN service s ON s.org_id=o.org_id AND s.is_current AND s.business_key='SVC-CRM'
JOIN supplier sup ON sup.org_id=o.org_id AND sup.is_current AND sup.business_key='SUP-TIM'
WHERE o.org_name='AlfaServizi S.r.l.'
ON CONFLICT DO NOTHING;

-- contacts
-- Service manager per CRM = Sara Verdi
INSERT INTO contact_point (org_id, contact_kind, person_id, service_id, note)
SELECT o.org_id, 'SERVICE_MANAGER', p.person_id, s.service_id, 'Referente operativo CRM'
FROM organization o
JOIN person p ON p.org_id=o.org_id AND p.email='sara.verdi@alfaservizi.it'
JOIN service s ON s.org_id=o.org_id AND s.is_current AND s.business_key='SVC-CRM'
WHERE o.org_name='AlfaServizi S.r.l.'
ON CONFLICT DO NOTHING;

-- Asset owner DB = Giulia Bianchi
INSERT INTO contact_point (org_id, contact_kind, person_id, asset_id, note)
SELECT o.org_id, 'ASSET_OWNER', p.person_id, a.asset_id, 'Owner tecnico del DB CRM'
FROM organization o
JOIN person p ON p.org_id=o.org_id AND p.email='giulia.bianchi@alfaservizi.it'
JOIN asset a ON a.org_id=o.org_id AND a.is_current AND a.business_key='AST-DB-01'
WHERE o.org_name='AlfaServizi S.r.l.'
ON CONFLICT DO NOTHING;

-- ---------------- FNCS controls (esempio minimo) ----------------
-- Functions
INSERT INTO control_function (code, name) VALUES
 ('ID','Identify'),
 ('PR','Protect'),
 ('DE','Detect'),
 ('RS','Respond'),
 ('RC','Recover')
ON CONFLICT (code) DO NOTHING;

-- Categories (subset dimostrativo)
INSERT INTO control_category (function_id, code, name)
SELECT f.function_id, x.code, x.name
FROM (VALUES
  ('ID','ID.AM','Asset Management'),
  ('PR','PR.AC','Identity Management, Authentication and Access Control'),
  ('DE','DE.CM','Security Continuous Monitoring')
) AS x(fn_code, code, name)
JOIN control_function f ON f.code = x.fn_code
ON CONFLICT (code) DO NOTHING;

-- Subcategories (subset dimostrativo)
INSERT INTO control_subcategory (category_id, code, description)
SELECT c.category_id, x.code, x.description
FROM (VALUES
  ('ID.AM','ID.AM-1','I dispositivi e i sistemi fisici dell’organizzazione sono inventariati.'),
  ('ID.AM','ID.AM-2','Piattaforme software e applicazioni sono inventariate.'),
  ('PR.AC','PR.AC-1','Identità e credenziali sono gestite per utenti, dispositivi e servizi.'),
  ('DE.CM','DE.CM-1','La rete è monitorata per individuare eventi potenzialmente anomali.')
) AS x(cat_code, code, description)
JOIN control_category c ON c.code = x.cat_code
ON CONFLICT (code) DO NOTHING;

-- Profili (Current/Target) per AlfaServizi
INSERT INTO control_profile (org_id, profile_type, profile_name)
SELECT o.org_id, 'CURRENT', 'Profilo Attuale 2026-02'
FROM organization o WHERE o.org_name='AlfaServizi S.r.l.'
ON CONFLICT DO NOTHING;

INSERT INTO control_profile (org_id, profile_type, profile_name)
SELECT o.org_id, 'TARGET', 'Profilo Target 2026-12'
FROM organization o WHERE o.org_name='AlfaServizi S.r.l.'
ON CONFLICT DO NOTHING;

-- Assessment (stato implementazione) - esempi
-- Owner: Marco Rossi (CISO) per controlli sicurezza, Giulia Bianchi (IT) per inventario asset
WITH org AS (SELECT org_id FROM organization WHERE org_name='AlfaServizi S.r.l.'),
cur AS (
  SELECT profile_id FROM control_profile cp JOIN org o ON o.org_id=cp.org_id
  WHERE cp.profile_type='CURRENT' AND cp.profile_name='Profilo Attuale 2026-02'
),
tgt AS (
  SELECT profile_id FROM control_profile cp JOIN org o ON o.org_id=cp.org_id
  WHERE cp.profile_type='TARGET' AND cp.profile_name='Profilo Target 2026-12'
),
p_it AS (
  SELECT person_id FROM person p JOIN org o ON o.org_id=p.org_id WHERE p.email='giulia.bianchi@alfaservizi.it'
),
p_ciso AS (
  SELECT person_id FROM person p JOIN org o ON o.org_id=p.org_id WHERE p.email='marco.rossi@alfaservizi.it'
)
INSERT INTO control_assessment (profile_id, subcategory_id, implementation, evidence, owner_person_id)
SELECT (SELECT profile_id FROM cur), sc.subcategory_id, x.impl, x.evidence,
       CASE WHEN sc.code LIKE 'ID.%' THEN (SELECT person_id FROM p_it) ELSE (SELECT person_id FROM p_ciso) END
FROM (VALUES
  ('ID.AM-1','IMPLEMENTED'::implementation_level,'Inventario asset mantenuto nel DB (tabelle asset/location) con business_key e versioning.'),
  ('ID.AM-2','PARTIAL'::implementation_level,'Inventario applicazioni presente; mancano alcuni componenti legacy.'),
  ('PR.AC-1','PARTIAL'::implementation_level,'Gestione identità con IAM su AWS; formalizzazione processi di revisione accessi in corso.'),
  ('DE.CM-1','IMPLEMENTED'::implementation_level,'Monitoraggio continuo tramite SIEM; log centralizzati e alerting.')
) AS x(code, impl, evidence)
JOIN control_subcategory sc ON sc.code=x.code
ON CONFLICT (profile_id, subcategory_id) DO NOTHING;

-- Target: obiettivo "IMPLEMENTED" su tutte le subcategory incluse
WITH org AS (SELECT org_id FROM organization WHERE org_name='AlfaServizi S.r.l.'),
tgt AS (
  SELECT profile_id FROM control_profile cp JOIN org o ON o.org_id=cp.org_id
  WHERE cp.profile_type='TARGET' AND cp.profile_name='Profilo Target 2026-12'
),
p_ciso AS (
  SELECT person_id FROM person p JOIN org o ON o.org_id=p.org_id WHERE p.email='marco.rossi@alfaservizi.it'
)
INSERT INTO control_assessment (profile_id, subcategory_id, implementation, evidence, owner_person_id)
SELECT (SELECT profile_id FROM tgt), sc.subcategory_id, 'IMPLEMENTED',
       'Target: controllo pianificato/standardizzato nel programma di compliance NIS2.', (SELECT person_id FROM p_ciso)
FROM control_subcategory sc
WHERE sc.code IN ('ID.AM-1','ID.AM-2','PR.AC-1','DE.CM-1')
ON CONFLICT (profile_id, subcategory_id) DO NOTHING;

-- Mapping controlli ↔ asset (quali asset rientrano nel perimetro della subcategory)
WITH o AS (SELECT org_id FROM organization WHERE org_name='AlfaServizi S.r.l.'),
a_db AS (SELECT asset_id FROM asset a JOIN o ON o.org_id=a.org_id WHERE a.is_current AND a.business_key='AST-DB-01'),
a_siem AS (SELECT asset_id FROM asset a JOIN o ON o.org_id=a.org_id WHERE a.is_current AND a.business_key='AST-SIEM')
INSERT INTO asset_control (org_id, asset_id, subcategory_id, applicable, note)
SELECT (SELECT org_id FROM o), (SELECT asset_id FROM a_db), sc.subcategory_id, TRUE, 'Inventario e gestione credenziali per DB CRM'
FROM control_subcategory sc
WHERE sc.code IN ('ID.AM-1','PR.AC-1')
ON CONFLICT (asset_id, subcategory_id) DO NOTHING;

WITH o AS (SELECT org_id FROM organization WHERE org_name='AlfaServizi S.r.l.'),
a_siem AS (SELECT asset_id FROM asset a JOIN o ON o.org_id=a.org_id WHERE a.is_current AND a.business_key='AST-SIEM')
INSERT INTO asset_control (org_id, asset_id, subcategory_id, applicable, note)
SELECT (SELECT org_id FROM o), (SELECT asset_id FROM a_siem), sc.subcategory_id, TRUE, 'SIEM come controllo di monitoraggio continuo'
FROM control_subcategory sc
WHERE sc.code IN ('ID.AM-2','DE.CM-1')
ON CONFLICT (asset_id, subcategory_id) DO NOTHING;

COMMIT;
