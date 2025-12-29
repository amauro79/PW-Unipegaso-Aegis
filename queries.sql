-- Query richieste dalla traccia: estrazione porzioni utili al profilo ACN

SET search_path TO acn;

-- 1) Elenco asset critici per azienda (solo versioni correnti)
SELECT * FROM acn.v_assets_critical_current
WHERE org_name = 'AlfaServizi S.r.l.'
ORDER BY criticality DESC, asset_name;

-- 2) Servizi erogati (con criticità) e contatto primario
SELECT
  o.org_name,
  s.business_key AS service_code,
  s.service_name,
  s.criticality,
  COALESCE(cp_mgr.full_name, cp_owner.full_name) AS primary_contact,
  COALESCE(cp_mgr.email, cp_owner.email)         AS primary_contact_email
FROM service s
JOIN organization o ON o.org_id=s.org_id
LEFT JOIN LATERAL (
  SELECT p.full_name, p.email
  FROM contact_point c JOIN person p ON p.person_id=c.person_id
  WHERE c.service_id=s.service_id AND c.contact_kind='SERVICE_MANAGER'
  LIMIT 1
) cp_mgr ON TRUE
LEFT JOIN LATERAL (
  SELECT p.full_name, p.email
  FROM contact_point c JOIN person p ON p.person_id=c.person_id
  WHERE c.service_id=s.service_id AND c.contact_kind='SERVICE_OWNER'
  LIMIT 1
) cp_owner ON TRUE
WHERE o.org_name='AlfaServizi S.r.l.' AND s.is_current
ORDER BY s.criticality DESC, s.service_name;

-- 3) Dipendenze da terze parti (fornitori) per servizio
SELECT * FROM acn.v_service_third_party_deps
WHERE org_name='AlfaServizi S.r.l.'
ORDER BY service_criticality DESC, service_name, is_critical_dep DESC;

-- 4) Output "minimo" (tabellare) pensato per esportazione CSV
SELECT * FROM acn.v_acn_profile_min
WHERE org_name='AlfaServizi S.r.l.'
ORDER BY service_criticality DESC, service_name;

-- Suggerimento export CSV (da psql):
-- \copy (SELECT * FROM acn.v_acn_profile_min WHERE org_name='AlfaServizi S.r.l.') TO 'acn_profile_min.csv' CSV HEADER;
