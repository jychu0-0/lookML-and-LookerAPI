view: patient_collections {
  derived_table: {
    sql:
        SELECT
          invoice.id
          ,invoice.type
          ,invoice.patient_invoice_amount as patient_invoice_amount
          ,invoice.patient_invoice_amount_net_opr_and_honor_comps
          ,invoice.timestamp
          ,invoice.moop_comps
          , CASE WHEN coalesce(opr_comp_amount,0) + coalesce(honor_estimate_amount,0) > 0 THEN TRUE ELSE FALSE END has_opr_honor_comp
          ,SUM(CASE WHEN payment.payment_method = 'comp' THEN 0 ELSE payment.transaction_amount END) AS invoice_level_total_payment
          ,SUM(CASE WHEN payment.payment_method = 'comp' THEN payment.transaction_amount ELSE 0 END) AS comp_amount
          ,SUM(CASE WHEN payment.payment_method = 'comp' THEN 0
                    WHEN date(payment.payment_date) - date(invoice.timestamp) <= 30 THEN payment.transaction_amount ELSE 0 END) payment_within_30
          ,SUM(CASE WHEN payment.payment_method = 'comp' THEN 0
                    WHEN date(payment.payment_date) - date(invoice.timestamp) <= 60 THEN payment.transaction_amount ELSE 0 END) payment_within_60
          ,SUM(CASE WHEN payment.payment_method = 'comp' THEN 0
                    WHEN date(payment.payment_date) - date(invoice.timestamp) <= 90 THEN payment.transaction_amount ELSE 0 END) payment_within_90
          ,SUM(CASE WHEN payment.payment_method = 'comp' THEN 0
                    WHEN date(payment.payment_date) - date(invoice.timestamp) <= 120 THEN payment.transaction_amount ELSE 0 END) payment_within_120
        FROM ${invoice.SQL_TABLE_NAME} AS invoice
        LEFT JOIN
          (SELECT * FROM ${revenue_all_matched_transactions.SQL_TABLE_NAME} pmt WHERE CASE WHEN pmt.description = 'hra eob' THEN pmt.transaction_amount > 0 ELSE 1=1 END) AS payment ON payment.invoice_id = invoice.id
        WHERE (payment.invoice_type = 'Customer' OR payment.invoice_type is null)
        GROUP BY 1,2,3,4,5,6,7

       ;;
    sql_trigger_value: select count(bank_pkey) from ${revenue_matched_bank_pkeys.SQL_TABLE_NAME} ;;
    indexes: ["id", "timestamp"]
  }

  #DIMENSIONS


  dimension: invoice_id {
    hidden: yes
    primary_key: yes
    sql: ${TABLE}.id ;;
  }

  dimension: invoice_type {
    hidden: yes
    sql: ${TABLE}.type ;;
  }

  dimension: patient_invoice_amount {
    hidden: yes
    type: number
    value_format_name: usd
    sql: ${TABLE}.patient_invoice_amount ;;
  }

  dimension: timestamp {
    hidden: yes
    sql: ${TABLE}.timestamp ;;
  }

  dimension: has_opr_honor_comp {
    type: yesno
    sql: ${TABLE}.has_opr_honor_comp ;;
  }
  dimension: moop_comps {
    hidden: yes
    value_format_name: usd
    sql: ${TABLE}.moop_comps ;;
  }

  measure: total_moop_comps {
    label: "$ Total MOOP Comps"
    type: sum
    sql: ${TABLE}.moop_comps ;;
  }

  dimension: comp_amount {
    sql: ${TABLE}.comp_amount ;;
  }

  dimension: invoice_level_total_payment {
    hidden: no
    type: number
    value_format_name: usd
    sql: ${TABLE}.invoice_level_total_payment ;;
  }

  dimension: outstanding_amount {
    #hidden: yes
    label: "Outstanding Amount"
    description: "The dollar amount that has been invoiced and not collected (net of comps)"
    type: number
    value_format_name: usd
    sql: ${patient_invoice_amount} - coalesce(${invoice_level_total_payment},0) - coalesce(${comp_amount},0);;
  }

  dimension: inv_amt_tier {
    alias: [patient_inv_amt_tier]
    label: "Invoice Tier (Pre-MOOP Period)"
    description: "The tiers/buckets of dollar amounts invoiced net of comps"
    sql: CASE WHEN ${patient_invoice_amount} >= 750 THEN '$750+'
        WHEN ${patient_invoice_amount} >= 500 THEN '$500 - $749'
        WHEN ${patient_invoice_amount} >= 349 THEN '$350 - $499'
        WHEN ${patient_invoice_amount} > 0 THEN '$1 - $349'
        WHEN ${patient_invoice_amount} = 0 THEN '$0'
        ELSE 'No Invoice Yet' END
       ;;
  }

  # MEASURES





  measure: total_collected_amount {
    label: "$ Total Collected Amount"
    description: "The total dollar amount collected on patient invoices"
    type: sum
    value_format_name: usd
    sql: ${invoice_level_total_payment} ;;
  }

  measure: total_collected_amount_within_30 {
    label: "$ Total Collected Amount (30 Days)"
    group_label: "Collected Over Time"
    description: "The total dollar amount collected on patient invoices in 30 days since invoice created"
    type: sum
    value_format_name: usd
    sql: ${TABLE}.payment_within_30 ;;
  }

  measure: total_collected_amount_within_60 {
    label: "$ Total Collected Amount (60 days)"
    group_label: "Collected Over Time"
    description: "The total dollar amount collected on patient invoices in the last 60 days since invoice created"
    type: sum
    value_format_name: usd
    sql: ${TABLE}.payment_within_60 ;;
  }

  measure: total_collected_amount_within_90 {
    label: "$ Total Collected Amount (90 days)"
    group_label: "Collected Over Time"
    description: "The total dollar amount collected on patient invoices in the last 90 days since invoice created"
    type: sum
    value_format_name: usd
    sql: ${TABLE}.payment_within_90 ;;
  }

  measure: total_collected_amount_within_120 {
    label: "$ Total Collected Amount (120 days)"
    group_label: "Collected Over Time"
    description: "The total dollar amount collected on patient invoices in the last 120 days since invoice created"
    type: sum
    value_format_name: usd
    sql: ${TABLE}.payment_within_120 ;;
  }

  measure: total_invoice_amount {
    label: "$ Total Patient Invoice Amount"
    description: "The total dollar amount invoiced to patients"
    type: sum
    value_format_name: usd
    sql: ${patient_invoice_amount} ;;
  }

  measure: total_invoice_amount_after_comps {
    label: "$ Total Patient Invoice Amount After OPR & Honor Comps"
    description: "The total dollar amount invoiced to patients"
    type: sum
    value_format_name: usd
    sql: ${TABLE}.patient_invoice_amount_net_opr_and_honor_comps ;;
  }

  measure: total_comp_amount {
    label: "$ Total Comp Amount"
    description: "The total dollar amount comped on patient invoices"
    type: sum
    value_format_name: usd
    sql: ${comp_amount} ;;
  }

  measure: total_outstanding_amount {
    label: "$ Total Outstanding Amount"
    description: "The total dollar amount that has been invoiced and not collected"
    type: number
    value_format_name: usd_2
    sql: ${total_invoice_amount} - coalesce(${total_collected_amount},0) - coalesce(${total_comp_amount},0) ;;
  }

  measure: collections_rate_before_comp {
    label: "% Patient Collections Rate (Invoice Amount Before OPR & Honor Comps)"
    description: "The percentage of the total amount invoiced that has been collected"
    type: number
    value_format: "00.0\%"
    sql: 100.00* coalesce(${total_collected_amount}/nullif(${total_invoice_amount},0),0) ;;
  }

  measure: collections_rate_after_comp {
    label: "% Patient Collections Rate (Invoice Amount After OPR & Honor Comps"
    description: "The percentage of the total amount invoiced that has been collected"
    type: number
    value_format: "00.0\%"
    sql: 100.00* coalesce(${total_collected_amount}/nullif(${total_invoice_amount_after_comps},0),0) ;;
  }

  measure: collections_rate_after_30 {
    label: "% Patient Collections Rate After 30 Days"
    description: "The percentage of the total amount invoiced that has been collected"
    type: number
    value_format: "00.0\%"
    sql: 100.00* coalesce(${total_collected_amount_within_30}/nullif(${total_invoice_amount_after_comps},0),0) ;;
  }

  measure: collections_rate_after_60 {
    label: "% Patient Collections Rate After 60 Days"
    description: "The percentage of the total amount invoiced that has been collected"
    type: number
    value_format: "00.0\%"
    sql: 100.00* coalesce(${total_collected_amount_within_60}/nullif(${total_invoice_amount_after_comps},0),0) ;;
  }

  measure: collections_rate_after_90 {
    label: "% Patient Collections Rate After 90 Days"
    description: "The percentage of the total amount invoiced that has been collected"
    type: number
    value_format: "00.0\%"
    sql: 100.00* coalesce(${total_collected_amount_within_90}/nullif(${total_invoice_amount_after_comps},0),0) ;;
  }

  measure: collections_rate_after_120 {
    label: "% Patient Collections Rate After 120 Days"
    description: "The percentage of the total amount invoiced that has been collected"
    type: number
    value_format: "00.0\%"
    sql: 100.00* coalesce(${total_collected_amount_within_120}/nullif(${total_invoice_amount_after_comps},0),0) ;;
  }

  measure: outstanding_rate {
    label: "% Patient Outstanding Rate"
    description: "The percentage of the total amount invoiced that is still outstanding"
    type: number
    value_format: "00.0\%"
    sql: 100.00* coalesce(${total_outstanding_amount}/nullif(${total_invoice_amount},0),0) ;;
  }


}





