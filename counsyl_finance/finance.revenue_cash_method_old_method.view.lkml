###=========CASH REVENUE: aggregates all cash-basis revenue to the barcode level========
##
##
##view: cash_revenue {
##  view_label: "Cash Revenue"
##
##  derived_table: {
##    sql: -- ===================== START ======================================================================================================
##
##                  -- ===================== Out-of-Network Insurance ==================================
##
##                  SELECT
##                    ord.id AS order_id
##                    , oon_insurer.barcode
##                    , revenue_recorded_timestamp
##                    , 'Cash OON Insurance' AS revenue_type
##                    , CASE
##                      WHEN has_ips_high_risk = TRUE and ord.product_name = 'Prelude Prenatal Screen' THEN 'Prelude Prenatal Screen - High Risk'
##                      WHEN has_ips_high_risk = FALSE and ord.product_name = 'Prelude Prenatal Screen' THEN 'Prelude Prenatal Screen - Low Risk'
##                      WHEN has_ips_high_risk is null and ord.product_name = 'Prelude Prenatal Screen' THEN 'Prelude Prenatal Screen - Low Risk'
##                      ELSE ord.product_name END as product
##                    , 'Hybrid Pkey' AS pkey_type
##                    , oon_insurer.hybrid_pkey AS pkey
##                    , SUM(oon_insurer_transaction_amt) AS revenue
##                    , ord.status AS order_status_name
##                  FROM ${order.SQL_TABLE_NAME} AS ord
##                  LEFT JOIN
##                    ${notable_diagnoses.SQL_TABLE_NAME} as nd on nd.order_id = ord.id
##                  LEFT JOIN ${oon_insurer.SQL_TABLE_NAME} AS oon_insurer ON oon_insurer.order_id = ord.id
##                  -- WHERE ord.completed_on < '2016-01-01'    PENDING WHENEVER WE DECIDE TO GO LIVE WITH ACCRUALS
##                  GROUP BY 1,2,3,4,5,6,7,9
##
##
##
##                  UNION
##
##
##                  -- ===================== Out-of-Network Customer ==================================
##
##
##                  SELECT
##                    ord.id AS order_id
##                     ,oon_customer.barcode
##                    , revenue_recorded_timestamp
##                    , 'Cash OON Customer' AS revenue_type
##                    , CASE
##                      WHEN has_ips_high_risk = TRUE and ord.product_name = 'Prelude Prenatal Screen' THEN 'Prelude Prenatal Screen - High Risk'
##                      WHEN has_ips_high_risk = FALSE and ord.product_name = 'Prelude Prenatal Screen' THEN 'Prelude Prenatal Screen - Low Risk'
##                      WHEN has_ips_high_risk is null and ord.product_name = 'Prelude Prenatal Screen' THEN 'Prelude Prenatal Screen - Low Risk'
##                      ELSE ord.product_name END as product
##                    , 'Hybrid Pkey' AS pkey_type
##                    , oon_customer.hybrid_pkey AS pkey
##                    , SUM(oon_customer_transaction_amt) AS revenue
##                    , ord.status AS order_status_name
##
##                  FROM ${order.SQL_TABLE_NAME} AS ord
##                  LEFT JOIN
##                    ${notable_diagnoses.SQL_TABLE_NAME} as nd on nd.order_id = ord.id
##                  LEFT JOIN ${oon_customer.SQL_TABLE_NAME} AS oon_customer ON oon_customer.order_id = ord.id
##                  -- WHERE ord.completed_on < '2016-01-01'    PENDING WHENEVER WE DECIDE TO GO LIVE WITH ACCRUALS
##                  GROUP BY 1,2,3,4,5,6,7,9
##
##
##                  -- ===================== Credit Card Customer ==================================
##
##
##                  UNION
##
##                  SELECT
##                    ord.id AS order_id
##                    , credit_card_customer.barcode
##                    , revenue_recorded_timestamp
##                    , 'Cash Credit Card Customer' AS revenue_type
##                    , CASE
##                      WHEN has_ips_high_risk = TRUE and ord.product_name = 'Prelude Prenatal Screen' THEN 'Prelude Prenatal Screen - High Risk'
##                      WHEN has_ips_high_risk = FALSE and ord.product_name = 'Prelude Prenatal Screen' THEN 'Prelude Prenatal Screen - Low Risk'
##                      WHEN has_ips_high_risk is null and ord.product_name = 'Prelude Prenatal Screen' THEN 'Prelude Prenatal Screen - Low Risk'
##                      ELSE ord.product_name END as product
##                    , 'Hybrid Pkey' AS pkey_type
##                    , credit_card_customer.hybrid_pkey AS pkey
##                    , SUM(credit_card_customer_transaction_amt) AS revenue
##                    , ord.status AS order_status_name
##
##                  FROM ${order.SQL_TABLE_NAME} AS ord
##                  LEFT JOIN
##                    ${notable_diagnoses.SQL_TABLE_NAME} as nd on nd.order_id = ord.id
##                  LEFT JOIN ${credit_card_customer.SQL_TABLE_NAME} AS credit_card_customer ON credit_card_customer.order_id = ord.id
##                        -- WHERE ord.completed_on < '2016-01-01'    PENDING WHENEVER WE DECIDE TO GO LIVE WITH ACCRUALS
##                  GROUP BY 1,2,3,4,5,6,7,9
##
##
##                  -- ===================== Insurer Non-Payments ==================================
##
##
##                  UNION
##
##                  SELECT
##                    ord.id AS order_id
##                    , insurer_non_payment.barcode
##                    , revenue_recorded_timestamp
##                    , 'Insurer Non-Payment' AS revenue_type
##                    , CASE
##                      WHEN has_ips_high_risk = TRUE and ord.product_name = 'Prelude Prenatal Screen' THEN 'Prelude Prenatal Screen - High Risk'
##                      WHEN has_ips_high_risk = FALSE and ord.product_name = 'Prelude Prenatal Screen' THEN 'Prelude Prenatal Screen - Low Risk'
##                      WHEN has_ips_high_risk is null and ord.product_name = 'Prelude Prenatal Screen' THEN 'Prelude Prenatal Screen - Low Risk'
##                      ELSE ord.product_name END as product
##                    , 'Check or EFT Trace Number' AS pkey_type
##                    , insurer_non_payment.check_or_eft_trace_number AS pkey
##                    , SUM(eob_paid) AS revenue
##                    , ord.status AS order_status_name
##
##                  FROM ${order.SQL_TABLE_NAME} AS ord
##                  LEFT JOIN
##                    ${notable_diagnoses.SQL_TABLE_NAME} as nd on nd.order_id = ord.id
##                  LEFT JOIN ${insurer_non_payment.SQL_TABLE_NAME} AS insurer_non_payment ON insurer_non_payment.order_id = ord.id
##                  -- WHERE ord.completed_on < '2016-01-01'    PENDING WHENEVER WE DECIDE TO GO LIVE WITH ACCRUALS
##                  GROUP BY 1,2,3,4,5,6,7,9
##
##                  -- ===================== Consignment ==================================
##
##                  UNION
##
##                    SELECT
##                      consignment.order_id AS order_id
##                      , consignment.latest_barcode AS barcode
##                      , consignment.revenue_recorded_timestamp AS revenue_recorded_timestamp
##                      , 'Consignment' AS revenue_type
##                      , product
##                      , 'Barcode' AS pkey_type
##                      , consignment.latest_barcode AS pkey
##                      , SUM(consignment.invoice_item_amount) AS revenue
##                      , order_status_name
##                    FROM ${consignment.SQL_TABLE_NAME} AS consignment
##
##
##                    GROUP BY 1,2,3,4,5,6,7,9
##
##                  -- ===================== JScreen Consignment  ==================================
##
##                  UNION
##
##                    SELECT
##                      jscreen_revenue.order_id AS order_id
##                      , latest_barcode AS barcode
##                      , revenue_recorded_timestamp AS revenue_recorded_timestamp
##                      , 'JScreen Consignment' AS revenue_type
##                      , product
##                      , 'Barcode' AS pkey_type
##                      , latest_barcode AS pkey
##                      , SUM(allocated_payment_amount) AS revenue
##                      , order_status_name
##                    FROM ${jscreen_revenue_payment_allocation.SQL_TABLE_NAME} AS jscreen_revenue
##                    GROUP BY 1,2,3,4,5,6,7,9
##
##
##                  -- ===================== Consignment Comps ==================================
##
##
##                  UNION
##
##
##                    SELECT
##                      consignment_comp.order_id AS order_id
##                      , consignment_comp.latest_barcode AS barcode
##                      , consignment_comp.revenue_recorded_timestamp AS revenue_recorded_timestamp
##                      , 'Consignment Comp' AS revenue_type
##                      , product
##                      , 'Invoice Number' AS pkey_type
##                      , invoice_number AS pkey
##                      , SUM(-1.00*consignment_comp.consignment_comp_revenue) AS revenue
##                      , order_status_name
##                    FROM ${consignment_comp_to_barcode.SQL_TABLE_NAME} AS consignment_comp
##                    GROUP BY 1,2,3,4,5,6,7,9
##
##                  -- ===================== END ======================================================================================================
##                   ;;
##    sql_trigger_value: select string_agg(to_char(full_count,'99999999'),',') from ((select count(*) AS full_count from ${oon_insurer.SQL_TABLE_NAME}) UNION (select count(*) AS full_count from ${oon_customer.SQL_TABLE_NAME}) UNION (select count(*) AS full_count from ${credit_card_customer.SQL_TABLE_NAME}) UNION (select count(*) AS full_count from ${insurer_non_payment.SQL_TABLE_NAME}) UNION (select count(*) AS full_count from ${consignment_comp.SQL_TABLE_NAME})) AS foo ;;
##    indexes: ["order_id", "barcode"]
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
##  dimension: product {
##    sql: ${TABLE}.product ;;
##  }
##
##  dimension: cash_revenue {
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
##  measure: total_cash_revenue {
##    value_format_name: usd
##    type: sum
##    sql: ${cash_revenue} ;;
##  }
##}
##
###=============================================================
###==================== OON INSURER #====================
##
##
###- explore: oon_insurer
### description: 'Out-of-network insurance component of cash-basis recurring revenue model; feeds into cash_revenue '
##view: oon_insurer {
##  view_label: "OON Insurer"
##
##  derived_table: {
##    sql:
##      SELECT
##        match.invoice_id
##        ,match.order_id
##        , match.claim_id
##        , match.barcode
##        , CASE
##            WHEN product = 'Foresight Carrier Screen' and testing_methodology = 0 THEN 'Foresight 1.0'
##            WHEN product = 'Foresight Carrier Screen' and testing_methodology = 1 THEN 'Foresight 2.0'
##            ELSE product END as product
##        , match.bill_type
##        , match.network_status
##        , match.payer_name
##        , match.rev_trn
##        , match.invoice_type
##        , match.completed_on
##        , match.deposit_date
##        , match.rev_rec_date AS revenue_recorded_timestamp
##        , match.hybrid_pkey
##        , sum(match.hybrid_transaction_amt) AS oon_insurer_transaction_amt
##      FROM ${matched_report_2014_to_current.SQL_TABLE_NAME} AS match
##
##      -- ===== FILTERS =====
##
##      WHERE
##        bill_type = 'in'
##        AND network_status = 'OON'
##        AND rev_trn = 'Revenue'
##        AND (ref_pay != 'Refund' OR ref_pay is null)
##        AND invoice_type = 'Insurer'
##        AND barcode is not null
##      GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14
##       ;;
##    sql_trigger_value: select count(*) from ${matched_report_2014_to_current.SQL_TABLE_NAME} ;;
##    indexes: ["invoice_id", "order_id", "barcode"]
##  }
##
##  dimension: order_id {
##    type: number
##    sql: ${TABLE}.order_id ;;
##  }
##
##  dimension: invoice_id {
##    type: number
##    sql: ${TABLE}.invoice_id ;;
##  }
##
##  dimension: barcode {
##    sql: ${TABLE}.barcode ;;
##  }
##
##  dimension: product {
##    sql: ${TABLE}.product ;;
##  }
##
##  dimension_group: revenue_recorded {
##    type: time
##    timeframes: [quarter, date, week, month, year]
##    sql: ${TABLE}.revenue_recorded_timestamp ;;
##  }
##
##  dimension_group: completed {
##    type: time
##    timeframes: [quarter, date, week, month, year]
##    sql: ${TABLE}.completed_on ;;
##  }
##
##  dimension_group: deposit {
##    type: time
##    timeframes: [quarter, date, week, month, year]
##    sql: ${TABLE}.deposit_date ;;
##  }
##
##  dimension: oon_insurer_transaction_amt {
##    type: number
##    sql: oon_insurer_transaction_amt ;;
##  }
##
##  measure: oon_insurer_total_revenue {
##    label: "OON Insurer Total Revenue"
##    type: sum
##    sql: ${oon_insurer_transaction_amt} ;;
##  }
##}
##
##view: oon_customer {
##  view_label: "OON Customer"
##
##  derived_table: {
##    sql:
##      SELECT
##        match.invoice_id
##        ,match.order_id
##        , match.claim_id
##        , match.barcode
##        , CASE
##            WHEN product = 'Foresight Carrier Screen' and testing_methodology = 0 THEN 'Foresight 1.0'
##            WHEN product = 'Foresight Carrier Screen' and testing_methodology = 1 THEN 'Foresight 2.0'
##            ELSE product END as product
##        , match.bill_type
##        , match.network_status
##        , match.payer_name
##        , match.rev_trn
##        , match.invoice_type
##        , match.completed_on
##        , match.deposit_date
##        , match.rev_rec_date AS revenue_recorded_timestamp
##        , match.hybrid_pkey
##        , sum(match.hybrid_transaction_amt) AS oon_customer_transaction_amt
##      FROM ${matched_report_2014_to_current.SQL_TABLE_NAME} AS match
##
##      -- ===== FILTERS =====
##
##      WHERE
##        bill_type = 'in'
##        AND network_status = 'OON'
##        AND rev_trn = 'Revenue'
##        AND (ref_pay != 'Refund' OR ref_pay is null)
##        AND invoice_type = 'Customer'
##        AND barcode is not null
##      GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14
##       ;;
##    sql_trigger_value: select count(*) from ${matched_report_2014_to_current.SQL_TABLE_NAME} ;;
##    indexes: ["invoice_id", "order_id", "barcode"]
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
##    sql: ${TABLE}.product ;;
##  }
##
##  dimension_group: revenue_recorded {
##    type: time
##    timeframes: [quarter, date, week, month, year]
##    sql: ${TABLE}.revenue_recorded_timestamp ;;
##  }
##
##  dimension_group: completed {
##    type: time
##    timeframes: [quarter, date, week, month, year]
##    sql: ${TABLE}.completed_on ;;
##  }
##
##  dimension_group: deposit {
##    type: time
##    timeframes: [quarter, date, week, month, year]
##    sql: ${TABLE}.deposit_date ;;
##  }
##
##  dimension: oon_customer_transaction_amt {
##    type: number
##    sql: oon_customer_transaction_amt ;;
##  }
##
##  measure: oon_customer_total_revenue {
##    label: "OON Customer Total Revenue"
##    type: sum
##    sql: ${oon_customer_transaction_amt} ;;
##  }
##}
##
##view: credit_card_customer {
##  view_label: "Credit Card Customer"
##
##  derived_table: {
##    sql:
##      SELECT
##      match.invoice_id
##      ,match.order_id
##      , match.claim_id
##      , match.barcode
##      , CASE
##          WHEN product = 'Foresight Carrier Screen' and testing_methodology = 0 THEN 'Foresight 1.0'
##          WHEN product = 'Foresight Carrier Screen' and testing_methodology = 1 THEN 'Foresight 2.0'
##          ELSE product END as product
##      , match.bill_type
##      , match.network_status
##      , match.payer_name
##      , match.rev_trn
##      , match.invoice_type
##      , match.completed_on
##      , match.deposit_date
##      , match.rev_rec_date AS revenue_recorded_timestamp
##      , match.hybrid_pkey
##      , sum(match.hybrid_transaction_amt) AS credit_card_customer_transaction_amt
##      FROM ${matched_report_2014_to_current.SQL_TABLE_NAME} AS match
##
##      -- ===== FILTERS =====
##
##      WHERE
##        bill_type = 'cc'
##        AND network_status is null
##        AND rev_trn = 'Revenue'
##        AND (ref_pay != 'Refund' OR ref_pay is null)
##        AND invoice_type = 'Customer'
##        AND barcode is not null
##      GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14
##       ;;
##    sql_trigger_value: select count(*) from ${matched_report_2014_to_current.SQL_TABLE_NAME} ;;
##    indexes: ["invoice_id", "order_id", "barcode"]
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
##    sql: ${TABLE}.product ;;
##  }
##
##  dimension_group: revenue_recorded {
##    type: time
##    timeframes: [quarter, date, week, month, year]
##    sql: ${TABLE}.revenue_recorded_timestamp ;;
##  }
##
##  dimension_group: completed {
##    type: time
##    timeframes: [quarter, date, week, month, year]
##    sql: ${TABLE}.completed_on ;;
##  }
##
##  dimension_group: deposit {
##    type: time
##    timeframes: [quarter, date, week, month, year]
##    sql: ${TABLE}.deposit_date ;;
##  }
##
##  dimension: credit_card_customer_transaction_amt {
##    type: number
##    sql: credit_card_customer_transaction_amt ;;
##  }
##
##  measure: credit_card_customer_total_revenue {
##    label: "Credit Card Customer Total Revenue"
##    type: sum
##    sql: ${credit_card_customer_transaction_amt} ;;
##  }
##}
##
##view: insurer_non_payment {
##  view_label: "Insurer Non-Payment"
##
##  derived_table: {
##    sql:
##      SELECT
##         eobbatch.payment_method AS payment_method
##        , "order".bill_type_label AS bill_type_label
##        , "order".id AS order_id
##        , "order".latest_barcode AS barcode
##        , claim.id AS claim_id
##        , eobbatch.check_or_eft_trace_number AS check_or_eft_trace_number
##        , eobbatch.date_recorded AS date_recorded
##        , eob.eob_batch_id AS eob_batch_id
##        , payer_attributes.display_name AS pretty_payer_name
##        , claim.date_of_service AS service_date
##        , "order".completed_on AS completed_on
##        , CASE
##            WHEN product = 'Foresight Carrier Screen' and testing_methodology = 0 THEN 'Foresight 1.0'
##            WHEN product = 'Foresight Carrier Screen' and testing_methodology = 1 THEN 'Foresight 2.0'
##            ELSE product END as product
##        , CASE
##          WHEN "order".product = 'Foresight Carrier Screen' and date_of_service >= inn.fps_date and date_of_service < coalesce(inn.fps_term,'2100-01-01'::date)
##            THEN 'In Net'
##          WHEN "order".product = 'Reliant Cancer Screen' and date_of_service >= inn.ics_date and date_of_service < coalesce(inn.ics_term,'2100-01-01'::date)
##            THEN 'In Net'
##          WHEN "order".product = 'Prelude Prenatal Screen' and date_of_service >= inn.ips_date and date_of_service < coalesce(inn.ips_term,'2100-01-01'::date)
##            THEN 'In Net'
##          ELSE 'OON'
##          END  AS network_status
##        , CASE
##          WHEN
##            CASE
##            WHEN "order".product = 'Foresight Carrier Screen' and date_of_service >= inn.fps_date and date_of_service < coalesce(inn.fps_term,'2100-01-01'::date)
##              THEN 'In Net'
##            WHEN "order".product = 'Reliant Cancer Screen' and date_of_service >= inn.ics_date and date_of_service < coalesce(inn.ics_term,'2100-01-01'::date)
##              THEN 'In Net'
##            WHEN "order".product = 'Prelude Prenatal Screen' and date_of_service >= inn.ips_date and date_of_service < coalesce(inn.ips_term,'2100-01-01'::date)
##              THEN 'In Net'
##            ELSE 'OON'
##            END  = 'OON' AND "order".completed_on is not null AND eobbatch.date_recorded is not null THEN
##          CASE
##            WHEN "order".completed_on > eobbatch.date_recorded THEN "order".completed_on
##            WHEN eobbatch.date_recorded > "order".completed_on THEN eobbatch.date_recorded ELSE null END
##           ELSE "order".completed_on END AS revenue_recorded_timestamp
##        , coalesce(sum(eob.paid)) AS eob_paid
##      FROM ${order.SQL_TABLE_NAME} AS "order"
##      LEFT JOIN current.insuranceclaim AS claim ON claim.order_id = ("order".id)
##      LEFT JOIN current.eob_no_duplicate_eob_batches AS eob ON eob.claim_id = claim.id
##      LEFT JOIN current.insurancepayer AS payer_attributes ON payer_attributes.id = claim.payer_id
##      LEFT JOIN current.eobbatch AS eobbatch ON eobbatch.id = eob.eob_batch_id --SQL table name instead
##      LEFT JOIN uploads.in_network_dates_w_terminal inn on inn.id = payer_attributes.id
##
##
##      -- ===== FILTERS =====
##
##      WHERE
##        (eobbatch.payment_method ILIKE 'non')
##        AND payer_attributes.display_name != 'Mayo Management Services'
##        AND (CASE
##          WHEN "order".product = 'Foresight Carrier Screen' and date_of_service >= inn.fps_date and date_of_service < coalesce(inn.fps_term,'2100-01-01'::date)
##            THEN 'In Net'
##          WHEN "order".product = 'Reliant Cancer Screen' and date_of_service >= inn.ics_date and date_of_service < coalesce(inn.ics_term,'2100-01-01'::date)
##            THEN 'In Net'
##          WHEN "order".product = 'Prelude Prenatal Screen' and date_of_service >= inn.ips_date and date_of_service < coalesce(inn.ips_term,'2100-01-01'::date)
##            THEN 'In Net'
##          ELSE 'OON'
##          END) = 'OON'
##        AND latest_barcode is not null
##      GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14
##      HAVING coalesce(sum(eob.paid))!=0
##       ;;
##    sql_trigger_value: select count(*) from ${matched_report_2014_to_current.SQL_TABLE_NAME} ;;
##    indexes: ["claim_id", "barcode"]
##  }
##
##  dimension: claim_id {
##    type: number
##    sql: ${TABLE}.claim_id ;;
##  }
##
##  dimension: barcode {
##    sql: ${TABLE}.barcode ;;
##  }
##
##  dimension: product {
##    sql: ${TABLE}.product ;;
##  }
##
##  dimension_group: revenue_recorded {
##    type: time
##    timeframes: [quarter, date, week, month, year]
##    sql: ${TABLE}.revenue_recorded_timestamp ;;
##  }
##
##  dimension_group: completed {
##    type: time
##    timeframes: [quarter, date, week, month, year]
##    sql: ${TABLE}.completed_on ;;
##  }
##
##  dimension: eob_paid {
##    type: number
##    sql: ${TABLE}.eob_paid ;;
##  }
##
##  measure: oon_insurer_total_revenue {
##    label: "OON Non-Payment Total Revenue"
##    type: sum
##    sql: ${eob_paid} ;;
##  }
##}
##
##view: consignment {
##  view_label: "Consignment Revenue"
##
##  derived_table: {
##    sql: SELECT
##        invoice.id AS invoice_id
##        ,invoice.type AS type
##        , invoice.invoice_number AS invoice_number
##        ,"order".latest_barcode AS latest_barcode
##        ,"order".id AS order_id
##        ,DATE("order".completed_on) AS revenue_recorded_timestamp
##        ,EXTRACT(YEAR FROM "order".completed_on)::integer AS completed_year
##        ,TO_CHAR("order".completed_on, 'YYYY-MM') AS completed_month
##        ,"order".bill_type_label AS bill_type_label
##        , CASE
##          WHEN has_ips_high_risk = TRUE and "order".product_name = 'Prelude Prenatal Screen' THEN 'Prelude Prenatal Screen - High Risk'
##          WHEN has_ips_high_risk = FALSE and "order".product_name = 'Prelude Prenatal Screen' THEN 'Prelude Prenatal Screen - Low Risk'
##          WHEN has_ips_high_risk is null and "order".product_name = 'Prelude Prenatal Screen' THEN 'Prelude Prenatal Screen - Low Risk'
##          ELSE "order".product_name END as product
##        , invoiceitem.id AS invoiceitem_id
##        , DATE(invoice.timestamp) AS invoice_timestamp_date
##        , invoicing_clinic_name AS name
##        , invoiceitem.amount AS invoice_item_amount
##        , "order".status AS order_status_name
##      FROM ${order.SQL_TABLE_NAME} AS "order"
##      LEFT JOIN current.insuranceclaim AS claim ON claim.order_id = ("order".id)
##      LEFT JOIN ${notable_diagnoses.SQL_TABLE_NAME} as nd on nd.order_id = "order".id
##      LEFT JOIN ${invoiceitem.SQL_TABLE_NAME} AS invoiceitem ON invoiceitem.order_id = ("order".id)
##      LEFT JOIN ${invoice.SQL_TABLE_NAME} AS invoice ON invoice.invoice_number = invoiceitem.invoice_number
##      LEFT JOIN ${payment.SQL_TABLE_NAME} AS payment ON payment.invoice_number = invoice.invoice_number
##      LEFT JOIN uploads.delinquent_consignment_clinics_w_terminal AS delinquent_consignment_clinics ON delinquent_consignment_clinics.clinic_id = invoicing_clinic_id
##      LEFT JOIN uploads.accrued_consignment_clinics ON accrued_consignment_clinics.clinic_id = invoicing_clinic_id
##
##      -- ===== FILTERS =====
##
##      WHERE
##
##        ("order".bill_type_label ILIKE 'Consignment'
##          AND (accrued_consignment_clinics.clinic_id is not null AND "order".completed_on::date >= accrued_consignment_clinics.accrual_effective_date::date AND "order".completed_on::date < coalesce(accrued_consignment_clinics.accrual_term_date::date, '2025-01-01'::date))
##          AND invoiceitem.invoice_type = 'Physician'
##          AND NOT invoicing_clinic_id = 4005 -- 'JScreen Screening Event - Department of Human Genetics Emory'/'JScreen/ Dr. Karson Account - Department of Human Genetics Emory'
##          AND NOT invoicing_clinic_id = 3334 -- 'JScreen, Dept of Human Genetics, Emory Univ'
##          AND NOT invoicing_clinic_id = 10040 -- 'Shire/JScreen Screening Events'
##          AND NOT invoicing_clinic_id = 3458 -- 'JGDC of Greater Phoenix - Screening Events '
##          AND NOT invoicing_clinic_id = 209  --'Counsyl Proficiency Testing'
##          AND NOT invoicing_clinic_id = 2819 --'Counsyl Screening Event'
##          AND NOT (delinquent_consignment_clinics.clinic_id is not null AND "order".completed_on::date >= delinquent_consignment_clinics.delinquent_effective_date::date AND "order".completed_on::date < coalesce(delinquent_consignment_clinics.delinquent_terminal_date::date, '2025-01-01'::date))
##          )
##
##          AND
##
##        (invoicing_clinic_id != 4005 -- 'JScreen Screening Event - Department of Human Genetics Emory'/'JScreen/ Dr. Karson Account - Department of Human Genetics Emory'
##          AND invoicing_clinic_id != 10040 -- 'Shire/JScreen Screening Events'
##          AND invoicing_clinic_id != 3334 -- 'JScreen, Dept of Human Genetics, Emory Univ'
##          AND invoicing_clinic_id != 3458) -- 'JGDC of Greater Phoenix - Screening Events '
##
##          AND latest_barcode is not null
##
##      GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
##       ;;
##    sql_trigger_value: select count(*) from ${matched_report_2014_to_current.SQL_TABLE_NAME} ;;
##    indexes: ["invoice_id"]
##  }
##
##  dimension: invoice_id {
##    type: number
##    sql: ${TABLE}.invoice_id ;;
##  }
##
##  dimension: invoiceitem_id {
##    type: number
##    sql: ${TABLE}.invoiceitem_id ;;
##  }
##
##  dimension: invoice_number {
##    type: string
##    sql: ${TABLE}.invoice_number ;;
##  }
##
##  dimension: invoice_type {
##    type: string
##    sql: ${TABLE}.type ;;
##  }
##
##  dimension: barcode {
##    type: string
##    sql: ${TABLE}.latest_barcode ;;
##  }
##
##  dimension_group: revenue_recorded {
##    type: time
##    timeframes: [quarter, date, week, month, year]
##    sql: ${TABLE}.revenue_recorded_timestamp ;;
##  }
##
##  dimension: invoice_item_amount {
##    type: number
##    sql: ${TABLE}.invoice_item_amount ;;
##  }
##
##  dimension: product {
##    sql: ${TABLE}.product ;;
##  }
##
##  measure: total_invoice_item_amount {
##    label: "Total Consignment Revenue"
##    type: sum
##    sql: ${invoice_item_amount} ;;
##  }
##}
##
##view: consignment_comp_to_barcode {
##  view_label: "Consignment Comp and Consignment to Barcode Intermediate"
##
##  derived_table: {
##    sql:
##      SELECT
##         order_id
##        , price
##        , latest_barcode
##        , product
##        , invoice_id
##        , invoice_number
##        , revenue_recorded_timestamp
##        , invoice_amount
##        , clinic
##        , percent_of_invoice
##        , consignment_comp_revenue
##        , order_status_name
##      FROM
##      (
##      SELECT
##          order_id
##          , price
##          , latest_barcode
##          , product
##          , foo.invoice_id
##          , foo.invoice_number
##          , foo3.revenue_recorded_timestamp
##          , invoice_amount
##          , clinic
##          , price/nullif(invoice_amount,0)  as percent_of_invoice
##          , (price/nullif(invoice_amount,0)) * foo3.consignment_comp_revenue AS consignment_comp_revenue
##          , foo.order_status_name
##        FROM
##          (
##          SELECT
##            ord.id as order_id
##            , clinic.name AS clinic
##            , ord.price
##            , CASE
##              WHEN has_ips_high_risk = TRUE and ord.product_name = 'Prelude Prenatal Screen' THEN 'Prelude Prenatal Screen - High Risk'
##              WHEN has_ips_high_risk = FALSE and ord.product_name = 'Prelude Prenatal Screen' THEN 'Prelude Prenatal Screen - Low Risk'
##              WHEN has_ips_high_risk is null and ord.product_name = 'Prelude Prenatal Screen' THEN 'Prelude Prenatal Screen - Low Risk'
##              ELSE ord.product_name END as product
##            , ord.latest_barcode
##            , invoice.id as invoice_id
##            , invoice.invoice_number
##            , invoice.amount as invoice_amount
##            , ord.status AS order_status_name
##          FROM
##            ${order.SQL_TABLE_NAME} as ord
##          LEFT JOIN ${notable_diagnoses.SQL_TABLE_NAME} as nd on nd.order_id = ord.id
##          INNER JOIN
##            ${invoiceitem.SQL_TABLE_NAME} as invoiceitem on invoiceitem.order_id= ord.id
##          INNER JOIN
##            current.invoice as invoice on invoice.id = invoiceitem.invoice_id
##          LEFT JOIN current.clinic AS clinic ON clinic.id=invoice.clinic_id
##          WHERE invoice.type = 'Physician'
##          AND invoice.clinic_id != 4005 -- 'JScreen Screening Event - Department of Human Genetics Emory'/'JScreen/ Dr. Karson Account - Department of Human Genetics Emory'
##          AND invoice.clinic_id != 10040 -- 'Shire/JScreen Screening Events'
##          AND invoice.clinic_id != 3334 -- 'JScreen, Dept of Human Genetics, Emory Univ'
##          AND invoice.clinic_id != 3458 -- 'JGDC of Greater Phoenix - Screening Events  '
##          AND latest_barcode is not null
##          ) as foo
##        LEFT JOIN ${consignment_comp.SQL_TABLE_NAME} as foo2 on foo2.invoice_id = foo.invoice_id
##        LEFT JOIN ${consignment_comp_aggregate.SQL_TABLE_NAME} AS foo3 ON foo3.invoice_id  = foo.invoice_id
##          GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12
##        ) AS allocation
##       ;;
##    sql_trigger_value: select count(*) AS full_count from ${consignment_comp.SQL_TABLE_NAME} ;;
##    indexes: ["invoice_id"]
##  }
##
##  dimension: invoice_id {
##    type: number
##    sql: ${TABLE}.invoice_id ;;
##  }
##
##  dimension: invoice_number {
##    sql: ${TABLE}.invoice_number ;;
##  }
##
##  dimension: order_id {
##    sql: ${TABLE}.order_id ;;
##  }
##
##  dimension: barcode {
##    sql: ${TABLE}.latest_barcode ;;
##  }
##
##  dimension: product {
##    sql: ${TABLE}.product ;;
##  }
##
##  dimension: price {
##    sql: ${TABLE}.price ;;
##  }
##
##  dimension_group: revenue_recorded {
##    type: time
##    timeframes: [quarter, date, week, month, year]
##    sql: ${TABLE}.revenue_recorded_timestamp ;;
##  }
##
##  dimension: consignment_comp_revenue {
##    type: number
##    sql: ${TABLE}.consignment_comp_revenue ;;
##  }
##
##  dimension: jscreen_payment_amount {
##    type: number
##    sql: ${TABLE}.jscreen_payment_amount ;;
##  }
##
##  measure: total_consignment_comp_revenue {
##    type: sum
##    sql: ${TABLE}.consignment_comp_revenue ;;
##  }
##}
##
##view: jscreen_consignment_comp_to_barcode {
##  view_label: "Consignment Comp and Consignment to Barcode Intermediate"
##
##  derived_table: {
##    sql:
##      SELECT
##        order_id
##        , price
##        , latest_barcode
##        , product
##        , invoice_id
##        , invoice_number
##        , revenue_recorded_timestamp
##        , invoice_amount
##        , clinic
##        , percent_of_invoice
##        , consignment_comp_revenue
##      FROM
##      (
##      SELECT
##          order_id
##          , price
##          , latest_barcode
##          , product
##          , foo.invoice_id
##          , foo.invoice_number
##          , revenue_recorded_timestamp
##          , invoice_amount
##          , foo.invoiceitem_amount
##          , clinic
##          , foo.invoiceitem_amount/nullif(invoice_amount,0)  as percent_of_invoice
##          , foo.invoiceitem_amount/nullif(invoice_amount,0)* sum(transaction_amount)  AS consignment_comp_revenue
##        FROM
##          (
##          SELECT
##            ord.id as order_id
##            , clinic.name AS clinic
##            , ord.price
##            , ord.product AS product
##            , ord.latest_barcode
##            , invoiceitem.amount AS invoiceitem_amount
##            , invoice.id as invoice_id
##            , invoice.invoice_number
##            , invoice.amount as invoice_amount
##          FROM
##            ${order.SQL_TABLE_NAME} as ord
##          INNER JOIN
##            ${invoiceitem.SQL_TABLE_NAME} as invoiceitem on invoiceitem.order_id= ord.id
##          INNER JOIN
##            current.invoice as invoice on invoice.id = invoiceitem.invoice_id -- swap in for SQL TABLE NAME
##          LEFT JOIN current.clinic AS clinic ON clinic.id=ord.clinic_id
##          WHERE invoice.type = 'Physician'
##          AND
##          (
##          clinic.id = 4005 -- 'JScreen Screening Event - Department of Human Genetics Emory'/'JScreen/ Dr. Karson Account - Department of Human Genetics Emory'
##          OR clinic.id = 10040 -- 'Shire/JScreen Screening Events'
##          OR clinic.id = 3334 -- 'JScreen, Dept of Human Genetics, Emory Univ'
##          OR clinic.id = 3458 -- 'JGDC of Greater Phoenix - Screening Events  '
##          )
##          AND latest_barcode is not null
##          ) as foo
##        LEFT JOIN ${consignment_comp.SQL_TABLE_NAME} as foo2 on foo2.invoice_id = foo.invoice_id
##          GROUP BY 1,2,3,4,5,6,7,8,9,10
##        ) AS jscreen_allocation
##       ;;
##    sql_trigger_value: select count(*) AS full_count from ${consignment_comp.SQL_TABLE_NAME} ;;
##    indexes: ["invoice_id"]
##  }
##
##  dimension: invoice_id {
##    type: number
##    sql: ${TABLE}.invoice_id ;;
##  }
##
##  dimension: invoice_number {
##    sql: ${TABLE}.invoice_number ;;
##  }
##
##  dimension: order_id {
##    sql: ${TABLE}.order_id ;;
##  }
##
##  dimension: barcode {
##    sql: ${TABLE}.latest_barcode ;;
##  }
##
##  dimension: product {
##    sql: ${TABLE}.product ;;
##  }
##
##  dimension: price {
##    sql: ${TABLE}.price ;;
##  }
##
##  dimension_group: revenue_recorded {
##    type: time
##    timeframes: [quarter, date, week, month, year]
##    sql: ${TABLE}.revenue_recorded_timestamp ;;
##  }
##
##  dimension: consignment_comp_revenue {
##    type: number
##    sql: ${TABLE}.consignment_comp_revenue ;;
##  }
##
##  dimension: jscreen_payment_amount {
##    type: number
##    sql: ${TABLE}.jscreen_payment_amount ;;
##  }
##
##  measure: total_consignment_comp_revenue {
##    type: sum
##    sql: ${TABLE}.consignment_comp_revenue ;;
##  }
##}
##
##view: consignment_comp {
##  view_label: "Consignment Comp"
##
##  derived_table: {
##    sql:
##      SELECT
##        'Consignment' AS bill_type_label
##        ,payment.payment_method AS payment_method
##        ,payment.timestamp AS revenue_recorded_timestamp
##        ,invoice.id AS invoice_id
##        ,invoice.invoice_number AS invoice_number
##        ,billing_clinic.name AS name
##        ,payment.transaction_id AS transaction_id
##        ,payment.amount AS transaction_amount
##        ,invoice.type AS typ
##      FROM ${payment.SQL_TABLE_NAME} AS payment
##      INNER JOIN ${invoice.SQL_TABLE_NAME} AS invoice ON invoice.invoice_number = payment.invoice_number
##      INNER JOIN ${billing_clinic.SQL_TABLE_NAME} AS billing_clinic ON invoice.invoicing_clinic_id = billing_clinic.id
##      LEFT JOIN uploads.delinquent_consignment_clinics_w_terminal AS delinquent_consignment_clinics  ON delinquent_consignment_clinics.clinic_id = billing_clinic.id
##      LEFT JOIN uploads.accrued_consignment_clinics ON accrued_consignment_clinics.clinic_id = billing_clinic.id
##      -- ===== FILTERS =====
##
##      WHERE
##        invoice.type = 'Physician' and cnsmt_item_count > 0
##        AND (accrued_consignment_clinics.clinic_id is not null AND max_complete_date >= accrued_consignment_clinics.accrual_effective_date::date  AND max_complete_date < coalesce(accrued_consignment_clinics.accrual_term_date::date, '2025-01-01'::date))
##        AND payment.payment_method = 'comp'
##        AND NOT invoicing_clinic_id = 209  --'Counsyl Proficiency Testing'
##        AND NOT invoicing_clinic_id = 2819 --'Counsyl Screening Event''
##        AND NOT (delinquent_consignment_clinics.clinic_id is not null AND max_complete_date >= delinquent_consignment_clinics.delinquent_effective_date::date AND max_complete_date < coalesce(delinquent_consignment_clinics.delinquent_terminal_date::date, '2025-01-01'::date))
##
##      GROUP BY 1,2,3,4,5,6,7,8,9
##       ;;
##    sql_trigger_value: select count(*) from ${matched_report_2014_to_current.SQL_TABLE_NAME} ;;
##    indexes: ["invoice_id"]
##  }
##
##  dimension: invoice_id {
##    type: number
##    sql: ${TABLE}.invoice_id ;;
##  }
##
##  dimension_group: revenue_recorded {
##    type: time
##    timeframes: [quarter, date, week, month, year]
##    sql: ${TABLE}.revenue_recorded_timestamp ;;
##  }
##
##  dimension: transaction_amount {
##    type: number
##    sql: ${TABLE}.transaction_amount ;;
##  }
##
##  dimension: product {
##    hidden: yes
##    sql: ${TABLE}.product ;;
##  }
##
##  measure: oon_insurer_total_revenue {
##    label: "Consignment Total Comp"
##    type: sum
##    sql: ${transaction_amount} ;;
##  }
##}
##
##view: consignment_comp_aggregate {
##  view_label: "Consignment Aggregate"
##
##  derived_table: {
##    sql: SELECT
##        invoice_id
##        , revenue_recorded_timestamp
##        , sum(transaction_amount) AS consignment_comp_revenue
##      FROM ${consignment_comp.SQL_TABLE_NAME}
##      GROUP BY 1,2
##       ;;
##    sql_trigger_value: SELECT count(invoice_id) FROM ${consignment_comp.SQL_TABLE_NAME} ;;
##    indexes: ["invoice_id"]
##  }
##
##  dimension: invoice_id {
##    sql: ${TABLE}.invoice_id ;;
##  }
##}
##
##view: jscreen_revenue {
##  view_label: "JScreen Revenue"
##
##  derived_table: {
##    sql: SELECT
##       foo2.type
##      ,foo2.bill_type_label
##      ,foo2.invoice_number
##      ,foo2.invoice_id
##      ,foo2.name
##      ,foo2.completed_date
##      ,foo2.product
##      ,foo2.latest_barcode
##      ,foo2.order_id
##      ,foo2.invoice_item_amount
##      --,foo2.transaction_id
##      ,foo2.revenue_recorded_timestamp
##      FROM (
##        SELECT
##          foo.type
##          ,foo.bill_type_label
##          ,foo.invoice_number
##          ,foo.invoice_id
##          ,foo.name
##          ,foo.completed_date
##          ,foo.product
##          ,foo.latest_barcode
##          ,foo.order_id
##          ,foo.invoice_item_amount
##          --,foo.transaction_id
##          ,jscreen_rev_record_date.deposit_date
##          , CASE
##            WHEN foo.completed_date is null THEN null
##            WHEN jscreen_rev_record_date.deposit_date is null THEN null
##            ELSE CASE
##              WHEN foo.completed_date > jscreen_rev_record_date.deposit_date THEN foo.completed_date
##              WHEN jscreen_rev_record_date.deposit_date > foo.completed_date THEN jscreen_rev_record_date.deposit_date ELSE null END END AS revenue_recorded_timestamp
##        FROM (
##          SELECT
##            invoice.type AS type
##            ,"order".bill_type_label AS bill_type_label
##            ,invoice.invoice_number AS invoice_number
##            ,invoice.id AS invoice_id
##            ,billing_clinic.name AS name
##            ,DATE("order".completed_on) AS completed_date
##            ,CASE
##                WHEN product_name = 'Foresight Carrier Screen' and testing_methodology = 0 THEN 'Foresight 1.0'
##                WHEN product_name = 'Foresight Carrier Screen' and testing_methodology = 1 THEN 'Foresight 2.0'
##                ELSE product_name END AS product
##            ,"order".latest_barcode AS latest_barcode
##            ,"order".id AS order_id
##            --, payment.transaction_id -- need to figure out whether we need to allocate jscreen revenue by transaction id
##            ,invoiceitem.amount AS invoice_item_amount
##            FROM ${order.SQL_TABLE_NAME} AS "order"
##            LEFT JOIN ${billing_clinic.SQL_TABLE_NAME} AS billing_clinic ON ("order".billing_clinic_id) = billing_clinic.id
##            LEFT JOIN ${invoiceitem.SQL_TABLE_NAME} AS invoiceitem ON invoiceitem.order_id = ("order".id)
##            LEFT JOIN ${invoice.SQL_TABLE_NAME} AS invoice ON invoice.invoice_number = invoiceitem.invoice_number
##            LEFT JOIN ${payment.SQL_TABLE_NAME} AS payment ON payment.invoice_number = invoice.invoice_number
##        -- ===== FILTERS =====
##
##          WHERE
##            (
##          billing_clinic.id = 4005 -- 'JScreen Screening Event - Department of Human Genetics Emory'/'JScreen/ Dr. Karson Account - Department of Human Genetics Emory'
##          OR billing_clinic.id = 10040 -- 'Shire/JScreen Screening Events'
##          OR billing_clinic.id = 3458 -- 'JGDC of Greater Phoenix - Screening Events  '
##          OR billing_clinic.id = 3334 -- 'JScreen, Dept of Human Genetics, Emory Univ'
##            )
##            AND (invoice.type ILIKE 'Physician')
##            AND latest_barcode is not null
##          GROUP BY 1,2,3,4,5,6,7,8,9,10) AS foo
##          LEFT JOIN ${jscreen_rev_record_date.SQL_TABLE_NAME} AS jscreen_rev_record_date ON jscreen_rev_record_date.invoice_number = foo.invoice_number
##          GROUP BY 1,2,3,4,5,6,7,8,9,10,11) AS foo2
##        GROUP BY 1,2,3,4,5,6,7,8,9,10,11
##       ;;
##    sql_trigger_value: select count(*) from ${matched_report_2014_to_current.SQL_TABLE_NAME} ;;
##    indexes: ["invoice_number"]
##  }
##
##  dimension: invoice_number {
##    type: string
##    sql: ${TABLE}.invoice_number ;;
##  }
##
##  dimension: barcode {
##    type: string
##    sql: ${TABLE}.latest_barcode ;;
##  }
##
##  dimension: product {
##    sql: ${TABLE}.product ;;
##  }
##
##  dimension: invoice_item_amount {
##    type: number
##    sql: ${TABLE}.invoice_item_amount ;;
##  }
##
##  dimension: jscreen_payment_amount {
##    type: number
##    sql: ${TABLE}.jscreen_payment_amount ;;
##  }
##
##  dimension: transaction_id {
##    sql: ${TABLE}.transaction_id ;;
##  }
##
##  dimension_group: revenue_recorded {
##    type: time
##    timeframes: [quarter, date, week, month, year]
##    sql: ${TABLE}.revenue_recorded_timestamp ;;
##  }
##
##  measure: total_invoice_item_amount {
##    label: "JScreen Revenue (Total Invoice Item Amount)"
##    type: sum
##    sql: ${invoice_item_amount} ;;
##  }
##
##  measure: total_deposit_amount {
##    label: "Total JScreen Payment (Deposit Amount)"
##    type: sum
##    sql: ${jscreen_payment_amount} ;;
##  }
##
##  measure: jscreen_credit {
##    label: "JScreen Credit"
##    type: number
##    sql: ${total_invoice_item_amount} - ${total_deposit_amount} ;;
##  }
##}
##
##view: jscreen_revenue_net_payments {
##  view_label: "JScreen Revenue Net Payments (Invoice-Level)"
##
##  derived_table: {
##    sql: SELECT
##      jscreen_revenue.invoice_id
##      ,jscreen_revenue.invoice_number
##      --,jscreen_revenue.revenue_recorded_timestamp --KEEPING IN HERE IN CASE WE WANT TO BRING IN REV REC DATE
##      ,invoiceitem_count
##      ,jscreen_revenue.invoice_item_amount AS invoice_item_amount
##      ,sum(jscreen_payments.deposit_amt) AS deposit_amount
##      FROM
##        (
##        SELECT
##          invoice.type
##          ,invoice.id AS invoice_id
##          ,invoice.invoice_number
##          ,COUNT(invoiceitem.id) AS invoiceitem_count
##          ,SUM(invoiceitem.amount) AS invoice_item_amount
##        FROM
##            ${invoiceitem.SQL_TABLE_NAME} AS invoiceitem
##        LEFT JOIN
##              ${invoice.SQL_TABLE_NAME} AS invoice ON invoice.id = invoiceitem.invoice_id
##        GROUP BY 1,2,3) AS jscreen_revenue
##      LEFT JOIN
##        ${jscreen_source.SQL_TABLE_NAME} AS jscreen_payments ON jscreen_payments.invoice_id = jscreen_revenue.invoice_id
##      GROUP BY 1,2,3,4
##       ;;
##  }
##
##  dimension: invoice_number {
##    type: string
##    sql: ${TABLE}.invoice_number ;;
##  }
##
##  dimension: invoice_item_amount {
##    type: number
##    sql: ${TABLE}.invoice_item_amount ;;
##  }
##
##  dimension: invoiceitem_count {
##    type: number
##    sql: ${TABLE}.invoiceitem_count ;;
##  }
##
##  dimension: deposit_amount {
##    type: number
##    sql: ${TABLE}.deposit_amount ;;
##  }
##
##  dimension_group: revenue_recorded {
##    hidden: yes
##    type: time
##    timeframes: [quarter, date, week, month, year]
##    sql: ${TABLE}.revenue_recorded_timestamp ;;
##  }
##
##  measure: total_invoice_item_amount {
##    label: "JScreen Revenue (Total Invoice Item Amount)"
##    type: sum
##    sql: ${invoice_item_amount} ;;
##  }
##
##  measure: total_deposit_amount {
##    label: "Total JScreen Payment (Deposit Amount)"
##    type: sum
##    sql: ${deposit_amount} ;;
##  }
##
##  measure: jscreen_credit {
##    label: "JScreen Credit"
##    type: number
##    sql: ${total_invoice_item_amount} - ${total_deposit_amount} ;;
##  }
##}
##
##view: jscreen_rev_record_date {
##  view_label: "JScreen Revenue Record Date"
##
##  derived_table: {
##    sql: SELECT
##      invoice_number
##      ,deposit_date
##      FROM (
##        SELECT
##          match.bai_code AS bai_code
##          ,match.bank_account AS bank_account
##          ,match.coid AS bank_coid
##          ,match.bank_data_type AS bank_data_type
##          ,match.bank_description AS bank_description
##          ,match.bank_pkey AS bank_pkey
##          ,match.bank_ref AS bank_ref
##          ,match.bank_text_desc AS bank_text_desc
##          ,match.bank_trans_id AS bank_trans_id
##          ,match.barcode AS barcode
##          ,match.bill_invoice_concat AS bill_inv_concat
##          ,match.bill_ops_source AS bill_ops_source
##          ,match.bill_type AS bill_type
##          ,match.claim_id AS claim_id
##          ,match.clinic_id AS clinic_id
##          ,match.clinic_name AS clinic_name
##          ,DATE(match.completed_on) AS completed_on_date
##          ,TO_CHAR(match.completed_on, 'YYYY-MM') AS completed_on_month
##          ,EXTRACT(YEAR FROM match.completed_on)::integer AS completed_on_year
##          ,DATE(match.date_of_service) AS date_of_service
##          ,match.deposit_amt AS deposit_amt
##          ,DATE(match.deposit_date) AS deposit_date
##          ,TO_CHAR(match.deposit_date, 'YYYY-MM') AS deposit_month
##          ,EXTRACT(YEAR FROM match.deposit_date)::integer AS deposit_year
##          ,match.disease_panel AS disease_panel
##          ,match.eob_batch_adjs AS eob_batch_adjs
##          ,DATE(match.hybrid_date_recorded) AS hybrid_date_recorded_date
##          ,match.hybrid_pkey AS hybrid_pkey
##          ,match.hybrid_trans_id AS hybrid_trans_id
##          ,match.hybrid_transaction_amt AS hybrid_transaction_amount
##          ,match.invoice_id AS invoice_id
##          ,match.invoice_number AS invoice_number
##          ,DATE(match.invoice_sent_date) AS invoice_sent_date
##          ,DATE(match.invoice_timestamp) AS invoice_timestamp
##          ,match.invoice_type AS invoice_type
##          ,CASE WHEN match.known_var THEN 'Yes' ELSE 'No' END AS known_var
##          ,"order".product_name AS "order.product"
##          ,match.network_status AS network_status
##          ,match.order_id AS order_id
##          ,match.payer_name AS payer_name
##          ,match.pretty_payer_name AS pretty_payer_name
##          ,match.product AS product
##          ,DATE(match.rev_rec_date) AS rev_rec_date
##          ,CASE WHEN match.rev_trn = 'Revenue' THEN 'Revenue' ELSE 'Non-Revenue' END AS rev_trn
##          ,match.source AS source
##        FROM ${matched_report_2014_to_current.SQL_TABLE_NAME} AS match
##        LEFT JOIN ${order.SQL_TABLE_NAME} AS "order" ON ("order".latest_barcode) = match.barcode
##
##        -- ===== FILTERS =====
##
##        WHERE
##        match.invoice_type ILIKE 'Physician'
##          AND (
##          match.clinic_id = 4005 -- 'JScreen Screening Event - Department of Human Genetics Emory'/'JScreen/ Dr. Karson Account - Department of Human Genetics Emory'
##          OR match.clinic_id = 10040 -- 'Shire/JScreen Screening Events'
##          OR match.clinic_id = 3334 -- 'JScreen, Dept of Human Genetics, Emory Univ'
##          OR match.clinic_id = 3458 -- 'JGDC of Greater Phoenix - Screening Events  '
##          )
##
##        GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45
##      ) AS foo
##       ;;
##    sql_trigger_value: select count(*) from ${matched_report_2014_to_current.SQL_TABLE_NAME} ;;
##    indexes: ["invoice_number"]
##  }
##
##  dimension: invoice_number {
##    sql: ${TABLE}.invoice_number ;;
##  }
##
##  dimension: deposit_date {
##    sql: ${TABLE}.deposit_date ;;
##  }
##}
##
##view: jscreen_source {
##  view_label: "JScreen Source"
##
##  derived_table: {
##    sql: SELECT
##      foo.invoice_id
##      ,foo.invoice_number
##      , foo.deposit_date
##      , foo.bank_text_desc
##      ,sum(foo.deposit_amt) AS deposit_amt
##      , product
##      FROM
##      (
##        SELECT
##          match.bai_code AS bai_code
##          ,match.bank_account AS bank_account
##          ,match.coid AS bank_coid
##          ,match.bank_data_type AS bank_data_type
##          ,match.bank_description AS bank_description
##          ,match.bank_pkey AS bank_pkey
##          ,match.bank_ref AS bank_ref
##          ,match.bank_text_desc AS bank_text_desc
##          ,match.bank_trans_id AS bank_trans_id
##          ,match.barcode AS barcode
##          ,match.bill_invoice_concat AS bill_inv_concat
##          ,match.bill_ops_source AS bill_ops_source
##          ,match.bill_type AS bill_type
##          ,match.claim_id AS claim_id
##          ,match.clinic_id AS clinic_id
##          ,match.clinic_name AS clinic_name
##          ,DATE(match.completed_on) AS completed_on_date
##          ,TO_CHAR(match.completed_on, 'YYYY-MM') AS completed_on_month
##          ,EXTRACT(YEAR FROM match.completed_on)::integer AS completed_on_year
##          ,DATE(match.date_of_service) AS date_of_service
##          ,match.deposit_amt AS deposit_amt
##          ,DATE(match.deposit_date) AS deposit_date
##          ,TO_CHAR(match.deposit_date, 'YYYY-MM') AS deposit_month
##          ,EXTRACT(YEAR FROM match.deposit_date)::integer AS deposit_year
##          ,match.disease_panel AS disease_panel
##          ,match.eob_batch_adjs AS eob_batch_adjs
##          ,DATE(match.hybrid_date_recorded) AS hybrid_date_recorded_date
##          ,match.hybrid_pkey AS hybrid_pkey
##          ,match.hybrid_trans_id AS hybrid_trans_id
##          ,match.hybrid_transaction_amt AS hybrid_transaction_amount
##          ,match.invoice_id AS invoice_id
##          ,match.invoice_number AS invoice_number
##          ,DATE(match.invoice_sent_date) AS invoice_sent_date
##          ,DATE(match.invoice_timestamp) AS invoice_timestamp
##          ,match.invoice_type AS invoice_type
##          ,CASE WHEN match.known_var THEN 'Yes' ELSE 'No' END AS known_var
##          ,match.product
##          ,match.network_status AS network_status
##          ,match.order_id AS order_id
##          ,match.payer_name AS payer_name
##          ,match.pretty_payer_name AS pretty_payer_name
##          ,match.product AS product
##          ,DATE(match.rev_rec_date) AS rev_rec_date
##          ,CASE WHEN match.rev_trn THEN 'Revenue' ELSE 'Non-Revenue' END AS rev_trn
##          ,match.source AS source
##        FROM ${matched_report_2014_to_current.SQL_TABLE_NAME} AS match
##
##        -- ===== FILTERS =====
##
##        WHERE
##        match.invoice_type ILIKE 'Physician'
##          AND
##          (
##          match.clinic_id = 4005 -- 'JScreen Screening Event - Department of Human Genetics Emory'/'JScreen/ Dr. Karson Account - Department of Human Genetics Emory'
##          OR match.clinic_id = 10040 -- 'Shire/JScreen Screening Events'
##          OR match.clinic_id = 3334 -- 'JScreen, Dept of Human Genetics, Emory Univ'
##          OR match.clinic_id = 3458 -- 'JGDC of Greater Phoenix - Screening Events  '
##          )
##
##        GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45
##      ) AS foo
##      GROUP BY 1,2,3,4
##       ;;
##  }
##
##  dimension: invoice_number {
##    type: string
##    sql: ${TABLE}.invoice_number ;;
##  }
##
##  measure: deposit_amount {
##    type: sum
##    sql: ${TABLE}.deposit_amt ;;
##  }
##
##  dimension: bank_text_desc {
##    sql: ${TABLE}.bank_text_desc ;;
##  }
##
##  dimension: barcode {
##    sql: ${TABLE}.barcode ;;
##  }
##
##  dimension: order_id {
##    sql: ${TABLE}.order_id ;;
##  }
##
##  dimension: deposit_date {
##    type: date
##    sql: ${TABLE}.deposit_date ;;
##  }
##}
##
##view: jscreen_payments_to_barcode {
##  view_label: "JScreen Payments to Barcode Intermediate"
##
##  derived_table: {
##    sql:
##      SELECT
##        allocation.order_id
##        ,allocation.price
##        ,allocation.latest_barcode
##        ,allocation.product
##        ,allocation.invoice_id
##        ,allocation.invoice_number
##        ,allocation.percent_of_invoice
##        ,allocation.deposit_date
##        ,allocation.jscreen_payment_amount
##        --,rev_rec_date.revenue_recorded_timestamp
##      FROM
##      (
##
##        SELECT
##          order_id
##          , price
##          , latest_barcode
##          , product
##          , foo.invoice_id
##          ,foo.invoice_number
##          ,deposit_date
##          , price/nullif(invoice_amount,0) as percent_of_invoice
##          , (price/nullif(invoice_amount,0)) * sum(deposit_amt) as jscreen_payment_amount
##        FROM
##          (SELECT
##            ord.id as order_id
##            , ord.price
##            , ord.product_name AS product
##            , ord.latest_barcode
##            , invoice.id as invoice_id
##            , invoice.invoice_number
##            , invoice.amount as invoice_amount
##          FROM
##            ${order.SQL_TABLE_NAME} as ord
##          INNER JOIN
##            ${invoiceitem.SQL_TABLE_NAME} as invoiceitem on invoiceitem.order_id= ord.id
##          INNER JOIN
##            ${invoice.SQL_TABLE_NAME} as invoice on invoice.id = invoiceitem.invoice_id
##          ) as foo
##          LEFT JOIN ${jscreen_source.SQL_TABLE_NAME} AS jscreen_source ON jscreen_source.invoice_id = foo.invoice_id
##          GROUP BY 1,2,3,4,5,6,7,8) AS allocation
##       ;;
##  }
##}
##
##view: jscreen_revenue_payment_allocation {
##  derived_table: {
##    sql: SELECT
##        foo1.invoice_id
##        , foo1.invoice_number
##        , foo1.order_id
##        , foo1.product
##        , foo1.latest_barcode
##        , foo1.order_status_name
##        , CASE
##          WHEN foo1.completed_on is null THEN null
##          WHEN foo2.deposit_date is null THEN null
##            ELSE
##              CASE
##                WHEN foo1.completed_on > foo2.deposit_date THEN foo1.completed_on
##                WHEN foo2.deposit_date > foo1.completed_on THEN foo2.deposit_date ELSE null END END AS revenue_recorded_timestamp
##        , CASE
##          WHEN foo1.completed_on is null THEN null
##          WHEN foo2.deposit_date is null THEN null
##            ELSE
##              CASE
##                WHEN foo1.completed_on > foo2.deposit_date THEN (1.00 * foo2.hybrid_transaction_amt * foo1.invoiceitem_percent_of_invoice)
##                WHEN foo2.deposit_date > foo1.completed_on THEN (1.00 * foo2.hybrid_transaction_amt * foo1.invoiceitem_percent_of_invoice)   ELSE null END END AS allocated_payment_amount
##        , foo2.total_payment_amt_on_invoice
##      FROM
##
##      (
##          SELECT
##            invoice_id
##            , invoice.invoice_number
##            , invoiceitem.id AS invoiceitem_id
##            , o.id AS order_id
##            , CASE
##              WHEN has_ips_high_risk = TRUE and o.product_name = 'Prelude Prenatal Screen' THEN 'Prelude Prenatal Screen - High Risk'
##              WHEN has_ips_high_risk = FALSE and o.product_name = 'Prelude Prenatal Screen' THEN 'Prelude Prenatal Screen - Low Risk'
##              WHEN has_ips_high_risk is null and o.product_name = 'Prelude Prenatal Screen' THEN 'Prelude Prenatal Screen - Low Risk'
##              ELSE o.product_name END as product
##            , o.completed_on
##            , invoiceitem.amount AS invoice_item_amount
##            , invoice.amount
##            , o.latest_barcode
##            , coalesce(coalesce(invoiceitem.amount,0) / nullif(invoice.amount,0),0) AS invoiceitem_percent_of_invoice
##            , o.status AS order_status_name
##          FROM ${order.SQL_TABLE_NAME} AS o
##          LEFT JOIN ${notable_diagnoses.SQL_TABLE_NAME} as nd on nd.order_id = o.id
##          LEFT JOIN ${billing_clinic.SQL_TABLE_NAME} AS billing_clinic ON (o.billing_clinic_id) = billing_clinic.id
##          LEFT JOIN ${invoiceitem.SQL_TABLE_NAME} AS invoiceitem ON invoiceitem.order_id = (o.id)
##          LEFT JOIN ${invoice.SQL_TABLE_NAME} AS invoice ON invoice.invoice_number = invoiceitem.invoice_number
##          -- ===== FILTERS =====
##
##          WHERE
##              (
##            billing_clinic.id = 4005 -- 'JScreen Screening Event - Department of Human Genetics Emory'/'JScreen/ Dr. Karson Account - Department of Human Genetics Emory'
##            OR billing_clinic.id = 10040 -- 'Shire/JScreen Screening Events'
##            OR billing_clinic.id = 3334 -- 'JScreen, Dept of Human Genetics, Emory Univ'
##            OR billing_clinic.id = 3458 -- 'JGDC of Greater Phoenix - Screening Events  '
##              )
##            AND (invoice.type ILIKE 'Physician')
##            AND latest_barcode is not null
##        ) AS foo1
##
##
##
##        LEFT JOIN
##        (
##            SELECT
##              invoice_number
##              , deposit_date
##              , hybrid_transaction_amt
##              , SUM(hybrid_transaction_amt) OVER(PARTITION BY invoice_number) AS total_payment_amt_on_invoice
##            FROM ${matched_report_2014_to_current.SQL_TABLE_NAME} AS match
##            LEFT JOIN ${order.SQL_TABLE_NAME} AS "order" ON ("order".latest_barcode) = match.barcode
##            WHERE
##            match.invoice_type ILIKE 'Physician'
##              AND
##              (
##              match.clinic_id = 4005 -- 'JScreen Screening Event - Department of Human Genetics Emory'/'JScreen/ Dr. Karson Account - Department of Human Genetics Emory'
##              OR match.clinic_id = 10040 -- 'Shire/JScreen Screening Events'
##              OR match.clinic_id = 3334 -- 'JScreen, Dept of Human Genetics, Emory Univ'
##              OR match.clinic_id = 3458 -- 'JGDC of Greater Phoenix - Screening Events  '
##          )
##        ) AS foo2 ON foo2.invoice_number = foo1.invoice_number
##       ;;
##    sql_trigger_value: select count(*) from ${matched_report_2014_to_current.SQL_TABLE_NAME} ;;
##    indexes: ["invoice_id", "order_id", "revenue_recorded_timestamp"]
##  }
##
##  dimension: invoice_id {
##    type: number
##    sql: ${TABLE}.invoice_id ;;
##  }
##
##  dimension: invoice_number {
##    sql: ${TABLE}.invoice_number ;;
##  }
##
##  dimension: order_id {
##    type: number
##    sql: ${TABLE}.order_id ;;
##  }
##
##  dimension: revenue_recorded_timestamp {
##    type: date
##    sql: ${TABLE}.revenue_recorded_timestamp ;;
##  }
##
##  dimension: allocated_payment_amount {
##    type: number
##    sql: ${TABLE}.allocated_payment_amount ;;
##  }
##
##  measure: total_allocated_payment_amount {
##    type: sum
##    sql: ${TABLE}.allocated_payment_amount ;;
##  }
##
##  dimension: total_payment_amt_on_invoice {
##    type: number
##    sql: ${TABLE}.total_payment_amt_on_invoice ;;
##  }
##}
##
