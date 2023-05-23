
view: revenue_charge_cap {
  derived_table: {
    sql:
        SELECT
        barcode
        , order_id
        , total_charges
        , total_revenue
        , product
        , completed_on
        , revenue_recorded_timestamp
        , CASE
            WHEN network_status = 'INN' THEN 'INN Charge Cap Adjustment'
            WHEN network_status = 'OON' THEN 'OON Charge Cap Adjustment' END AS revenue_type
        , payer_name
        , CASE WHEN (coalesce(total_charges,0) - coalesce(total_revenue,0)) < 0 THEN coalesce(total_charges,0) - coalesce(total_revenue,0) END AS revenue_overage
        FROM(
          SELECT
          barcode
          , ord.id as order_id
          , total_charges
          , completed_on
          , revenue_recorded_timestamp
          , CASE
            WHEN ord.product = 'Foresight Carrier Screen' and testing_methodology = 0 THEN 'Foresight 1.0'
            WHEN ord.product = 'Foresight Carrier Screen' and testing_methodology = 1 THEN 'Foresight 2.0'
            ELSE ord.product END as product
          , CASE
              WHEN ord.product = 'Foresight Carrier Screen' and date_of_service >= inn.fps_date and date_of_service < coalesce(inn.fps_term,'2100-01-01'::date) THEN 'INN'
              WHEN ord.product = 'Reliant Cancer Screen' and date_of_service >= inn.ics_date and date_of_service < coalesce(inn.ics_term,'2100-01-01'::date) THEN 'INN'
              WHEN ord.product = 'Prelude Prenatal Screen' and date_of_service >= inn.ips_date and date_of_service < coalesce(inn.ips_term,'2100-01-01'::date) THEN 'INN'
              ELSE 'OON' END AS network_status
          , pay.name AS payer_name
          , SUM(coalesce(revenue, 0)) AS total_revenue
          FROM ${all_revenue.SQL_TABLE_NAME} rev
          INNER JOIN ${order.SQL_TABLE_NAME} ord ON ord.id = rev.order_id
          INNER JOIN current.insuranceclaim clm ON ord.id = clm.order_id
          LEFT JOIN current.insurancepayer pay ON pay.id = clm.payer_id
          LEFT JOIN uploads.in_network_dates_w_terminal inn ON inn.id = pay.id
          WHERE revenue_type IN ('INN Insurance Revenue','INN Customer Revenue','INN Invoice Flux','OON Insurance Revenue','OON Customer Revenue','OON Invoice Flux')
          AND status_name NOT IN ('Canceled Chose Cash','Canceled Chose Consignment','Maximum OOP - No Insurance','Invoiced - Cash (Bad Info)')
          GROUP BY 1,2,3,4,5,6,7,8) AS sub;;

      sql_trigger_value: select (revenue) from ${all_revenue.SQL_TABLE_NAME} ;;
    }

    dimension: barcode {
      type: string
      sql: ${TABLE}.barcode ;;
    }

    dimension: order_id {
      type: number
      sql: ${TABLE}.order_id ;;
    }

    dimension: revenue_type {
      type: string
      sql: ${TABLE}.revenue_type ;;
    }

    dimension: payer_name {
      type: string
      sql: ${TABLE}.payer_name ;;
    }

    dimension: product {
      type: string
      sql: ${TABLE}.product ;;
    }

    dimension: total_revenue {
      type: number
      sql: ${TABLE}.total_revenue;;
    }

    dimension: total_charges {
      type: number
      sql: ${TABLE}.total_charges;;
    }

    measure: revenue_overage {
      type: sum
      value_format_name: usd
      sql: ${TABLE}.revenue_overage;;
    }

    dimension_group: revenue_recorded {
      type: time
      timeframes: [quarter, date, week, month, year]
      sql: ${TABLE}.revenue_recorded_timestamp ;;
    }

    dimension_group: completed_on {
      type: time
      timeframes: [quarter, date, week, month, year]
      sql: ${TABLE}.completed_on ;;
    }


    #dimension: total_charges {
    #  type: number
    #  sql: ${TABLE}.total_charges;;
    #}


  }