view: patient_collections_trend2 {
  derived_table: {
    sql:
      SELECT
      CASE
        WHEN days_from_invoice_to_paid::int >= 0 AND  days_from_invoice_to_paid::int<=10 THEN '00_0-10'
        WHEN days_from_invoice_to_paid::int >= 11 AND days_from_invoice_to_paid::int <=20 THEN '01_11-20'
        WHEN days_from_invoice_to_paid::int >= 21 AND days_from_invoice_to_paid::int <=30 THEN '02_21-30'
        WHEN days_from_invoice_to_paid::int >= 31 AND days_from_invoice_to_paid::int <=40 THEN '03_31-40'
        WHEN days_from_invoice_to_paid::int >= 41 AND days_from_invoice_to_paid::int <=50 THEN '04_41-50'
        WHEN days_from_invoice_to_paid::int >= 51 AND days_from_invoice_to_paid::int <= 60 THEN '05_51 -60'
        WHEN days_from_invoice_to_paid::int >= 61 AND days_from_invoice_to_paid::int <= 70 THEN '06_61 -70'
        WHEN days_from_invoice_to_paid::int >= 71 AND days_from_invoice_to_paid::int <= 80 THEN '07_71 -80'
        WHEN days_from_invoice_to_paid::int >= 81 AND days_from_invoice_to_paid::int <= 90 THEN '08_81 -90'
        WHEN days_from_invoice_to_paid::int >= 91 AND days_from_invoice_to_paid::int <= 100 THEN '09_91 -100'
        WHEN days_from_invoice_to_paid::int >= 101 AND days_from_invoice_to_paid::int <=110 THEN '10_101-110'
        WHEN days_from_invoice_to_paid::int >= 111 AND days_from_invoice_to_paid::int <=120 THEN '11_111-120'
        WHEN days_from_invoice_to_paid::int >= 121 AND days_from_invoice_to_paid::int <=130 THEN '12_121-130'
        WHEN days_from_invoice_to_paid::int >= 131 AND days_from_invoice_to_paid::int <=140 THEN '13_131-140'
        WHEN days_from_invoice_to_paid::int >= 141 AND days_from_invoice_to_paid::int <=150 THEN '14_141-150'
        WHEN days_from_invoice_to_paid::int >= 151 AND days_from_invoice_to_paid::int <=160 THEN '15_151-160'
        WHEN days_from_invoice_to_paid::int >= 161 AND days_from_invoice_to_paid::int <=170 THEN '16_161-170'
        WHEN days_from_invoice_to_paid::int >= 171 AND days_from_invoice_to_paid::int <=180 THEN '17_171-180'
        WHEN days_from_invoice_to_paid::int >= 181 AND days_from_invoice_to_paid::int <=190 THEN '18_181-190'
        WHEN days_from_invoice_to_paid::int >= 191 AND days_from_invoice_to_paid::int <=200 THEN '19_191-200'
        WHEN days_from_invoice_to_paid::int >= 201 AND days_from_invoice_to_paid::int <=210 THEN '20_201-210'
        ELSE null END AS days_from_invoice_to_paid
      , AVG(percent_paid_of_invoice) AS percent_paid_of_invoice
      FROM
      (
        SELECT
          invoice.id
          ,invoice.type
          ,invoice.patient_invoice_amount as patient_invoice_amount
          ,invoice.timestamp
          ,invoice.moop_comps
          , payment.date_recorded
          , payment_method
          , payment.transaction_amount
          , (payment.date_recorded::date - invoice.timestamp::date)::int AS days_from_invoice_to_paid
          , sum(coalesce((CASE WHEN payment.payment_method = 'comp' THEN 0 ELSE 1.0*payment.transaction_amount END)/nullif(1.0*invoice.patient_invoice_amount,0),0)) OVER(PARTITION BY invoice.id) AS percent_paid_of_invoice
          ,SUM(CASE WHEN payment.payment_method = 'comp' THEN 0 ELSE payment.transaction_amount END) AS invoice_level_total_payment
        FROM ${invoice.SQL_TABLE_NAME} AS invoice
        LEFT JOIN uploads.custom_hybrid_file AS payment ON payment.invoice_id = invoice.id
        LEFT JOIN ${order.SQL_TABLE_NAME} AS o on o.id = payment.order_id
        WHERE (payment.invoice_type = 'Customer' OR payment.invoice_type is null) AND (payment.source != 'hra-era' OR payment.source is null) AND completed_on >= '2015-07-01'::date AND completed_on < '2016-01-01'::date
        GROUP BY 1,2,3,4,5,6,7,8,9) AS foo
        GROUP BY 1
       ;;
    sql_trigger_value: select count(pkey) from uploads.custom_hybrid_file ;;
    indexes: ["days_from_invoice_to_paid"]
  }

  dimension: invoice_id {
    hidden: yes
    primary_key: yes
    sql: ${TABLE}.id ;;
  }

  dimension: invoice_type {
    hidden: yes
    sql: ${TABLE}.type ;;
  }

  dimension: patient_invoice_amount {
    type: number
    value_format_name: usd
    sql: ${TABLE}.patient_invoice_amount ;;
  }

  dimension: timestamp {
    type: date_time
    sql: ${TABLE}.timestamp ;;
  }

  dimension: moop_comps {
    value_format_name: usd
    sql: ${TABLE}.moop_comps ;;
  }

  measure: total_moop_comps {
    type: sum
    sql: ${TABLE}.moop_comps ;;
  }

  dimension: invoice_level_total_payment {
    type: number
    value_format_name: usd
    sql: ${TABLE}.invoice_level_total_payment ;;
  }

  dimension: outstanding_amount {
    label: "Collections Amount"
    type: number
    value_format_name: usd
    sql: ${patient_invoice_amount} - ${invoice_level_total_payment} ;;
  }

  dimension: inv_amt_tier {
    alias: [patient_inv_amt_tier]
    label: "Invoice Tier (Pre-MOOP Period)"
    description: "The tiers/buckets of dollar amounts invoiced net of comps"
    sql: CASE WHEN ${patient_invoice_amount} >= 750 THEN '$750+'
        WHEN ${patient_invoice_amount} >= 500 THEN '$500 - $749'
        WHEN ${patient_invoice_amount} >= 349 THEN '$350 - $499'
        WHEN ${patient_invoice_amount} > 0 THEN '$1 - $349'
        WHEN ${patient_invoice_amount} = 0 THEN '$0'
        ELSE 'No Invoice Yet' END
       ;;
  }

  measure: total_collected_amount {
    label: "$ Total Collected Amount"
    description: "The total dollar amount collected on patient invoices"
    type: sum
    value_format_name: usd
    sql: ${invoice_level_total_payment} ;;
  }

  measure: total_invoice_amount {
    label: "$ Total Patient Invoice Amount"
    description: "The total dollar amount invoiced to patients"
    type: sum
    value_format_name: usd
    sql: ${patient_invoice_amount} ;;
  }

  measure: total_outstanding_amount {
    label: "$ Total Outstanding Amount"
    description: "The total dollar amount that has been invoiced and not collected"
    type: number
    value_format_name: usd
    sql: ${total_invoice_amount} - ${total_collected_amount} ;;
  }

  measure: collections_rate {
    label: "% Patient Collections Rate"
    description: "The percentage of the total amount invoiced that is still outstanding"
    type: number
    value_format_name: percent_1
    sql: 100.00* coalesce(${total_collected_amount}/nullif(${total_invoice_amount},0),0) ;;
  }

  dimension: days_from_invoice_to_paid {
    type: string
    sql: ${TABLE}.days_from_invoice_to_paid ;;
  }

  measure: percent_paid_of_invoice {
    type: average
    value_format_name: percent_1
    sql: ${TABLE}.percent_paid_of_invoice ;;
  }

  measure: running_cumulative_percent {
    type: running_total
    value_format: "00.0%"
    direction: "column"
    sql: ${percent_paid_of_invoice} ;;
  }
}

