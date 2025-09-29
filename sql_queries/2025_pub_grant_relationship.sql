-- Grant-pub relationship
BEGIN TRANSACTION;

SELECT DISTINCT
	lp.[Publication ID],
	dg.*,
	CASE WHEN
		dg.[Grant ID] IS NULL
		THEN 1 ELSE 0 END AS [Non-DOE funding]
FROM
	#lbl_pubs lp
		LEFT JOIN [Grant Publication Relationship] gpr
			on lp.[publication id] = gpr.[Publication ID]
		LEFT JOIN #doe_grants dg
			ON dg.[Grant ID] = gpr.[Grant ID]

COMMIT TRANSACTION;
