
CREATE CLUSTERED INDEX
idx_lbl_pubs ON #lbl_pubs([Publication ID] ASC, [claimed] DESC);

CREATE CLUSTERED INDEX
idx_lbl_users ON #lbl_users([user id] ASC);

-- User Pub Relationship
SET TRANSACTION ISOLATION LEVEL SNAPSHOT;
BEGIN TRANSACTION;

with lbl_pur_full as (
	select
		lp.[publication id],
		lu.[User ID],
		CASE WHEN pur.[User ID] IS NULL
			THEN 1 else 0
			END AS [user_claim],
		ROW_NUMBER() OVER(
			PARTITION BY
				lp.[Publication ID]
			ORDER BY
				-- Ensures claims are ordered before pending
				CASE WHEN pur.[User ID] IS NULL
					THEN 0 ELSE 1 END,
				lu.[User ID] asc
			) AS [author_count]
	from
		#lbl_pubs lp
			left join [publication user relationship] pur
				on lp.[publication id] = pur.[publication id]
				and pur.[User ID] in (select [User ID] from #lbl_users)
			left join [pending publication] pp
				on lp.[publication id] = pp.[publication id]
				and pp.[User ID] in (select [User ID] from #lbl_users)
			join #lbl_users lu
				on pur.[user ID] = lu.[User ID]
				or pp.[User ID] = lu.[User ID]
)
select distinct
	[publication id],
	[user id],
	[user_claim]
from
	lbl_pur_full
where
	[author_count] <= 10
order by
	[publication id],
	[user_claim] desc,
	[user id];

COMMIT TRANSACTION;