view: patient_collections_trend {
  derived_table: {
    sql: SELECT
        invoice_tier
        , payment_lag
        , a_b
        , sum((payment_amount/total_invoice_tier_amount)) OVER(partition by payment_lag,invoice_tier,a_b) as cumulative_percent
        , sum(payment_amount) OVER(partition by payment_lag,invoice_tier,a_b)  as cumulative_payment
        , total_invoice_tier_amount
      FROM
        (SELECT
          sub1.invoice_tier
          , sub1.a_b
          , CASE WHEN sub2.payment_lag::int > 300 THEN 300
            WHEN sub2.payment_lag::int > 270 THEN 270
            WHEN sub2.payment_lag::int > 240 THEN 240
            WHEN sub2.payment_lag::int > 210 THEN 210
            WHEN sub2.payment_lag::int > 180 THEN 180
            WHEN sub2.payment_lag::int > 150 THEN 150
            WHEN sub2.payment_lag::int > 120 THEN 120
            WHEN sub2.payment_lag::int > 90 THEN 90
            WHEN sub2.payment_lag::int > 60 THEN 60
            WHEN sub2.payment_lag::int > 30 THEN 30
            ELSE 0 END as payment_lag
          , sum(payment_amount) as payment_amount
          , total_invoice_tier_amount
        FROM
          (SELECT
            CASE WHEN patient_invoice_amount >= 500 THEN '$500+'
              WHEN patient_invoice_amount > 349 THEN '$350-499'
              WHEN patient_invoice_amount = 349 THEN '$349'
              WHEN patient_invoice_amount >= 100 THEN '$100-348'
              WHEN patient_invoice_amount <100 AND patient_invoice_amount >= 0 THEN '$0-99'
              ELSE null END as invoice_tier
            , CASE
                WHEN claim.status_name = 'Canceled Chose Cash' AND (billingpolicy.name = 'Oon, High Estimate' OR billingpolicy.name = 'No Insurance Self Pay' OR billingpolicy.name = 'Send To Cash Patient Choice' OR billingpolicy.name = 'Send To Cash Prior Auth Denied') THEN 'Chose Cash'
                WHEN abs(patient_invoice_amount - pricingestimate.raw_estimated_total_oop) <= 25 THEN 'Accurate Estimate'
                WHEN (patient_invoice_amount - pricingestimate.raw_estimated_total_oop) < -25 THEN 'Over Estimate'
                WHEN o.bill_type = 'Self Pay' THEN 'Self Pay'
                WHEN paid_to_patient > 0 THEN 'Paid to Patient'
                ELSE null END AS a_b
            , sum(patient_invoice_amount) as total_invoice_tier_amount
          FROM
            ${invoice.SQL_TABLE_NAME} as invoice
          INNER JOIN
            current.invoiceitem as ii on ii.invoice_id = invoice.id
          INNER JOIN
            current.order as o on o.id = ii.order_id
          INNER JOIN
            current.insuranceclaim as claim on claim.order_id = o.id
          LEFT JOIN
            current.billingpolicy on billingpolicy.id = claim.billing_policy_id
          LEFT JOIN
            current.pricingestimate on pricingestimate.profile_external_id = (o.profile_external_id)
          WHERE
            type = 'Customer'
            and {% condition invoice_date_filter %} o.completed_on {% endcondition %}
          GROUP BY
            1,2
          ) as sub1
        LEFT JOIN
          (SELECT
            (payment.date_recorded::date - invoice.timestamp::date)::int as payment_lag
            , CASE WHEN invoice.patient_invoice_amount >= 500 THEN '$500+'
              WHEN invoice.patient_invoice_amount > 349 THEN '$350-499'
              WHEN invoice.patient_invoice_amount = 349 THEN '$349'
              WHEN invoice.patient_invoice_amount >= 100 THEN '$100-348'
              WHEN patient_invoice_amount <100 AND patient_invoice_amount >= 0 THEN '$0-99'
              ELSE null END as invoice_tier
            , CASE
                WHEN claim.status_name = 'Canceled Chose Cash' AND (billingpolicy.name = 'Oon, High Estimate' OR billingpolicy.name = 'No Insurance Self Pay' OR billingpolicy.name = 'Send To Cash Patient Choice' OR billingpolicy.name = 'Send To Cash Prior Auth Denied') THEN 'Chose Cash'
                WHEN abs(patient_invoice_amount - pricingestimate.raw_estimated_total_oop) <= 25 THEN 'Accurate Estimate'
                WHEN (patient_invoice_amount - pricingestimate.raw_estimated_total_oop) < -25 THEN 'Over Estimate'
                WHEN o.bill_type = 'Self Pay' THEN 'Self Pay'
                WHEN paid_to_patient > 0 THEN 'Paid to Patient'
                ELSE null END AS a_b
            , sum(CASE WHEN payment.payment_method != 'comp' THEN payment.transaction_amount ELSE NULL END) as payment_amount
          FROM
            ${invoice.SQL_TABLE_NAME} as invoice
          INNER JOIN
            current.invoiceitem as ii on ii.invoice_id = invoice.id
          INNER JOIN
            current.order as o on o.id = ii.order_id
          INNER JOIN
            current.insuranceclaim as claim on claim.order_id = o.id
          LEFT JOIN
            current.billingpolicy on billingpolicy.id = claim.billing_policy_id
          LEFT JOIN
            current.pricingestimate ON pricingestimate.profile_external_id = (o.profile_external_id)
          LEFT JOIN
            uploads.custom_hybrid_file as payment on payment.invoice_id = invoice.id
          WHERE
            (payment.invoice_type = 'Customer' OR payment.invoice_type is null) AND (payment.source != 'hra-era' OR payment.source is null)
            and {% condition invoice_date_filter %} o.completed_on {% endcondition %}
          GROUP BY
            1,2,3
          ) as sub2 on sub1.invoice_tier = sub2.invoice_tier and sub1.a_b = sub2.a_b
        GROUP BY 1,2,3,5
        ) as sub3
       ;;
  }

  filter: invoice_date_filter {
    type: date
  }

  dimension: invoice_tier {
    case: {
      when: {
        sql: ${TABLE}.invoice_tier = '$0-99' ;;
        label: "$0-99"
      }

      when: {
        sql: ${TABLE}.invoice_tier = '$100-348' ;;
        label: "$100-348"
      }

      when: {
        sql: ${TABLE}.invoice_tier = '$349' ;;
        label: "$349"
      }

      when: {
        sql: ${TABLE}.invoice_tier = '$350-499' ;;
        label: "$350-499"
      }

      when: {
        sql: ${TABLE}.invoice_tier = '$500+' ;;
        label: "$500+"
      }
    }
  }

  dimension: payment_lag {
    type: number
    sql: ${TABLE}.payment_lag ;;
  }

  dimension: test {
    sql: ${TABLE}.a_b ;;
  }

  dimension: total_invoice_amount {
    type: number
    sql: ${TABLE}.total_invoice_tier_amount ;;
  }

  measure: cumulative_percent {
    type: sum
    sql: ${TABLE}.cumulative_percent ;;
  }

  measure: running_cumulative_percent {
    type: running_total
    value_format: "00.0%"
    direction: "column"
    sql: ${cumulative_percent} ;;
  }

  measure: cumulative_payment {
    type: sum
    sql: ${TABLE}.cumulative_payment ;;
  }

  measure: running_cumulative_payment {
    type: running_total
    value_format_name: usd_0
    direction: "column"
    sql: ${cumulative_payment} ;;
  }
}

