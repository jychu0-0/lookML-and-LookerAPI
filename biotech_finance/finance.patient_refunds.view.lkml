view: patient_refunds {
  derived_table: {
    sql:
      SELECT
        o.id as order_id
        , o.bill_type
        , o.completed_on
        , o.product_name as product
        , o.latest_barcode as barcode
        , type as transaction_type
        , invoice_number
        , invoice_type
        , invoice_amount
        , invoice_id
        , date as transaction_date
        , cast(EXTRACT(year FROM date) as varchar)
          ||
          ' - Q'
          ||
          cast(EXTRACT(quarter FROM date) as varchar) as transaction_quarter
        , amount as transaction_amount
        , CASE
          WHEN o.bill_type in ('cnsmt','cc') OR o.bill_type IS NULL THEN NULL
          WHEN o.product = 'Foresight Carrier Screen' and date_of_service >= inn.fps_date and date_of_service < coalesce(inn.fps_term,'2100-01-01'::date)
            THEN 'In Net'
          WHEN o.product = 'Reliant Cancer Screen' and date_of_service >= inn.ics_date and date_of_service < coalesce(inn.ics_term,'2100-01-01'::date)
            THEN 'In Net'
          WHEN o.product = 'Prelude Prenatal Screen' and date_of_service >= inn.ips_date and date_of_service < coalesce(inn.ips_term,'2100-01-01'::date)
            THEN 'In Net'
          ELSE 'OON'
          END as network_status

      FROM
        ${order.SQL_TABLE_NAME} as o
      LEFT JOIN
        current.insuranceclaim as claim on claim.order_id = o.id
      LEFT JOIN
        uploads.in_network_dates_w_terminal inn on inn.id = claim.payer_id


      LEFT JOIN

        (SELECT
          o.id as order_id
          , payment_method as type
          , invoice.invoice_number
          , invoice.type as invoice_type
          , invoice.amount as invoice_amount
          , invoice.id as invoice_id
          , date_trunc('day', payment.timestamp) as date
          , sum(payment.amount) as amount
        FROM
          ${order.SQL_TABLE_NAME} as o
        LEFT JOIN
          ${invoiceitem.SQL_TABLE_NAME} as invoiceitem on invoiceitem.order_id = o.id
        LEFT JOIN
          ${invoice.SQL_TABLE_NAME} as invoice on invoice.id = invoiceitem.invoice_id
        LEFT JOIN
          ${payment.SQL_TABLE_NAME} as payment on payment.invoice_id = invoice.id
        WHERE
          (payment_method = 'comp'
          and position('COMP_CANC' in transaction_id) = 0
          and position('COMP CANCEL' in transaction_id) = 0
          and position('CANCELED REF' in transaction_id) = 0
          and position('CANCELED_REF' in transaction_id) = 0)
          or payment_method = 'transfer'
        GROUP BY
          1,2,3,4,5,6,7

      UNION ALL

        --BEGIN MATCH SUBQUERY

        SELECT
          o.id as order_id
          , payment_method as type
          , match.invoice_number
          , match.invoice_type
          , invoice.amount
          , match.invoice_id
          , match.deposit_date
          , sum(transaction_amount) as payment_amount
        FROM
          ${order.SQL_TABLE_NAME} as o
        LEFT JOIN
          ${revenue_all_matched_transactions.SQL_TABLE_NAME} as match on match.order_id = o.id
        LEFT JOIN
          ${invoice.SQL_TABLE_NAME} invoice on invoice.id = match.invoice_id
        GROUP BY
          1,2,3,4,5,6,7
        ) as match_subquery on o.id = match_subquery.order_id

        --END MATCH SUBQUERY

      WHERE
        date is not null

      GROUP BY
        1,2,3,4,5,6,7,8,9,10,11,12,13,14
       ;;
    datagroup_trigger: etl_refresh
    #sql_trigger_value: select count(id) from ${order.SQL_TABLE_NAME} ;;
  }

  dimension: order_id {
    type: number
    sql: ${TABLE}.order_id ;;
  }

  dimension: transaction_type {
    sql: ${TABLE}.transaction_type ;;
  }

  dimension: invoice_number {
    sql: ${TABLE}.invoice_number ;;
  }

  dimension: transaction_date {
    type: date
    sql: ${TABLE}.transaction_date ;;
  }

  measure: transaction_amount {
    type: sum
    value_format_name: usd
    sql: ${TABLE}.transaction_amount ;;
  }

  dimension: transaction_quarter {
    sql: ${TABLE}.transaction_quarter ;;
  }

  dimension: bill_type {
    sql: ${TABLE}.bill_type ;;
  }

  dimension: product {
    sql: ${TABLE}.product ;;
  }

  dimension: invoice_type {
    sql: ${TABLE}.invoice_type ;;
  }

  dimension: invoice_amount {
    type: number
    value_format_name: usd
    sql: ${TABLE}.invoice_amount ;;
  }

  dimension: invoice_id {
    type: number
    sql: ${TABLE}.invoice_id ;;
  }

  dimension: barcode {
    sql: ${TABLE}.barcode ;;
  }

  dimension: completed_on {
    type: date
    sql: ${TABLE}.completed_on ;;
  }

  dimension: network_status {
    sql: ${TABLE}.network_status ;;
  }
}
