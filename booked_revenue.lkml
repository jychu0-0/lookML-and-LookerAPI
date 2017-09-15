#at the revenue-level
view: booked_revenue {
  derived_table: {
    sql: SELECT
        order_id
        , barcode
        , revenue_type
        , rev_rec_date
        , revenue
        , order_id::text || barcode::text || rev_rec_date::text || revenue_type || revenue::text AS pkey -- check to see if this is unique
      FROM
        uploads.barcoderevenue
       ;;
    sql_trigger_value: select sum(revenue) from uploads.barcoderevenue ;;
    indexes: ["order_id", "rev_rec_date"]
  }

  dimension: order_id {
    hidden: yes
    type: number
    sql: ${TABLE}.order_id ;;
  }

  dimension: barcode {
    hidden: yes
    sql: ${TABLE}.barcode ;;
  }

  dimension: revenue_type {
    description: "The type of revenue determined by the revenue accounting team"
    sql: ${TABLE}.revenue_type ;;
  }

  dimension: booked_aggregate_type {
    description: "Disaggregating by Recurring and non-Recurring revenue types"
    sql: CASE
          WHEN ${TABLE}.revenue_type IN ('PP True-Up','Medicare Adj','Kaiser ADJ','IPS Microdeletions Adjustment','Insight Adjustment','INN Payer True-Up','INN Patient True-Up','Additional Direct Bill') THEN ${TABLE}.revenue_type
          WHEN ${TABLE}.revenue_type IS NULL THEN NULL
          ELSE 'Recurring Revenue' END ;;
  }

  dimension_group: rev_rec_date {
    type: time
    description: "Date at which revenue was recognized. DO NOT result both Rev Rec Date and Completed Date to avoid fanning/duplicating lines."
    timeframes: [quarter, date, week, month, year]
    sql: ${TABLE}.rev_rec_date ;;
  }

  measure: revenue_count {
    hidden: yes
    label: "# Revenue Transaction Count"
    type: count_distinct
    sql: ${TABLE}.pkey ;;
  }

  dimension: revenue {
    description: "The booked revenue dollar amount associated with each order"
    type: number
    value_format_name: usd
    sql: ${TABLE}.revenue ;;
  }

  measure: total_revenue {
    label: "$ Total Booked Revenue"
    description: "The total booked dollar amount. The sum of the booked insurance, customer, and physician revenue on orders."
    value_format_name: usd
    type: sum
    sql: ${revenue} ;;
  }

  measure: average_revenue {
    hidden: yes
    label: "$ Average Booked Revenue"
    description: "The average booked dollar amount. The average of combined booked insurance, customer, and physician revenue amounts on an order."
    value_format_name: usd
    sql: ${revenue} ;;
  }
}