view: patient_collections_trend_no_tier {
  derived_table: {
    sql: SELECT
        payment_lag
        , sum((payment_amount/total_invoice_tier_amount)) over( partition by payment_lag) as cumulative_percent
        , sum(payment_amount) over( partition by payment_lag) as cumulative_payment
        , total_invoice_tier_amount
      FROM
        (SELECT
          CASE WHEN sub2.payment_lag::int > 300 THEN 300
            WHEN sub2.payment_lag::int > 270 THEN 270
            WHEN sub2.payment_lag::int > 240 THEN 240
            WHEN sub2.payment_lag::int > 210 THEN 210
            WHEN sub2.payment_lag::int > 180 THEN 180
            WHEN sub2.payment_lag::int > 150 THEN 150
            WHEN sub2.payment_lag::int > 120 THEN 120
            WHEN sub2.payment_lag::int > 90 THEN 90
            WHEN sub2.payment_lag::int > 60 THEN 60
            WHEN sub2.payment_lag::int > 30 THEN 30
            ELSE 0 END as payment_lag
          , sum(payment_amount) as payment_amount
          , total_invoice_tier_amount
        FROM
          (SELECT
            1 as joiner
            , sum(patient_invoice_amount_net_all_comps) as total_invoice_tier_amount
          FROM
            ${invoice.SQL_TABLE_NAME} as invoice
          INNER JOIN
            current.invoiceitem as ii on ii.invoice_id = invoice.id
          INNER JOIN
            current.order as o on o.id = ii.order_id
          WHERE
            invoice.type = 'Customer'
            and {% condition invoice_date_filter %} o.completed_on {% endcondition %}
          GROUP BY
            1
          ) as sub1
        LEFT JOIN
          (SELECT
            1 as joiner
            , (payment.date_recorded::date - invoice.timestamp::date)::int as payment_lag
            , sum(payment.transaction_amount) as payment_amount
          FROM
            ${invoice.SQL_TABLE_NAME} as invoice
          INNER JOIN
            current.invoiceitem as ii on ii.invoice_id = invoice.id
          INNER JOIN
            current.order as o on o.id= ii.order_id
          LEFT JOIN
            uploads.custom_hybrid_file as payment on payment.invoice_id = invoice.id
          WHERE
            invoice.type = 'Customer'
            and {% condition invoice_date_filter %} o.completed_on {% endcondition %}
          GROUP BY
            1,2
          ) as sub2 on sub1.joiner = sub2.joiner
        GROUP BY 1,3
        ) as sub3
       ;;
  }

  filter: invoice_date_filter {
    type: date
  }

  dimension: invoice_tier {
    case: {
      when: {
        sql: ${TABLE}.invoice_tier = '$0-99' ;;
        label: "$0-99"
      }

      when: {
        sql: ${TABLE}.invoice_tier = '$100-348' ;;
        label: "$100-348"
      }

      when: {
        sql: ${TABLE}.invoice_tier = '$349' ;;
        label: "$349"
      }

      when: {
        sql: ${TABLE}.invoice_tier = '$350-499' ;;
        label: "$350-499"
      }

      when: {
        sql: ${TABLE}.invoice_tier = '$500+' ;;
        label: "$500+"
      }
    }
  }

  dimension: payment_lag {
    type: number
    sql: ${TABLE}.payment_lag ;;
  }

  dimension: total_invoice_amount {
    type: number
    sql: ${TABLE}.total_invoice_tier_amount ;;
  }

  measure: cumulative_percent {
    type: sum
    sql: ${TABLE}.cumulative_percent ;;
  }

  measure: running_cumulative_percent {
    type: running_total
    value_format: "00.0%"
    direction: "column"
    sql: ${cumulative_percent} ;;
  }

  measure: cumulative_payment {
    type: sum
    sql: ${TABLE}.cumulative_payment ;;
  }

  measure: running_cumulative_payment {
    type: running_total
    value_format_name: usd_0
    direction: "column"
    sql: ${cumulative_payment} ;;
  }
}

