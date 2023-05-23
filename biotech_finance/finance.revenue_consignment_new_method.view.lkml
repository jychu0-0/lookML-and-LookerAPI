#=========CASH REVENUE: aggregates all cash-basis revenue to the barcode level========


view: consignment_revenue {
  view_label: "Consignment Revenue"

  derived_table: {
    sql:

                  -- ===================== Consignment ==================================



                    SELECT
                      consignment.order_id AS order_id
                      , consignment.latest_barcode AS barcode
                      , consignment.revenue_recorded_timestamp AS revenue_recorded_timestamp
                      , 'Consignment' AS revenue_type
                      , product
                      , 'Barcode' AS pkey_type
                      , consignment.latest_barcode AS pkey
                      , SUM(consignment.invoice_item_amount) AS revenue
                      , order_status_name
                    FROM ${consignment.SQL_TABLE_NAME} AS consignment


                    GROUP BY 1,2,3,4,5,6,7,9



                  -- ===================== Consignment Comps ==================================


                  UNION


                    SELECT
                      consignment_comp.order_id AS order_id
                      , consignment_comp.latest_barcode AS barcode
                      , consignment_comp.revenue_recorded_timestamp AS revenue_recorded_timestamp
                      , 'Consignment Comp' AS revenue_type
                      , product
                      , 'Invoice Number' AS pkey_type
                      , invoice_number AS pkey
                      , SUM(-1.00*consignment_comp.consignment_comp_revenue) AS revenue
                      , order_status_name
                    FROM ${consignment_comp_to_barcode.SQL_TABLE_NAME} AS consignment_comp
                    GROUP BY 1,2,3,4,5,6,7,9

                  -- ===================== END ======================================================================================================
                   ;;
    sql_trigger_value: select string_agg(to_char(full_count,'99999999'),',') from ((select count(*) AS full_count from ${consignment_comp.SQL_TABLE_NAME}) UNION (select count(*) AS full_count from ${consignment.SQL_TABLE_NAME}) UNION (select count(*) AS full_count from uploads.accrued_consignment_clinics) UNION (select count(*) AS full_count from uploads.delinquent_consignment_clinics_w_terminal) ) AS foo ;;
    #datagroup_trigger: etl_refresh
    indexes: ["order_id", "barcode"]
  }

  dimension: order_id {
    type: number
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

  dimension: product {
    sql: ${TABLE}.product ;;
  }

  dimension: cash_revenue {
    sql: ${TABLE}.revenue ;;
  }

  dimension: pkey_type {
    sql: ${TABLE}.pkey_type ;;
  }

  dimension: pkey {
    sql: ${TABLE}.pkey ;;
  }

  measure: total_cash_revenue {
    value_format_name: usd
    type: sum
    sql: ${cash_revenue} ;;
  }
}


view: consignment {
  view_label: "Consignment Revenue"

  derived_table: {
    sql: SELECT
        invoice.id AS invoice_id
        ,invoice.type AS type
        , invoice.invoice_number AS invoice_number
        ,"order".latest_barcode AS latest_barcode
        ,"order".id AS order_id
        ,CASE
          WHEN invoicing_clinic_id IN (3334,4055,10040,3458) -- JScreen clinic ids
            AND DATE(invoice.timestamp) IS NULL OR DATE("order".completed_on) IS NULL THEN NULL
          WHEN invoicing_clinic_id IN (3334,4055,10040,3458) -- JScreen clinic ids
            AND TO_DATE(TO_CHAR(invoice.timestamp - INTERVAL '1 day', 'YYYY-MM-DD'),'YYYY-MM-DD') > DATE("order".completed_on) THEN TO_DATE(TO_CHAR(invoice.timestamp - INTERVAL '1 day', 'YYYY-MM-DD'),'YYYY-MM-DD')
          ELSE DATE("order".completed_on) END AS revenue_recorded_timestamp
        ,EXTRACT(YEAR FROM "order".completed_on)::integer AS completed_year
        ,TO_CHAR("order".completed_on, 'YYYY-MM') AS completed_month
        ,"order".bill_type_label AS bill_type_label
        , CASE
          WHEN has_ips_high_risk = TRUE and "order".product_name = 'Prelude Prenatal Screen' THEN 'Prelude Prenatal Screen - High Risk'
          WHEN has_ips_high_risk = FALSE and "order".product_name = 'Prelude Prenatal Screen' THEN 'Prelude Prenatal Screen - Low Risk'
          WHEN has_ips_high_risk is null and "order".product_name = 'Prelude Prenatal Screen' THEN 'Prelude Prenatal Screen - Low Risk'
          ELSE "order".product_name END as product
        , invoiceitem.id AS invoiceitem_id
        , DATE(invoice.timestamp) AS invoice_timestamp_date
        , invoicing_clinic_name AS name
        , CASE
          WHEN invoicing_clinic_id IN (3334,4055,10040,3458) -- JScreen clinic ids
            AND DATE(invoice.timestamp) IS NULL THEN NULL ELSE invoiceitem.amount END AS invoice_item_amount
        , "order".status AS order_status_name
      FROM ${order.SQL_TABLE_NAME} AS "order"
      LEFT JOIN current.insuranceclaim AS claim ON claim.order_id = ("order".id)
      LEFT JOIN ${notable_diagnoses.SQL_TABLE_NAME} as nd on nd.order_id = "order".id
      LEFT JOIN ${invoiceitem.SQL_TABLE_NAME} AS invoiceitem ON invoiceitem.order_id = ("order".id)
      LEFT JOIN ${invoice.SQL_TABLE_NAME} AS invoice ON invoice.invoice_number = invoiceitem.invoice_number
      LEFT JOIN ${payment.SQL_TABLE_NAME} AS payment ON payment.invoice_number = invoice.invoice_number
      LEFT JOIN uploads.delinquent_consignment_clinics_w_terminal AS delinquent_consignment_clinics ON delinquent_consignment_clinics.clinic_id = invoicing_clinic_id
      LEFT JOIN uploads.accrued_consignment_clinics ON accrued_consignment_clinics.clinic_id = invoicing_clinic_id

      -- ===== FILTERS =====

      WHERE

        ((accrued_consignment_clinics.clinic_id is not null AND "order".completed_on::date >= accrued_consignment_clinics.accrual_effective_date::date AND "order".completed_on::date < coalesce(accrued_consignment_clinics.accrual_term_date::date, '2025-01-01'::date))
          AND invoiceitem.invoice_type ILIKE 'Physician'
          AND NOT invoicing_clinic_id = 209  --'Counsyl Proficiency Testing'
          AND NOT invoicing_clinic_id = 2819 --'Counsyl Screening Event'
          AND NOT invoicing_clinic_id = 87061 --'Genome Medical - Counsyl Employee Screening'
          AND NOT (delinquent_consignment_clinics.clinic_id is not null AND "order".completed_on::date >= delinquent_consignment_clinics.delinquent_effective_date::date AND "order".completed_on::date < coalesce(delinquent_consignment_clinics.delinquent_terminal_date::date, '2025-01-01'::date))
          )



          AND latest_barcode is not null

      GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
       ;;
    sql_trigger_value: select count(*) from ${order.SQL_TABLE_NAME} ;;
    #datagroup_trigger: etl_refresh
    indexes: ["invoice_id"]
  }

  dimension: invoice_id {
    type: number
    sql: ${TABLE}.invoice_id ;;
  }
  dimension: order_id {
    type: number
    sql: ${TABLE}.order_id ;;
  }

  dimension: invoiceitem_id {
    type: number
    sql: ${TABLE}.invoiceitem_id ;;
  }

  dimension: invoice_number {
    type: string
    sql: ${TABLE}.invoice_number ;;
  }

  dimension: invoice_type {
    type: string
    sql: ${TABLE}.type ;;
  }

  dimension_group: invoice_timestamp_date {
    type: time
    timeframes: [quarter, date, week, month, year]
    sql: ${TABLE}.invoice_timestamp_date ;;
  }

  dimension: barcode {
    type: string
    sql: ${TABLE}.latest_barcode ;;
  }

  dimension_group: revenue_recorded {
    type: time
    timeframes: [quarter, date, week, month, year]
    sql: ${TABLE}.revenue_recorded_timestamp ;;
  }

  dimension: invoice_item_amount {
    type: number
    sql: ${TABLE}.invoice_item_amount ;;
  }

  dimension: product {
    sql: ${TABLE}.product ;;
  }

  measure: total_invoice_item_amount {
    label: "Total Consignment Revenue"
    type: sum
    sql: ${invoice_item_amount} ;;
  }
}

view: consignment_comp_to_barcode {
  view_label: "Consignment Comp and Consignment to Barcode Intermediate"

  derived_table: {
    sql:
              SELECT
                 order_id
                , price
                , latest_barcode
                , product
                , invoice_id
                , invoice_number
                , revenue_recorded_timestamp
                , invoice_amount
                , clinic
                , percent_of_invoice
                , consignment_comp_revenue
                , order_status_name
              FROM
              (
              SELECT
                  order_id
                  , price
                  , latest_barcode
                  , product
                  , foo.invoice_id
                  , foo.invoice_number
                  , foo3.revenue_recorded_timestamp
                  , invoice_amount
                  , clinic
                  , price/nullif(invoice_amount,0)  as percent_of_invoice
                  , (price/nullif(invoice_amount,0)) * foo3.consignment_comp_revenue AS consignment_comp_revenue
                  , foo.order_status_name
                FROM
                  (
                  SELECT
                    ord.id as order_id
                    , clinic.name AS clinic
                    , invoiceitem.amount AS price
                    , CASE
                      WHEN has_ips_high_risk = TRUE and ord.product_name = 'Prelude Prenatal Screen' THEN 'Prelude Prenatal Screen - High Risk'
                      WHEN has_ips_high_risk = FALSE and ord.product_name = 'Prelude Prenatal Screen' THEN 'Prelude Prenatal Screen - Low Risk'
                      WHEN has_ips_high_risk is null and ord.product_name = 'Prelude Prenatal Screen' THEN 'Prelude Prenatal Screen - Low Risk'
                      ELSE ord.product_name END as product
                    , ord.latest_barcode
                    , invoice.id as invoice_id
                    , invoice.invoice_number
                    , invoice.amount as invoice_amount
                    , ord.status AS order_status_name
                  FROM
                    ${order.SQL_TABLE_NAME} as ord
                  LEFT JOIN ${notable_diagnoses.SQL_TABLE_NAME} as nd on nd.order_id = ord.id
                  INNER JOIN
                    ${invoiceitem.SQL_TABLE_NAME} as invoiceitem on invoiceitem.order_id= ord.id
                  INNER JOIN
                    current.invoice as invoice on invoice.id = invoiceitem.invoice_id
                  LEFT JOIN current.clinic AS clinic ON clinic.id=invoice.clinic_id
                  WHERE invoice.type ILIKE 'Physician'
                  AND latest_barcode is not null
                  ) as foo
                LEFT JOIN ${consignment_comp.SQL_TABLE_NAME} as foo2 on foo2.invoice_id = foo.invoice_id
                LEFT JOIN ${consignment_comp_aggregate.SQL_TABLE_NAME} AS foo3 ON foo3.invoice_id  = foo.invoice_id
                  GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12
                ) AS allocation
               ;;
    sql_trigger_value: select count(*) AS full_count from ${consignment_comp.SQL_TABLE_NAME} ;;
    #datagroup_trigger: etl_refresh
    indexes: ["invoice_id"]
  }

  dimension: invoice_id {
    type: number
    sql: ${TABLE}.invoice_id ;;
  }

  dimension: invoice_number {
    sql: ${TABLE}.invoice_number ;;
  }

  dimension: order_id {
    sql: ${TABLE}.order_id ;;
  }

  dimension: barcode {
    sql: ${TABLE}.latest_barcode ;;
  }

  dimension: product {
    sql: ${TABLE}.product ;;
  }

  dimension: price {
    sql: ${TABLE}.price ;;
  }

  dimension_group: revenue_recorded {
    type: time
    timeframes: [quarter, date, week, month, year]
    sql: ${TABLE}.revenue_recorded_timestamp ;;
  }

  dimension: consignment_comp_revenue {
    type: number
    sql: ${TABLE}.consignment_comp_revenue ;;
  }

  dimension: jscreen_payment_amount {
    type: number
    sql: ${TABLE}.jscreen_payment_amount ;;
  }

  measure: total_consignment_comp_revenue {
    type: sum
    sql: ${TABLE}.consignment_comp_revenue ;;
  }
}



view: consignment_comp {
  view_label: "Consignment Comp"

  derived_table: {
    sql:
                SELECT
                  'Consignment' AS bill_type_label
                  ,payment.payment_method AS payment_method
                  ,payment.timestamp AS revenue_recorded_timestamp
                  ,invoice.id AS invoice_id
                  ,invoice.invoice_number AS invoice_number
                  , billing_clinic.name AS name
                  ,payment.transaction_id AS transaction_id
                  ,payment.amount AS transaction_amount
                  ,invoice.type AS typ
                FROM ${payment.SQL_TABLE_NAME} AS payment
                INNER JOIN ${invoice.SQL_TABLE_NAME} AS invoice ON invoice.invoice_number = payment.invoice_number
                INNER JOIN ${billing_clinic.SQL_TABLE_NAME} AS billing_clinic ON invoice.invoicing_clinic_id = billing_clinic.id
                LEFT JOIN uploads.delinquent_consignment_clinics_w_terminal AS delinquent_consignment_clinics  ON delinquent_consignment_clinics.clinic_id = billing_clinic.id
                LEFT JOIN uploads.accrued_consignment_clinics ON accrued_consignment_clinics.clinic_id = billing_clinic.id
                -- ===== FILTERS =====

                WHERE
                  invoice.type ILIKE 'Physician'
                  AND (accrued_consignment_clinics.clinic_id is not null AND max_complete_date >= accrued_consignment_clinics.accrual_effective_date::date  AND max_complete_date < coalesce(accrued_consignment_clinics.accrual_term_date::date, '2025-01-01'::date))
                  AND payment.payment_method ILIKE 'comp'
                  AND NOT invoicing_clinic_id = 209  --'Counsyl Proficiency Testing'
                  AND NOT invoicing_clinic_id = 2819 --'Counsyl Screening Event'
                  AND NOT invoicing_clinic_id = 87061 --'Genome Medical - Counsyl Employee Screening'
                  AND NOT (delinquent_consignment_clinics.clinic_id is not null AND max_complete_date >= delinquent_consignment_clinics.delinquent_effective_date::date AND max_complete_date < coalesce(delinquent_consignment_clinics.delinquent_terminal_date::date, '2025-01-01'::date))

                GROUP BY 1,2,3,4,5,6,7,8,9
                 ;;
    sql_trigger_value: select count(*) from ${payment.SQL_TABLE_NAME} ;;
    #datagroup_trigger: etl_refresh
    indexes: ["invoice_id"]
  }

  dimension: invoice_id {
    type: number
    sql: ${TABLE}.invoice_id ;;
  }

  dimension_group: revenue_recorded {
    type: time
    timeframes: [quarter, date, week, month, year]
    sql: ${TABLE}.revenue_recorded_timestamp ;;
  }

  dimension: transaction_amount {
    type: number
    sql: ${TABLE}.transaction_amount ;;
  }

  dimension: product {
    hidden: yes
    sql: ${TABLE}.product ;;
  }

  measure: oon_insurer_total_revenue {
    label: "Consignment Total Comp"
    type: sum
    sql: ${transaction_amount} ;;
  }
}

view: consignment_comp_aggregate {
  view_label: "Consignment Aggregate"

  derived_table: {
    sql: SELECT
                      invoice_id
                      , revenue_recorded_timestamp
                      , sum(transaction_amount) AS consignment_comp_revenue
                    FROM ${consignment_comp.SQL_TABLE_NAME}
                    GROUP BY 1,2
                     ;;
    sql_trigger_value: SELECT count(invoice_id) FROM ${consignment_comp.SQL_TABLE_NAME} ;;
    #datagroup_trigger: etl_refresh
    indexes: ["invoice_id"]
  }

  dimension: invoice_id {
    sql: ${TABLE}.invoice_id ;;
  }
}
