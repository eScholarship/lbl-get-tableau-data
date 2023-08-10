-- USE "elements-cdl-prod-reporting";

-- Unclaimed Publication Metadata
-- Not required for the dashboard, but potential useful to have around
SELECT DISTINCT(p.[ID]) as "system_id",
LOWER(p.[doi]) as "doi",
-- Claimed By
u.[LBL Employee ID] as "unclaimed_id",
-- EPPN
u.[LBL Email] as "unclaimed_email"
FROM [Publication] p
JOIN [Pending Publication] pp ON p.[ID] = pp.[Publication ID]
JOIN [User] u on u.[ID] = pp.[User ID]
WHERE u.[Primary Group Descriptor] LIKE '%lbl-%'
  AND u.[Primary Group Descriptor] NOT IN ('lbl-delegate','lbl-admin')
  AND p.[Reporting Date 1] > '2015-12-31'
  AND p.[doi] is not NULL
  AND (u.[LBL Email] is not NULL OR u.[LBL Employee ID] is not NULL)
  -- Should filter out publications with ANY LBL claimants
  AND p.ID not in (
      select [Publication ID] from [Publication User Relationship] pur
      INNER JOIN [User] u on u.[ID] = pur.[User ID]
     WHERE u.[Primary Group Descriptor] LIKE '%lbl-%');