view: patient_collections_trend3 {
  derived_table: {
    sql: SELECT
        invoice_tier
        , payment_lag
        , a_b
        , sum((payment_amount/total_invoice_tier_amount)) OVER(partition by payment_lag,invoice_tier,a_b) as cumulative_percent
        , sum(payment_amount) OVER(partition by payment_lag,invoice_tier,a_b)  as cumulative_payment
        , total_invoice_tier_amount
      FROM
        (SELECT
          sub1.invoice_tier
          , sub1.a_b
          , CASE WHEN sub2.payment_lag::int > 300 THEN 300
            WHEN sub2.payment_lag::int > 270 THEN 270
            WHEN sub2.payment_lag::int > 240 THEN 240
            WHEN sub2.payment_lag::int > 210 THEN 210
            WHEN sub2.payment_lag::int > 180 THEN 180
            WHEN sub2.payment_lag::int > 150 THEN 150
            WHEN sub2.payment_lag::int > 120 THEN 120
            WHEN sub2.payment_lag::int > 90 THEN 90
            WHEN sub2.payment_lag::int > 60 THEN 60
            WHEN sub2.payment_lag::int > 30 THEN 30
            ELSE 0 END as payment_lag
          , sum(payment_amount) as payment_amount
          , total_invoice_tier_amount
        FROM
          (SELECT
            CASE WHEN patient_invoice_amount >= 500 THEN '$500+'
              WHEN patient_invoice_amount > 349 THEN '$350-499'
              WHEN patient_invoice_amount = 349 THEN '$349'
              WHEN patient_invoice_amount >= 100 THEN '$100-348'
              WHEN patient_invoice_amount <100 AND patient_invoice_amount >= 0 THEN '$0-99'
              ELSE null END as invoice_tier
            , CASE
                WHEN claim.status_name = 'Canceled Chose Cash' AND (billingpolicy.name = 'Oon, High Estimate' OR billingpolicy.name = 'No Insurance Self Pay' OR billingpolicy.name = 'Send To Cash Patient Choice' OR billingpolicy.name = 'Send To Cash Prior Auth Denied') THEN 'Chose Cash'
                WHEN abs(patient_invoice_amount - pricingestimate.raw_estimated_total_oop) <= 25 THEN 'Accurate Estimate'
                WHEN (patient_invoice_amount - pricingestimate.raw_estimated_total_oop) < -25 THEN 'Over Estimate'
                WHEN o.bill_type = 'cc' THEN 'Self Pay'
                WHEN paid_to_patient > 0 THEN 'Paid to Patient'
                ELSE null END AS a_b
            , sum(patient_invoice_amount) as total_invoice_tier_amount
          FROM
            ${invoice.SQL_TABLE_NAME} as invoice
          INNER JOIN
            ${invoiceitem.SQL_TABLE_NAME} as ii on ii.invoice_id = invoice.id
          INNER JOIN
            current.order as o on o.id = ii.order_id
          LEFT JOIN
            current.insuranceclaim as claim on claim.order_id = o.id
          LEFT JOIN
            current.billingpolicy on billingpolicy.id = claim.billing_policy_id
          LEFT JOIN
            current.pricingestimate on pricingestimate.profile_external_id = (o.profile_external_id)
          WHERE
            type = 'Customer'
            and {% condition invoice_date_filter %} o.completed_on {% endcondition %}
            and {% condition invoice_date_filter %} invoice.timestamp {% endcondition %}
          GROUP BY
            1,2
          ) as sub1
        LEFT JOIN
          (SELECT
            (payment.date_recorded::date - invoice.timestamp::date)::int as payment_lag
            , CASE WHEN invoice.patient_invoice_amount >= 500 THEN '$500+'
              WHEN invoice.patient_invoice_amount > 349 THEN '$350-499'
              WHEN invoice.patient_invoice_amount = 349 THEN '$349'
              WHEN invoice.patient_invoice_amount >= 100 THEN '$100-348'
              WHEN patient_invoice_amount <100 AND patient_invoice_amount >= 0 THEN '$0-99'
              ELSE null END as invoice_tier
            , CASE
                WHEN claim.status_name = 'Canceled Chose Cash' AND (billingpolicy.name = 'Oon, High Estimate' OR billingpolicy.name = 'No Insurance Self Pay' OR billingpolicy.name = 'Send To Cash Patient Choice' OR billingpolicy.name = 'Send To Cash Prior Auth Denied') THEN 'Chose Cash'
                WHEN abs(patient_invoice_amount - pricingestimate.raw_estimated_total_oop) <= 25 THEN 'Accurate Estimate'
                WHEN (patient_invoice_amount - pricingestimate.raw_estimated_total_oop) < -25 THEN 'Over Estimate'
                WHEN o.bill_type = 'cc' THEN 'Self Pay'
                WHEN paid_to_patient > 0 THEN 'Paid to Patient'
                ELSE null END AS a_b
            , sum(CASE WHEN payment.payment_method != 'comp' THEN payment.transaction_amount ELSE NULL END) as payment_amount
          FROM
            ${invoice.SQL_TABLE_NAME} as invoice
          INNER JOIN
            ${invoiceitem.SQL_TABLE_NAME} as ii on ii.invoice_id = invoice.id
          INNER JOIN
            current.order as o on o.id = ii.order_id
          LEFT JOIN
            current.insuranceclaim as claim on claim.order_id = o.id
          LEFT JOIN
            current.billingpolicy on billingpolicy.id = claim.billing_policy_id
          LEFT JOIN
            current.pricingestimate ON pricingestimate.profile_external_id = (o.profile_external_id)
          LEFT JOIN
            uploads.custom_hybrid_file as payment on payment.invoice_id = invoice.id
          WHERE
            (payment.invoice_type = 'Customer' OR payment.invoice_type is null) AND (payment.source != 'hra-era' OR payment.source is null)
            and {% condition invoice_date_filter %} o.completed_on {% endcondition %}
            and {% condition invoice_date_filter %} invoice.timestamp {% endcondition %}
          GROUP BY
            1,2,3
          ) as sub2 on sub1.invoice_tier = sub2.invoice_tier and sub1.a_b = sub2.a_b
        GROUP BY 1,2,3,5
        ) as sub3
       ;;
    indexes: ["invoice_tier"]
    persist_for: "60 minutes"
  }

  filter: invoice_date_filter {
    type: date
  }

  dimension: collections_category {
    case: {
      when: {
        sql: ${TABLE}.a_b = 'Chose Cash' ;;
        label: "Chose Cash"
      }

      when: {
        sql: ${TABLE}.a_b = 'Accurate Estimate' ;;
        label: "Accurate Estimate"
      }

      when: {
        sql: ${TABLE}.a_b = 'Over Estimate' ;;
        label: "Over Estimate"
      }

      when: {
        sql: ${TABLE}.a_b = 'Paid to Patient' ;;
        label: "Paid to Patient"
      }

      when: {
        sql: ${TABLE}.a_b = 'Self Pay' ;;
        label: "Self Pay"
      }
    }
  }

  dimension: invoice_tier {
    case: {
      when: {
        sql: ${TABLE}.invoice_tier = '$0-99' ;;
        label: "$0-99"
      }

      when: {
        sql: ${TABLE}.invoice_tier = '$100-348' ;;
        label: "$100-348"
      }

      when: {
        sql: ${TABLE}.invoice_tier = '$349' ;;
        label: "$349"
      }

      when: {
        sql: ${TABLE}.invoice_tier = '$350-499' ;;
        label: "$350-499"
      }

      when: {
        sql: ${TABLE}.invoice_tier = '$500+' ;;
        label: "$500+"
      }
    }
  }

  dimension: payment_lag {
    type: number
    sql: ${TABLE}.payment_lag ;;
  }

  dimension: total_invoice_amount {
    type: number
    sql: ${TABLE}.total_invoice_tier_amount ;;
  }

  measure: cumulative_percent {
    type: sum
    sql: ${TABLE}.cumulative_percent ;;
  }

  measure: running_cumulative_percent {
    type: running_total
    value_format: "00.0%"
    direction: "column"
    sql: ${cumulative_percent} ;;
  }

  measure: cumulative_payment {
    type: sum
    sql: ${TABLE}.cumulative_payment ;;
  }

  measure: running_cumulative_payment {
    type: running_total
    value_format_name: usd_0
    direction: "column"
    sql: ${cumulative_payment} ;;
  }
}

