view: finance_historical_patient_payments {
  derived_table: {
    sql:
      WITH cte as (SELECT
        claim.id
        , coalesce(actual_co_insurance + actual_co_payment + actual_deductible) as real_patient_responsibility
        , invoice.amount invoice_amount
        , invoice.timestamp invoice_date
        , CASE WHEN invoice.amount > 1000 THEN invoice.amount * .37              -- numbers from 2016 historicals for claims with $0 OPR
               WHEN invoice.amount > 500 THEN invoice.amount * .48               -- numbers from 2016 historicals for claims with $0 OPR
               WHEN invoice.amount > 350 THEN invoice.amount * .60               -- numbers from 2016 historicals for claims with $0 OPR
               WHEN invoice.amount > 100 THEN invoice.amount * .75               -- numbers from 2016 historicals for claims with $0 OPR
               ELSE invoice.amount * .90 END as expected_payment_without_comp
        , sum(payment.amount) filter (where transaction_id = 'DISCOUNTCOMP_HONOR') honor_comp_amount
        , sum(payment.amount) filter (where transaction_id = 'DISCOUNTCOMP_OPR') opr_comp_amount
        , coalesce(sum(payment.amount) filter (where payment_method in ('chck','cc','et')),0) payment_amount
        , coalesce(sum(payment.amount) filter (where payment.timestamp < invoice.timestamp + '30 days' and payment_method in ('cc','chck','et')),0) payment_within_30_days
        , coalesce(sum(payment.amount) filter (where payment.timestamp < invoice.timestamp + '60 days' and payment_method in ('cc','chck','et')),0) payment_within_60_days
        , coalesce(sum(payment.amount) filter (where payment.timestamp < invoice.timestamp + '90 days' and payment_method in ('cc','chck','et')),0) payment_within_90_days
      FROM
        current.insuranceclaim claim
      INNER JOIN
        current.invoice on invoice.id = claim.patient_invoice_id
      LEFT JOIN
        ${payment.SQL_TABLE_NAME} as payment on payment.invoice_id = invoice.id

      WHERE
        actual_deductible is not null

      GROUP BY 1,2,3,4 order by 7 desc)

      SELECT *, invoice_amount - coalesce(honor_comp_amount,0) invoice_net_honor_comps from cte where real_patient_responsibility = invoice_amount
      ;;
    persist_for: "24 hours"
  }
  dimension: claim_id {
    type: number
    primary_key: yes
    sql: ${TABLE}.id ;;
  }
  dimension: real_patient_responsibility {
    hidden: yes
    type: number
    value_format_name: usd
    sql: ${TABLE}.real_patient_responsibility ;;
  }
  dimension: patient_invoice_amount {
    hidden: yes
    type: number
    value_format_name: usd
    sql: ${TABLE}.invoice_amount ;;
  }
  dimension: invoice_bins {
    type: tier
    tiers: [100,350,500,1000]
    sql: ${patient_invoice_amount} ;;
  }
  dimension_group: patient_invoice_date {
    type: time
    timeframes: [date,month,quarter,year]
    sql: ${TABLE}.invoice_date ;;
  }
  dimension: has_honor_comp {
    type: yesno
    sql: ${TABLE}.honor_comp_amount > 0 ;;
  }
  dimension: honor_comp_amount {
    hidden: yes
    type: number
    value_format_name: usd
    sql: ${TABLE}.honor_comp_amount ;;
  }
  dimension: patient_payment_amount {
    hidden: yes
    type: number
    value_format_name: usd
    sql: ${TABLE}.payment_amount ;;
  }
  dimension: percent_of_payment_within_30_days {
    hidden: yes
    type: number
    value_format_name: percent_1
    sql: ${TABLE}.payment_within_30_days * 1.0 / nullif(${patient_payment_amount},0);;
  }
  dimension: percent_of_payment_within_60_days {
    type: number
    hidden: yes
    value_format_name: percent_1
    sql: ${TABLE}.payment_within_60_days * 1.0 / nullif(${patient_payment_amount},0);;
  }
  dimension: percent_of_payment_within_90_days {
    type: number
    hidden: yes
    value_format_name: percent_1
    sql: ${TABLE}.payment_within_90_days * 1.0 / nullif(${patient_payment_amount},0);;
  }
  measure: average_patient_payment_amount {
    label: "$ Average Patient Payment Amount"
    description: "Average patient payment amount"
    type: average
    sql: ${patient_payment_amount} ;;
  }
  measure: average_payment_percent_within_30_days {
    label: "% Average Payment Percent Within 30 days"
    description: "Average amount of customer invoices paid within 30 days from the invoice date"
    type: average
    sql: ${percent_of_payment_within_30_days} ;;
  }
  measure: average_payment_within_30_days {
    label: "$ Average Payment Within 30 days"
    description: "Average payment amount on customer invoices within 30 days from invoice date"
    type: average
    sql: ${TABLE}.payment_within_30_days ;;
  }
  measure: average_payment_within_60_days {
    label: "$ Average Payment Within 60 days"
    description: "Average payment amount on customer invoices within 60 days from invoice date"
    type: average
    sql: ${TABLE}.payment_within_60_days ;;
  }
  measure: average_payment_within_90_days {
    label: "$ Average Payment Within 90 days"
    description: "Average payment amount on customer invoices within 90 days from invoice date"
    type: average
    sql: ${TABLE}.payment_within_90_days ;;
  }
  measure: average_payment_percent_within_60_days {
    label: "% Average Payment Percent Within 60 days"
    description: "Average amount of customer invoices paid within 60 days from the invoice date"
    type: average
    sql: ${percent_of_payment_within_60_days} ;;
  }
  measure: average_payment_percent_within_90_days {
    label: "% Average Payment Percent Within 90 days"
    description: "Average amount of customer invoices paid within 90 days from the invoice date"
    type: average
    sql: ${percent_of_payment_within_90_days} ;;
  }
  measure: average_payment_percent {
    label: "% Average Payment Percent"
    description: "Average percent paid on an invoice"
    type: average
    sql: ${patient_payment_amount}/nullif(${patient_invoice_amount},0) ;;
  }
  measure: total_expected_payment_without_comp {
    label: "$ Total Expected Payment If Estimate Was Not Honored"
    description: "Total expected payment on a customer invoice if their underestimate had not been honored"
    type: sum
    value_format_name: usd
    sql: CASE WHEN coalesce(${honor_comp_amount},0) > 0 THEN ${TABLE}.expected_payment_without_comp ELSE 0 END;;
  }
  measure: total_patient_payment_amount {
    label: "$ Total Patient Payment Amount When Estimate Honored"
    description: "Total paid amount on customer invoices where the underestimate was honored"
    type: sum
    value_format_name: usd
    sql: CASE WHEN coalesce(${honor_comp_amount},0) > 0 THEN
              CASE WHEN (current_date - ${patient_invoice_date_date} > 90) and (current_date - ${patient_invoice_date_date} < 120) THEN ${patient_payment_amount} * 1.08
                   WHEN current_date - ${patient_invoice_date_date} > 60 THEN ${patient_payment_amount} * 1.15
                   WHEN current_date - ${patient_invoice_date_date} > 30 THEN ${patient_payment_amount} * 1.4
                   ELSE ${patient_payment_amount} END
            ELSE 0 END;;
    # Hard-coded values computed from 2016 historicals of customer invoice payments over time
  }
  measure: total_invoice_net_honor_comps {
    label: "$ Total Invoice Net Honor Comps"
    description: "Total customer invoice amounts after honor underestimate comps"
    type: sum
    value_format_name: usd
    sql: CASE WHEN ${honor_comp_amount} > 0 THEN ${TABLE}.invoice_net_honor_comps ELSE 0 END ;;
  }
  measure: total_original_invoice_amount {
    label: "$ Total Original Patient Invoice Amount"
    description: "Total amount of customer invoice amounts"
    type: sum
    value_format_name: usd
    sql: CASE WHEN ${honor_comp_amount} > 0 THEN ${TABLE}.invoice_amount ELSE 0 END;;
  }
  measure: total_honor_comps {
    label: "$ Total Honor Comps"
    description: "Total value of honor underestimate comps"
    type: sum
    value_format_name: usd
    sql: ${honor_comp_amount} ;;
  }
  measure: patient_count {
    label: "# Claim Count with Honor Discount"
    description: "Patient Count with Honor Discount"
    type: count_distinct
    sql: ${claim_id} ;;
  }
}
