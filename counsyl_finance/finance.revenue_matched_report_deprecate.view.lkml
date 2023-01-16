##view: order_level_payments {
##  derived_table: {
##    sql: SELECT
##        order_id
##        , sum(patient_payment_amount) as patient_payment_amount
##        , sum(insurer_payment_amount) as insurer_payment_amount
##        , sum(physician_payment_amount) as physician_payment_amount
##      FROM
##
##        (SELECT
##          match.order_id
##          , 1 as invoice_item_count
##          , 0 as physician_payment_amount
##          , sum(CASE WHEN invoice_type = 'Customer' THEN hybrid_transaction_amt ELSE 0 END) as patient_payment_amount
##          , sum(CASE WHEN invoice_type = 'Insurer' THEN hybrid_transaction_amt ELSE 0 END) as insurer_payment_amount
##        FROM
##          ${matched_report_2014_to_current.SQL_TABLE_NAME} as match
##        WHERE
##          invoice_type in ('Customer', 'Insurer')
##        GROUP BY
##          1,2,3
##
##        UNION ALL
##          SELECT
##            sub2.order_id
##            , invoice_item_count
##            , sum(CASE WHEN invoice_type = 'Physician' THEN hybrid_transaction_amt ELSE 0 END) / nullif(invoice_item_count,0) as physician_payment_amount
##            , 0 as patient_payment_amount
##            , 0 as insurer_payment_amount
##          FROM
##            ${matched_report_2014_to_current.SQL_TABLE_NAME} as match
##          LEFT JOIN
##            (SELECT
##              ii.order_id
##              , ii.invoice_id
##              , invoice_item_count
##            FROM
##              ${invoiceitem.SQL_TABLE_NAME} as ii
##            INNER JOIN
##              (SELECT
##                invoice_id
##                , count(id) as invoice_item_count
##              FROM
##                ${invoiceitem.SQL_TABLE_NAME}
##              WHERE
##                invoice_type = 'Physician'
##              GROUP BY
##                1
##              ) as sub on sub.invoice_id = ii.invoice_id
##            GROUP BY
##              1,2,3
##            ) as sub2 on sub2.invoice_id = match.invoice_id
##          WHERE
##            match.invoice_type = 'Physician'
##          GROUP BY
##            1,2,4,5
##          ) as sub3
##        GROUP BY
##          1
##       ;;
##    sql_trigger_value: select sum(hybrid_transaction_amt) from ${matched_report_2014_to_current.SQL_TABLE_NAME} ;;
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
##  dimension: patient_payment_amount {
##    hidden: yes
##    type: number
##    sql: ${TABLE}.patient_payment_amount ;;
##  }
##
##  dimension: insurer_payment_amount {
##    type: number
##    hidden: yes
##    sql: ${TABLE}.insurer_payment_amount ;;
##  }
##
##  dimension: physician_payment_amount {
##    hidden: yes
##    type: number
##    sql: ${TABLE}.physician_payment_amount ;;
##  }
##}
##
##view: bank_recon_summary {
##  derived_table: {
##    sql: SELECT
##        coid
##        , bank_trans_id
##        , bank_account
##        , bai_code
##        , bank_ref
##        , bank_data_type
##        , deposit_amt
##        , deposit_date
##        , bd.is_business_date
##        , bank_description
##        , bank_text_desc
##        , bank_pkey
##        , known_var
##        , rev_trn
##        , eob_batch_adjs
##        , ref_pay
##        , eob_batch_adj_type
##        , deposit_amt - coalesce(total_posted,0) + coalesce(eob_batch_adjs,0) as variance
##        , max(match_type) as match_type
##      FROM
##        ${matched_report_2014_to_current.SQL_TABLE_NAME} match
##      INNER JOIN
##        uploads.business_days as bd on bd.calendar_date = match.deposit_date
##      GROUP BY
##        1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18
##       ;;
##    sql_trigger_value: select sum(deposit_amt) from ${matched_report_2014_to_current.SQL_TABLE_NAME} ;;
##  }
##
##  dimension: coid {
##    sql: ${TABLE}.coid ;;
##  }
##
##  dimension: bank_trans_id {
##    sql: ${TABLE}.bank_trans_id ;;
##  }
##
##  dimension: bank_account {
##    sql: ${TABLE}.bank_account ;;
##  }
##
##  dimension: bai_code {
##    sql: ${TABLE}.bai_code ;;
##  }
##
##  dimension: product {
##    sql: ${TABLE}.product ;;
##  }
##
##  dimension: bank_ref {
##    sql: ${TABLE}.bank_ref ;;
##  }
##
##  dimension: is_business_date {
##    hidden: yes
##    type: yesno
##    sql: ${TABLE}.is_business_date ;;
##  }
##
##  dimension: bank_data_type {
##    sql: ${TABLE}.bank_data_type ;;
##  }
##
##  measure: business_day_count {
##    type: count_distinct
##    hidden: yes
##    sql: ${deposit_date} ;;
##
##    filters: {
##      field: is_business_date
##      value: "Yes"
##    }
##  }
##
##  measure: deposit_amt {
##    type: sum
##    value_format_name: usd
##    sql: ${TABLE}.deposit_amt ;;
##  }
##
##  measure: deposits_per_business_day {
##    type: number
##    value_format_name: usd
##    sql: ${deposit_amt} / ${business_day_count} ;;
##  }
##
##  dimension_group: deposit {
##    type: time
##    timeframes: [quarter, date, week, month, year]
##    sql: ${TABLE}.deposit_date ;;
##  }
##
##  dimension: bank_description {
##    sql: ${TABLE}.bank_description ;;
##  }
##
##  dimension: bank_text_desc {
##    sql: ${TABLE}.bank_text_desc ;;
##  }
##
##  dimension: bank_pkey {
##    #type: number
##    primary_key: yes
##    sql: ${TABLE}.bank_pkey ;;
##  }
##
##  dimension: known_var {
##    sql: ${TABLE}.known_var ;;
##  }
##
##  dimension: rev_trn {
##    sql: ${TABLE}.rev_trn ;;
##  }
##
##  measure: eob_batch_adjs {
##    type: sum
##    value_format_name: usd
##    sql: ${TABLE}.eob_batch_adjs ;;
##  }
##
##  measure: matched_variance {
##    type: sum
##    value_format_name: usd
##    sql: ${TABLE}.variance ;;
##  }
##
##  dimension: ref_pay {
##    label: "Refund/Payment/Other Stripe"
##    sql: ${TABLE}.ref_pay ;;
##  }
##
##  dimension: match_type {
##    sql: ${TABLE}.match_type ;;
##  }
##
##  dimension: eob_batch_adj_type {
##    sql: ${TABLE}.eob_batch_adj_type ;;
##  }
##
##  dimension: auto_manual {
##    sql: ${TABLE}.auto_manual ;;
##  }
##}
##
##view: matched_report_2014_to_current {
##  derived_table: {
##    sql: SELECT
##        coid
##        , bank_trans_id
##        , bank_account
##        , bai_code
##        , bank_ref
##        , bank_data_type
##        , match.deposit_amt
##        , deposit_date
##        , bank_description
##        , bank_text_desc
##        , match.bank_pkey
##        , known_var
##        , rev_trn
##        , eob_batch_adjs
##        , hybrid_pkey
##        , hybrid_trans_id
##        , hybrid_transaction_amt
##        , hybrid_date_recorded
##        , barcode
##        , claim_id
##        , order_id
##        , invoice_id
##        , invoice_type
##        , source
##        , bill_ops_source
##        , bill_type
##        , product
##        , disease_panel
##        , testing_methodology
##        , completed_on
##        , clinic_id
##        , clinic_name
##        , date_of_service
##        , payer_name
##        , invoice.sent as invoice_sent_date
##        , invoice.timestamp as invoice_timestamp
##        , invoice.invoice_number as invoice_number
##        , invoice.amount as invoice_amount
##        , invoice.invoicing_clinic_id
##        , invoice.invoicing_clinic_name
##        , pretty_payer_name
##        , network_status
##        , bill_invoice_concat
##        , rev_rec_date
##        , ref_pay
##        , CASE WHEN abs(coalesce(total_posted,0) - coalesce(eob_batch_adjs,0) - match.deposit_amt) < 1 THEN 'Matched No Var'
##          WHEN match.deposit_amt - coalesce(total_posted,0) + coalesce(eob_batch_adjs,0) = match.deposit_amt THEN 'Unmatched'
##          ELSE 'Matched with Var' END as match_type
##        , CASE WHEN bank_data_type = 'Stripe Transaction' and eob_batch_adjs <> 0 THEN 'Stripe Fees'
##          WHEN eob_batch_adjs = 0 THEN NULL
##          WHEN source = 'manual - interest only' THEN 'Interest Only' ELSE 'EOB Batch Adjs' END as eob_batch_adj_type
##        , total_posted
##      FROM
##        ${matched_build_04_compute_network_status.SQL_TABLE_NAME} as match
##      INNER JOIN
##        (SELECT
##          bank_pkey::text
##          , deposit_amt
##          , sum(hybrid_transaction_amt) as total_posted
##        FROM
##          ${matched_build_04_compute_network_status.SQL_TABLE_NAME}
##        GROUP BY
##          1,2
##        ) as sub1 on sub1.bank_pkey::text = match.bank_pkey::text
##      LEFT JOIN
##        ${invoice.SQL_TABLE_NAME} as invoice on invoice.id = match.invoice_id
##
##      UNION ALL
##        SELECT
##          coid
##          , bank_trans_id
##          , bank_account
##          , bai_code
##          , bank_ref
##          , bank_data_type
##          , deposit_amt
##          , deposit_date
##          , bank_description
##          , bank_text_desc
##          , bank_pkey::text
##          , known_var
##          , rev_trn
##          , eob_batch_adjs
##          , hybrid_pkey
##          , hybrid_trans_id
##          , hybrid_transaction_amt
##          , hybrid_date_recorded
##          , barcode
##          , claim_id
##          , lookback.order_id
##          , invoice_id
##          , invoice_type
##          , source
##          , bill_ops_source
##          , CASE WHEN invoice_type = 'Physician' THEN 'cnsmt' ELSE o.bill_type END as bill_type
##          , o.product
##          , o.disease_panel
##          , o.testing_methodology
##          , o.completed_on
##          , lookback.clinic_id
##          , clinic_name
##          , lookback.date_of_service
##          , lookback.payer_name
##          , invoice.sent as invoice_sent_date
##          , invoice.timestamp as invoice_timestamp
##          , invoice.invoice_number as invoice_number
##          , invoice.amount as invoice_amount
##          , invoice.invoicing_clinic_id
##          , invoice.invoicing_clinic_name
##          , lookback.pretty_payer_name
##          , claim.network_status
##          , CASE WHEN claim.network_status = 'OON' or claim.network_status = 'INN' THEN
##            concat(claim.network_status,' ',CASE WHEN invoice_type = 'Customer' THEN 'Patient'
##              WHEN invoice_type = 'Insurer' THEN 'Payer'
##              ELSE 'ERROR' END)
##            WHEN invoice_type = 'Physician' THEN 'Consignment'
##            ELSE claim.network_status END as bill_invoice_concat
##          , CASE
##              WHEN (claim.network_status = 'OON' or claim.network_status is null)
##                AND (o.completed_on is not null and deposit_date is not null)
##                THEN
##                CASE
##                  WHEN o.completed_on::date>= deposit_date THEN o.completed_on::date
##                  WHEN  deposit_date > o.completed_on::date THEN deposit_date ELSE null
##                END
##              WHEN claim.network_status = 'In Net' THEN
##                CASE
##                  WHEN o.completed_on is null THEN '2020-01-01' ELSE o.completed_on END
##              WHEN claim.network_status = 'Consignment' THEN '2020-01-01'
##              ELSE o.completed_on END as rev_rec_date
##          , ref_pay
##          , match_type
##          , eob_batch_adj_type
##          , total_posted
##        FROM uploads.matched_report_as_of_20170103 as lookback
##        LEFT JOIN
##          (SELECT
##            claim.*
##            , CASE
##              WHEN o.product = 'Foresight Carrier Screen' and claim.date_of_service >= fps_date and date_of_service < coalesce(inn.fps_term,'2100-01-01'::date)
##                THEN 'In Net'
##              WHEN o.product = 'Reliant Cancer Screen' and claim.date_of_service >= ics_date and date_of_service < coalesce(inn.ics_term,'2100-01-01'::date)
##                THEN 'In Net'
##              WHEN o.product = 'Prelude Prenatal Screen' and claim.date_of_service >= ips_date and date_of_service < coalesce(inn.ips_term,'2100-01-01'::date)
##                THEN 'In Net'
##              ELSE 'OON'
##              END as network_status
##            FROM
##              current.insuranceclaim as claim
##            INNER JOIN current.order o on o.id = claim.order_id
##            LEFT JOIN current.insurancepayer on insurancepayer.id = claim.payer_id
##            LEFT JOIN uploads.in_network_dates_w_terminal inn on inn.id = insurancepayer.id
##          ) as claim on claim.id = lookback.claim_id
##        LEFT JOIN ${invoice.SQL_TABLE_NAME} as invoice on invoice.id = lookback.invoice_id
##        LEFT JOIN ${order.SQL_TABLE_NAME} as o on o.id = lookback.order_id
##        WHERE extract('year' from deposit_date) <= 2016
##       ;;
##    sql_trigger_value: SELECT sum(hybrid_transaction_amt) from ${matched_build_04_compute_network_status.SQL_TABLE_NAME} ;;
##    indexes: ["hybrid_date_recorded", "invoice_type", "ref_pay"]
##  }
##
##  dimension: bank_coid {
##    sql: ${TABLE}.coid ;;
##  }
##
##  dimension: bank_trans_id {
##    sql: ${TABLE}.bank_trans_id ;;
##  }
##
##  dimension: bank_account {
##    sql: ${TABLE}.bank_account ;;
##  }
##
##  dimension: bai_code {
##    sql: ${TABLE}.bai_code ;;
##  }
##
##  dimension: bank_ref {
##    sql: ${TABLE}.bank_ref ;;
##  }
##
##  dimension: bank_data_type {
##    sql: ${TABLE}.bank_data_type ;;
##  }
##
##  dimension: deposit_amt {
##    type: number
##    value_format_name: usd
##    sql: ${TABLE}.deposit_amt ;;
##  }
##
##  dimension_group: deposit {
##    type: time
##    timeframes: [quarter, date, month, year]
##    sql: ${TABLE}.deposit_date ;;
##  }
##
##  dimension: bank_description {
##    sql: ${TABLE}.bank_description ;;
##  }
##
##  dimension: bank_text_desc {
##    sql: ${TABLE}.bank_text_desc ;;
##  }
##
##  dimension: bank_pkey {
##    #type: number
##    sql: ${TABLE}.bank_pkey ;;
##  }
##
##  dimension: known_var {
##    type: yesno
##    sql: ${TABLE}.known_var ;;
##  }
##
##  dimension: rev_trn {
##    sql: ${TABLE}.rev_trn ;;
##  }
##
##  dimension: eob_batch_adjs {
##    type: number
##    value_format_name: usd
##    sql: ${TABLE}.eob_batch_adjs ;;
##  }
##
##  dimension: eob_batch_adj_type {
##    sql: ${TABLE}.eob_batch_adj_type ;;
##  }
##
##  dimension: hybrid_pkey {
##    primary_key: yes
##    sql: ${TABLE}.hybrid_pkey ;;
##  }
##
##  dimension: hybrid_trans_id {
##    sql: ${TABLE}.hybrid_trans_id ;;
##  }
##
##  dimension: hybrid_transaction_amount {
##    type: number
##    value_format_name: usd
##    sql: ${TABLE}.hybrid_transaction_amt ;;
##  }
##
##  dimension_group: hybrid_date_recorded {
##    type: time
##    timeframes: [quarter, date, month, year]
##    sql: ${TABLE}.hybrid_date_recorded ;;
##  }
##
##  dimension: barcode {
##    type: string
##    sql: ${TABLE}.barcode ;;
##  }
##
##  dimension: claim_id {
##    type: number
##    sql: ${TABLE}.claim_id ;;
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
##  dimension: invoice_type {
##    sql: ${TABLE}.invoice_type ;;
##  }
##
##  dimension: source {
##    sql: ${TABLE}.source ;;
##  }
##
##  dimension: bill_ops_source {
##    sql: ${TABLE}.bill_ops_source ;;
##  }
##
##  dimension: bill_type {
##    sql: ${TABLE}.bill_type ;;
##  }
##
##  dimension: product {
##    sql: ${TABLE}.product ;;
##  }
##
##  dimension: disease_panel {
##    sql: ${TABLE}.disease_panel ;;
##  }
##
##  dimension: methodology {
##    sql: ${TABLE}.testing_methodology ;;
##  }
##
##  dimension_group: completed_on {
##    type: time
##    timeframes: [quarter, date, month, year]
##    sql: ${TABLE}.completed_on ;;
##  }
##
##  dimension: clinic_id {
##    type: number
##    sql: ${TABLE}.clinic_id ;;
##  }
##
##  dimension: clinic_name {
##    sql: ${TABLE}.clinic_name ;;
##  }
##
##  dimension: invoicing_clinic_id {
##    type: number
##    sql: ${TABLE}.invoicing_clinic_id ;;
##  }
##
##  dimension: invoicing_clinic_name {
##    sql: ${TABLE}.invoicing_clinic_name ;;
##  }
##
##  dimension: date_of_service {
##    type: date
##    sql: ${TABLE}.date_of_service ;;
##  }
##
##  dimension: payer_name {
##    sql: ${TABLE}.payer_name ;;
##  }
##
##  dimension: invoice_sent_date {
##    type: date
##    sql: ${TABLE}.invoice_sent_date ;;
##  }
##
##  dimension: invoice_timestamp {
##    type: date
##    sql: ${TABLE}.invoice_timestamp ;;
##  }
##
##  dimension: invoice_number {
##    sql: ${TABLE}.invoice_number ;;
##  }
##
##  dimension: pretty_payer_name {
##    sql: ${TABLE}.pretty_payer_name ;;
##  }
##
##  dimension: network_status {
##    sql: ${TABLE}.network_status ;;
##  }
##
##  dimension: bill_inv_concat {
##    sql: ${TABLE}.bill_invoice_concat ;;
##  }
##
##  dimension: rev_rec_date {
##    type: date
##    sql: ${TABLE}.rev_rec_date ;;
##  }
##
##  dimension: ref_pay {
##    label: "Refund/Payment"
##    sql: ${TABLE}.ref_pay ;;
##  }
##
##  measure: transaction_sum {
##    type: sum
##    value_format_name: usd
##    sql: ${hybrid_transaction_amount} ;;
##  }
##
##  dimension: match_type {
##    sql: ${TABLE}.match_type ;;
##  }
##
##  dimension: age_of_cash_collected_tier {
##    type: tier
##    tiers: [0, 15, 30, 45, 90, 120, 180]
##    sql: extract('epoch' from ${TABLE}.deposit_date - ${TABLE}.completed_on)/3600 ;;
##  }
##
##  measure: avg_cash_collected_within_15_yield {
##    label: "Yield: Avg. Cash Collected In 15 Days"
##    description: "Yield curve for average cash collected within 15 days from completed date"
##    type: number
##    value_format_name: usd
##    sql: sum(CASE WHEN current_date - ${order.completed_date} < 15 THEN NULL
##        WHEN ${deposit_date} - ${completed_on_date} <= 15 THEN hybrid_transaction_amt ELSE 0 END) / CASE WHEN current_date - (${order.completed_week}::date + 5) > 15 THEN nullif(${yield_15_denominator},0) ELSE null END
##       ;;
##  }
##
##  measure: yield_15_denominator {
##    hidden: yes
##    type: number
##    sql: count(distinct CASE WHEN current_date - ${order.completed_date} >= 15 THEN ${claim.id} ELSE NULL END)
##      ;;
##  }
##
##  measure: avg_cash_collected_within_30_yield {
##    label: "Yield: Avg. Cash Collected In 30 Days"
##    description: "Yield curve for average cash collected within 30 days from completed date"
##    type: number
##    value_format_name: usd
##    sql: sum(CASE WHEN current_date - ${order.completed_date} < 30 THEN NULL
##        WHEN ${deposit_date} - ${completed_on_date} <= 30 THEN hybrid_transaction_amt ELSE 0 END) / CASE WHEN current_date - (${order.completed_week}::date + 5) > 30 THEN nullif(${yield_30_denominator},0) ELSE null END
##       ;;
##  }
##
##  measure: yield_30_denominator {
##    hidden: yes
##    type: number
##    sql: count(distinct CASE WHEN current_date - ${order.completed_date} >= 30 THEN ${claim.id} ELSE NULL END)
##      ;;
##  }
##
##  measure: avg_cash_collected_within_45_yield {
##    label: "Yield: Avg. Cash Collected In 45 Days"
##    description: "Yield curve for average cash collected within 45 days from completed date"
##    type: number
##    value_format_name: usd
##    sql: sum(CASE WHEN current_date - ${order.completed_date} < 45 THEN NULL
##        WHEN ${deposit_date} - ${completed_on_date} <= 45 THEN hybrid_transaction_amt ELSE 0 END) / CASE WHEN current_date - (${order.completed_week}::date + 5) > 45 THEN nullif(${yield_45_denominator},0) ELSE null END
##       ;;
##  }
##
##  measure: yield_45_denominator {
##    hidden: yes
##    type: number
##    sql: count(distinct CASE WHEN current_date - ${order.completed_date} >= 45 THEN ${claim.id} ELSE NULL END)
##      ;;
##  }
##
##  measure: avg_cash_collected_within_60_yield {
##    label: "Yield: Avg. Cash Collected In 60 Days"
##    description: "Yield curve for average cash collected within 60 days from completed date"
##    type: number
##    value_format_name: usd
##    sql: sum(CASE WHEN current_date - ${order.completed_date} < 60 THEN NULL
##        WHEN ${deposit_date} - ${completed_on_date} <= 60 THEN hybrid_transaction_amt ELSE 0 END) / CASE WHEN current_date - (${order.completed_week}::date + 5) > 60 THEN nullif(${yield_60_denominator},0) ELSE null END
##       ;;
##  }
##
##  measure: yield_60_denominator {
##    hidden: yes
##    type: number
##    sql: count(distinct CASE WHEN current_date - ${order.completed_date} >= 60 THEN ${claim.id} ELSE NULL END)
##      ;;
##  }
##
##  measure: avg_cash_collected_within_90_yield {
##    label: "Yield: Avg. Cash Collected In 90 Days"
##    description: "Yield curve for average cash collected within 90 days from completed date"
##    type: number
##    value_format_name: usd
##    sql: sum(CASE WHEN current_date - ${order.completed_date} < 90 THEN NULL
##        WHEN ${deposit_date} - ${completed_on_date} <= 90 THEN hybrid_transaction_amt ELSE 0 END) / CASE WHEN current_date - (${order.completed_week}::date + 5) > 90 THEN nullif(${yield_90_denominator},0) ELSE null END
##       ;;
##  }
##
##  measure: yield_90_denominator {
##    hidden: yes
##    type: number
##    sql: count(distinct CASE WHEN current_date - ${order.completed_date} >= 90 THEN ${claim.id} ELSE NULL END)
##      ;;
##  }
##
##  measure: avg_cash_collected_within_120_yield {
##    label: "Yield: Avg. Cash Collected In 120 Days"
##    description: "Yield curve for average cash collected within 120 days from completed date"
##    type: number
##    value_format_name: usd
##    sql: sum(CASE WHEN current_date - ${order.completed_date} < 120 THEN NULL
##        WHEN ${deposit_date} - ${completed_on_date} <= 120 THEN hybrid_transaction_amt ELSE 0 END) / CASE WHEN current_date - (${order.completed_week}::date + 5) > 120 THEN nullif(${yield_120_denominator},0) ELSE null END
##       ;;
##  }
##
##  measure: yield_120_denominator {
##    hidden: yes
##    type: number
##    sql: count(distinct CASE WHEN current_date - ${order.completed_date} >= 120 THEN ${claim.id} ELSE NULL END)
##      ;;
##  }
##
##  measure: avg_cash_collected_within_180_yield {
##    label: "Yield: Avg. Cash Collected In 180 Days"
##    description: "Yield curve for average cash collected within 180 days from completed date"
##    type: number
##    value_format_name: usd
##    sql: sum(CASE WHEN current_date - ${order.completed_date} < 180 THEN NULL
##        WHEN ${deposit_date} - ${completed_on_date} <= 180 THEN hybrid_transaction_amt ELSE 0 END) / CASE WHEN current_date - (${order.completed_week}::date + 5) > 180 THEN nullif(${yield_180_denominator},0) ELSE null END
##       ;;
##  }
##
##  measure: yield_180_denominator {
##    hidden: yes
##    type: number
##    sql: count(distinct CASE WHEN current_date - ${order.completed_date} >= 180 THEN ${claim.id} ELSE NULL END)
##      ;;
##  }
##
##  measure: avg_cash_collected_within_365_yield {
##    label: "Yield: Avg. Cash Collected In 365 Days"
##    description: "Yield curve for average cash collected within 365 days from completed date"
##    type: number
##    value_format_name: usd
##    sql: sum(CASE WHEN current_date - ${order.completed_date} < 365 THEN NULL
##        WHEN ${deposit_date} - ${completed_on_date} <= 365 THEN hybrid_transaction_amt ELSE 0 END) / CASE WHEN current_date - (${order.completed_week}::date + 5) > 365 THEN nullif(${yield_365_denominator},0) ELSE null END
##       ;;
##  }
##
##  measure: yield_365_denominator {
##    hidden: yes
##    type: number
##    sql: count(distinct CASE WHEN current_date - ${order.completed_date} >= 365 THEN ${claim.id} ELSE NULL END)
##      ;;
##  }
##
##  measure: cash_collected_within_15_yield {
##    label: "Yield: Total Cash Collected In 15 Days"
##    description: "Yield curve for total cash collected within 15 days from completed date"
##    type: number
##    value_format_name: usd_0
##    sql: sum(CASE WHEN ${deposit_date} - ${completed_on_date} <= 15 THEN hybrid_transaction_amt ELSE 0 END)
##      ;;
##  }
##
##  measure: cash_collected_within_30_yield {
##    label: "Yield: Total Cash Collected In 30 Days"
##    description: "Yield curve for total cash collected within 30 days from completed date"
##    type: number
##    value_format_name: usd_0
##    sql: sum(CASE WHEN ${deposit_date} - ${completed_on_date} <= 30 THEN hybrid_transaction_amt ELSE 0 END)
##      ;;
##  }
##
##  measure: cash_collected_within_45_yield {
##    label: "Yield: Total Cash Collected In 45 Days"
##    description: "Yield curve for total cash collected within 45 days from completed date"
##    type: number
##    value_format_name: usd_0
##    sql: sum(CASE WHEN ${deposit_date} - ${completed_on_date} <= 45 THEN hybrid_transaction_amt ELSE 0 END)
##      ;;
##  }
##
##  measure: cash_collected_within_60_yield {
##    label: "Yield: Total Cash Collected In 60 Days"
##    description: "Yield curve for total cash collected within 60 days from completed date"
##    type: number
##    value_format_name: usd_0
##    sql: sum(CASE WHEN ${deposit_date} - ${completed_on_date} <= 60 THEN hybrid_transaction_amt ELSE 0 END)
##      ;;
##  }
##
##  measure: cash_collected_within_90_yield {
##    label: "Yield: Total Cash Collected In 90 Days"
##    description: "Yield curve for total cash collected within 90 days from completed date"
##    type: number
##    value_format_name: usd_0
##    sql: sum(CASE WHEN ${deposit_date} - ${completed_on_date} <= 90 THEN hybrid_transaction_amt ELSE 0 END)
##      ;;
##  }
##
##  measure: cash_collected_within_120_yield {
##    label: "Yield: Total Cash Collected In 120 Days"
##    description: "Yield curve for cash collected within 120 days from completed date"
##    type: number
##    value_format_name: usd_0
##    sql: sum(CASE WHEN ${deposit_date} - ${completed_on_date} <= 120 THEN hybrid_transaction_amt ELSE 0 END)
##      ;;
##  }
##
##  measure: cash_collected_within_180_yield {
##    label: "Yield: Total Cash Collected In 180 Days"
##    description: "Yield curve for total cash collected within 180 days from completed date"
##    type: number
##    value_format_name: usd_0
##    sql: sum(CASE WHEN ${deposit_date} - ${completed_on_date} <= 180 THEN hybrid_transaction_amt ELSE 0 END)
##      ;;
##  }
##
##  measure: cash_collected_within_365_yield {
##    label: "Yield: Total Cash Collected In 365 Days"
##    description: "Yield curve for total cash collected within 365 days from completed date"
##    type: number
##    value_format_name: usd_0
##    sql: sum(CASE WHEN ${deposit_date} - ${completed_on_date} <= 365 THEN hybrid_transaction_amt ELSE 0 END)
##      ;;
##  }
##}
##
###- explore: matched_build_04_compute_network_status
##view: matched_build_04_compute_network_status {
##  derived_table: {
##    sql:
##      SELECT
##        coid
##        , bank_trans_id
##        , bank_account
##        , bai_code
##        , bank_ref
##        , bank_data_type
##        , deposit_amt
##        , deposit_date
##        , bank_description
##        , bank_text_desc
##        , match.bank_pkey::text AS bank_pkey
##        , known_var
##        , CASE WHEN tickmark = 'F' THEN 'Non-Revenue' ELSE rev_trn END as rev_trn
##        , eob_batch_adjs
##        , hybrid_pkey
##        , hybrid_trans_id
##        , hybrid_transaction_amt
##        , hybrid_date_recorded
##        , barcode
##        , claim_id
##        , match.order_id
##        , invoice_id
##        , invoice_type
##        , source
##        , bill_ops_source
##        , bill_type
##        , product
##        , disease_panel
##        , testing_methodology::int
##        , match.completed_on
##        , match.clinic_id
##        , clinic.name as clinic_name
##        , match.date_of_service
##        , payer_name
##        , sent as invoice_sent_date
##        , invoice.timestamp as invoice_timestamp
##        , invoice_number
##        , invoice.amount as invoice_amount
##        , pretty_payer_name
##        , network_status
##        , CASE WHEN network_status = 'OON' or network_status = 'INN' THEN
##          concat(network_status,' ',CASE WHEN invoice_type = 'Customer' THEN 'Patient'
##            WHEN invoice_type = 'Insurer' THEN 'Payer'
##            ELSE 'ERROR' END)
##          WHEN invoice_type = 'Physician' THEN 'Consignment'
##          ELSE network_status END as bill_invoice_concat
##        , CASE
##            WHEN (network_status = 'OON' or network_status is null)
##              AND (completed_on is not null and deposit_date is not null)
##              THEN
##              CASE
##                WHEN completed_on::date>= deposit_date THEN completed_on::date
##                WHEN  deposit_date > completed_on::date THEN deposit_date ELSE null
##              END
##            WHEN network_status = 'In Net' THEN
##              CASE
##                WHEN completed_on is null THEN '2020-01-01' ELSE completed_on END
##            WHEN network_status = 'Consignment' THEN '2020-01-01'
##            ELSE completed_on END as rev_rec_date
##        , ref_pay
##
##      FROM
##        ${matched_build_03_all_fields.SQL_TABLE_NAME} as match
##      LEFT JOIN
##        current.invoice on invoice.id::int = match.invoice_id::int
##      LEFT JOIN
##        (SELECT
##          bank_pkey::text
##          , tickmark
##        FROM
##          uploads.manual_final_unmatched
##        WHERE
##          tickmark = 'F'
##        GROUP BY
##          1,2
##        ) as tick on tick.bank_pkey::text = match.bank_pkey::text
##      LEFT JOIN
##        current.clinic on clinic.id = match.clinic_id
##       ;;
##    sql_trigger_value: SELECT count(hybrid_transaction_amt) from ${matched_build_03_all_fields.SQL_TABLE_NAME} ;;
##  }
##
##  dimension: bank_coid {
##    sql: ${TABLE}.coid ;;
##  }
##
##  dimension: bank_trans_id {
##    sql: ${TABLE}.bank_trans_id ;;
##  }
##
##  dimension: bank_account {
##    sql: ${TABLE}.bank_account ;;
##  }
##
##  dimension: bai_code {
##    sql: ${TABLE}.bai_code ;;
##  }
##
##  dimension: bank_ref {
##    sql: ${TABLE}.bank_ref ;;
##  }
##
##  dimension: bank_data_type {
##    sql: ${TABLE}.bank_data_type ;;
##  }
##
##  dimension: deposit_amt {
##    type: number
##    sql: ${TABLE}.deposit_amt ;;
##  }
##
##  dimension: deposit_date {
##    type: date
##    sql: ${TABLE}.deposit_date ;;
##  }
##
##  dimension: bank_description {
##    sql: ${TABLE}.bank_description ;;
##  }
##
##  dimension: bank_text_desc {
##    sql: ${TABLE}.bank_text_desc ;;
##  }
##
##  dimension: bank_pkey {
##    sql: ${TABLE}.bank_pkey ;;
##  }
##}
##
##view: matched_build_03_all_fields {
##  derived_table: {
##    sql: SELECT
##        coid
##        , trn as bank_trans_id
##        , account as bank_account
##        , bai_code
##        , bank_ref
##        , data_type as bank_data_type
##        , deposit_amt
##        , deposit_date
##        , description as bank_description
##        , text_desc as bank_text_desc
##        , bank_pkey::text
##        , known_var
##        , rev_trn
##        , eob_batch_adjs
##        , hybrid_pkey
##        , hybrid_trans_id
##        , transaction_amount as hybrid_transaction_amt
##        , date_recorded as hybrid_date_recorded
##        , barcode
##        , claim_id
##        , dep.order_id
##        , dep.invoice_id
##        , dep.invoice_type
##        , source
##        , bill_ops_source
##        , CASE WHEN sub.invoice_id is null THEN o.bill_type ELSE sub.bill_type END as bill_type
##        , o.product_name as product
##        , o.disease_panel
##        , o.testing_methodology
##        , o.completed_on
##        , CASE WHEN sub.invoice_id is null THEN o.billing_clinic_id ELSE sub.account_id END as clinic_id
##        , claim.date_of_service
##        , insurancepayer.name AS payer_name
##        , insurancepayer.display_name as pretty_payer_name
##        , CASE WHEN claim.id is not null THEN
##          CASE
##            WHEN o.product = 'Foresight Carrier Screen' and date_of_service >= fps_date and date_of_service < coalesce(inn.fps_term,'2100-01-01'::date)
##              THEN 'In Net'
##            WHEN o.product = 'Reliant Cancer Screen' and date_of_service >= ics_date and date_of_service < coalesce(inn.ics_term,'2100-01-01'::date)
##              THEN 'In Net'
##            WHEN o.product = 'Prelude Prenatal Screen' and date_of_service >= ips_date and date_of_service < coalesce(inn.ips_term,'2100-01-01'::date)
##              THEN 'In Net'
##            ELSE 'OON'
##            END
##          ELSE null END as network_status
##        , ref_pay
##
##      FROM
##        ${matched_build_02_all_deposits_with_barcodes.SQL_TABLE_NAME} as dep
##      LEFT JOIN
##        ${order.SQL_TABLE_NAME} as o on o.id = dep.order_id
##      LEFT JOIN
##        current.insuranceclaim as claim on claim.order_id = o.id
##      LEFT JOIN
##        current.insurancepayer ON insurancepayer.id = claim.payer_id
##      LEFT JOIN
##        uploads.in_network_dates_w_terminal as inn on inn.id = insurancepayer.id
##
##      --BEGIN SUBQUERY
##
##      LEFT JOIN
##        (SELECT
##          invoice_id
##          , max(clinic_id) as account_id
##          , CASE WHEN invoice_type = 'Physician' THEN 'cnsmt' ELSE bill_type END as bill_type
##        FROM
##          ${invoiceitem.SQL_TABLE_NAME} as invoiceitem
##        INNER JOIN
##          current.order as o on o.id = invoiceitem.order_id
##        WHERE
##          invoiceitem.invoice_type = 'Physician'
##        GROUP BY
##          1,3
##        ) as sub on sub.invoice_id = dep.invoice_id
##
##      --END SUBQUERY
##       ;;
##    sql_trigger_value: select sum(transaction_amount) from ${matched_build_02_all_deposits_with_barcodes.SQL_TABLE_NAME} ;;
##  }
##
##  dimension: bank_coid {
##    sql: ${TABLE}.coid ;;
##  }
##
##  dimension: bank_trans_id {
##    sql: ${TABLE}.bank_trans_id ;;
##  }
##
##  dimension: bank_account {
##    sql: ${TABLE}.bank_account ;;
##  }
##
##  dimension: bai_code {
##    sql: ${TABLE}.bai_code ;;
##  }
##
##  dimension: bank_ref {
##    sql: ${TABLE}.bank_ref ;;
##  }
##
##  dimension: bank_data_type {
##    sql: ${TABLE}.bank_data_type ;;
##  }
##
##  dimension: deposit_amt {
##    type: number
##    sql: ${TABLE}.deposit_amt ;;
##  }
##
##  dimension: deposit_date {
##    type: date
##    sql: ${TABLE}.deposit_date ;;
##  }
##
##  dimension: bank_description {
##    sql: ${TABLE}.bank_description ;;
##  }
##
##  dimension: bank_text_desc {
##    sql: ${TABLE}.bank_text_desc ;;
##  }
##
##  dimension: bank_pkey {
##    sql: ${TABLE}.bank_pkey ;;
##  }
##
##  dimension: known_var {
##    type: yesno
##    sql: ${TABLE}.known_var ;;
##  }
##
##  dimension: rev_trn {
##    sql: ${TABLE}.rev_trn ;;
##  }
##
##  dimension: eob_batch_adjs {
##    type: number
##    sql: ${TABLE}.eob_batch_adjs ;;
##  }
##
##  dimension: hybrid_pkey {
##    sql: ${TABLE}.hybrid_pkey ;;
##  }
##
##  dimension: hybrid_trans_id {
##    sql: ${TABLE}.hybrid_trans_id ;;
##  }
##
##  dimension: hybrid_transaction_amount {
##    type: number
##    sql: ${TABLE}.hybrid_transaction_amt ;;
##  }
##
##  dimension: hybrid_date_recorded {
##    type: date
##    sql: ${TABLE}.hybrid_date_recorded ;;
##  }
##
##  dimension: barcode {
##    type: number
##    sql: ${TABLE}.barcode ;;
##  }
##
##  dimension: claim_id {
##    type: number
##    sql: ${TABLE}.claim_id ;;
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
##  dimension: invoice_type {
##    sql: ${TABLE}.invoice_type ;;
##  }
##
##  dimension: source {
##    sql: ${TABLE}.source ;;
##  }
##
##  dimension: bill_ops_source {
##    sql: ${TABLE}.bill_ops_source ;;
##  }
##
##  dimension: bill_type {
##    sql: ${TABLE}.bill_type ;;
##  }
##
##  dimension: product {
##    sql: ${TABLE}.product ;;
##  }
##
##  dimension: disease_panel {
##    sql: ${TABLE}.disease_panel ;;
##  }
##
##  dimension: methodology {
##    sql: ${TABLE}.testing_methodology ;;
##  }
##
##  dimension: completed_on {
##    type: date
##    sql: ${TABLE}.completed_on ;;
##  }
##
##  dimension: clinic {
##    sql: ${TABLE}.clinic_id ;;
##  }
##
##  dimension: date_of_service {
##    type: date
##    sql: ${TABLE}.date_of_service ;;
##  }
##
##  dimension: payer_name {
##    sql: ${TABLE}.payer_name ;;
##  }
##}
##
##view: matched_build_02_all_deposits_with_barcodes {
##  derived_table: {
##    sql: SELECT
##        coid
##        , bank.trn
##        , bank.account
##        , bank.bai_code
##        , bank_ref
##        , bank.data_type
##        , bank.deposit_amt
##        , bank.deposit_date
##        , description
##        , bank.text_desc
##        , bank.pkey::text as bank_pkey
##        , known_var
##        , rev_trn
##        , coalesce(eob_batch_match.eob_batch_adjs,0) as eob_batch_adjs
##        , hybrid_pkey
##        , hybrid_trans_id
##        , transaction_amount
##        , date_recorded
##        , barcode
##        , claim_id
##        , order_id
##        , invoice_id
##        , invoice_type
##        , source
##        , bill_ops_source
##        , bank.ref_pay
##        , '' as filler
##      FROM
##        ${bank_statement_deposits.SQL_TABLE_NAME} as bank
##
##      --BEGIN SUBQUERY
##
##      LEFT JOIN
##        (SELECT
##          bank_pkey::text
##          , CASE WHEN max(eob_batch_adjs) = 0 and min(eob_batch_adjs) < 0 THEN min(eob_batch_adjs)
##            WHEN min(eob_batch_adjs) = 0 and max(eob_batch_adjs) > 0 THEN max(eob_batch_adjs)
##            ELSE max(eob_batch_adjs) END as eob_batch_adjs
##        FROM
##          ${matched_build_01_union_all_barcodes.SQL_TABLE_NAME}
##        GROUP BY
##          1
##        ) as eob_batch_match on bank.pkey::text = eob_batch_match.bank_pkey::text
##
##      --END SUBQUERY
##
##      LEFT JOIN
##        ${matched_build_01_union_all_barcodes.SQL_TABLE_NAME} as match on match.bank_pkey::text = bank.pkey::text
##
##      --BEGIN Subquery
##
##      LEFT JOIN
##        (SELECT
##          bank_pkey::text
##          , max(source) as bill_ops_source
##        FROM
##          uploads.given_to_bill_ops
##        GROUP BY
##          1
##        ) as bo on bo.bank_pkey::text = bank.pkey::text
##
##      --END SUBQUERY
##
##      WHERE
##        (bank.data_type is null or bank.data_type = 'Credits' or bank.data_type = 'Credit Card' or bank.data_type = 'Stripe Transaction')
##        and (bank.bai_code is null or bank.bai_code != '275')
##        and (date_part('year', bank.deposit_date) >= 2017)
##        and position('Lockbox Deposit' in bank.text_desc) != 1
##        and position('STRIPE' in bank.text_desc) != 1
##       ;;
##    sql_trigger_value: select sum(transaction_amount) from ${matched_build_01_union_all_barcodes.SQL_TABLE_NAME} ;;
##  }
##
##  dimension: deposit_date {
##    type: date
##    sql: ${TABLE}.deposit_date ;;
##  }
##
##  dimension: bank_trans_id {
##    sql: ${TABLE}.trn ;;
##  }
##
##  dimension: deposit_amt {
##    type: number
##    sql: ${TABLE}.deposit_amt ;;
##  }
##
##  dimension: bank_pkey {
##    sql: ${TABLE}.bank_pkey ;;
##  }
##
##  dimension: text_desc {
##    sql: ${TABLE}.text_desc ;;
##  }
##
##  dimension: hybrid_trans_id {
##    sql: ${TABLE}.hybrid_trans_id ;;
##  }
##
##  dimension: barcode {
##    sql: ${TABLE}.barcode ;;
##  }
##
##  dimension: transaction_amount {
##    type: number
##    sql: ${TABLE}.transaction_amount ;;
##  }
##
##  dimension: invoice_id {
##    type: number
##    sql: ${TABLE}.invoice_id ;;
##  }
##
##  dimension: invoice_type {
##    sql: ${TABLE}.invoice_type ;;
##  }
##
##  dimension: hybrid_pkey {
##    sql: ${TABLE}.hybrid_pkey ;;
##  }
##
##  dimension: date_recorded {
##    type: date
##    sql: ${TABLE}.date_recorded ;;
##  }
##
##  dimension: claim_id {
##    type: number
##    sql: ${TABLE}.claim_id ;;
##  }
##
##  dimension: order_id {
##    type: number
##    sql: ${TABLE}.order_id ;;
##  }
##
##  dimension: account {
##    sql: ${TABLE}.account ;;
##  }
##
##  dimension: bai_code {
##    sql: ${TABLE}.bai_code ;;
##  }
##
##  dimension: source {
##    sql: ${TABLE}.source ;;
##  }
##
##  dimension: eob_batch_adjs {
##    type: number
##    sql: ${TABLE}.eob_batch_adjs ;;
##  }
##
##  dimension: coid {
##    sql: ${TABLE}.coid ;;
##  }
##
##  dimension: bank_ref {
##    sql: ${TABLE}.bank_ref ;;
##  }
##
##  dimension: known_var {
##    sql: ${TABLE}.known_var ;;
##  }
##
##  dimension: rev_trn {
##    label: "Rev Related?"
##    sql: ${TABLE}.rev_trn ;;
##  }
##
##  dimension: billing_ops_source {
##    sql: ${TABLE}.bill_ops_source ;;
##  }
##}
##
##view: matched_build_01_union_all_barcodes {
##  derived_table: {
##    sql: SELECT
##        deposit_date
##        , account
##        , bai_code
##        , bank.trn as bank_trans_id
##        , deposit_amt
##        , CASE WHEN max(eob_batch_adjs) = 0 and min(eob_batch_adjs) < 0 THEN min(eob_batch_adjs)
##            WHEN min(eob_batch_adjs) = 0 and max(eob_batch_adjs) > 0 THEN max(eob_batch_adjs)
##            ELSE max(eob_batch_adjs) END as eob_batch_adjs
##        , hybrid_pkey
##        , transaction_id as hybrid_trans_id
##        , transaction_amount
##        , date_recorded
##        , latest_barcode as barcode
##        , claim_id
##        , order_id
##        , invoice_id
##        , invoice_type
##        , bank_pkey::text
##        , text_desc
##        , min(union_subquery.source) as source
##
##      FROM
##        (SELECT
##            0.00 as eob_batch_adjs
##            , hybrid_pkey
##            , bank_pkey::text
##            , 'auto - new lockbox' as source
##          FROM
##            ${matched_barcodes_01a_lockbox_acct_trn.SQL_TABLE_NAME}
##        UNION
##          SELECT
##            eob_batch_adjs
##            , hybrid_pkey
##            , bank_pkey::text
##            , 'auto - new lockbox era' as source
##          FROM
##            ${matched_barcodes_01b_lockbox_insurer_era.SQL_TABLE_NAME}
##        UNION
##          SELECT
##            eob_batch_adjs
##            , hybrid_pkey
##            , bank_pkey::text
##            , 'auto - bofa refunds' as source
##          FROM
##            ${matched_barcodes_01c_lockbox_check_refunds.SQL_TABLE_NAME}
##        UNION
##          SELECT
##            eob_batch_adjs
##            , hybrid_pkey
##            , bank_pkey::text
##            , 'auto - verafund lockbox' as source
##          FROM
##            ${matched_barcodes_01d_verafund_lockbox.SQL_TABLE_NAME}
##        UNION
##          SELECT
##            eob_batch_adjs
##            , hybrid_pkey
##            , bank_pkey::text
##            , 'auto - lockbox extra digits' as source
##          FROM ${matched_barcodes_01e_lockbox_insurer_era_extra_digits_in_front.SQL_TABLE_NAME}
##        UNION
##          SELECT
##          eob_batch_adjs
##          , hybrid_pkey
##          , bank_pkey::text
##          , 'auto - unique ach cc' as source
##        FROM
##          ${matched_barcodes_02a_electronic_payer_clinic_deposits.SQL_TABLE_NAME}
##        UNION
##          SELECT
##          eob_batch_adjs
##          , hybrid_pkey
##          , bank_pkey::text
##          , 'auto - stripe cc' as source
##        FROM
##          ${matched_barcodes_02b1_stripe.SQL_TABLE_NAME}
##        UNION
##          SELECT
##          eob_batch_adjs
##          , hybrid_pkey
##          , bank_pkey::text
##          , 'auto - stripe cc refunds' as source
##        FROM
##          ${matched_barcodes_02b2_stripe_refunds.SQL_TABLE_NAME}
##        UNION
##          SELECT
##          eob_batch_adjs
##          , hybrid_pkey
##          , bank_pkey::text
##          , 'auto - kaiser match' as source
##        FROM
##          ${matched_barcodes_02c_kaiser.SQL_TABLE_NAME}
##
##        UNION
##          SELECT
##          eob_batch_adjs
##          , hybrid_pkey
##          , bank_pkey::text
##          , 'auto - rounded 16' as source
##          FROM
##            ${matched_barcodes_02e_rounded_to_16_chars.SQL_TABLE_NAME}
##        UNION
##          SELECT
##            eob_batch_adjs
##            , hybrid_pkey
##            , bank_pkey::text
##            , 'auto - pg' as source
##          FROM
##            ${matched_barcodes_02f_check_number_prefixes.SQL_TABLE_NAME}
##        UNION
##          SELECT
##            eob_batch_adjs
##            , hybrid_pkey
##            , bank_pkey::text
##            , 'auto - connecticare' as source
##          FROM
##            ${matched_barcodes_02g_connecticare.SQL_TABLE_NAME}
##        UNION
##          SELECT
##            eob_batch_adjs
##            , hybrid_pkey
##            , bank_pkey::text
##            , 'auto - natera' as source
##          FROM
##            ${matched_barcodes_02h_consignment_wires.SQL_TABLE_NAME}
##        UNION
##          SELECT
##            eob_batch_adjs
##            , hybrid_pkey
##            , bank_pkey::text
##            , 'auto - beacon' as source
##          FROM
##            ${matched_barcodes_02i_beacon.SQL_TABLE_NAME}
##        UNION
##          SELECT
##            eob_batch_adjs
##            , hybrid_pkey
##            , bank_pkey::text
##            , 'manual - q3 manual upload eob' as source
##          FROM
##            ${matched_barcodes_03a_manual_upload_eob_batches.SQL_TABLE_NAME}
##        UNION
##          SELECT
##            eob_batch_adjs
##            , hybrid_pkey
##            , bank_pkey::text
##            , 'manual - q3 manual upload payment' as source
##          FROM
##            ${matched_barcodes_03b_manual_upload_payments.SQL_TABLE_NAME}
##        UNION
##          SELECT
##            eob_batch_adjs
##            , hybrid_pkey
##            , bank_pkey::text
##            , 'manual - interest only' as source
##          FROM
##            ${matched_barcodes_03c_interest_only.SQL_TABLE_NAME}
##        ) as union_subquery
##      LEFT JOIN
##        uploads.custom_hybrid_file as hybrid on hybrid.pkey = union_subquery.hybrid_pkey
##      LEFT JOIN
##        ${bank_statement_deposits.SQL_TABLE_NAME} as bank on bank.pkey::text = union_subquery.bank_pkey::text
##      GROUP BY
##        1,2,3,4,5,7,8,9,10,11,12,13,14,15,16,17
##       ;;
##    sql_trigger_value:
##      select sum(trigger) from (
##        SELECT count(*) as trigger from ${matched_barcodes_01a_lockbox_acct_trn.SQL_TABLE_NAME}
##        UNION ALL SELECT count(*) as trigger from ${matched_barcodes_01b_lockbox_insurer_era.SQL_TABLE_NAME}
##        UNION ALL SELECT count(*) as trigger from ${matched_barcodes_01c_lockbox_check_refunds.SQL_TABLE_NAME}
##        UNION ALL SELECT count(*) as trigger from ${matched_barcodes_01d_verafund_lockbox.SQL_TABLE_NAME}
##        UNION ALL SELECT count(*) as trigger from ${matched_barcodes_01e_lockbox_insurer_era_extra_digits_in_front.SQL_TABLE_NAME}
##        UNION ALL SELECT count(*) as trigger from ${matched_barcodes_02a_electronic_payer_clinic_deposits.SQL_TABLE_NAME}
##        UNION ALL SELECT count(*) as trigger from ${matched_barcodes_02b1_stripe.SQL_TABLE_NAME}
##        UNION ALL SELECT count(*) as trigger from ${matched_barcodes_02c_kaiser.SQL_TABLE_NAME}
##        UNION ALL SELECT count(*) as trigger from ${matched_barcodes_02e_rounded_to_16_chars.SQL_TABLE_NAME}
##        UNION ALL SELECT count(*) as trigger from ${matched_barcodes_02f_check_number_prefixes.SQL_TABLE_NAME}
##        UNION ALL SELECT count(*) as trigger from ${matched_barcodes_02g_connecticare.SQL_TABLE_NAME}
##        UNION ALL SELECT count(*) as trigger from ${matched_barcodes_02h_consignment_wires.SQL_TABLE_NAME}
##        UNION ALL SELECT count(*) as trigger from ${matched_barcodes_03a_manual_upload_eob_batches.SQL_TABLE_NAME}
##        UNION ALL SELECT count(*) as trigger from ${matched_barcodes_03b_manual_upload_payments.SQL_TABLE_NAME}) as t ;;
##  }
##
##  dimension: bank_trans_id {
##    sql: ${TABLE}.bank_trans_id ;;
##  }
##
##  dimension: eob_batch_adjs {
##    sql: ${TABLE}.eob_batch_adjs ;;
##  }
##
##  dimension: hybrid_pkey {
##    sql: ${TABLE}.hybrid_pkey ;;
##  }
##
##  dimension: transaction_amount {
##    sql: ${TABLE}.transaction_amount ;;
##  }
##
##  dimension: bank_pkey {
##    sql: ${TABLE}.bank_pkey ;;
##  }
##
##  dimension: source {
##    sql: ${TABLE}.source ;;
##  }
##}
##
##view: match_lockbox_hybrid_file_trunc_ids {
##  derived_table: {
##    sql: SELECT
##        transaction_id
##        --, concat(right(substring(transaction_id for position('-' in transaction_id) - 1),10),'-',right(substring(transaction_id from position('-' in transaction_id) +1),least(8,char_length(substring(transaction_id from position('-' in transaction_id) +1))))) as trunc_id
##        , CASE WHEN position('-' in transaction_id) > 0 THEN
##            concat(trim(leading '0' from right(substring(transaction_id for position('-' in transaction_id) -1),10)),'-',trim(leading '0' from right(substring(transaction_id from position('-' in transaction_id) + 1),8)))
##            ELSE concat(trim(leading '0' from right(substring(transaction_id for position('-' in transaction_id) -1),10)),'-',trim(leading '0' from right(substring(transaction_id from position('' in transaction_id) + 1),8))) END as trunc_id
##        , ref_pay
##        , sum(transaction_amount) as total_transaction_amount
##      FROM
##        uploads.custom_hybrid_file as hyb
##      WHERE
##        position('-' in transaction_id) > 0 or position('-' in transaction_id) > 0
##      GROUP BY
##        1,2,3
##       ;;
##    sql_trigger_value: select count(*) from uploads.custom_hybrid_file ;;
##  }
##
##  dimension: transaction_id {
##    sql: ${TABLE}.transaction_Id ;;
##  }
##
##  dimension: trunc_id {
##    sql: ${TABLE}.trunc_id ;;
##  }
##}
##
##view: matched_barcodes_01a_lockbox_acct_trn {
##  derived_table: {
##    sql: SELECT
##        eob_batch_adjs
##        , hybrid.pkey as hybrid_pkey
##        , bank_pkey
##
##      FROM
##        (SELECT
##          bank.pkey::text as bank_pkey
##          , coalesce(CASE WHEN interest.interest <> 0 THEN interest.interest * -1 ELSE 0.00 END,0) as eob_batch_adjs
##          , bank.ref_pay
##          , transaction_id as hybrid_trans_id
##        FROM
##          ${bank_statement_deposits.SQL_TABLE_NAME} as bank
##
##        --BEGIN FIRST SUBQUERY which groups hybrid transactions by ID and sums amount posted, eob_batch_adjustments
##
##        INNER JOIN
##          ${match_lockbox_hybrid_file_trunc_ids.SQL_TABLE_NAME} as hybrid on hybrid.trunc_id = concat(trim(leading '0' from account),'-',trim(leading '0' from trn)) and bank.ref_pay = hybrid.ref_pay
##
##        --END FIRST SUBQUERY
##
##        LEFT JOIN
##            uploads.interest as interest on interest.pkey::text = bank.pkey::text
##
##        WHERE
##          (bai_code = '115') and date_part('year', deposit_date) >= 2017
##        ) as lbx
##      INNER JOIN
##        uploads.custom_hybrid_file as hybrid on hybrid.transaction_id = lbx.hybrid_trans_id and lbx.ref_pay = hybrid.ref_pay
##       ;;
##    sql_trigger_value: select count(transaction_id) from ${match_lockbox_hybrid_file_trunc_ids.SQL_TABLE_NAME} ;;
##  }
##
##  dimension: hybrid_trans_id {
##    sql: ${TABLE}.hybrid_trans_id ;;
##  }
##}
##
##view: matched_barcodes_01b_lockbox_insurer_era {
##  derived_table: {
##    sql: SELECT
##        lbx.eob_batch_adjs
##        , hybrid.pkey as hybrid_pkey
##        , lbx.bank_pkey
##
##      FROM
##        (SELECT
##          bank.pkey::text as bank_pkey
##          , transaction_id as hybrid_trans_id
##          , coalesce(CASE WHEN interest.interest <> 0 THEN interest.interest * -1 ELSE hybrid.eob_batch_adjs END,0) as eob_batch_adjs
##          , bank.deposit_date
##          , bank.ref_pay
##        FROM
##          ${bank_statement_deposits.SQL_TABLE_NAME} as bank
##
##        --BEGIN FIRST SUBQUERY which groups hybrid transactions by ID and sums amount posted, eob_batch_adjustments
##
##        INNER JOIN
##          (SELECT
##            transaction_id
##            , hyb.ref_pay
##            , coalesce(eob_batch_adjustments,0) as eob_batch_adjs
##            , sum(transaction_amount) as total_transaction_amount
##          FROM
##            uploads.custom_hybrid_file as hyb
##
##          LEFT JOIN
##            (SELECT
##              CASE WHEN
##                eobbatch.id = 84652 --this eobbatch adj was issued in the wrong direction
##              THEN -1 * sum(value)
##              ELSE sum(value) END as eob_batch_adjustments
##              , eobbatch.id
##              , CASE WHEN trim(leading '0' from check_or_eft_trace_number) = '' THEN check_or_eft_trace_number ELSE trim(leading '0' from check_or_eft_trace_number) END as check_or_eft_trace_number
##            FROM
##              current.eobbatchadjustment
##            INNER JOIN
##              current.eobbatch on eobbatch.id = eobbatchadjustment.eob_batch_id
##            WHERE
##              duplicate_of_eob_batch_id is null
##            GROUP BY
##              2,3
##            ) as eob_batch_adjs on eob_batch_adjs.check_or_eft_trace_number = hyb.transaction_id
##
##          WHERE
##            date_recorded >= '2015-12-01' and invoice_type = 'Insurer' and trim(leading '0' from transaction_id) != ''
##          GROUP BY
##            1,2,3
##          ) as hybrid on right(hybrid.transaction_id,8) = bank.trn and bank.ref_pay = hybrid.ref_pay
##
##        --END FIRST SUBQUERY
##
##        LEFT JOIN
##            uploads.interest as interest on interest.pkey::text = bank.pkey::text
##
##        WHERE
##          ((bai_code = '115') and date_part('year', deposit_date) >= 2017
##          and bank.text_desc != '0')
##          and (data_type is null or (data_type != 'Stripe Transaction' and data_type != 'WFMSTRIPE1'))
##        ) as lbx
##      INNER JOIN
##        uploads.custom_hybrid_file as hybrid on hybrid.transaction_id = hybrid_trans_id and lbx.ref_pay = hybrid.ref_pay
##      LEFT JOIN
##        ${matched_barcodes_01a_lockbox_acct_trn.SQL_TABLE_NAME} as lbx_1a on lbx_1a.bank_pkey = lbx.bank_pkey
##      WHERE
##        hybrid.invoice_type = 'Insurer' and hybrid.date_recorded >= '2015-12-01'
##        and lbx_1a.bank_pkey is null
##        and (lbx.deposit_date::date - hybrid.date_recorded::date) <= 90
##       ;;
##    sql_trigger_value: select count(*) from uploads.custom_hybrid_file ;;
##  }
##
##  dimension: account {
##    sql: ${TABLE}.account ;;
##  }
##
##  dimension: bank_trans_id {
##    sql: ${TABLE}.bank_trans_id ;;
##  }
##
##  dimension: invoice_type {
##    sql: ${TABLE}.invoice_type ;;
##  }
##
##  dimension: hybrid_trans_id {
##    sql: ${TABLE}.hybrid_trans_id ;;
##  }
##
##  dimension: claim_id {
##    sql: ${TABLE}.claim_id ;;
##  }
##
##  dimension: transaction_amount {
##    sql: ${TABLE}.transaction_amount ;;
##  }
##
##  dimension: deposit_amt {
##    sql: ${TABLE}.deposit_amt ;;
##  }
##
##  dimension: hybrid_pkey {
##    sql: ${TABLE}.hybrid_pkey ;;
##  }
##
##  dimension: barcode {
##    sql: ${TABLE}.barcode ;;
##  }
##}
##
##view: matched_barcodes_01c_lockbox_check_refunds {
##  derived_table: {
##    sql: SELECT
##        eob_batch_adjs
##        , hybrid.pkey as hybrid_pkey
##        , bank_pkey
##
##      FROM
##        (SELECT
##          bank.pkey::text as bank_pkey
##          , transaction_id as hybrid_trans_id
##          , coalesce(CASE WHEN interest.interest <> 0 THEN interest.interest * -1 ELSE hybrid.eob_batch_adjs END,0) as eob_batch_adjs
##          , bank.ref_pay
##        FROM
##          ${bank_statement_deposits.SQL_TABLE_NAME} as bank
##
##        --BEGIN FIRST SUBQUERY which groups hybrid transactions by ID and sums amount posted, eob_batch_adjustments
##
##        INNER JOIN
##          (SELECT
##            transaction_id
##            , hyb.ref_pay
##            , 0 as eob_batch_adjs
##            , sum(transaction_amount) as total_transaction_amount
##          FROM
##            uploads.custom_hybrid_file as hyb
##          GROUP BY
##            1,2,3
##          ) as hybrid on transaction_id = bank.trn and bank.ref_pay = hybrid.ref_pay
##
##        --END FIRST SUBQUERY
##
##        LEFT JOIN
##            uploads.interest as interest on interest.pkey::text = bank.pkey::text
##
##        WHERE
##          bank.ref_pay = 'Refund'
##          and bai_code = '115'
##          and date_part('year', deposit_date) >= 2017
##          and position('BOFA' in bank.text_desc) = 1
##        ) as lbx
##      INNER JOIN
##        uploads.custom_hybrid_file as hybrid on hybrid.transaction_id = hybrid_trans_id and lbx.ref_pay = hybrid.ref_pay
##       ;;
##    sql_trigger_value: select count(*) from uploads.custom_hybrid_file ;;
##  }
##
##  dimension: bank_trans_id {
##    sql: ${TABLE}.bank_trans_id ;;
##  }
##
##  dimension: eob_batch_adjs {
##    sql: ${TABLE}.eob_batch_adjs ;;
##  }
##
##  dimension: hybrid_pkey {
##    sql: ${TABLE}.hybrid_pkey ;;
##  }
##}
##
##view: matched_barcodes_01d_verafund_lockbox {
##  derived_table: {
##    sql: SELECT
##        eob_batch_adjs
##        , hybrid.pkey as hybrid_pkey
##        , bank_pkey
##        , 'filler' as filler
##        , total_transaction_amount
##
##      FROM
##        (SELECT
##          bank.pkey::text as bank_pkey
##          , transaction_id as hybrid_trans_id
##          , coalesce(CASE WHEN interest.interest <> 0 THEN interest.interest * -1 ELSE hybrid.eob_batch_adjs END,0) as eob_batch_adjs
##          , bank.ref_pay
##          , total_transaction_amount
##        FROM
##          ${bank_statement_deposits.SQL_TABLE_NAME} as bank
##
##        --BEGIN FIRST SUBQUERY which groups hybrid transactions by ID and sums amount posted, eob_batch_adjustments
##
##        INNER JOIN
##          (SELECT
##            deposit_date::date as deposit_date
##            , substring(transaction_id from position('-' in transaction_id) + 1) as transaction_id
##            , hyb.ref_pay
##            , eob_batch_adjustments as eob_batch_adjs
##            , sum(transaction_amount) as total_transaction_amount
##          FROM
##            uploads.custom_hybrid_file as hyb
##          INNER JOIN
##            (SELECT check_number, deposit_date from uploads.verafund_translator group by 1,2) vt on vt.check_number = substring(hyb.transaction_id from position('-' in hyb.transaction_id) + 1) and (hyb.source = 'eob1' or hyb.source = 'eob2')
##          LEFT JOIN
##            (SELECT
##              sum(value) as eob_batch_adjustments
##              , CASE
##                WHEN x12_payer_payer_id = 1275 THEN concat('Avalon_',trim(leading '0' from check_or_eft_trace_number))
##                WHEN trim(leading '0' from check_or_eft_trace_number) = '' THEN check_or_eft_trace_number ELSE trim(leading '0' from check_or_eft_trace_number) END as check_or_eft_trace_number
##            FROM
##              current.eobbatchadjustment
##            INNER JOIN
##              current.eobbatch on eobbatch.id = eobbatchadjustment.eob_batch_id
##            WHERE
##              duplicate_of_eob_batch_id is null
##            GROUP BY
##              2
##            ) as eob_batch_adjs on eob_batch_adjs.check_or_eft_trace_number = hyb.transaction_id
##          GROUP BY
##            1,2,3,4
##          ) as hybrid on hybrid.deposit_date = bank.deposit_date::date
##
##        --END FIRST SUBQUERY
##
##        LEFT JOIN
##            uploads.interest as interest on interest.pkey::text = bank.pkey::text
##
##        WHERE
##          left(bank.text_desc,9) = 'VERA-FUND'
##        ) as lbx
##      INNER JOIN
##        uploads.custom_hybrid_file as hybrid on substring(hybrid.transaction_id from position('-' in hybrid.transaction_id) + 1) = hybrid_trans_id and lbx.ref_pay = hybrid.ref_pay and (hybrid.source = 'eob1' or hybrid.source = 'eob2')
##       ;;
##    sql_trigger_value: select count(*) from uploads.custom_hybrid_file ;;
##  }
##
##  dimension: bank_pkey {
##    sql: ${TABLE}.bank_pkey ;;
##  }
##
##  dimension: eob_batch_adjs {
##    sql: ${TABLE}.eob_batch_adjs ;;
##  }
##
##  dimension: hybrid_pkey {
##    sql: ${TABLE}.hybrid_pkey ;;
##  }
##
##  dimension: total_transaction_amount {
##    sql:  ${TABLE}.total_transaction_amount ;;
##  }
##}
##
##view: matched_barcodes_01e_lockbox_insurer_era_extra_digits_in_front {
##  derived_table: {
##    sql: SELECT
##        lbx.eob_batch_adjs
##        , hybrid.pkey as hybrid_pkey
##        , lbx.bank_pkey
##
##      FROM
##        (SELECT
##          bank.pkey::text as bank_pkey
##          , transaction_id as hybrid_trans_id
##          , coalesce(CASE WHEN interest.interest <> 0 THEN interest.interest * -1 ELSE hybrid.eob_batch_adjs END,0) as eob_batch_adjs
##          , bank.deposit_date
##          , bank.ref_pay
##        FROM
##          ${bank_statement_deposits.SQL_TABLE_NAME} as bank
##
##        --BEGIN FIRST SUBQUERY which groups hybrid transactions by ID and sums amount posted, eob_batch_adjustments
##
##        INNER JOIN
##          (SELECT
##            trim(leading '0' from right(transaction_id,8)) transaction_id
##            , hyb.ref_pay
##            , coalesce(eob_batch_adjustments,0) as eob_batch_adjs
##            , sum(transaction_amount) as total_transaction_amount
##          FROM
##            uploads.custom_hybrid_file as hyb
##
##          LEFT JOIN
##            (SELECT
##              CASE WHEN
##                eobbatch.id = 84652 --this eobbatch adj was issued in the wrong direction
##              THEN -1 * sum(value)
##              ELSE sum(value) END as eob_batch_adjustments
##              , eobbatch.id
##              , CASE WHEN trim(leading '0' from check_or_eft_trace_number) = '' THEN check_or_eft_trace_number ELSE trim(leading '0' from check_or_eft_trace_number) END as check_or_eft_trace_number
##            FROM
##              current.eobbatchadjustment
##            INNER JOIN
##              current.eobbatch on eobbatch.id = eobbatchadjustment.eob_batch_id
##            WHERE
##              duplicate_of_eob_batch_id is null
##            GROUP BY
##              2,3
##            ) as eob_batch_adjs on eob_batch_adjs.check_or_eft_trace_number = hyb.transaction_id
##          LEFT JOIN (SELECT distinct hybrid_pkey from ${matched_barcodes_01b_lockbox_insurer_era.SQL_TABLE_NAME}) as match on match.hybrid_pkey = hyb.pkey
##
##          WHERE
##            date_recorded >= '2015-12-01' and invoice_type = 'Insurer' and trim(leading '0' from transaction_id) != ''
##          GROUP BY
##            1,2,3
##          ) as hybrid on trim(leading '0' from right(hybrid.transaction_id,8)) = bank.trn and bank.ref_pay = hybrid.ref_pay
##
##
##        --END FIRST SUBQUERY
##
##        LEFT JOIN
##            uploads.interest as interest on interest.pkey::text = bank.pkey::text
##        LEFT JOIN
##          (SELECT distinct bank_pkey from ${matched_barcodes_01a_lockbox_acct_trn.SQL_TABLE_NAME}) as lbx_1a on lbx_1a.bank_pkey = bank.pkey
##        LEFT JOIN
##          (SELECT distinct bank_pkey from ${matched_barcodes_01b_lockbox_insurer_era.SQL_TABLE_NAME}) as lbx_1b on lbx_1b.bank_pkey = bank.pkey
##
##        WHERE
##          ((bai_code = '115') and date_part('year', deposit_date) >= 2017
##          and bank.text_desc != '0' and bank.text_desc is not null and bank.text_desc != '')
##          and (data_type is null or (data_type != 'Stripe Transaction' and data_type != 'WFMSTRIPE1'))
##          and lbx_1a.bank_pkey is null
##          and lbx_1b.bank_pkey is null
##        ) as lbx
##      INNER JOIN
##        uploads.custom_hybrid_file as hybrid on trim(leading '0' from right(hybrid.transaction_id,8)) = hybrid_trans_id and lbx.ref_pay = hybrid.ref_pay
##      LEFT JOIN
##        (SELECT distinct hybrid_pkey from ${matched_barcodes_01b_lockbox_insurer_era.SQL_TABLE_NAME}) as match on match.hybrid_pkey = hybrid.pkey
##      WHERE
##        hybrid.invoice_type = 'Insurer' and hybrid.date_recorded >= '2015-12-01'
##        and match.hybrid_pkey is null
##        and (lbx.deposit_date::date - hybrid.date_recorded::date) <= 90
##       ;;
##    sql_trigger_value: select count(*) from uploads.custom_hybrid_file ;;
##  }
##
##  dimension: account {
##    sql: ${TABLE}.account ;;
##  }
##
##  dimension: bank_trans_id {
##    sql: ${TABLE}.bank_trans_id ;;
##  }
##
##  dimension: invoice_type {
##    sql: ${TABLE}.invoice_type ;;
##  }
##
##  dimension: hybrid_trans_id {
##    sql: ${TABLE}.hybrid_trans_id ;;
##  }
##
##  dimension: claim_id {
##    sql: ${TABLE}.claim_id ;;
##  }
##
##  dimension: transaction_amount {
##    sql: ${TABLE}.transaction_amount ;;
##  }
##
##  dimension: deposit_amt {
##    sql: ${TABLE}.deposit_amt ;;
##  }
##
##  dimension: hybrid_pkey {
##    sql: ${TABLE}.hybrid_pkey ;;
##  }
##
##  dimension: barcode {
##    sql: ${TABLE}.barcode ;;
##  }
##}
##
##view: matched_barcodes_02a_electronic_payer_clinic_deposits {
##  derived_table: {
##    sql: SELECT
##        eob_batch_adjs
##        , hybrid.pkey as hybrid_pkey
##        , bank_pkey
##
##      FROM
##        (SELECT
##          bank.pkey::text as bank_pkey
##          , bank.ref_pay
##          , transaction_id as hybrid_trans_id
##          , bank.deposit_date
##          , coalesce(CASE WHEN interest.interest <> 0 THEN interest.interest * -1 ELSE hybrid.eob_batch_adjs END,0) as eob_batch_adjs
##        FROM
##          ${bank_statement_deposits.SQL_TABLE_NAME} as bank
##
##        --BEGIN FIRST SUBQUERY which groups hybrid transactions by ID and sums amount posted, eob_batch_adjustments
##
##        INNER JOIN
##          (SELECT
##            transaction_id
##            , hyb.ref_pay
##            , sum(transaction_amount) as total_transaction_amount
##            , coalesce(eob_batch_adjustments,0) as eob_batch_adjs
##          FROM
##            uploads.custom_hybrid_file as hyb
##
##          --BEGIN SECOND SUBQUERY which sums eob_batch_adjustments by transaction ID
##
##          LEFT JOIN
##            (SELECT
##              sum(value) as eob_batch_adjustments
##              , CASE
##                WHEN x12_payer_payer_id = 1275 THEN concat('Avalon_',trim(leading '0' from check_or_eft_trace_number))
##                WHEN trim(leading '0' from check_or_eft_trace_number) = '' THEN check_or_eft_trace_number ELSE trim(leading '0' from check_or_eft_trace_number) END as check_or_eft_trace_number
##            FROM
##              current.eobbatchadjustment
##            INNER JOIN
##              current.eobbatch on eobbatch.id = eobbatchadjustment.eob_batch_id
##            WHERE
##              duplicate_of_eob_batch_id is null
##            GROUP BY
##              2
##            ) as eob_batch_adjs on eob_batch_adjs.check_or_eft_trace_number = hyb.transaction_id
##          WHERE
##            hyb.source not in ('beacon-era','patient_payments')
##
##          --END SECOND SUBQUERY
##
##          GROUP BY
##            1,2,4
##          ) as hybrid on hybrid.transaction_id = bank.trn and hybrid.ref_pay = bank.ref_pay
##
##        --END FIRST SUBQUERY
##
##        LEFT JOIN
##            uploads.interest as interest on interest.pkey::text = bank.pkey::text
##
##        WHERE
##          ((account = '2' or account = '3301385741') or bai_code != '115')
##          and date_part('year', deposit_date) >= 2017
##          and (data_type is null or data_type != 'Stripe Transaction')
##        ) as uni
##      INNER JOIN
##        uploads.custom_hybrid_file as hybrid on hybrid.transaction_id = hybrid_trans_id and hybrid.ref_pay = uni.ref_pay and hybrid.source not in ('beacon-era','patient_payments')
##      WHERE (uni.deposit_date::date - hybrid.date_recorded::date) <= 90
##       ;;
##    sql_trigger_value: select count(*) from uploads.custom_hybrid_file ;;
##    indexes: ["bank_pkey"]
##  }
##
##  dimension: bank_pkey {
##    sql: ${TABLE}.bank_pkey;;
##  }
##
##  dimension: eob_batch_adjs {
##    sql: ${TABLE}.eob_batch_adjs ;;
##  }
##
##  dimension: hybrid_pkey {
##    sql: ${TABLE}.hybrid_pkey ;;
##  }
##}
##
##view: matched_barcodes_02b1_stripe {
##  derived_table: {
##    sql: SELECT
##        eob_batch_adjs
##        , hybrid.pkey as hybrid_pkey
##        , bank_pkey
##
##      FROM
##        (SELECT
##          bank.pkey::text as bank_pkey
##          , bank.ref_pay
##          , s1.transaction_id as hybrid_trans_id
##          , bank.fee as eob_batch_adjs
##        FROM
##          ${stripe_deposits.SQL_TABLE_NAME} as bank
##        INNER JOIN
##          current.paymentgatewaytransfertransaction as p on p.id = bank.stripe_id
##        INNER JOIN
##          (SELECT
##            transaction_id
##            , hyb.ref_pay
##            , sum(transaction_amount) as total_transaction_amount
##          FROM
##            uploads.custom_hybrid_file as hyb
##          WHERE
##            date_recorded >= '2015-12-29' and ref_pay = 'Payment'
##          GROUP BY 1,2
##          ) as s1 on s1.transaction_id = bank.trn
##            and total_transaction_amount = p.amount
##            and CASE WHEN s1.ref_pay = 'Refund' THEN 'refund' WHEN s1.ref_pay = 'Payment' THEN 'charge' ELSE '' END = p.transaction_type
##        WHERE
##          coid = 'Stripe Transaction' and date_part('year', deposit_date) >= 2017 and bank.ref_pay = 'Payment'
##        ) as uni
##      INNER JOIN
##        uploads.custom_hybrid_file as hybrid on hybrid.transaction_id = hybrid_trans_id and hybrid.ref_pay = uni.ref_pay
##      WHERE
##        date_recorded >= '2015-12-29'
##       ;;
##    sql_trigger_value: select count(*) from uploads.custom_hybrid_file ;;
##  }
##
##  dimension: bank_trans_id {
##    sql: ${TABLE}.bank_trans_id ;;
##  }
##
##  dimension: eob_batch_adjs {
##    sql: ${TABLE}.eob_batch_adjs ;;
##  }
##
##  dimension: hybrid_pkey {
##    sql: ${TABLE}.hybrid_pkey ;;
##  }
##}
##
##view: matched_barcodes_02b2_stripe_refunds {
##  derived_table: {
##    sql: SELECT
##        eob_batch_adjs
##        , hybrid.pkey as hybrid_pkey
##        , bank_pkey
##
##      FROM
##        (SELECT
##          bank.pkey::text as bank_pkey
##          , bank.ref_pay
##          , s1.transaction_id as hybrid_trans_id
##          , bank.fee as eob_batch_adjs
##        FROM
##          ${stripe_deposits.SQL_TABLE_NAME} as bank
##        INNER JOIN
##          (SELECT
##            charge_id
##            , transaction_type
##            , sum(fee) as fee
##            , sum(amount) as amount
##            , min(id) as id
##          FROM
##            current.paymentgatewaytransfertransaction
##          WHERE
##            transaction_type = 'refund'
##          GROUP BY
##            1,2
##          ) as p on p.id = bank.stripe_id
##        INNER JOIN
##          (SELECT
##            transaction_id
##            , hyb.ref_pay
##            , sum(transaction_amount) as total_transaction_amount
##          FROM
##            uploads.custom_hybrid_file as hyb
##          WHERE
##            date_recorded >= '2015-12-29' and ref_pay = 'Refund'
##          GROUP BY 1,2
##          ) as s1 on s1.transaction_id = bank.trn
##            and total_transaction_amount = p.amount
##            and CASE WHEN s1.ref_pay = 'Refund' THEN 'refund' WHEN s1.ref_pay = 'Payment' THEN 'charge' ELSE '' END = p.transaction_type
##        WHERE
##          coid = 'Stripe Transaction' and date_part('year', deposit_date) >= 2017 and bank.ref_pay = 'Refund'
##        ) as uni
##      INNER JOIN
##        uploads.custom_hybrid_file as hybrid on hybrid.transaction_id = hybrid_trans_id and hybrid.ref_pay = uni.ref_pay
##      WHERE
##        date_recorded >= '2015-12-29'
##       ;;
##    sql_trigger_value: select count(*) from uploads.custom_hybrid_file ;;
##  }
##
##  dimension: bank_trans_id {
##    sql: ${TABLE}.bank_trans_id ;;
##  }
##
##  dimension: eob_batch_adjs {
##    sql: ${TABLE}.eob_batch_adjs ;;
##  }
##
##  dimension: hybrid_pkey {
##    sql: ${TABLE}.hybrid_pkey ;;
##  }
##}
##
##view: matched_barcodes_02c_kaiser {
##  derived_table: {
##    sql: SELECT
##        eob_batch_adjs
##        , hybrid.pkey as hybrid_pkey
##        , bank_pkey
##
##      FROM
##        (SELECT
##          bank.pkey::text as bank_pkey
##          , hybrid.eob_batch_id
##          , bank.ref_pay
##          , coalesce(CASE WHEN interest.interest <> 0 THEN interest.interest * -1 ELSE hybrid.eob_batch_adjs END,0) as eob_batch_adjs
##        FROM
##          ${bank_statement_deposits.SQL_TABLE_NAME} as bank
##
##        --BEGIN FIRST SUBQUERY which groups hybrid transactions by ID and sums amount posted, eob_batch_adjustments
##
##        INNER JOIN
##          (SELECT
##            hyb.eob_batch_id
##            , max(date_recorded) as date_recorded
##            , sum(transaction_amount) as total_transaction_amount
##            , coalesce(eob_batch_adjustments,0) as eob_batch_adjs
##          FROM
##            uploads.custom_hybrid_file as hyb
##
##          --BEGIN SECOND SUBQUERY which sums eob_batch_adjustments by transaction ID
##
##          LEFT JOIN
##            (SELECT
##              sum(value) as eob_batch_adjustments
##              , eob_batch_id
##            FROM
##              current.eobbatchadjustment
##            INNER JOIN
##              current.eobbatch on eobbatch.id = eobbatchadjustment.eob_batch_id
##            WHERE
##              duplicate_of_eob_batch_id is null
##            GROUP BY
##              2
##            ) as eob_batch_adjs on eob_batch_adjs.eob_batch_id::int = hyb.eob_batch_id::int
##
##          --END SECOND SUBQUERY
##
##          WHERE
##            position('Kaiser' in hyb.payer_name) > 0 and hyb.eob_batch_id is not null
##          GROUP BY
##            1,4
##          ) as hybrid on (hybrid.total_transaction_amount - hybrid.eob_batch_adjs) = bank.deposit_amt
##
##        --END FIRST SUBQUERY
##
##        LEFT JOIN
##            uploads.interest as interest on interest.pkey::text = bank.pkey::text
##
##        WHERE
##          bai_code = '165'
##          and date_part('year', deposit_date) >= 2017
##          and (bank.text_desc ILIKE '%Kaiser%' or bank.text_desc ILIKE '%KFHP%')
##          and (bank.trn is null or bank.trn = '')
##          and abs(date_recorded::date - deposit_date::date) < 5
##        ) as uni
##      INNER JOIN
##        uploads.custom_hybrid_file as hybrid on hybrid.eob_batch_id::int = uni.eob_batch_id::int
##       ;;
##    sql_trigger_value: select count(*) from uploads.custom_hybrid_file ;;
##  }
##
##  dimension: bank_trans_id {
##    sql: ${TABLE}.bank_trans_id ;;
##  }
##
##  dimension: eob_batch_adjs {
##    sql: ${TABLE}.eob_batch_adjs ;;
##  }
##
##  dimension: hybrid_pkey {
##    sql: ${TABLE}.hybrid_pkey ;;
##  }
##
##  dimension: bank_pkey {
##    sql: ${TABLE}.bank_pkey ;;
##  }
##
##  dimension: claim_id {
##    type: number
##    sql: ${TABLE}.claim_id ;;
##  }
##
##  dimension: hybrid_trans_id {
##    sql: ${TABLE}.hybrid_trans_id ;;
##  }
##
##  dimension: bai_code {
##    sql: ${TABLE}.bai_code ;;
##  }
##}
##
##view: matched_barcodes_02d_hra_era {
##  derived_table: {
##    sql: SELECT
##        eob_batch_adjs
##        , hybrid.pkey as hybrid_pkey
##        , bank_pkey
##
##      FROM
##        (SELECT
##          bank.pkey::text as bank_pkey
##          , hybrid.eob_batch_id
##          , bank.ref_pay
##          , coalesce(CASE WHEN interest.interest <> 0 THEN interest.interest * -1 ELSE hybrid.eob_batch_adjs END,0) as eob_batch_adjs
##        FROM
##          ${bank_statement_deposits.SQL_TABLE_NAME} as bank
##
##        --BEGIN FIRST SUBQUERY which groups hybrid transactions by ID and sums amount posted, eob_batch_adjustments
##
##        INNER JOIN
##          (SELECT
##            hyb.eob_batch_id
##            , source
##            , sum(transaction_amount) as total_transaction_amount
##            , coalesce(eob_batch_adjustments,0) as eob_batch_adjs
##          FROM
##            uploads.custom_hybrid_file as hyb
##
##          --BEGIN SECOND SUBQUERY which sums eob_batch_adjustments by transaction ID
##
##          LEFT JOIN
##            (SELECT
##              sum(value) as eob_batch_adjustments
##              , eob_batch_id
##            FROM
##              current.eobbatchadjustment
##            INNER JOIN
##              current.eobbatch on eobbatch.id = eobbatchadjustment.eob_batch_id
##            WHERE
##              duplicate_of_eob_batch_id is null
##            GROUP BY
##              2
##            ) as eob_batch_adjs on eob_batch_adjs.eob_batch_id::int = hyb.eob_batch_id::int
##
##          --END SECOND SUBQUERY
##
##          WHERE
##            source = 'hra-era'
##          GROUP BY
##            1,2,4
##          ) as hybrid on (hybrid.total_transaction_amount - hybrid.eob_batch_adjs) = bank.deposit_amt
##
##        --END FIRST SUBQUERY
##
##        LEFT JOIN
##            uploads.interest as interest on interest.pkey::text = bank.pkey::text
##
##        WHERE
##          bai_code = '115'
##          and date_part('year', deposit_date) >= 2017
##        ) as uni
##      INNER JOIN
##        uploads.custom_hybrid_file as hybrid on hybrid.eob_batch_id::int = uni.eob_batch_id::int
##       ;;
##    sql_trigger_value: select count(*) from uploads.custom_hybrid_file ;;
##  }
##
##  dimension: bank_trans_id {
##    sql: ${TABLE}.bank_trans_id ;;
##  }
##
##  dimension: eob_batch_adjs {
##    sql: ${TABLE}.eob_batch_adjs ;;
##  }
##
##  dimension: hybrid_pkey {
##    sql: ${TABLE}.hybrid_pkey ;;
##  }
##
##  dimension: bank_pkey {
##    sql: ${TABLE}.bank_pkey ;;
##  }
##
##  dimension: claim_id {
##    type: number
##    sql: ${TABLE}.claim_id ;;
##  }
##
##  dimension: hybrid_trans_id {
##    sql: ${TABLE}.hybrid_trans_id ;;
##  }
##
##  dimension: bai_code {
##    sql: ${TABLE}.bai_code ;;
##  }
##}
##
##view: matched_barcodes_02e_rounded_to_16_chars {
##  derived_table: {
##    sql: SELECT
##        eob_batch_adjs
##        , hybrid.pkey as hybrid_pkey
##        , bank_pkey
##      FROM
##        (SELECT
##          bank.pkey::text as bank_pkey
##          , hybrid.transaction_id as hybrid_trans_id
##          , hybrid.total_transaction_amount
##          , coalesce(CASE WHEN interest.interest <> 0 THEN interest.interest * -1 ELSE hybrid.eob_batch_adjs END,0) as eob_batch_adjs
##        FROM
##          ${bank_statement_deposits.SQL_TABLE_NAME} as bank
##
##        --BEGIN FIRST SUBQUERY which groups hybrid transactions by ID and sums amount posted, eob_batch_adjustments
##
##        INNER JOIN
##          (SELECT
##            transaction_id
##            , sum(transaction_amount) as total_transaction_amount
##            , coalesce(eob_batch_adjustments,0) as eob_batch_adjs
##          FROM
##            uploads.custom_hybrid_file as hyb
##
##          --BEGIN SECOND SUBQUERY which sums eob_batch_adjustments by transaction ID
##
##          LEFT JOIN
##            (SELECT
##              sum(value) as eob_batch_adjustments
##              , CASE WHEN trim(leading '0' from check_or_eft_trace_number) = '' THEN check_or_eft_trace_number ELSE trim(leading '0' from check_or_eft_trace_number) END check_or_eft_trace_number
##            FROM
##              current.eobbatchadjustment
##            INNER JOIN
##              current.eobbatch on eobbatch.id = eobbatchadjustment.eob_batch_id
##            WHERE
##              duplicate_of_eob_batch_id is null
##            GROUP BY
##              2
##            ) as eob_batch_adjs on eob_batch_adjs.check_or_eft_trace_number = hyb.transaction_id
##
##          --END SECOND SUBQUERY
##
##          GROUP BY
##            1,3
##          ) as hybrid on substring(hybrid.transaction_id for 16) = substring(bank.trn for 16)
##
##        --END FIRST SUBQUERY
##
##        LEFT JOIN
##            uploads.interest as interest on interest.pkey::text = bank.pkey::text
##
##        LEFT JOIN
##          (SELECT DISTINCT bank_pkey::text FROM ${matched_barcodes_02a_electronic_payer_clinic_deposits.SQL_TABLE_NAME}) as sub on sub.bank_pkey::text = bank.pkey::text
##        WHERE
##          (bank.account = '2' or bank.bai_code != '115')
##          and date_part('year', bank.deposit_date) >= 2017
##          and abs(hybrid.total_transaction_amount - coalesce(CASE WHEN interest.interest <> 0 THEN interest.interest * -1 ELSE hybrid.eob_batch_adjs END,0) - bank.deposit_amt) < 1
##          and sub.bank_pkey is null
##        ) as hyb
##      INNER JOIN
##        uploads.custom_hybrid_file as hybrid on hybrid.transaction_id = hyb.hybrid_trans_id
##       ;;
##    sql_trigger_value: select count(*) from uploads.custom_hybrid_file ;;
##    indexes: ["bank_pkey"]
##  }
##}
##
##view: matched_barcodes_02f_check_number_prefixes {
##  derived_table: {
##    sql: SELECT
##        eob_batch_adjs
##        , hybrid.pkey as hybrid_pkey
##        , bank_pkey
##      FROM
##        (SELECT
##          bank.pkey::text as bank_pkey
##          , hybrid.transaction_id as hybrid_trans_id
##          , hybrid.total_transaction_amount
##          , hybrid.eob_batch_adjs
##
##        FROM
##          ${bank_statement_deposits.SQL_TABLE_NAME} as bank
##        INNER JOIN
##          (SELECT
##            transaction_id
##            , sum(transaction_amount) as total_transaction_amount
##            , coalesce(eob_batch_adjustments,0) as eob_batch_adjs
##          FROM
##            uploads.custom_hybrid_file as hyb
##          LEFT JOIN
##            (SELECT
##              sum(value) as eob_batch_adjustments
##              , CASE WHEN trim(leading '0' from check_or_eft_trace_number) = '' THEN check_or_eft_trace_number ELSE trim(leading '0' from check_or_eft_trace_number) END as check_or_eft_trace_number
##            FROM
##              current.eobbatchadjustment
##            INNER JOIN
##              current.eobbatch on eobbatch.id = eobbatchadjustment.eob_batch_id
##            WHERE
##              duplicate_of_eob_batch_id is null
##            GROUP BY
##              2) as eob_batch_adjs on eob_batch_adjs.check_or_eft_trace_number = CASE WHEN trim(leading '0' from substring(hyb.transaction_id from 3)) = '' THEN substring(hyb.transaction_id from 3) ELSE trim(leading '0' from substring(hyb.transaction_id from 3)) END
##          WHERE
##            position('PG' in transaction_id) = 1 or position('PH' in transaction_id) = 1
##          GROUP BY
##            1,3
##          ) as hybrid on CASE WHEN trim(leading '0' from substring(hybrid.transaction_id from 3)) = '' THEN substring(hybrid.transaction_id from 3) ELSE trim(leading '0' from substring(hybrid.transaction_id from 3)) END = bank.trn
##        LEFT JOIN
##          (SELECT DISTINCT bank_pkey::text FROM ${matched_barcodes_02a_electronic_payer_clinic_deposits.SQL_TABLE_NAME}) as sub on sub.bank_pkey::text = bank.pkey::text
##        LEFT JOIN
##          (SELECT DISTINCT bank_pkey::text FROM ${matched_barcodes_02e_rounded_to_16_chars.SQL_TABLE_NAME}) as sub2 on sub2.bank_pkey::text = bank.pkey::text
##        WHERE
##          date_part('year', bank.deposit_date) >= 2017
##          and abs(hybrid.total_transaction_amount - hybrid.eob_batch_adjs - bank.deposit_amt) < 1
##          and sub.bank_pkey is null
##          and sub2.bank_pkey is null
##        ) as hyb
##      INNER JOIN
##        uploads.custom_hybrid_file as hybrid on substring(hybrid.transaction_id from 3) = substring(hyb.hybrid_trans_id from 3)
##       ;;
##    sql_trigger_value: select count(*) from uploads.custom_hybrid_file ;;
##    indexes: ["bank_pkey"]
##  }
##}
##
##view: matched_barcodes_02g_connecticare {
##  derived_table: {
##    sql: SELECT
##        eob_batch_adjs
##        , hybrid.pkey as hybrid_pkey
##        , bank_pkey
##      FROM
##        (SELECT
##          bank.pkey::text as bank_pkey
##          , hybrid.transaction_id as hybrid_trans_id
##          , hybrid.total_transaction_amount
##          , coalesce(CASE WHEN hybrid.eob_batch_adjs <> 0 THEN hybrid.eob_batch_adjs ELSE interest.interest * -1 END,0) as eob_batch_adjs
##
##        FROM
##          ${bank_statement_deposits.SQL_TABLE_NAME} as bank
##        INNER JOIN
##          (SELECT
##            transaction_id
##            , sum(transaction_amount) as total_transaction_amount
##            , coalesce(eob_batch_adjustments,0) as eob_batch_adjs
##          FROM
##            uploads.custom_hybrid_file as hyb
##          LEFT JOIN
##            (SELECT
##              sum(value) as eob_batch_adjustments
##              , CASE WHEN trim(leading '0' from check_or_eft_trace_number) = '' THEN check_or_eft_trace_number ELSE trim(leading '0' from check_or_eft_trace_number) END as check_or_eft_trace_number
##            FROM
##              current.eobbatchadjustment
##            INNER JOIN
##              current.eobbatch on eobbatch.id = eobbatchadjustment.eob_batch_id
##            WHERE
##              duplicate_of_eob_batch_id is null
##            GROUP BY
##              2) as eob_batch_adjs on eob_batch_adjs.check_or_eft_trace_number = CASE WHEN trim(leading '0' from substring(hyb.transaction_id from 3)) = '' THEN substring(hyb.transaction_id from 3) ELSE trim(leading '0' from substring(hyb.transaction_id from 3)) END
##          WHERE
##            position('1E' in transaction_id) = 1 and char_length(transaction_id) = 11
##            or (position('e000' in lower(transaction_id)) = 3 and (char_length(transaction_id) = 12 or char_length(transaction_id) = 10))
##          GROUP BY
##            1,3
##          ) as hybrid on replace(substring(hybrid.transaction_id from position('E' in transaction_id)),'E','e') = replace(bank.trn,'E','e')
##
##        LEFT JOIN
##            uploads.interest as interest on interest.pkey::text = bank.pkey::text
##        LEFT JOIN
##          (SELECT DISTINCT bank_pkey::text FROM ${matched_barcodes_02a_electronic_payer_clinic_deposits.SQL_TABLE_NAME}) as sub on sub.bank_pkey::text = bank.pkey::text
##        LEFT JOIN
##          (SELECT DISTINCT bank_pkey::text FROM ${matched_barcodes_02e_rounded_to_16_chars.SQL_TABLE_NAME}) as sub2 on sub2.bank_pkey::text = bank.pkey::text
##        LEFT JOIN
##          (SELECT DISTINCT bank_pkey::text FROM ${matched_barcodes_02f_check_number_prefixes.SQL_TABLE_NAME}) as sub3 on sub3.bank_pkey::text = bank.pkey::text
##
##        WHERE
##          date_part('year', bank.deposit_date) >= 2017
##          and abs(hybrid.total_transaction_amount - coalesce(CASE WHEN hybrid.eob_batch_adjs <> 0 THEN hybrid.eob_batch_adjs ELSE interest.interest * -1 END,0) - bank.deposit_amt) < 1
##          and sub.bank_pkey is null
##          and sub2.bank_pkey is null
##          and sub3.bank_pkey is null
##        ) as hyb
##      INNER JOIN
##        uploads.custom_hybrid_file as hybrid on right(hybrid.transaction_id, 8) = right(hyb.hybrid_trans_id, 8)
##       ;;
##    sql_trigger_value: select count(*) from uploads.custom_hybrid_file ;;
##    indexes: ["bank_pkey"]
##  }
##
##  dimension: bank_trans_id {
##    sql: ${TABLE}.bank_trans_id ;;
##  }
##
##  dimension: eob_batch_adjs {
##    sql: ${TABLE}.eob_batch_adjs ;;
##  }
##
##  dimension: hybrid_pkey {
##    sql: ${TABLE}.hybrid_pkey ;;
##  }
##}
##
##view: matched_barcodes_02h_consignment_wires {
##  derived_table: {
##    sql: SELECT
##        0 as eob_batch_adjs
##        , hyb.pkey as hybrid_pkey
##        , bank.pkey as bank_pkey
##      FROM
##        ${bank_statement_deposits.SQL_TABLE_NAME} as bank
##      INNER JOIN
##        (SELECT
##          distinct transaction_id
##        FROM
##          uploads.custom_hybrid_file
##        ) as hybrid on trim(leading '0' from hybrid.transaction_id) = trim(leading '0' from bank.bank_ref)
##      INNER JOIN
##        uploads.custom_hybrid_file as hyb on hyb.transaction_id = hybrid.transaction_id
##      WHERE
##        invoice_type = 'Physician' and date_part('year', deposit_date) >= 2017 and bank.bank_ref is not null
##       ;;
##    sql_trigger_value: select count(*) from uploads.custom_hybrid_file ;;
##  }
##
##  dimension: invoice_id {
##    type: number
##    sql: ${TABLE}.invoice_id ;;
##  }
##
##  dimension: trn {
##    sql: ${TABLE}.trn ;;
##  }
##}
##
##view: matched_barcodes_02i_beacon {
##  derived_table: {
##    sql: SELECT
##          0 as eob_batch_adjs
##          , hybrid.pkey hybrid_pkey
##          , bank_pkey
##        FROM
##          (
##            SELECT
##              claim_id
##              , bank_pkey
##            FROM
##              (
##                SELECT
##                  date_of_service
##                  , claim_id
##                  , date_recorded
##                  , transaction_id
##                  , round(total_transaction_amount::numeric,2) total_transaction_amount
##                  , row_number() over(partition by date_recorded, date_of_service, total_transaction_amount) as row
##                FROM
##                  (
##                    SELECT
##                      date_of_service
##                      , hyb.claim_id
##                      , hyb.date_recorded
##                      , transaction_id
##                      , sum(transaction_amount) as total_transaction_amount
##                    FROM
##                      uploads.custom_hybrid_file as hyb
##                    INNER JOIN
##                      current.insuranceclaim on hyb.claim_id = insuranceclaim.id
##                    WHERE
##                      source = 'beacon-era'
##                    GROUP BY
##                      1,2,3,4
##                  ) sub
##              ) sub2
##            INNER JOIN
##              (
##                SELECT
##                  claim_reference_number
##                  , date_of_service_from
##                  , claim_received_by_uhc_date
##                  , beacon_paid
##                  , bank_pkey
##                  , row_number () over(partition by date_of_service_from, claim_received_by_uhc_date, beacon_paid) as beacon_row
##                FROM
##                  (
##                    SELECT
##                      claim_reference_number
##                      , date_of_service_from
##                      , claim_received_by_uhc_date
##                      , bank.pkey bank_pkey
##                      , sum(net_paid) beacon_paid
##                    FROM
##                      uploads.beacon_payments
##                    INNER JOIN
##                      ${bank_statement_deposits.SQL_TABLE_NAME} bank on bank.trn = beacon_payments.invoice_number
##                    GROUP BY
##                      1,2,3,4
##                  ) beacon_sub
##              ) as bs on bs.beacon_paid = sub2.total_transaction_amount and bs.date_of_service_from = sub2.date_of_service and bs.claim_received_by_uhc_date = sub2.date_recorded and bs.beacon_paid = sub2.total_transaction_amount and bs.beacon_row = sub2.row
##            ) as outer_sub
##          INNER JOIN
##            uploads.custom_hybrid_file hybrid on hybrid.claim_id = outer_sub.claim_id and hybrid.source = 'beacon-era'
##  ;;
##    sql_trigger_value: select count(*) from uploads.custom_hybrid_file ;;
##  }
##
##  dimension: bank_pkey {
##    sql: ${TABLE}.bank_pkey ;;
##  }
##
##  dimension: eob_batch_adjs {
##    sql: ${TABLE}.eob_batch_adjs ;;
##  }
##
##  dimension: hybrid_pkey {
##    sql: ${TABLE}.hybrid_pkey ;;
##  }
##
##  dimension: total_transaction_amount {
##    sql:  ${TABLE}.total_transaction_amount ;;
##  }
##}
##
##view: matched_barcodes_03a_manual_upload_eob_batches {
##  derived_table: {
##    sql: SELECT
##        eob_batch_adjs.eob_batch_adjs
##        , hybrid.pkey as hybrid_pkey
##        , uni.bank_pkey
##      FROM
##        (SELECT
##          bank.pkey::text as bank_pkey
##          , hybrid.eob_batch_id
##        FROM
##          ${bank_statement_deposits.SQL_TABLE_NAME} as bank
##        INNER JOIN
##          uploads.manual_recon_file as recon on bank.pkey::text = recon.pkey::text
##        INNER JOIN
##          (SELECT
##            distinct eob_batch_id
##          FROM uploads.custom_hybrid_file
##          ) as hybrid on hybrid.eob_batch_id::int = recon.eob_batch_id::int
##        LEFT JOIN
##          (SELECT DISTINCT bank_pkey::text FROM ${matched_barcodes_02a_electronic_payer_clinic_deposits.SQL_TABLE_NAME}) as sub on sub.bank_pkey::text = bank.pkey::text
##        LEFT JOIN
##          (SELECT DISTINCT bank_pkey::text FROM ${matched_barcodes_02e_rounded_to_16_chars.SQL_TABLE_NAME}) as sub2 on sub2.bank_pkey::text = bank.pkey::text
##        LEFT JOIN
##          (SELECT DISTINCT bank_pkey::text FROM ${matched_barcodes_02f_check_number_prefixes.SQL_TABLE_NAME}) as sub3 on sub3.bank_pkey::text = bank.pkey::text
##        LEFT JOIN
##          (SELECT DISTINCT bank_pkey::text FROM ${matched_barcodes_02g_connecticare.SQL_TABLE_NAME}) as sub4 on sub4.bank_pkey::text = bank.pkey::text
##        LEFT JOIN
##          (SELECT DISTINCT bank_pkey::text FROM ${matched_barcodes_01b_lockbox_insurer_era.SQL_TABLE_NAME}) as sub5 on sub5.bank_pkey::text = bank.pkey::text
##
##        WHERE
##          date_part('year', bank.deposit_date) >= 2017
##          and sub.bank_pkey is null
##          and sub2.bank_pkey is null
##          and sub3.bank_pkey is null
##          and sub4.bank_pkey is null
##          and sub5.bank_pkey is null
##          and recon.payment_source = 'EOB'
##        ) as uni
##      INNER JOIN
##        uploads.custom_hybrid_file as hybrid on hybrid.eob_batch_id = uni.eob_batch_id and hybrid.ref_pay = 'Payment'
##      LEFT JOIN
##        (SELECT
##          eob_batch_id
##          , sum(value) * -1 as eob_batch_adjs
##        FROM
##          current.eobbatchadjustment
##        GROUP BY 1
##        ) as eob_batch_adjs on eob_batch_adjs.eob_batch_id = uni.eob_batch_id
##       ;;
##    sql_trigger_value: select sum(trigger) from (select count(pkey) as trigger from uploads.custom_hybrid_file UNION ALL SELECT count(pkey) as trigger from uploads.manual_recon_file) as t ;;
##  }
##
##  dimension: bank_trans_id {
##    sql: ${TABLE}.bank_trans_id ;;
##  }
##
##  dimension: eob_batch_adjs {
##    sql: ${TABLE}.eob_batch_adjs ;;
##  }
##
##  dimension: hybrid_pkey {
##    sql: ${TABLE}.hybrid_pkey ;;
##  }
##
##  dimension: bank_ref {
##    sql: ${TABLE}.bank_ref ;;
##  }
##}
##
##view: matched_barcodes_03b_manual_upload_payments {
##  derived_table: {
##    sql: SELECT
##        eob_batch_adjs
##        , hybrid.pkey as hybrid_pkey
##        , bank_pkey
##
##      FROM
##        (SELECT
##          bank.pkey::text as bank_pkey
##          , hybrid.transaction_id as hybrid_trans_id
##          , recon.eob_batch_adjs * -1 as eob_batch_adjs
##        FROM
##          ${bank_statement_deposits.SQL_TABLE_NAME} as bank
##        INNER JOIN
##          uploads.manual_recon_file as recon on bank.pkey::text = recon.pkey::text
##        INNER JOIN
##          (SELECT
##            distinct transaction_id
##          FROM
##            uploads.custom_hybrid_file as hyb
##          ) as hybrid on hybrid.transaction_id = replace(recon.transaction_id, ' ','')
##
##        LEFT JOIN
##            uploads.interest as interest on interest.pkey::text = bank.pkey::text
##
##        LEFT JOIN
##          (SELECT DISTINCT bank_pkey::text FROM ${matched_barcodes_02a_electronic_payer_clinic_deposits.SQL_TABLE_NAME}) as sub on sub.bank_pkey::text = bank.pkey::text
##        LEFT JOIN
##          (SELECT DISTINCT bank_pkey::text FROM ${matched_barcodes_02e_rounded_to_16_chars.SQL_TABLE_NAME}) as sub2 on sub2.bank_pkey::text = bank.pkey::text
##        LEFT JOIN
##          (SELECT DISTINCT bank_pkey::text FROM ${matched_barcodes_02f_check_number_prefixes.SQL_TABLE_NAME}) as sub3 on sub3.bank_pkey::text = bank.pkey::text
##        LEFT JOIN
##          (SELECT DISTINCT bank_pkey::text FROM ${matched_barcodes_02g_connecticare.SQL_TABLE_NAME}) as sub4 on sub4.bank_pkey::text = bank.pkey::text
##
##        WHERE
##          date_part('year', bank.deposit_date) >= 2017
##
##          and sub.bank_pkey is null
##          and sub2.bank_pkey is null
##          and sub3.bank_pkey is null
##          and sub4.bank_pkey is null
##          and recon.payment_source = 'Payment'
##        ) as uni
##      INNER JOIN
##        uploads.custom_hybrid_file as hybrid on hybrid.transaction_id = hybrid_trans_id and hybrid.ref_pay = 'Payment'
##       ;;
##    sql_trigger_value: select sum(trigger) from (select count(pkey) as trigger from uploads.custom_hybrid_file UNION ALL SELECT count(pkey) as trigger from uploads.manual_recon_file) as t ;;
##  }
##
##  dimension: bank_trans_id {
##    sql: ${TABLE}.bank_trans_id ;;
##  }
##
##  dimension: eob_batch_adjs {
##    sql: ${TABLE}.eob_batch_adjs ;;
##  }
##
##  dimension: hybrid_pkey {
##    sql: ${TABLE}.hybrid_pkey ;;
##  }
##}
##
##view: matched_barcodes_03c_interest_only {
##  derived_table: {
##    sql: SELECT
##        eob_batch_adjs
##        , null::text as hybrid_pkey
##        , bank_pkey
##
##      FROM
##        (SELECT
##          bank.pkey::text as bank_pkey
##          , interest * -1 as eob_batch_adjs
##        FROM
##          ${bank_statement_deposits.SQL_TABLE_NAME} as bank
##        INNER JOIN
##          uploads.interest as interest on interest.pkey::text = bank.pkey::text and interest.interest = bank.deposit_amt
##
##        WHERE
##          date_part('year', bank.deposit_date) >= 2017
##        ) as uni
##       ;;
##    sql_trigger_value: select count(pkey) from ${bank_statement_deposits.SQL_TABLE_NAME} ;;
##  }
##
##  dimension: bank_trans_id {
##    sql: ${TABLE}.bank_trans_id ;;
##  }
##
##  dimension: eob_batch_adjs {
##    sql: ${TABLE}.eob_batch_adjs ;;
##  }
##
##  dimension: hybrid_pkey {
##    sql: ${TABLE}.hybrid_pkey ;;
##  }
##}##
