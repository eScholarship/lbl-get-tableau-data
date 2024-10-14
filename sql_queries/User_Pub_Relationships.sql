SET TRANSACTION ISOLATION LEVEL SNAPSHOT
BEGIN TRANSACTION;

-- User Pub Links
SELECT DISTINCT(p.[ID]) as "system_id",
LOWER(p.[doi]) as "doi",
-- Claimed By
u.[LBL Employee ID] as "id",
-- EPPN
u.[LBL Email] as "email",
'claim' as "link_type"
FROM [Publication] p
INNER JOIN [Publication User Relationship] pur ON p.[ID] = pur.[Publication ID]
INNER JOIN [User] u on u.[ID] = pur.[User ID]
WHERE u.[Primary Group Descriptor] LIKE '%lbl-%'
  AND u.[Primary Group Descriptor] NOT IN ('lbl-delegate','lbl-admin')
  -- Reporting date cutoff (adjust as need)
  AND p.[Reporting Date 1] > '2016-12-31'
UNION
-- Unclaimed Publication Metadata
SELECT DISTINCT(p.[ID]) as "system_id",
LOWER(p.[doi]) as "doi",
-- Claimed By
u.[LBL Employee ID] as "id",
-- EPPN
u.[LBL Email] as "email",
'potential claim' as "link_type"
FROM [Publication] p
JOIN [Pending Publication] pp ON p.[ID] = pp.[Publication ID]
JOIN [User] u on u.[ID] = pp.[User ID]
WHERE u.[Primary Group Descriptor] LIKE '%lbl-%'
  AND u.[Primary Group Descriptor] NOT IN ('lbl-delegate','lbl-admin')
  -- Reporting date cutoff (adjust as needed)
  AND p.[Reporting Date 1] > '2016-12-31'
  AND p.[doi] is not NULL
  AND (u.[LBL Email] is not NULL OR u.[LBL Employee ID] is not NULL)
  -- Should filter out publications with ANY LBL claimants
  AND p.ID not in (
      select [Publication ID] from [Publication User Relationship] pur
      INNER JOIN [User] u on u.[ID] = pur.[User ID]
     WHERE u.[Primary Group Descriptor] LIKE '%lbl-%');

COMMIT TRANSACTION