-- Dati di test (simulati) per AlfaServizi S.r.l.
BEGIN;
SET search_path TO acn;

INSERT INTO organization (org_name, vat_code) VALUES
  ('AlfaServizi S.r.l.', 'IT12345678901')
ON CONFLICT (org_name) DO NOTHING;

-- locations
INSERT INTO location (org_id, location_name, address, city, country)
SELECT org_id, 'HQ Milano', 'Via Innovazione 10', 'Milano', 'IT'
FROM organization WHERE org_name='AlfaServizi S.r.l.'
ON CONFLICT (org_id, location_name) DO NOTHING;

INSERT INTO location (org_id, location_name, address, city, country)
SELECT org_id, 'DC Torino', 'Strada Datacenter 3', 'Torino', 'IT'
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
SELECT org_id, 'Giulia Bianchi', 'giulia.bianchi@alfaservizi.it', '+39-02-0000001', 'IT'
FROM organization WHERE org_name='AlfaServizi S.r.l.'
ON CONFLICT (org_id, email) DO NOTHING;

INSERT INTO person (org_id, full_name, email, phone, department)
SELECT org_id, 'Marco Rossi', 'marco.rossi@alfaservizi.it', '+39-02-0000002', 'Security'
FROM organization WHERE org_name='AlfaServizi S.r.l.'
ON CONFLICT (org_id, email) DO NOTHING;

INSERT INTO person (org_id, full_name, email, phone, department)
SELECT org_id, 'Sara Verdi', 'sara.verdi@alfaservizi.it', '+39-02-0000003', 'Operations'
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

-- suppliers (versioning through function)
SELECT acn.upsert_supplier(o.org_id,'SUP-AWS','Amazon Web Services','cloud','CNTR-2024-001','CRITICAL')
FROM acn.organization o WHERE o.org_name='AlfaServizi S.r.l.';

SELECT acn.upsert_supplier(o.org_id,'SUP-TIM','TIM Enterprise','connectivity','CNTR-2023-014','HIGH')
FROM acn.organization o WHERE o.org_name='AlfaServizi S.r.l.';

-- services
SELECT acn.upsert_service(o.org_id,'SVC-CRM','CRM Clienti','Piattaforma CRM multitenant','CRITICAL','99.9%',4,1)
FROM acn.organization o WHERE o.org_name='AlfaServizi S.r.l.';

SELECT acn.upsert_service(o.org_id,'SVC-SIEM','Security Monitoring','Raccolta log e correlazione eventi','HIGH','99.5%',8,4)
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
  SELECT location_id FROM acn.location l JOIN org o ON o.org_id=l.org_id WHERE location_name='HQ Milano'
),
owner AS (
  SELECT person_id FROM acn.person p JOIN org o ON o.org_id=p.org_id WHERE email='marco.rossi@alfaservizi.it'
)
SELECT acn.upsert_asset((SELECT org_id FROM org),'AST-SIEM','SIEM Platform','SOFTWARE','Stack SIEM e log collector','HIGH',
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

COMMIT;
