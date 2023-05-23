view: pricingestimateaccruals {
  derived_table: {
    sql: WITH cash_or_insurance as (
        SELECT
          o.id,
          case when o.bill_type != 'in' then 'Not Bill Type Insurance'
               WHEN ic.status_name in ('Canceled Chose Cash', 'Maximum OOP - No Insurance', 'Invoiced - Cash (Bad Info)') then 'Cash'
               WHEN ic.status_name is not null then 'Insurance'
               end as cash_or_insurance
            FROM
              current.order o
            LEFT JOIN
              current.insuranceclaim ic
              on o.id = ic.order_id
           )


      SELECT
        o.id as order_id,
        o.completed_on as order_completed_month,
        o.product,
        cash_or_insurance,
        CASE WHEN cash_or_insurance = 'Insurance'
            THEN estimated_allowed_amount - (estimated_coinsurance + estimated_copayment + estimated_deductible) ELSE NULL END as total_estimated_payer_paid_amount,
        CASE WHEN cash_or_insurance = 'Insurance'
          THEN (estimated_coinsurance + estimated_copayment + estimated_deductible) ELSE NULL END as estimated_real_patient_responsibility,
        CASE WHEN cash_or_insurance = 'Insurance'
          THEN
            CASE
              WHEN
                product in ('Foresight Carrier Screen', 'Prelude Prenatal Screen')
                THEN (estimated_coinsurance + estimated_copayment + estimated_deductible) * .55 --Collection rate
              WHEN
                product = 'Reliant Cancer Screen'
                THEN (estimated_coinsurance + estimated_copayment + estimated_deductible) * .55 * .5
                END ELSE NULL END as haircut_patient_responsibility,
      CASE WHEN cash_or_insurance = 'Cash'
        THEN
          CASE
            WHEN
              product = 'Foresight Carrier Screen' then 349 * .68
            WHEN
              product = 'Prelude Prenatal Screen' then 349 * .63
            WHEN
              product = 'Reliant Cancer Screen' then 349 * .57
          END ELSE NULL END as estimated_cash_payment_received
      FROM
        current.order o
      LEFT JOIN
        current.insuranceclaim ic
        on o.id = ic.order_id
      LEFT JOIN
        current.pricingestimate pe
        on ic.id = pe.claim_id AND pe.is_current = 'True'
      LEFT JOIN
        cash_or_insurance coi
        on o.id = coi.id
       ;;
  }


  dimension: order_id {
    label: "Order ID"
    type: number
    sql: ${TABLE}.order_id ;;
  }
  dimension_group: order_completed_date {
    label: "Order Completed Date"
    type: time
    timeframes: [date, week, month, quarter, year]
    sql: ${TABLE}.order_completed_month ;;
  }

  dimension: product {
    label: "Counsyl Product"
    type: string
    sql: ${TABLE}.product ;;
  }

  dimension: cash_or_insurance {
    label: "Order paid through insurance or in cash"
    type: string
    sql: ${TABLE}.cash_or_insurance ;;
  }

  measure: total_estimated_payer_paid_amount {
    label: "Total estimated payer paid amount"
    value_format_name: usd
    type: sum
    sql: ${TABLE}.total_estimated_payer_paid_amount ;;
  }

  measure: estimated_real_patient_responsibility {
    label: "Total estimated patient responsibility"
    value_format_name: usd
    type: sum
    sql: ${TABLE}.estimated_real_patient_responsibility ;;
  }

  measure: haircut_patient_responsibility {
    label: "Total estimated patient paid after haircut"
    value_format_name: usd
    type: sum
    sql: ${TABLE}.haircut_patient_responsibility ;;
  }

  measure: estimated_cash_payment_received {
    label: "Total estimated cash received for cash pay"
    value_format_name: usd
    type: sum
    sql: ${TABLE}.estimated_cash_payment_received ;;
  }

  measure: revenue_estimated {
    label: "Total estimated revenue for order"
    value_format_name: usd
    type: sum
    sql: coalesce(${TABLE}.estimated_cash_payment_received, 0) + coalesce(${TABLE}.haircut_patient_responsibility, 0) + coalesce(${TABLE}.total_estimated_payer_paid_amount, 0);;
  }
  }