view: patient_collections_trend4 {
  derived_table: {
    sql: SELECT

              payment_lag
              , a_b
              , sum((payment_amount/total_invoice_tier_amount)) OVER(partition by payment_lag, a_b) as cumulative_percent
              , sum(payment_amount) OVER(partition by payment_lag, a_b)  as cumulative_payment
              , total_invoice_tier_amount
            FROM
              (SELECT

                 sub1.a_b
                , CASE WHEN sub2.payment_lag::int > 300 THEN 300
                  WHEN sub2.payment_lag::int > 270 THEN 270
                  WHEN sub2.payment_lag::int > 240 THEN 240
                  WHEN sub2.payment_lag::int > 210 THEN 210
                  WHEN sub2.payment_lag::int > 180 THEN 180
                  WHEN sub2.payment_lag::int > 150 THEN 150
                  WHEN sub2.payment_lag::int > 120 THEN 120
                  WHEN sub2.payment_lag::int > 90 THEN 90
                  WHEN sub2.payment_lag::int > 60 THEN 60
                  WHEN sub2.payment_lag::int > 30 THEN 30
                  ELSE 0 END as payment_lag
                , sum(payment_amount) as payment_amount
                , total_invoice_tier_amount
              FROM
                (SELECT

                   CASE
                      WHEN claim.status_name = 'Canceled Chose Cash' AND (billingpolicy.name = 'Oon, High Estimate' OR billingpolicy.name = 'No Insurance Self Pay' OR billingpolicy.name = 'Send To Cash Patient Choice' OR billingpolicy.name = 'Send To Cash Prior Auth Denied' or billingpolicy.name is null) THEN 'Chose Cash'
                      WHEN abs(patient_invoice_amount - pricingestimate.raw_estimated_total_oop) <= 25 THEN 'Accurate Estimate'
                      WHEN (patient_invoice_amount - pricingestimate.raw_estimated_total_oop) < -25 THEN 'Over Estimate'
                      WHEN o.bill_type = 'cc' THEN 'Self Pay'
                      WHEN paid_to_patient > 0 THEN 'Paid to Patient'
                      ELSE null END AS a_b
                  , sum(patient_invoice_amount) as total_invoice_tier_amount
                FROM
                  ${invoice.SQL_TABLE_NAME} as invoice
                INNER JOIN
                  ${invoiceitem.SQL_TABLE_NAME} as ii on ii.invoice_id = invoice.id
                INNER JOIN
                  current.order as o on o.id = ii.order_id
                LEFT JOIN
                  current.insuranceclaim as claim on claim.order_id = o.id
                LEFT JOIN
                  current.billingpolicy on billingpolicy.id = claim.billing_policy_id
                LEFT JOIN
                  current.pricingestimate on pricingestimate.profile_external_id = (o.profile_external_id)
                WHERE
                  type = 'Customer'
                  and {% condition invoice_date_filter %} o.completed_on {% endcondition %}
                  and {% condition invoice_date_filter %} invoice.timestamp {% endcondition %}
                GROUP BY
                  1
                ) as sub1
              LEFT JOIN
                (SELECT
                  (payment.date_recorded::date - invoice.timestamp::date)::int as payment_lag
                  , CASE
                      WHEN claim.status_name = 'Canceled Chose Cash' AND (billingpolicy.name = 'Oon, High Estimate' OR billingpolicy.name = 'No Insurance Self Pay' OR billingpolicy.name = 'Send To Cash Patient Choice' OR billingpolicy.name = 'Send To Cash Prior Auth Denied' or billingpolicy.name is null) THEN 'Chose Cash'
                      WHEN abs(invoice.patient_invoice_amount - pricingestimate.raw_estimated_total_oop) <= 25 THEN 'Accurate Estimate'
                      WHEN (invoice.patient_invoice_amount - pricingestimate.raw_estimated_total_oop) < -25 THEN 'Over Estimate'
                      WHEN o.bill_type = 'cc' THEN 'Self Pay'
                      WHEN paid_to_patient > 0 THEN 'Paid to Patient'
                      ELSE null END AS a_b
                  , sum(CASE WHEN payment.payment_method != 'comp' THEN payment.transaction_amount ELSE NULL END) as payment_amount
                FROM
                  ${invoice.SQL_TABLE_NAME} as invoice
                INNER JOIN
                  ${invoiceitem.SQL_TABLE_NAME} as ii on ii.invoice_id = invoice.id
                INNER JOIN
                  current.order as o on o.id = ii.order_id
                LEFT JOIN
                  current.insuranceclaim as claim on claim.order_id = o.id
                LEFT JOIN
                  current.billingpolicy on billingpolicy.id = claim.billing_policy_id
                LEFT JOIN
                  current.pricingestimate ON pricingestimate.profile_external_id = (o.profile_external_id)
                LEFT JOIN
                  uploads.custom_hybrid_file as payment on payment.invoice_id = invoice.id
                WHERE
                  (payment.invoice_type = 'Customer' OR payment.invoice_type is null) AND (payment.source != 'hra-era' OR payment.source is null)
                  and {% condition invoice_date_filter %} o.completed_on {% endcondition %}
                  and {% condition invoice_date_filter %} invoice.timestamp {% endcondition %}
                GROUP BY
                  1,2
                ) as sub2 on sub1.a_b = sub2.a_b
              GROUP BY 1,2,4
              ) as sub3
             ;;
    indexes: ["a_b"]
    persist_for: "60 minutes"
  }

  filter: invoice_date_filter {
    type: date
  }

  dimension: collections_category {
    case: {
      when: {
        sql: ${TABLE}.a_b = 'Chose Cash' ;;
        label: "Chose Cash"
      }

      when: {
        sql: ${TABLE}.a_b = 'Accurate Estimate' ;;
        label: "Accurate Estimate"
      }

      when: {
        sql: ${TABLE}.a_b = 'Over Estimate' ;;
        label: "Over Estimate"
      }

      when: {
        sql: ${TABLE}.a_b = 'Paid to Patient' ;;
        label: "Paid to Patient"
      }

      when: {
        sql: ${TABLE}.a_b = 'Self Pay' ;;
        label: "Self Pay"
      }
    }
  }

  dimension: invoice_tier {
    hidden: yes

    case: {
      when: {
        sql: ${TABLE}.invoice_tier = '$0-99' ;;
        label: "$0-99"
      }

      when: {
        sql: ${TABLE}.invoice_tier = '$100-348' ;;
        label: "$100-348"
      }

      when: {
        sql: ${TABLE}.invoice_tier = '$349' ;;
        label: "$349"
      }

      when: {
        sql: ${TABLE}.invoice_tier = '$350-499' ;;
        label: "$350-499"
      }

      when: {
        sql: ${TABLE}.invoice_tier = '$500+' ;;
        label: "$500+"
      }
    }
  }

  dimension: payment_lag {
    type: number
    sql: ${TABLE}.payment_lag ;;
  }

  dimension: total_invoice_amount {
    type: number
    sql: ${TABLE}.total_invoice_tier_amount ;;
  }

  measure: cumulative_percent {
    type: sum
    sql: ${TABLE}.cumulative_percent ;;
  }

  measure: running_cumulative_percent {
    type: running_total
    value_format: "00.0%"
    direction: "column"
    sql: ${cumulative_percent} ;;
  }

  measure: cumulative_payment {
    type: sum
    sql: ${TABLE}.cumulative_payment ;;
  }

  measure: running_cumulative_payment {
    type: running_total
    value_format_name: usd_0
    direction: "column"
    sql: ${cumulative_payment} ;;
  }
}


