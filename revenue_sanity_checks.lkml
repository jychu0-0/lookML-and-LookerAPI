view: revenue_sanity_checks {
  derived_table: {
    sql:
      SELECT
          foo.order_id
          , foo.barcode
          , foo.aggregate_type
          , foo.revenue_type
          , foo.revenue_recorded_timestamp
          , foo.pkey_type
          , foo.pkey
          , foo.revenue
          , foo.aggregate_type_count
          , CASE
            WHEN foo.aggregate_type <> 'INN' AND (SUM(foo.revenue) OVER(PARTITION BY foo.order_id)) > 1500 THEN '>$1.5k'
            WHEN foo.revenue_type NOT IN ('Consignment Comp','Invoice Flux','Insurer Non-Payment') AND foo.revenue < 0 THEN '<$0'
            WHEN (foo.aggregate_type = 'INN' OR foo.aggregate_type = 'Consignment') AND foo.completed_on IS NOT NULL AND (SUM(foo.revenue) OVER(PARTITION BY foo.order_id)) = 0 THEN 'Completed No Revenue'
            WHEN foo.aggregate_type_count > 1 THEN 'Multiple Types'
            WHEN (foo.aggregate_type = 'INN' OR foo.aggregate_type = 'Consignment') AND DATE(foo.completed_on) <> DATE(foo.revenue_recorded_timestamp) THEN 'INN/CNSMT Rev Rec Date'
            ELSE NULL
            END AS check_failure

      FROM
        (
        SELECT
          rev.order_id
          , rev.barcode
          , rev.revenue_type
          , rev.aggregate_type
          , rev.revenue_recorded_timestamp
          , rev.pkey_type
          , rev.pkey
          , rev.revenue
          , o.completed_on
          , CASE
            WHEN o.product = 'Foresight Carrier Screen' and date_of_service >= fps_date and date_of_service < coalesce(fps_term,'2100-01-01'::date)
              THEN 'In Net'
            WHEN o.product = 'Reliant Cancer Screen' and date_of_service >= ics_date and date_of_service < coalesce(ics_term,'2100-01-01'::date)
              THEN 'In Net'
            WHEN o.product = 'Prelude Prenatal Screen' and date_of_service >= ips_date and date_of_service < coalesce(ips_term ,'2100-01-01'::date)
              THEN 'In Net'
            ELSE 'OON'
            END as network_status
          , distinctcount.aggregate_type_count
        FROM ${all_revenue.SQL_TABLE_NAME} AS rev
        JOIN ${order.SQL_TABLE_NAME} AS o ON o.id = rev.order_id
        JOIN current.insuranceclaim AS claim ON claim.order_id = o.id
        JOIN uploads.in_network_dates_w_terminal inn on inn.id = claim.payer_id
        JOIN
          (
          SELECT
          rev1.order_id
          , COUNT(DISTINCT (CASE WHEN rev1.aggregate_type <> 'JScreen' THEN rev1.aggregate_type END)) AS aggregate_type_count
          FROM ${all_revenue.SQL_TABLE_NAME} AS rev1
          GROUP BY 1) AS distinctcount ON distinctcount.order_id = rev.order_id
        ) AS foo
       ;;
    sql_trigger_value: select string_agg(to_char(full_count,'99999999'),',') from ((select count(*) AS full_count from ${all_revenue.SQL_TABLE_NAME})) AS foo ;;
    indexes: ["order_id", "barcode"]
  }

  dimension: order_id {
    type: number
    hidden: yes
    sql: ${TABLE}.order_id ;;
  }

  dimension: barcode {
    sql: ${TABLE}.barcode ;;
  }

  dimension_group: revenue_recorded {
    type: time
    timeframes: [quarter, date, week, month, year]
    sql: ${TABLE}.revenue_recorded_timestamp ;;
  }

  dimension: revenue_type {
    sql: ${TABLE}.revenue_type ;;
  }

  dimension: aggregate_type {
    sql: ${TABLE}.aggregate_type ;;
  }

  dimension: check_failiure {
    sql: ${TABLE}.check_failure ;;
  }

  dimension: revenue {
    hidden: yes
    sql: ${TABLE}.revenue ;;
  }

  dimension: pkey_type {
    hidden: yes
    sql: ${TABLE}.pkey_type ;;
  }

  dimension: pkey {
    hidden: yes
    sql: ${TABLE}.pkey ;;
  }

  measure: total_revenue {
    label: "$ Total Revenue"
    value_format_name: usd
    type: sum
    sql: ${revenue} ;;
  }
}
