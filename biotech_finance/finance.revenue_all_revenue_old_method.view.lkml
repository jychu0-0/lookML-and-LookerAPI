##view: all_revenue {
##  derived_table: {
##    sql: -- ===================== START ======================================================================================================
##
##                  -- ===================== INN Customer ==================================
##
##                  SELECT
##                    inn_customer_revenue.order_id AS order_id
##                    , inn_customer_revenue.latest_barcode AS barcode
##                    , 'INN Customer Revenue' AS revenue_type
##                    , 'INN' AS aggregate_type
##                    , inn_customer_revenue.completed_on AS revenue_recorded_timestamp
##                    , 'Barcode' AS pkey_type
##                    , inn_customer_revenue.latest_barcode AS pkey
##                    , product
##                    , SUM(coalesce(inn_customer_revenue.regular_patient_revenue,0)) AS revenue
##                  FROM ${revenue_inn_barcode.SQL_TABLE_NAME} AS inn_customer_revenue
##                  WHERE completed_on >= '2015-01-01' AND order_status_name <> 'canceled' AND payer_id <> 1575 AND payer_id <> 1581
##                  GROUP BY 1,2,3,4,5,8
##
##
##                  UNION
##
##
##                  -- ===================== INN Insurance ==================================
##
##                  SELECT
##                    inn_insurance_revenue.order_id AS order_id
##                    , inn_insurance_revenue.latest_barcode AS barcode
##                    , 'INN Insurance Revenue' AS revenue_type
##                    , 'INN' AS aggregate_type
##                    , inn_insurance_revenue.completed_on AS revenue_recorded_timestamp
##                    , 'Barcode' AS pkey_type
##                    , inn_insurance_revenue.latest_barcode AS pkey
##                    , product
##                    , SUM(coalesce(inn_insurance_revenue.payer_revenue,0)) AS revenue
##                  FROM ${revenue_inn_barcode.SQL_TABLE_NAME} AS inn_insurance_revenue
##                  WHERE completed_on >= '2015-01-01' AND order_status_name <> 'canceled'
##                  GROUP BY 1,2,3,4,5,6,7,8
##
##
##                  UNION
##
##
##                  -- ===================== INN Customer MOOP ==================================
##
##                  SELECT
##                    inn_moop_customer_revenue.order_id AS order_id
##                    , inn_moop_customer_revenue.latest_barcode AS barcode
##                    , 'INN MOOP Customer Revenue' AS revenue_type
##                    , 'INN' AS aggregate_type
##                    , inn_moop_customer_revenue.completed_on AS revenue_recorded_timestamp
##                    , 'Barcode' AS pkey_type
##                    , inn_moop_customer_revenue.latest_barcode AS pkey
##                    , product
##                    , SUM(coalesce(inn_moop_customer_revenue.moop_patient_revenue,0)) AS revenue
##                  FROM ${revenue_inn_barcode.SQL_TABLE_NAME} AS inn_moop_customer_revenue
##                  WHERE completed_on >= '2015-01-01' AND order_status_name <> 'canceled' AND payer_id <> 1575 AND payer_id <> 1581
##                  GROUP BY 1,2,3,4,5,8
##
##
##
##                  UNION
##
##                  -- ===================== INN Invoice Flux ==================================
##
##                  SELECT
##                    flux_factor_applied_to_barcodes.order_id AS order_id
##                    , flux_factor_applied_to_barcodes.barcode AS barcode
##                    , 'INN Invoice Flux' AS revenue_type
##                    , 'INN' AS aggregate_type
##                    , flux_factor_applied_to_barcodes.completed_on AS revenue_recorded_timestamp
##                    , 'Barcode' AS pkey_type
##                    , flux_factor_applied_to_barcodes.barcode AS pkey
##                    , product
##                    , SUM(coalesce(flux_factor_applied_to_barcodes.invoice_flux_revenue,0)) AS revenue
##                  FROM ${flux_factor_applied_to_barcodes.SQL_TABLE_NAME} AS flux_factor_applied_to_barcodes
##                  WHERE completed_on >= '2015-01-01' AND order_status_name <> 'canceled' AND payer_id <> 1575 AND payer_id <> 1581
##                  GROUP BY 1,2,3,4,5,6,7,8
##
##
##                  UNION
##
##
##
##                  -- ===================== CASH ==================================
##
##                  SELECT
##                    cash_revenue.order_id AS order_id
##                    , cash_revenue.barcode AS barcode
##                    , cash_revenue.revenue_type AS revenue_type
##                    , CASE
##                        WHEN cash_revenue.revenue_type = 'Consignment' THEN 'Consignment'
##                        WHEN cash_revenue.revenue_type = 'Consignment Comp' THEN 'Consignment'
##                        WHEN cash_revenue.revenue_type = 'Cash Credit Card Customer' THEN 'CC'
##                        WHEN cash_revenue.revenue_type = 'Cash OON Customer' THEN 'OON'
##                        WHEN cash_revenue.revenue_type = 'Cash OON Insurance' THEN 'OON'
##                        WHEN cash_revenue.revenue_type = 'Insurer Non-Payment' THEN 'OON'
##                        WHEN cash_revenue.revenue_type = 'JScreen Consignment' THEN 'JScreen'
##                        WHEN cash_revenue.revenue_type = 'JScreen Consignment Comp' THEN 'JScreen'
##                        END AS aggregate_type
##                    , cash_revenue.revenue_recorded_timestamp AS revenue_recorded_timestamp
##                    , cash_revenue.pkey_type
##                    , cash_revenue.pkey
##                    , product
##                    , SUM(coalesce(cash_revenue.revenue,0)) AS revenue
##                  FROM ${cash_revenue.SQL_TABLE_NAME} AS cash_revenue
##                  WHERE revenue_recorded_timestamp >= '2015-01-01' AND order_status_name <> 'canceled'
##                  GROUP BY 1,2,3,4,5,6,7,8
##
##            -- Joel, CFO, and auditors have voted to punt on moving to an accrual model until further comparisons to actuals exist.
##            -- Potentially going live Q2 2017
##            --      UNION
##            --
##            --
##            --      -- ===================== OON Customer Accrual ==================================
##            --
##            --      SELECT
##            --        oon_customer_revenue.order_id AS order_id
##            --        , oon_customer_revenue.latest_barcode AS barcode
##            --        , 'OON Customer Revenue' AS revenue_type
##            --        , 'OON' AS aggregate_type
##            --        , oon_customer_revenue.completed_on AS revenue_recorded_timestamp
##            --        , 'Barcode' AS pkey_type
##            --        , oon_customer_revenue.latest_barcode AS pkey
##            --        , SUM(coalesce(oon_customer_revenue.regular_patient_revenue,0)) AS revenue
##            --      FROM ${revenue_oon_barcode.SQL_TABLE_NAME} AS oon_customer_revenue
##            --      WHERE order_status_name <> 'canceled'
##            --      GROUP BY 1,2,3,4,5
##            --
##            --
##            --      UNION
##            --
##            --      -- ===================== OON Insurance Accrual ==================================
##            --
##            --      SELECT
##            --        oon_insurance_revenue.order_id AS order_id
##            --        , oon_insurance_revenue.latest_barcode AS barcode
##            --        , 'OON Insurance Revenue' AS revenue_type
##            --        , 'OON' AS aggregate_type
##            --        , oon_insurance_revenue.completed_on AS revenue_recorded_timestamp
##            --        , 'Barcode' AS pkey_type
##            --        , oon_insurance_revenue.latest_barcode AS pkey
##            --        , SUM(coalesce(oon_insurance_revenue.payer_revenue,0)) AS revenue
##            --      FROM ${revenue_oon_barcode.SQL_TABLE_NAME} AS oon_insurance_revenue
##            --      WHERE order_status_name <> 'canceled'
##            --      GROUP BY 1,2,3,4,5,6,7
##            --
##            --      UNION
##            --
##            --      -- ===================== OON Customer MOOP Accrual ==================================
##            --
##            --
##            --      SELECT
##            --        oon_moop_customer_revenue.order_id AS order_id
##            --        , oon_moop_customer_revenue.latest_barcode AS barcode
##            --        , 'OON MOOP Customer Revenue' AS revenue_type
##            --        , 'OON' AS aggregate_type
##            --        , oon_moop_customer_revenue.completed_on AS revenue_recorded_timestamp
##            --        , 'Barcode' AS pkey_type
##            --        , oon_moop_customer_revenue.latest_barcode AS pkey
##            --        , SUM(coalesce(oon_moop_customer_revenue.moop_patient_revenue,0)) AS revenue
##            --      FROM ${revenue_oon_barcode.SQL_TABLE_NAME} AS oon_moop_customer_revenue
##            --      WHERE order_status_name <> 'canceled'
##            --      GROUP BY 1,2,3,4,5
##            --
##            --      UNION
##            --
##            --
##            --      -- ===================== OON Invoice Flux ==================================
##            --
##            --      SELECT
##            --        oon_flux_factor_applied_to_barcodes.order_id AS order_id
##            --        , oon_flux_factor_applied_to_barcodes.barcode AS barcode
##            --        , 'OON Invoice Flux' AS revenue_type
##            --        , 'OON' AS aggregate_type
##            --        , oon_flux_factor_applied_to_barcodes.completed_on AS revenue_recorded_timestamp
##            --        , 'Barcode' AS pkey_type
##            --        , oon_flux_factor_applied_to_barcodes.barcode AS pkey
##            --        , SUM(coalesce(oon_flux_factor_applied_to_barcodes.invoice_flux_revenue,0)) AS revenue
##            --      FROM ${oon_flux_factor_applied_to_barcodes.SQL_TABLE_NAME} AS oon_flux_factor_applied_to_barcodes
##            --      WHERE order_status_name <> 'canceled'
##            --      GROUP BY 1,2,3,4,5,6,7
##            --
##            --      UNION
##            --
##            --
##            --      -- =================== SELF PAY ACCRUAL ==========================
##            --
##            --      SELECT
##            --        self_pay_accrual.order_id AS order_id
##            --        , self_pay_accrual.barcode AS barcode
##            --        , 'Credit Card Customer Revenue' AS revenue_type
##            --        , 'CC' AS aggregate_type
##            --        , self_pay_accrual.completed_on AS revenue_recorded_timestamp
##            --        , 'Barcode' AS pkey_type
##            --        , self_pay_accrual.barcode AS pkey
##            --        , SUM(coalesce(self_pay_accrual.self_pay_accrual,0)) AS revenue
##            --      FROM ${revenue_self_pay_accrual.SQL_TABLE_NAME} AS self_pay_accrual
##            --      WHERE order_status_name <> 'canceled'
##            --      GROUP BY 1,2,3,4,5,6,7
##
##
##
##
##
##
##                  -- ===================== END ======================================================================================================
##                   ;;
##    #datagroup_trigger: etl_refresh
##    sql_trigger_value: select string_agg(to_char(full_count,'99999999'),',') from ((select count(*) AS full_count from ${cash_revenue.SQL_TABLE_NAME}) UNION (select count(*) AS full_count from ${revenue_inn_barcode.SQL_TABLE_NAME})) AS foo ;;
##    indexes: ["order_id", "barcode", "revenue_type", "revenue_recorded_timestamp"]
##  }
##
##  dimension: order_id {
##    type: number
##    sql: ${TABLE}.order_id ;;
##  }
##
##  dimension: barcode {
##    sql: ${TABLE}.barcode ;;
##  }
##
##  dimension: product {
##    label: "Rev Product"
##    sql: ${TABLE}.product ;;
##  }
##
##  dimension_group: revenue_recorded {
##    type: time
##    timeframes: [quarter, date, week, month, year]
##    sql: ${TABLE}.revenue_recorded_timestamp ;;
##  }
##
##  dimension: revenue_type {
##    sql: ${TABLE}.revenue_type ;;
##  }
##
##  dimension: aggregate_type {
##    sql: ${TABLE}.aggregate_type ;;
##  }
##
##  dimension: revenue {
##    hidden: yes
##    sql: ${TABLE}.revenue ;;
##  }
##
##  dimension: pkey_type {
##    sql: ${TABLE}.pkey_type ;;
##  }
##
##  dimension: pkey {
##    sql: ${TABLE}.pkey ;;
##  }
##
##  measure: total_revenue {
##    label: "$ Total Revenue"
##    value_format_name: usd
##    type: sum
##    sql: ${revenue} ;;
##  }
##}
##
##view: revenue_per_barcode {
##  view_label: "Estimated Revenue"
##
##  derived_table: {
##    sql: -- ===================== START ======================================================================================================
##
##
##                    SELECT
##                      ord.id AS order_id
##                      , revenue_inn_barcode.payer_revenue AS inn_payer_revenue
##                      , revenue_inn_barcode.regular_patient_revenue AS inn_patient_revenue
##                      , revenue_inn_barcode.moop_patient_revenue
##                      , consignment_revenue
##                      , oon_insurer_revenue
##                      , oon_customer_revenue
##                      , credit_card_customer_revenue
##                      , insurer_non_payment_revenue
##                      , jscreen_revenue
##                      , consignment_comp_revenue
##                      , invoice_flux_revenue
##
##                      , coalesce(payer_revenue,0) + coalesce(oon_insurer_revenue,0) + coalesce(insurer_non_payment_revenue,0) AS insurance_revenue
##                      , coalesce(invoice_flux_revenue,0) + coalesce(regular_patient_revenue,0) + coalesce(moop_patient_revenue,0) + coalesce(oon_customer_revenue,0) + coalesce(credit_card_customer_revenue,0) AS customer_revenue
##                      , coalesce(consignment_revenue,0) + coalesce(jscreen_revenue,0) + coalesce(consignment_comp_revenue,0) AS physician_revenue
##
##
##                    FROM current.order AS ord
##
##                    LEFT JOIN
##                      ${revenue_inn_barcode.SQL_TABLE_NAME} AS revenue_inn_barcode ON revenue_inn_barcode.order_id = ord.id
##
##                    LEFT JOIN
##                      (
##                        SELECT
##                          order_id
##                          , SUM(revenue) AS oon_insurer_revenue
##                        FROM ${all_revenue.SQL_TABLE_NAME} AS oon_insurer
##                        WHERE revenue_type = 'Cash OON Insurance'
##                        OR revenue_type = 'OON Insurance Revenue'
##                        GROUP BY 1
##                      ) AS oon_insurer ON oon_insurer.order_id = ord.id
##
##                    LEFT JOIN
##                      (
##                        SELECT
##                          order_id
##                          , SUM(revenue) AS oon_customer_revenue
##                        FROM ${all_revenue.SQL_TABLE_NAME} AS oon_customer
##                        WHERE revenue_type = 'Cash OON Customer'
##                        OR revenue_type = 'OON Customer Revenue'
##                        GROUP BY 1
##                      ) AS oon_customer ON oon_customer.order_id = ord.id
##
##                    LEFT JOIN
##                      (
##                      SELECT
##                        order_id
##                        , SUM(revenue) AS credit_card_customer_revenue
##                      FROM ${all_revenue.SQL_TABLE_NAME} AS credit_card_customer
##                      WHERE revenue_type = 'Cash Credit Card Customer'
##                      OR revenue_type = 'Credit Card Customer Reveune'
##                      GROUP BY 1
##                      ) AS credit_card_customer ON credit_card_customer.order_id = ord.id
##
##                    LEFT JOIN
##                      (
##                      SELECT
##                        order_id
##                        , SUM(revenue) AS insurer_non_payment_revenue
##                      FROM ${all_revenue.SQL_TABLE_NAME} AS insurer_non_payment
##                      WHERE revenue_type = 'Insurer Non-Payment'
##                      GROUP BY 1
##                      ) AS insurer_non_payment ON insurer_non_payment.order_id = ord.id
##
##                    LEFT JOIN
##                      (
##                      SELECT
##                        consignment.order_id AS order_id
##                        , SUM(revenue) AS consignment_revenue
##
##                      FROM ${all_revenue.SQL_TABLE_NAME} AS consignment
##                      WHERE revenue_type = 'Consignment'
##                      GROUP BY 1
##                      ) AS consignment ON consignment.order_id = ord.id
##
##                    LEFT JOIN
##                      (
##                      SELECT
##                        order_id
##                        , SUM(revenue) AS jscreen_revenue
##
##                      FROM ${all_revenue.SQL_TABLE_NAME} AS jscreen_revenue
##                      WHERE revenue_type = 'JScreen Consignment'
##                      GROUP BY 1
##                      ) AS jscreen_revenue ON jscreen_revenue.order_id = ord.id
##
##                    LEFT JOIN
##                      (
##                      SELECT
##                        consignment_comp.order_id AS order_id
##                        , SUM(revenue) AS consignment_comp_revenue
##
##                      FROM ${all_revenue.SQL_TABLE_NAME} AS consignment_comp
##                      WHERE revenue_type = 'Consignment Comp'
##                      GROUP BY 1
##                      ) AS consignment_comp ON consignment_comp.order_id = ord.id
##
##
##                    LEFT JOIN
##                      (
##                      SELECT
##                        invoice_flux.order_id AS order_id
##                        , SUM(revenue) AS invoice_flux_revenue
##
##                      FROM ${all_revenue.SQL_TABLE_NAME} AS invoice_flux
##                      WHERE revenue_type = 'INN Invoice Flux'
##                      OR revenue_type = 'OON Invoice Flux'
##                      GROUP BY 1
##                      ) AS invoice_flux ON invoice_flux.order_id = ord.id
##
##
##                  -- ===================== END ======================================================================================================
##                   ;;
##    #datagroup_trigger: etl_refresh
##    sql_trigger_value: select sum(revenue) from ${all_revenue.SQL_TABLE_NAME} ;;
##    indexes: ["order_id"]
##  }
##
##  dimension: order_id {
##    primary_key: yes
##    hidden: yes
##    type: number
##    sql: ${TABLE}.order_id ;;
##  }
##
##  dimension: barcode {
##    hidden: yes
##    sql: ${TABLE}.barcode ;;
##  }
##
##  dimension: inn_payer_revenue {
##    hidden: yes
##    sql: ${TABLE}.inn_payer_revenue ;;
##  }
##
##  dimension: inn_patient_revenue {
##    hidden: yes
##    sql: ${TABLE}.inn_patient_revenue ;;
##  }
##
##  dimension: moop_patient_revenue {
##    hidden: yes
##    sql: ${TABLE}.moop_patient_revenue ;;
##  }
##
##  dimension: consignment_revenue {
##    hidden: yes
##    sql: ${TABLE}.consignment_revenue ;;
##  }
##
##  dimension: oon_insurer_revenue {
##    hidden: yes
##    sql: ${TABLE}.oon_insurer_revenue ;;
##  }
##
##  dimension: oon_customer_revenue {
##    hidden: yes
##    sql: ${TABLE}.oon_customer_revenue ;;
##  }
##
##  dimension: credit_card_customer_revenue {
##    hidden: yes
##    sql: ${TABLE}.credit_card_customer_revenue ;;
##  }
##
##  dimension: insurer_non_payment_revenue {
##    hidden: yes
##    sql: ${TABLE}.insurer_non_payment_revenue ;;
##  }
##
##  dimension: jscreen_revenue {
##    hidden: yes
##    sql: ${TABLE}.jscreen_revenue ;;
##  }
##
##  dimension: consignment_comp_revenue {
##    hidden: yes
##    sql: ${TABLE}.consignment_comp_revenue ;;
##  }
##
##  dimension: invoice_flux_revenue {
##    hidden: yes
##    sql: ${TABLE}.invoice_flux_revenue ;;
##  }
##
##  measure: total_inn_payer_revenue {
##    hidden: yes
##    type: sum
##    sql: ${TABLE}.inn_payer_revenue ;;
##  }
##
##  measure: total_inn_patient_revenue {
##    hidden: yes
##    type: sum
##    sql: ${TABLE}.inn_patient_revenue ;;
##  }
##
##  measure: total_moop_patient_revenue {
##    hidden: yes
##    type: sum
##    sql: ${TABLE}.moop_patient_revenue ;;
##  }
##
##  measure: total_consignment_revenue {
##    hidden: yes
##    type: sum
##    sql: ${TABLE}.consignment_revenue ;;
##  }
##
##  measure: total_oon_insurer_revenue {
##    hidden: yes
##    type: sum
##    sql: ${TABLE}.oon_insurer_revenue ;;
##  }
##
##  measure: total_oon_customer_revenue {
##    hidden: yes
##    type: sum
##    sql: ${TABLE}.oon_customer_revenue ;;
##  }
##
##  measure: total_credit_card_customer_revenue {
##    hidden: yes
##    type: sum
##    sql: ${TABLE}.credit_card_customer_revenue ;;
##  }
##
##  measure: total_insurer_non_payment_revenue {
##    hidden: yes
##    type: sum
##    sql: ${TABLE}.insurer_non_payment_revenue ;;
##  }
##
##  measure: total_jscreen_revenue {
##    hidden: yes
##    type: sum
##    sql: ${TABLE}.jscreen_revenue ;;
##  }
##
##  measure: total_consignment_comp_revenue {
##    hidden: yes
##    type: sum
##    sql: ${TABLE}.consignment_comp_revenue ;;
##  }
##
##  measure: total_invoice_flux_revenue {
##    hidden: yes
##    type: sum
##    sql: ${TABLE}.invoice_flux_revenue ;;
##  }
##
##  dimension: customer_revenue {
##    hidden: yes
##    description: "The dollar amount in estimated revenue attributed to patients/customers"
##    sql: ${TABLE}.customer_revenue ;;
##  }
##
##  dimension: insurance_revenue {
##    hidden: yes
##    description: "The dollar amount in estimated revenue attributed to insurance payments"
##    sql: ${TABLE}.insurance_revenue ;;
##  }
##
##  dimension: physician_revenue {
##    hidden: yes
##    description: "The dollar amount in estimated revenue attributed to physican/consignment orders"
##    sql: ${TABLE}.physician_revenue ;;
##  }
##
##  measure: total_customer_revenue {
##    label: "$ Total Estimated Customer Revenue"
##    description: "The total dollar amount in estimated revenue attributed to patients/customers, i.e. - In-Network accrued payment, OON cash-basis payments, MOOP payments, credit card payments, and invoice flux"
##    value_format_name: usd
##    type: sum
##    sql: ${customer_revenue} ;;
##  }
##
##  measure: total_insurance_revenue {
##    label: "$ Total Estimated Insurance Revenue"
##    description: "The total dollar amount estimated in revenue attributed to insurance payments, i.e. In-Network accrued payment, OON cash-basis payments, and non-payment cash"
##    value_format_name: usd
##    type: sum
##    sql: ${insurance_revenue} ;;
##  }
##
##  measure: total_physician_revenue {
##    description: "The total dollar amount in revenue attributed to physician/consignment orders, i.e. - consignment payments, consighment comps (-), and JScreen payments"
##    label: "$ Total Estimated Physician Revenue"
##    value_format_name: usd
##    type: sum
##    sql: ${physician_revenue} ;;
##  }
##
##  dimension: revenue {
##    description: "The excpected revenue dollar amount associated with each order"
##    type: number
##    value_format_name: usd
##    sql: coalesce(${customer_revenue},0) + coalesce(${insurance_revenue},0) + coalesce(${physician_revenue},0) ;;
##  }
##
##  measure: total_revenue {
##    label: "$ Total Estimated Revenue"
##    description: "The estimated total dollar amount. The sum of the insurance, customer, and physician revenue."
##    value_format_name: usd
##    type: sum
##    sql: ${revenue} ;;
##  }
##
##  measure: cumulative_revenue {
##    label: "$ Cumulative Estimated Revenue"
##    description: "The estimated total dollar amount. The cumulative sum of the insurance, customer, and physician revenue."
##    value_format: "$0,\"K\""
##    type: running_total
##    sql: ${total_revenue} ;;
##  }
##
##  measure: average {
##    label: "$ Average Estimated Revenue"
##    description: "The estimated average dollar amount. The average of combined insurance, customer, and physician revenue."
##    value_format_name: usd
##    type: average
##    sql: ${revenue} ;;
##  }
##
##  measure: dollar_divider {
##    hidden: yes
##    label: "$ ========= $ $ $ VALUES ========= $"
##    type: string
##    sql: 'DO NOT USE'
##      ;;
##  }
##}
##