view: patient_payments {
  derived_table: {
    sql: SELECT
      pkey
      , invoice_id
      , payment_method
      , date_recorded
      , transaction_amount
      FROM uploads.custom_hybrid_file AS payment
      WHERE (payment.invoice_type = 'Customer' OR payment.invoice_type is null) AND (payment.source != 'hra-era' OR payment.source is null)
       ;;
    sql_trigger_value: select COUNT(*) FROM uploads.custom_hybrid_file AS payment ;;
    indexes: ["invoice_id", "date_recorded"]
  }

  dimension: invoice_id {
    type: number
    sql: ${TABLE}.invoice_id ;;
  }

  dimension: pkey {
    primary_key: yes
    type: string
    sql: ${TABLE}.pkey ;;
  }

  dimension: payment_method {
    description: "The form of payment that Counsyl received, e.g. chck for \"Check\", etc."
    type: string
    sql: ${TABLE}.payment_method ;;
  }

  dimension_group: date_recorded {
    type: time
    timeframes: [date, week, month, quarter, year]
    sql: ${TABLE}.date_recorded ;;
  }

  measure: total_transaction_amount {
    label: "$ Total Transaction Amount"
    value_format_name: usd
    type: sum
    sql: ${TABLE}.transaction_amount ;;
  }

  measure: average_transaction_amount {
    label: "$ Average Transaction Amount"
    value_format_name: usd
    type: average
    sql: ${TABLE}.transaction_amount ;;
  }

}
