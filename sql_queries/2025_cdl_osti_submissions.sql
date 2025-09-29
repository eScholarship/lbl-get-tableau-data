select
	id as cdl_osti_submission_id,
	osti_id,
	elements_id,
	eschol_id,
	case when doi is null
		then osti_doi else doi
		end as doi,
	date_stamp,
	case when MONTH(date_stamp) >= 10
		THEN (year(date_stamp) + 1)
		ELSE year(date_stamp)
		END AS fiscal_year,
	case
		when (media_response_code = 200
			or media_response_code = 201)
			THEN 'success'
		when (media_response_code is NULL
			AND date_stamp <= '2025-06-01')
			THEN 'E-Link 1'
		else 'failure' end as 'media_response'
from
	osti_submissions_live
	where date_stamp > '2023-01-01'
order by id desc;