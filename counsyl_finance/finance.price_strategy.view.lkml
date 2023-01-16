view: finance_price_strategy_metrics {
  derived_table: {
    sql:
      SELECT
        o.id as order_id
        , o.completed_on
        , CASE WHEN coalesce(fhpp.honor_comp_amount,0) > 0 THEN fhpp.expected_payment_without_comp ELSE 0 END -
          CASE WHEN coalesce(fhpp.honor_comp_amount,0) > 0 THEN
              CASE WHEN (current_date - (fhpp.invoice_date::date) > 90) and (current_date - (fhpp.invoice_date::date) < 120) THEN fhpp.payment_amount * 1.08
                   WHEN current_date - (fhpp.invoice_date::date) > 60 THEN fhpp.payment_amount * 1.15
                   WHEN current_date - (fhpp.invoice_date::date) > 30 THEN fhpp.payment_amount * 1.4
                   ELSE fhpp.payment_amount END
            ELSE 0 END AS cash_loss_due_to_honoring_underestimates
        , CASE WHEN (coalesce(final_estimated_payer_paid,0) - coalesce(first_estimated_payer_paid_after_complete,0) - (coalesce(final_estimated_payer_paid - actual_payer_paid_amount,0))) > 0
          THEN (coalesce(final_estimated_payer_paid,0) - coalesce(first_estimated_payer_paid_after_complete,0) - (coalesce(final_estimated_payer_paid - actual_payer_paid_amount,0))) ELSE 0 END * 0.50 as cash_pickup_from_delay
      FROM current.order o
      LEFT JOIN current.insuranceclaim claim on claim.order_id = o.id
      LEFT JOIN ${finance_historical_patient_payments.SQL_TABLE_NAME} fhpp on fhpp.id = claim.id
      LEFT JOIN ${claim_level_file_delay_metrics.SQL_TABLE_NAME} clfd on clfd.claim_id = claim.id
      WHERE {% condition product_filter %} o.product {% endcondition %}
      ;;
  }
  filter: product_filter {
    suggest_dimension: order.product_group

  }
  dimension: order_id {
    description: "Order ID"
    type: number
    primary_key: yes
    sql: ${TABLE}.order_id ;;
  }
  dimension: cash_loss_due_to_honoring_underestimates {
    description: "Cash lost due to honoring underestimates"
    type: number
    value_format_name: usd
    sql: ${TABLE}.cash_loss_due_to_honoring_underestimates * -1 ;;
  }
  dimension: cash_pickup_from_delay {
    description: "Cash gained from delaying claim filing"
    type: number
    value_format_name: usd
    sql: ${TABLE}.cash_pickup_from_delay ;;
  }
  dimension_group: completed {
    description: "Completed date of the orders"
    type: time
    timeframes: [date,week,month,quarter,year]
    sql: ${TABLE}.completed_on ;;
  }
  measure: total_cash_loss_from_honoring_underestimates {
    label: "$ Cash Loss from Honoring Estimates"
    description: "Total cash lost from honoring underestimates"
    type: sum
    value_format_name: usd
    sql: ${cash_loss_due_to_honoring_underestimates} ;;
  }
  measure: total_cash_pickup_from_delay {
    description: "Total cash gained from delaying claim filing"
    label: "$ Cash Pickup from Delay"
    type: sum
    value_format_name: usd
    sql: ${cash_pickup_from_delay} ;;
  }
  measure: order_count {
    description: "Count of Orders"
    type: count_distinct
    sql: ${order_id} ;;
  }

}

# Delete this file for freeze