#at the revenue-level
view: booked_revenue_order_level {
  derived_table: {
    sql: SELECT
      o.id AS order_id
      , o.latest_barcode AS barcode
      , o.bill_type_label AS bill_type
      , insurance_payer_revenue
      , insurance_payer_trueup
      , insurance_customer_revenue
      , insurance_customer_trueup
      , pp_trueup
      , physician_revenue
      , self_pay_revenue
      , trueups
      , reoccurring_revenue
      , revenue_adjustments
      , revenue AS booked_revenue
      FROM ${order.SQL_TABLE_NAME} as o
      LEFT JOIN
        (SELECT
          order_id
          , barcode
          , SUM(CASE
                WHEN revenue_type = 'INN Insurance Revenue'
                OR revenue_type = 'OON Insurance Revenue'
                OR revenue_type = 'Cash OON Insurance'
                OR revenue_type = 'Insurer Non-Payment'
                OR revenue_type = 'IPS Microdeletions Adjustment'
                  THEN revenue ELSE null END) AS insurance_payer_revenue
          , SUM(CASE
                WHEN revenue_type = 'INN Payer True-Up'
                OR revenue_type = 'OON Payer True-Up'
                  THEN revenue ELSE null END) as insurance_payer_trueup
          , SUM(CASE
                  WHEN revenue_type = 'INN MOOP Customer Revenue'
                  OR revenue_type = 'OON MOOP Customer Revenue'
                  OR revenue_type = 'INN Invoice Flux'
                  OR revenue_type = 'OON Invoice Flux'
                  OR revenue_type = 'INN Customer Revenue'
                  OR revenue_type = 'OON Customer Revenue'
                  OR revenue_type = 'Cash OON Customer'
                    THEN revenue ELSE null END) AS insurance_customer_revenue
          , SUM(CASE
                WHEN revenue_type = 'INN Patient True-Up'
                OR revenue_type = 'OON Patient True-Up'
                  THEN revenue ELSE null END) AS insurance_customer_trueup
          , SUM(CASE
                WHEN revenue_type = 'PP True-Up'
                  THEN revenue ELSE null END) AS pp_trueup
          , SUM(CASE
                WHEN revenue_type = 'Cash Credit Card Customer'
                OR revenue_type = 'Credit Card Customer Revenue' THEN revenue ELSE null END) AS self_pay_revenue
          , SUM(CASE
                WHEN revenue_type = 'Consignment Comp'
                  OR revenue_type = 'Consignment'
                  OR revenue_type = 'JScreen Consignment'
                  OR revenue_type = 'Additional Direct Bill'
                  OR revenue_type = 'Enzo Recurring Revenue Adjustment'
                  OR revenue_type = 'Insight Adjustment'
                    THEN revenue ELSE null END) AS physician_revenue
          , SUM(CASE
                WHEN revenue_type = 'INN Patient True-Up'
                OR revenue_type = 'OON Patient True-Up'
                OR revenue_type = 'INN Payer True-Up'
                OR revenue_type = 'OON Payer True-Up'
                OR revenue_type = 'PP True-Up'
                  THEN revenue ELSE null END) AS trueups
          , SUM(CASE
                WHEN revenue_type = 'INN Insurance Revenue'
                OR revenue_type = 'OON Insurance Revenue'
                OR revenue_type = 'Cash OON Insurance'
                OR revenue_type = 'INN MOOP Customer Revenue'
                OR revenue_type = 'OON MOOP Customer Revenue'
                OR revenue_type = 'INN Invoice Flux'
                OR revenue_type = 'OON Invoice Flux'
                OR revenue_type = 'INN Customer Revenue'
                OR revenue_type = 'OON Customer Revenue'
                OR revenue_type = 'Cash OON Customer'
                OR revenue_type = 'Cash Credit Card Customer'
                OR revenue_type = 'Credit Card Customer Revenue'
                OR revenue_type = 'Consignment Comp'
                OR revenue_type = 'Consignment'
                OR revenue_type = 'JScreen Consignment'
                OR revenue_type = 'Insurer Non-Payment'
                  THEN revenue ELSE null END) AS reoccurring_revenue
          , SUM(CASE
            WHEN revenue_type = 'Additional Direct Bill'
            OR revenue_type = 'Enzo Recurring Revenue Adjustment'
            OR revenue_type = 'Insight Adjustment'
            OR revenue_type = 'IPS Microdeletions Adjustment'
              THEN revenue ELSE null END) as revenue_adjustments



          -- may be worth making individual fields summing each revenue type if you want to be able determine contribution from different types

          , SUM(revenue) AS revenue

        FROM
          ${booked_revenue.SQL_TABLE_NAME} AS booked_revenue
        GROUP BY 1,2) as sub on sub.order_id = o.id
      GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14
       ;;
    sql_trigger_value: select sum(revenue) from uploads.barcoderevenue ;;
    indexes: ["order_id", "booked_revenue"]
  }

  dimension: order_id {
    hidden: yes
    primary_key: yes
    type: number
    sql: ${TABLE}.order_id ;;
  }

  dimension: barcode {
    hidden: yes
    sql: ${TABLE}.barcode ;;
  }

  dimension: bill_type {
    hidden: yes
    type: string
    sql: ${TABLE}.bill_type ;;
  }

  dimension: booked_revenue {
    hidden: yes
    description: "The booked revenue dollar amount associated with each order"
    type: number
    value_format_name: usd
    sql: ${TABLE}.booked_revenue ;;
  }

  measure: total_revenue {
    group_label: "Totals"
    label: "$ Total Booked Revenue"
    description: "The  total booked dollar amount. The sum of the booked insurance, customer, and physician revenue + trueps and adjustments on orders."
    value_format_name: usd
    type: sum
    sql: ${booked_revenue} ;;
  }

  measure: average_revenue {
    group_label: "Totals"
    label: "$ Average Booked Revenue"
    description: "The average booked dollar amount. The average of combined booked insurance, customer, and physician revenue amounts on an order."
    value_format_name: usd
    type: number
    sql: ${total_revenue} / COUNT(${order_id}) ;;
  }

  ## made these to match up with "Expected Revenue" fields-- for users who are less accounting-saavy

  dimension: insurance_customer_revenue {
    hidden: yes
    description: "The dollar amount in revenue attributed to insurance customers that was booked by acccounting, i.e. - In-Network accrued customer revenue, OON accrued customer revenue, OON cash-basis customer payments, MOOP revenue, and invoice flux"
    type: number
    sql: ${TABLE}.insurance_customer_revenue ;;
  }

  dimension: insurance_customer_trueup {
    hidden: yes
    description: "The dollar amount in revenue attributed to insurance customer true-ups that was booked by acccounting, i.e. - In-Network customer trueup and OON customer trueup"
    type: number
    sql: ${TABLE}.insurance_customer_trueup ;;
  }

  dimension: insurance_payer_revenue {
    hidden: yes
    description: "The dollar amount in revenue attributed to insurance payers that was booked by acccounting, i.e. In-Network accrued revenue, OON accrued revenue, OON cash-basis payments, and non-payments"
    type: number
    sql: ${TABLE}.insurance_payer_revenue ;;
  }

  dimension: insurance_payer_trueup {
    hidden: yes
    description: "The dollar amount in revenue attributed to insurance payer true-ups that was booked by acccounting, i.e. In-Network payer trueup and OON payer trueup"
    type: number
    sql: ${TABLE}.insurance_payer_trueup ;;
  }

  dimension: physician_revenue {
    hidden: yes
    description: "The dollar amount in revenue attributed to physican/consignment orders that was booked by acccounting, i.e. - consignment revenue, consighment comps (-), and JScreen revenue"
    type: number
    sql: ${TABLE}.physician_revenue ;;
  }

  dimension: self_pay_revenue {
    hidden: yes
    description: "The dollar amount in revenue attributed to credit card/self-pay orders that was booked by acccounting, i.e. - Credit card revenue"
    type: number
    sql: ${TABLE}.self_pay_revenue ;;
  }

  dimension: pp_trueup {
    hidden: yes
    description: "The dollar amount in revenue attributed to pp trueups that was booked by accounting"
    type: number
    sql: ${TABLE}.pp_trueup ;;
  }

  dimension: trueups {
    hidden: yes
    description: "The dollar amount in revenue attributed to both payer and customer insurance trueups that was booked by acccounting, i.e. - In-Network payer trueup, OON payer trueup, In-Network customer trueup, and OON customer trueup"
    type: number
    sql: ${TABLE}.trueups ;;
  }


  dimension: reoccurring_revenue {
    hidden: yes
    description: "The dollar amount in revenue attributed to reoccurring revenue that was booked by acccounting, i.e. - In-Network accrued revenue, OON accrued revenue, OON cash-basis payments, non-payments, In-Network accrued customer revenue, OON accrued customer revenue, OON cash-basis customer payments, MOOP revenue, invoice flux, consignment revenue, consighment comps (-), JScreen revenue and credit card revenue"
    type: number
    sql: ${TABLE}.reoccurring_revenue ;;
  }

  dimension: revenue_adjustments {
    hidden: yes
    description: "The dollar amount in revenue attributed to Adjustments"
    type: number
    sql: ${TABLE}.revenue_adjustments ;;
  }

  ## Totals

  measure: total_insurance_customer_revenue {
    group_label: "Sub-Totals B"     hidden: yes
    label: "$ Total Booked Insurance Customer Revenue"
    description: "The total dollar amount in revenue attributed to insurance customers that was booked by acccounting, i.e. - In-Network accrued customer revenue, OON accrued customer revenue, OON cash-basis customer payments, MOOP revenue, and invoice flux"
    value_format_name: usd
    type: sum
    sql: ${insurance_customer_revenue} ;;
  }

  measure: total_insurance_payer_revenue {
    group_label: "Sub-Totals B"     hidden: yes
    hidden: yes
    label: "$ Total Booked Insurance Payer Revenue"
    description: "The total dollar amount in revenue attributed to insurance payers that was booked by acccounting, i.e. In-Network accrued revenue, OON accrued revenue, OON cash-basis payments, and non-payments"
    value_format_name: usd
    type: sum
    sql: ${insurance_payer_revenue} ;;
  }

  measure: total_physician_revenue {
    group_label: "Sub-Totals B"     hidden: yes     hidden: yes
    description: "The total dollar amount in revenue attributed to physician/consignment orders that was booked by acccounting, i.e. - consignment payments, consighment comps (-), and JScreen payments"
    label: "$ Total Booked Physician Revenue"
    value_format_name: usd
    type: sum
    sql: ${physician_revenue} ;;
  }

  measure: total_insurance_customer_trueup {
    group_label: "Sub-Totals B"     hidden: yes     hidden: yes
    label: "$ Total Booked Insurance Customer True-Up"
    description: "The total dollar amount in revenue attributed to patient/customer true-ups that was booked by acccounting, i.e. -  difference between accruals and actual cash collection"
    value_format_name: usd
    type: sum
    sql: ${insurance_customer_trueup} ;;
  }

  measure: total_insurance_payer_trueup {
    group_label: "Sub-Totals B"     hidden: yes
    label: "$ Total Booked Insurance True-Up"
    description: "The total dollar amount in revenue attributed to insurance true-ups that was booked by acccounting, i.e. - difference between accruals and actual cash collection"
    value_format_name: usd
    type: sum
    sql: ${insurance_payer_trueup} ;;
  }

  measure: total_pp_trueup {
    group_label: "Sub-Totals B"     hidden: yes
    label: "$ Total Booked Prior Period True-Up"
    description: "The total dollar amount in revenue attributed to pp true-ups that was booked by acccounting"
    value_format_name: usd
    type: sum
    sql: ${pp_trueup} ;;
  }


  measure: total_self_pay_revenue {
    group_label: "Sub-Totals B"     hidden: yes
    label: "$ Total Booked Self-Pay"
    description: "The total dollar aamount in revenue attributed to credit card/self-pay orders that was booked by acccounting, i.e. - Credit card revenue"
    value_format_name: usd
    type: sum
    sql: ${self_pay_revenue} ;;
  }

  measure: total_trueup {
    group_label: "Sub-Totals A"     hidden: yes
    label: "$ Total Booked True-Up"
    description: "The total dollar amount in revenue attributed to both customer, insurance and pp true-ups that was booked by acccounting, i.e. - difference between accruals and actual cash collection"
    value_format_name: usd
    type: sum
    sql: ${trueups} ;;
  }


  measure: total_reoccurring_revenue {
    group_label: "Sub-Totals A"     hidden: yes
    label: "$ Total Booked Reoccurring Revenue"
    description: "The total dollar amount in revenue attributed to reoccurring revenue that was booked by acccounting, i.e. - In-Network accrued revenue, OON accrued revenue, OON cash-basis payments, non-payments, In-Network accrued customer revenue, OON accrued customer revenue, OON cash-basis customer payments, MOOP revenue, invoice flux, consignment revenue, consighment comps (-), JScreen revenue and credit card revenue"
    value_format_name: usd
    type: sum
    sql: ${reoccurring_revenue} ;;
  }

  measure: total_revenue_adjustments {
    group_label: "Sub-Totals A"     hidden: yes
    label: "$ Total Booked Revenue Adjustments"
    description: "The total dollar amount in revenue attributed to Adjustments, i.e. Additional Direct Bill, Enzo Recurring Revenue Adjustment, Insight Adjustment, IPS Microdeletions Adjustment"
    value_format_name: usd
    type: sum
    sql: ${revenue_adjustments} ;;
  }

  ## Averages

  measure: average_insurance_customer_revenue {
    group_label: "Sub-Totals B"     hidden: yes
    label: "$ Average Booked Insurance Customer Revenue"
    description: "The average dollar amount in revenue attributed to insurance customers that was booked by acccounting, i.e. - In-Network accrued revenue, OON accrued revenue, OON cash-basis payments, MOOP payments, credit card payments, and invoice flux"
    value_format_name: usd
    type: number
    sql: ${total_insurance_customer_revenue} / SUM(CASE WHEN ${bill_type} = 'Insurance' THEN 1 ELSE NULL END) ;;
  }

  measure: average_insurance_payer_revenue {
    group_label: "Sub-Totals B"     hidden: yes
    label: "$ Average Booked Insurance Payer Revenue"
    description: "The average dollar amount in revenue attributed to insurance payers that was booked by acccounting, i.e. In-Network accrued revenue, OON accrued revenue, OON cash-basis payments, and non-payment cash"
    value_format_name: usd
    type: number
    sql: ${total_insurance_payer_revenue} / SUM(CASE WHEN ${bill_type} = 'Insurance' THEN 1 ELSE NULL END) ;;
  }

  measure: average_physician_revenue {
    group_label: "Sub-Totals B"     hidden: yes
    description: "The average dollar amount in revenue attributed to physician/consignment orders that was booked by acccounting, i.e. - consignment payments, consighment comps (-), and JScreen payments"
    label: "$ Average Booked Physician Revenue"
    value_format_name: usd
    type: number
    sql: ${total_physician_revenue} / SUM(CASE WHEN ${bill_type} = 'Consignment' THEN 1 ELSE NULL END) ;;
  }

  measure: average_insurance_customer_trueup {
    group_label: "Sub-Totals B"     hidden: yes
    label: "$ Average Booked Customer True-Up"
    description: "The average dollar amount in revenue attributed to patient/customer true-ups that was booked by acccounting, i.e. -  difference between accruals and actual cash collection"
    value_format_name: usd
    type: number
    sql: ${total_insurance_customer_trueup} / SUM(CASE WHEN ${bill_type} = 'Insurance' THEN 1 ELSE NULL END) ;;
  }

  measure: average_insurance_payer_trueup {
    group_label: "Sub-Totals B"     hidden: yes
    label: "$ Average Booked Insurance True-Up"
    description: "The average dollar amount in revenue attributed to insurance true-ups that was booked by acccounting, i.e. - difference between accruals and actual cash collection"
    value_format_name: usd
    type: number
    sql: ${total_insurance_payer_trueup} / SUM(CASE WHEN ${bill_type} = 'Insurance' THEN 1 ELSE NULL END) ;;
  }
  measure: average_pp_trueup {
    group_label: "Sub-Totals B"     hidden: yes
    label: "$ Average Booked Prior Period True-Up"
    description: "The average dollar amount in revenue attributed to pp true-ups that was booked by acccounting"
    value_format_name: usd
    type: number
    sql: ${total_pp_trueup} / SUM(CASE WHEN ${bill_type} = 'Insurance' THEN 1 ELSE NULL END) ;;
  }

  measure: average_self_pay_revenue {
    group_label: "Sub-Totals B"     hidden: yes
    label: "$ Average Booked Self-Pay"
    description: "The average dollar aamount in revenue attributed to credit card/self-pay orders that was booked by acccounting, i.e. - Credit card revenue"
    value_format_name: usd
    type: number
    sql: ${total_self_pay_revenue} / SUM(CASE WHEN ${bill_type} = 'Self Pay' THEN 1 ELSE NULL END) ;;
  }

  measure: average_trueup {
    group_label: "Sub-Totals A"     hidden: yes
    label: "$ Average Total Booked True-Up"
    description: "The average dollar amount in revenue attributed to both customer and insurance true-ups that was booked by acccounting, i.e. - difference between accruals and actual cash collection"
    value_format_name: usd
    type: number
    sql: ${total_trueup} / SUM(CASE WHEN ${bill_type} = 'Insurance' THEN 1 ELSE NULL END) ;;
  }


  measure: average_reoccurring_revenue {
    group_label: "Sub-Totals A"     hidden: yes
    label: "$ Average Total Booked Reoccurring Revenue"
    description: "The average dollar amount in revenue attributed to reoccurring revenue that was booked by acccounting, i.e. - In-Network accrued revenue, OON accrued revenue, OON cash-basis payments, non-payments, In-Network accrued customer revenue, OON accrued customer revenue, OON cash-basis customer payments, MOOP revenue, invoice flux, consignment revenue, consighment comps (-), JScreen revenue and credit card revenue"
    value_format_name: usd
    type: number
    sql: ${total_reoccurring_revenue} / COUNT(${order_id}) ;;
  }

  measure: average_revenue_adjustments {
    group_label: "Sub-Totals A"     hidden: yes
    label: "$ Average Total Booked Revenue Adjustments"
    description: "The average dollar amount in revenue attributed to reoccurring revenue that was booked by acccounting, i.e. - In-Network accrued revenue, OON accrued revenue, OON cash-basis payments, non-payments, In-Network accrued customer revenue, OON accrued customer revenue, OON cash-basis customer payments, MOOP revenue, invoice flux, consignment revenue, consighment comps (-), JScreen revenue and credit card revenue"
    value_format_name: usd
    type: number
    sql: ${total_revenue_adjustments} / COUNT(${order_id}) ;;
  }
}
