WITH alerts AS (
	SELECT
	b.*,
	CASE WHEN b.height NOT BETWEEN b.lcl AND b.ucl
		 THEN TRUE
		 ELSE FALSE
		 END AS alert
	FROM (
		SELECT
			a.*, 
			a.avg_height + 3*a.stddev_height/SQRT(5) AS ucl, 
			a.avg_height - 3*a.stddev_height/SQRT(5) AS lcl  
		FROM (
			SELECT
				item_no,
				operator,
				ROW_NUMBER() OVER w AS row_number, 
				height, 
				AVG(height) OVER w AS avg_height, 
				STDDEV(height) OVER w AS stddev_height
			FROM manufacturing_parts 
			WINDOW w AS (
				PARTITION BY operator 
				ORDER BY item_no 
				ROWS BETWEEN 4 PRECEDING AND CURRENT ROW
			)
		) AS a
		WHERE a.row_number >= 5
	) AS b
),
operator_alerts AS (
    SELECT
        operator,
        COUNT(*) AS alert_count
    FROM alerts
    WHERE alert = TRUE
    GROUP BY operator
),
alert_stats AS (
	SELECT
		operator,
		alert_count,
		SUM(alert_count) OVER() AS total_alerts,
		alert_count / NULLIF(SUM(alert_count) OVER()::FLOAT, 0) AS alert_rate,
		1 / (COUNT(operator) OVER())::FLOAT AS avg_alert_rate
	FROM operator_alerts
)
SELECT
	operator,
	alert_count,
	alert_rate,
	avg_alert_rate,
	alert_rate > avg_alert_rate AS above_average
FROM alert_stats
ORDER BY alert_count DESC;
