
-- Temp table: LBL users
SET TRANSACTION ISOLATION LEVEL SNAPSHOT;
BEGIN TRANSACTION;

SELECT DISTINCT
	u.[ID] as [User ID],
	u.[Proprietary ID] as [ucpath_id],
	u.[Computed Name Full],
	u.[Email],
	u.[Primary Group Descriptor]
INTO
	#lbl_users
FROM
	[User] u
WHERE
	u.[Primary Group Descriptor] LIKE '%lbl-%'
	AND u.[LBL Employee ID] IS NOT NULL;

COMMIT TRANSACTION;




-- Temp table: DOE grants
SET TRANSACTION ISOLATION LEVEL SNAPSHOT;
BEGIN TRANSACTION;

SELECT DISTINCT
	g.[ID] as [Grant ID],
	g.[funder-name],
	g.[funder-reference],
	g.[title]
INTO
	#doe_grants
FROM
	[Grant] g
WHERE
	g.title LIKE 'USDOE%'
	OR g.[Data Source Proprietary ID] LIKE 'lblfund%';

COMMIT TRANSACTION;




-- Temp table: LBL publications
SET TRANSACTION ISOLATION LEVEL SNAPSHOT;
BEGIN TRANSACTION;

DECLARE @pub_start DATE = DATEADD(YEAR, -3, GETDATE());
DECLARE @elements_pub_url VARCHAR(80)
	= 'https://oapolicy.universityofcalifornia.edu/viewobject.html?cid=1&id=';
DECLARE @eschol_pub_url VARCHAR(80)
	= 'https://escholarship.org/uc/item/';

-- Pub IDs for everything in the set
with lbl_pubs as (
	select distinct
		p.id as [publication id],
		case when pur.[user id] is not null
			then 1 else 0
			end as 'claimed'
	from
		[publication] p
			left join [publication user relationship] pur
				on p.id = pur.[publication id]
			left join [pending publication] pp
				on p.id = pp.[publication id]
	where
		p.[Reporting Date 1] > @pub_start
		and (
			pur.[User ID] in (select [User ID] from #lbl_users)
			or pp.[User ID] in (select [User ID] from #lbl_users))
),
-- eSchol records if available, with ranking.
eschol_records as (
	select
		lp.[Publication ID],
		pr.[ID] AS [publication record ID],
		pr.[Data Source Proprietary ID] AS [eschol_id],
		ROW_NUMBER() OVER(
			PARTITION BY lp.[Publication ID]
			ORDER BY pr.[ID]
			) AS [record_number]
	from
		lbl_pubs lp
			JOIN [Publication Record] pr
				ON lp.[Publication ID] = pr.[Publication ID]
				AND pr.[Data Source] = 'eScholarship'
				AND pr.[record-created-at-source-date] IS NOT NULL
),
-- Full metadata record
pub_metadata as (
	select
		p.id as [publication id],
		er.[eschol_id],
		CONCAT(@elements_pub_url, p.[ID]) as [elements_link],
		CASE WHEN er.[eschol_id] IS NOT NULL
			THEN CONCAT(@eschol_pub_url, er.[eschol_id])
			ELSE NULL
			END AS [eschol_link],
		lower(p.doi) as [doi],
		p.[Type] as [pub_type],
		p.[title (cropped)] as [title],
		p.[journal (cropped)] as [journal],
		p.[volume],
		p.[issue],
		p.[publication-date] as [publication_date],
		p.[Flagged As Not Externally Funded] as [not_externally_funded],
		CASE WHEN oax.[Publication ID] IS NOT NULL
			THEN 1 ELSE 0
			END as [oa_policy_exception],
		-- Claimed, deposited, funded
		lp.claimed,
		CASE WHEN er.eschol_id IS NOT NULL
			THEN 1 ELSE 0
			END AS [deposited],
		CASE WHEN dg.[grant id] IS NOT NULL
			THEN 1 ELSE 0
			END AS [doe_grant]
	from [publication] p
		join lbl_pubs as lp
			on p.id = lp.[publication id]
		left join eschol_records er
			on p.id = er.[publication id]
			and er.record_number = 1
		LEFT JOIN [Grant Publication Relationship] gpr
			ON p.id = gpr.[Publication ID]
		LEFT JOIN #doe_grants dg
			ON dg.[Grant ID] = gpr.[Grant ID]
		LEFT JOIN [Publication OA Policy Exception] oax
			ON p.id = oax.[Publication ID]
)
SELECT
	*,
	CASE
		WHEN (not_externally_funded=1 OR oa_policy_exception=1)
			THEN 'Exempt/Exception'
		WHEN (claimed=1 AND deposited=1 AND doe_grant=1)
			THEN 'Complete'
		WHEN (claimed=0)
			THEN 'Unclaimed'
		WHEN (claimed=1 AND deposited=0 AND doe_grant=0)
			THEN 'Claim Only'
		WHEN (claimed=1 AND deposited=0 AND doe_grant=1)
			THEN 'Needs Deposit'
		WHEN (claimed=1 AND deposited=1 AND doe_grant=0)
			THEN 'Needs Funding'
		ELSE 'ERROR'
	END AS [lbl_working_status],
	CASE
		WHEN (not_externally_funded=1 OR oa_policy_exception=1)
		OR (claimed=1 AND deposited=1 AND doe_grant=1)
			THEN 0 ELSE 1
	END AS [lbl_work_needed]
INTO
	#lbl_pubs
FROM
	pub_metadata;

COMMIT TRANSACTION;
