-- USE "elements-cdl-prod-reporting";
-- Retrieves pubs claimed by LBL users within the past 7 years (to filter out extremely out entries for elements)
-- for the purpose of measuring compliance.
-- Publication Metadata
SELECT DISTINCT(p.[ID]) as "system_id",
-- Case insensitive DOI, make sure to join against a lowered version
LOWER(p.[doi]) as "doi",
p.[Type] as "pub_type",
REPLACE(REPLACE(p.[title], CHAR(13), ''), CHAR(10), '') as "title",
COALESCE(REPLACE(REPLACE(p.[journal], CHAR(13), ''), CHAR(10), ''), '') as "journal",
COALESCE(p.[volume], '') as "volume",
COALESCE(p.[issue], '') as "issue",
p.[publication-date] as "publication_date",
-- Deposited
(SELECT COUNT(DISTINCT(pr.[Publication ID])) FROM [Publication Record] pr
WHERE pr.[Publication ID] = p.[ID]
AND pr.[record-created-at-source-date] IS NOT NULL
AND pr.[Data Source] = N'eScholarship')
as "deposited",
-- Funding Linked
(SELECT COUNT(DISTINCT(gur.[Grant ID])) FROM [Grant Publication Relationship] gur
WHERE gur.[Publication ID] = p.[ID])
as "funding_linked",
-- Funding Sources
(SELECT g.[funder-reference] + ';' AS 'data()'  FROM [Grant Publication Relationship] gur
JOIN [Grant] g ON gur.[Grant ID] = g.[ID]
WHERE gur.[Publication ID] = p.[ID]
FOR XML PATH(''))
as "funding_source",
-- Citation Count
(SELECT MAX(pr.[Citation Count]) FROM [Publication Record] pr
WHERE pr.[Publication ID] = p.[ID])
as "citation_count",
-- eschol link
(SELECT TOP 1 pr.[public-url] FROM [Publication Record] pr
WHERE pr.[Publication ID] = p.[ID]
AND pr.[public-url] IS NOT NULL)
as "escholarship_link",
-- author provided url
(SELECT TOP 1 pr.[author-url] from [Publication Record] pr
WHERE pr.[Publication ID] = p.[ID]
AND pr.[author-url] is NOT NULL)
as "author_link",
-- keep, indicates graduate work from lbl employees
p.[Flagged As Not Externally Funded] as 'not_externally_funded',
-- OA policy exception
(select oaex.[Type] AS 'data()' from [Publication OA Policy Exception] oaex
    where p.[ID] = oaex.[Publication ID]
for XML PATH(''))
as "oa_policy_exception",
-- OA status
(SELECT DISTINCT [Compliance Status] AS 'data()' from [Publication OA Policy] poap where
    poap.[Publication ID] = p.[ID] FOR XML PATH(''))
as "oa_status"
FROM [Publication] p
WHERE p.[Reporting Date 1] > '2016-12-31'
-- This is so ugly but it works
-- All pubs claimed by at least one LBL author
AND (p.[ID] in (
        SELECT p.[ID]
        FROM [Publication] p
        JOIN [Publication User Relationship] pur on p.[ID] = pur.[Publication ID]
        INNER JOIN [User] u on u.[ID] = pur.[User ID]
        WHERE u.[Primary Group Descriptor] LIKE '%lbl-%'
        AND u.[LBL Employee ID] is not NULL)
    -- All pubs that could be claimed by at least one LBL author
    OR p.[ID] in (
        SELECT p.[ID]
        FROM [Publication] p
        JOIN [Pending Publication] pp ON p.[ID] = pp.[Publication ID]
        INNER JOIN [User] u on u.[ID] = pp.[User ID]
        WHERE u.[Primary Group Descriptor] LIKE '%lbl-%'
        AND u.[LBL Employee ID] is not NULL
        AND p.[doi] is not NULL));