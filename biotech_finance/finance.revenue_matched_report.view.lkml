view: order_level_payments {
  derived_table: {
    sql: SELECT
        order_id
        , sum(patient_payment_amount) as patient_payment_amount
        , sum(insurer_payment_amount) as insurer_payment_amount
        , sum(physician_payment_amount) as physician_payment_amount
      FROM

        (SELECT
          match.order_id
          , 1 as invoice_item_count
          , 0 as physician_payment_amount
          , sum(CASE WHEN invoice_type = 'Customer' THEN transaction_amount ELSE 0 END) as patient_payment_amount
          , sum(CASE WHEN invoice_type = 'Insurer' THEN transaction_amount ELSE 0 END) as insurer_payment_amount
        FROM
          ${revenue_all_matched_transactions.SQL_TABLE_NAME} as match
        WHERE
          invoice_type in ('Customer', 'Insurer')
        GROUP BY
          1,2,3

        UNION ALL
          SELECT
            sub2.order_id
            , invoice_item_count
            , sum(CASE WHEN invoice_type = 'Physician' THEN transaction_amount ELSE 0 END) / nullif(invoice_item_count,0) as physician_payment_amount
            , 0 as patient_payment_amount
            , 0 as insurer_payment_amount
          FROM
            ${revenue_all_matched_transactions.SQL_TABLE_NAME} as match
          LEFT JOIN
            (SELECT
              ii.order_id
              , ii.invoice_id
              , invoice_item_count
            FROM
              ${invoiceitem.SQL_TABLE_NAME} as ii
            INNER JOIN
              (SELECT
                invoice_id
                , count(id) as invoice_item_count
              FROM
                ${invoiceitem.SQL_TABLE_NAME}
              WHERE
                invoice_type = 'Physician'
              GROUP BY
                1
              ) as sub on sub.invoice_id = ii.invoice_id
            GROUP BY
              1,2,3
            ) as sub2 on sub2.invoice_id = match.invoice_id
          WHERE
            match.invoice_type = 'Physician'
          GROUP BY
            1,2,4,5
          ) as sub3
        GROUP BY
          1
       ;;
    sql_trigger_value: select sum(transaction_amount) from ${revenue_all_matched_transactions.SQL_TABLE_NAME} ;;
    indexes: ["order_id"]
  }

  dimension: order_id {
    primary_key: yes
    hidden: yes
    type: number
    sql: ${TABLE}.order_id ;;
  }

  dimension: patient_payment_amount {
    hidden: yes
    type: number
    sql: ${TABLE}.patient_payment_amount ;;
  }

  dimension: insurer_payment_amount {
    type: number
    hidden: yes
    sql: ${TABLE}.insurer_payment_amount ;;
  }

  dimension: physician_payment_amount {
    hidden: yes
    type: number
    sql: ${TABLE}.physician_payment_amount ;;
  }
}

# REVENUE_EOB_MATCHING
#   CTE to compile all payments made via EOB
#   Note: Matching can occur on the full check_or_eft_trace_number, or some variation of the number (e.g. first 8 digits, last 8 digits, etc.)
#   Each match is done via subsequent CTE with results from the preceding CTEs excluded (in order to avoid duplicate matching)
#   Results from all CTEs are unioned at the end of the query

view: revenue_eob_matching {
  derived_table: {
    sql:
      WITH eob_payments as (
        SELECT
          eobbatch.id eob_batch_id
          , CASE
            WHEN trim(leading '0' from eobbatch.check_or_eft_trace_number) = '' THEN eobbatch.check_or_eft_trace_number
            WHEN x12_payer_payer_id = 1275 THEN concat('Avalon_',trim(leading '0' from eobbatch.check_or_eft_trace_number))
            WHEN x12_payer_name = 'PROGYNY INC' THEN concat('Progyny_',trim(leading '0' from eobbatch.check_or_eft_trace_number))
            ELSE trim(leading '0' from eobbatch.check_or_eft_trace_number) END check_or_eft_trace_number_trim
          , trim(leading '0' from right(check_or_eft_trace_number,8)) check_eft_number_last_eight
          , left(check_or_eft_trace_number,16) check_eft_number_first_sixteen
          , left(check_or_eft_trace_number,8) check_eft_number_first_eight
          , trim(leading'0' from replace(check_or_eft_trace_number,' ','')) check_eft_number_spaces_replaced
          , substring(check_or_eft_trace_number from position('-' in check_or_eft_trace_number) + 1) check_eft_number_after_dash
          , date_paid
          , eob_paid
          , sum(value) eob_batch_adjs
        FROM current.eobbatch
        INNER JOIN (SELECT eob_batch_id, sum(paid) eob_paid FROM current.eob WHERE claim_id is not null GROUP BY 1) as eob_paid on eob_paid.eob_batch_id = eobbatch.id
        LEFT JOIN current.eobbatchadjustment eba on eba.eob_batch_id = eobbatch.id
        LEFT JOIN uploads.duplicate_eob_batches dup on dup.eob_batch = eobbatch.id
        WHERE duplicate_of_eob_batch_id is null and dup.eob_batch is null
        GROUP BY 1,2,3,4,5,6,7,8,9)

      -- Matching check_or_eft_trace_number to bank transaction ID on the full number

      , full_match as (
        SELECT
          eob_payments.eob_batch_id
          , eob_payments.eob_paid
          , coalesce(eob_payments.eob_batch_adjs,0) eob_batch_adjs
          , bank.deposit_amt
          , bank.pkey bank_pkey
          , bank.deposit_date
          , bank.ref_pay
        FROM eob_payments
        INNER JOIN ${bank_statement_deposits.SQL_TABLE_NAME} bank on bank.trn = eob_payments.check_or_eft_trace_number_trim
        WHERE
          abs(bank.deposit_amt + coalesce(eob_payments.eob_batch_adjs,0) - eob_payments.eob_paid) < 5
          and bank.deposit_date > '2017-12-31'
          and bank.deposit_amt <> 0
          and abs(bank.deposit_date - eob_payments.date_paid) < 30
          and bank.trn is not null and bank.trn <> '')

      -- Matching check_or_eft_trace_number to bank transaction ID on the last 8 digits

      , last_eight_match as (
        SELECT
          eob_payments.eob_batch_id
          , eob_payments.eob_paid
          , coalesce(eob_payments.eob_batch_adjs,0) eob_batch_adjs
          , bank.deposit_amt
          , bank.pkey bank_pkey
          , bank.deposit_date
          , bank.ref_pay
        FROM eob_payments
        INNER JOIN ${bank_statement_deposits.SQL_TABLE_NAME} bank on trim(leading '0' from right(bank.trn,8)) = eob_payments.check_eft_number_last_eight
        LEFT JOIN full_match on full_match.bank_pkey = bank.pkey
        WHERE abs(bank.deposit_amt + coalesce(eob_payments.eob_batch_adjs,0) - eob_payments.eob_paid) < 5
          and full_match.bank_pkey is null
          and bank.deposit_date > '2017-12-31'
          and bank.deposit_amt <> 0
          and bank.trn is not null
          and abs(bank.deposit_date - eob_payments.date_paid) < 60
          and bank.trn <> '')

      -- Matching check_or_eft_trace_number to bank transaction ID where spaces in the ID are eliminated

      , spaces_replaced_match as (
        SELECT
          eob_payments.eob_batch_id
          , eob_payments.eob_paid
          , coalesce(eob_payments.eob_batch_adjs,0) eob_batch_adjs
          , bank.deposit_amt
          , bank.pkey bank_pkey
          , bank.deposit_date
          , bank.ref_pay
        FROM eob_payments
        INNER JOIN ${bank_statement_deposits.SQL_TABLE_NAME} bank on bank.trn = eob_payments.check_eft_number_spaces_replaced
        LEFT JOIN full_match on full_match.bank_pkey = bank.pkey
        LEFT JOIN last_eight_match on last_eight_match.bank_pkey = bank.pkey
        WHERE abs(bank.deposit_amt - eob_payments.eob_paid) < 5
          and full_match.bank_pkey is null
          and last_eight_match.bank_pkey is null
          and bank.deposit_date > '2017-12-31'
          and bank.deposit_amt <> 0
          and bank.trn is not null
          and abs(bank.deposit_date - eob_payments.date_paid) < 30
          and bank.trn <> '')

      -- Matching check_or_eft_trace_number to bank transaction ID on digits after the '-'

      , after_dash_match as (
        SELECT
          eob_payments.eob_batch_id
          , eob_payments.eob_paid
          , coalesce(eob_payments.eob_batch_adjs,0) eob_batch_adjs
          , bank.deposit_amt
          , bank.pkey bank_pkey
          , bank.deposit_date
          , bank.ref_pay
        FROM eob_payments
        INNER JOIN ${bank_statement_deposits.SQL_TABLE_NAME} bank on bank.trn = eob_payments.check_eft_number_after_dash
        LEFT JOIN full_match on full_match.bank_pkey = bank.pkey
        LEFT JOIN last_eight_match on last_eight_match.bank_pkey = bank.pkey
        LEFT JOIN spaces_replaced_match on spaces_replaced_match.bank_pkey = bank.pkey
        WHERE abs(bank.deposit_amt - eob_payments.eob_paid) < 5
          and full_match.bank_pkey is null
          and last_eight_match.bank_pkey is null
          and spaces_replaced_match.bank_pkey is null
          and bank.deposit_date > '2017-12-31'
          and bank.deposit_amt <> 0
          and bank.trn is not null
          and abs(bank.deposit_date - eob_payments.date_paid) < 30
          and bank.trn <> '')

      -- Matching check_or_eft_trace_number to bank transaction ID on the first 16 digits

      , first_sixteen_match as (
        SELECT
          eob_payments.eob_batch_id
          , eob_payments.eob_paid
          , coalesce(eob_payments.eob_batch_adjs,0) eob_batch_adjs
          , bank.deposit_amt
          , bank.pkey bank_pkey
          , bank.deposit_date
          , bank.ref_pay
        FROM eob_payments
        INNER JOIN ${bank_statement_deposits.SQL_TABLE_NAME} bank on bank.trn = eob_payments.check_eft_number_first_sixteen
        LEFT JOIN full_match on full_match.bank_pkey = bank.pkey
        LEFT JOIN last_eight_match on last_eight_match.bank_pkey = bank.pkey
        LEFT JOIN spaces_replaced_match on spaces_replaced_match.bank_pkey = bank.pkey
        LEFT JOIN after_dash_match on after_dash_match.bank_pkey = bank.pkey
        WHERE abs(bank.deposit_amt - eob_payments.eob_paid) < 5
          and full_match.bank_pkey is null
          and last_eight_match.bank_pkey is null
          and spaces_replaced_match.bank_pkey is null
          and after_dash_match.bank_pkey is null
          and bank.deposit_date > '2017-12-31'
          and bank.deposit_amt <> 0
          and bank.trn is not null
          and abs(bank.deposit_date - eob_payments.date_paid) < 30
          and bank.trn <> '')

      -- Matching check_or_eft_trace_number to bank transaction ID on the first 8 digits

      , first_eight_match as (
        SELECT
          eob_payments.eob_batch_id
          , eob_payments.eob_paid
          , coalesce(eob_payments.eob_batch_adjs,0) eob_batch_adjs
          , bank.deposit_amt
          , bank.pkey bank_pkey
          , bank.deposit_date
          , bank.ref_pay
        FROM eob_payments
        INNER JOIN ${bank_statement_deposits.SQL_TABLE_NAME} bank on bank.trn = eob_payments.check_eft_number_first_eight
        LEFT JOIN full_match on full_match.bank_pkey = bank.pkey
        LEFT JOIN last_eight_match on last_eight_match.bank_pkey = bank.pkey
        LEFT JOIN spaces_replaced_match on spaces_replaced_match.bank_pkey = bank.pkey
        LEFT JOIN after_dash_match on after_dash_match.bank_pkey = bank.pkey
        LEFT JOIN first_sixteen_match on first_sixteen_match.bank_pkey = bank.pkey
        WHERE abs(bank.deposit_amt - eob_payments.eob_paid) < 5
          and full_match.bank_pkey is null
          and last_eight_match.bank_pkey is null
          and spaces_replaced_match.bank_pkey is null
          and after_dash_match.bank_pkey is null
          and first_sixteen_match.bank_pkey is null
          and bank.deposit_date > '2017-12-31'
          and bank.deposit_amt <> 0
          and bank.trn is not null
          and abs(bank.deposit_date - eob_payments.date_paid) < 30
          and bank.trn <> '')

      SELECT * FROM full_match
      UNION ALL SELECT * FROM last_eight_match
      UNION ALL SELECT * FROM spaces_replaced_match
      UNION ALL SELECT * FROM after_dash_match
      UNION ALL SELECT * FROM first_sixteen_match
      UNION ALL SELECT * FROM first_eight_match

      ;;
    sql_trigger_value: select count(*) from ${bank_statement_deposits.SQL_TABLE_NAME} as bank;;
  }
  dimension: bank_pkey {
    type: string
    sql: ${TABLE}.bank_pkey ;;
  }
  dimension: check_or_eft_trace_number {
    sql: ${TABLE}.check_or_eft_trace_number ;;
  }
  dimension: deposit_amt {
    type: number
    sql: ${TABLE}.deposit_amt ;;
  }
}


# REVENUE_PAYMENT_MATCHING
#   CTE to compile all payments made via payment model
#   Note: Matching can occur on the full transaction ID, or some variation of the number (0's truncated, etc.)
#   Each match is done via subsequent CTE with results from the preceding CTEs excluded (in order to avoid duplicate matching)
#   Results from all CTEs are unioned at the end of the query

view: revenue_payment_matching {
  derived_table: {
    sql:
      WITH payments as (
        SELECT
          trim(leading '0' from transaction_id) as transaction_id
          , concat(trim(leading '0' from right(substring(transaction_id for greatest(1,position('-' in transaction_id)) -1),10)),'-',trim(leading '0' from right(substring(transaction_id from position('-' in transaction_id) + 1),8))) as acct_dash_zeros_trunc
          , trim(leading '0' from right(transaction_id,8)) transaction_id_last_eight
          , sum(amount) payment_amount
        FROM current.payment
        WHERE payment_method in ('chck','et','ref') and voided_by_payment_id is null
        GROUP BY 1,2,3)

      -- Matching transaction_id to concatenation of bank account and bank transaction ID, which is relevant for paper check payments

      , account_dash_match as (
        SELECT
          payments.transaction_id
          , payments.payment_amount
          , bank.deposit_amt
          , bank.pkey bank_pkey
          , coalesce(interest.interest * -1, 0) as eob_batch_adjs
          , bank.deposit_date
          , bank.ref_pay
        FROM payments
        INNER JOIN ${bank_statement_deposits.SQL_TABLE_NAME} bank on concat(trim(leading '0' from account),'-',trim(leading '0' from trn)) = acct_dash_zeros_trunc
        LEFT JOIN ${revenue_eob_matching.SQL_TABLE_NAME} eob_only on eob_only.bank_pkey = bank.pkey
        LEFT JOIN uploads.interest as interest on interest.pkey::text = bank.pkey::text
        WHERE position('-' in transaction_id) > 1
          and (data_type is null or data_type <> 'Stripe Transaction')
          and eob_only.bank_pkey is null
          and bank.deposit_date > '2017-12-31')

      -- Matching transaction_id to bank transaction_id in full

      , full_match as (
        SELECT
          payments.transaction_id
          , payments.payment_amount
          , bank.deposit_amt
          , bank.pkey bank_pkey
          , coalesce(interest.interest * -1, 0) as eob_batch_adjs
          , bank.deposit_date
          , bank.ref_pay
        FROM payments
        INNER JOIN ${bank_statement_deposits.SQL_TABLE_NAME} bank on trim(leading '0' from bank.trn) = trim(leading '0' from payments.transaction_id)
        LEFT JOIN ${revenue_eob_matching.SQL_TABLE_NAME} eob_only on eob_only.bank_pkey = bank.pkey
        LEFT JOIN uploads.interest as interest on interest.pkey::text = bank.pkey::text
        LEFT JOIN account_dash_match adm on adm.bank_pkey = bank.pkey
        WHERE eob_only.bank_pkey is null
          and adm.bank_pkey is null
          and (data_type is null or data_type <> 'Stripe Transaction')
          and payments.transaction_id is not null and payments.transaction_id <> ''
          and CASE WHEN length(payments.transaction_id) < 8 THEN abs(payments.payment_amount + coalesce(interest.interest,0) - bank.deposit_amt) < 5 ELSE true END
          and bank.deposit_date > '2017-12-31')

      -- Matching transaction_id to bank transaction_id on the last 8 digits

      , last_eight_match as (
        SELECT
          payments.transaction_id
          , payments.payment_amount
          , bank.deposit_amt
          , bank.pkey bank_pkey
          , coalesce(interest.interest * -1, 0) as eob_batch_adjs
          , bank.deposit_date
          , bank.ref_pay
        FROM payments
        INNER JOIN ${bank_statement_deposits.SQL_TABLE_NAME} bank on trim(leading '0' from right(bank.trn,8)) = transaction_id_last_eight
        LEFT JOIN ${revenue_eob_matching.SQL_TABLE_NAME} eob_only on eob_only.bank_pkey = bank.pkey
        LEFT JOIN full_match on full_match.bank_pkey = bank.pkey
        LEFT JOIN account_dash_match on account_dash_match.bank_pkey = bank.pkey
        LEFT JOIN uploads.interest as interest on interest.pkey::text = bank.pkey::text
        WHERE
          eob_only.bank_pkey is null
          and (data_type is null or data_type <> 'Stripe Transaction')
          and payments.transaction_id is not null and payments.transaction_id <> ''
          and full_match.bank_pkey is null
          and account_dash_match.bank_pkey is null
          and abs(payments.payment_amount - coalesce(interest.interest * -1,0) - bank.deposit_amt) < 5
          and bank.deposit_date > '2017-12-31')

      SELECT * FROM full_match
      UNION ALL SELECT * FROM account_dash_match
      UNION ALL SELECT * FROM last_eight_match
      ;;

      sql_trigger_value: select count(*) from ${revenue_eob_matching.SQL_TABLE_NAME} ;;
    }
    dimension: bank_pkey {
      type: string
      sql: ${TABLE}.bank_pkey ;;
    }
    dimension: transaction_id {
      sql: ${TABLE}.transaction_id ;;
    }
    dimension: deposit_amt {
      type: number
      sql: ${TABLE}.deposit_amt ;;
    }
    measure: payment_amt {
      type: sum
      sql: ${TABLE}.payment_amount ;;
    }
  }

# REVENUE_STRIPE_MATCHING
#   CTE to compile all credit card payments made via payment model
#   Note: Tandem Payments have extra words appended to end of transaction ID which need to be truncated for matching
#   Note: Refunds have the same transaction ID as their respective payment

  view: revenue_stripe_matching {
    derived_table: {
      sql:
              WITH payments as (
                SELECT
                  replace(transaction_id,' NATIVE_TANDEM_PAYMENT','') transaction_id_trunc
                  , transaction_id
                  , CASE WHEN payment_method = 'cc' THEN 'Payment' ELSE 'Refund' END as ref_pay
                  , sum(amount) payment_amount
                FROM current.payment
                WHERE payment_method in ('cc','ref') and voided_by_payment_id is null
                GROUP BY 1,2,3)

              SELECT
                payments.transaction_id
                , payment_amount
                , fee
                , payments.ref_pay
                , bank.deposit_amt
                , bank.pkey bank_pkey
                , bank.deposit_date
              FROM payments
              INNER JOIN ${stripe_deposits.SQL_TABLE_NAME} bank on bank.trn = payments.transaction_id_trunc
              WHERE payments.ref_pay = bank.ref_pay and  bank.deposit_date > '2017-12-31'
              ;;

        sql_trigger_value: select count(*) from ${stripe_deposits.SQL_TABLE_NAME} ;;
      }
      dimension: bank_pkey {
        type: number
        sql: ${TABLE}.bank_pkey ;;
      }
      dimension: transaction_id {
        sql: ${TABLE}.transaction_id ;;
      }
      dimension: deposit_amt {
        type: number
        sql: ${TABLE}.deposit_amt ;;
      }
      dimension: payment_amount {
        type: number
        sql: ${TABLE}.payment_amount ;;
      }
      dimension: fee {
        type: number
        sql: ${TABLE}.fee ;;
      }
    }

# REVENUE_WIRE_MATCHING
#   CTE to compile all wire made via payment model
#   Note: Matching can occur on the full transaction ID to the bank_reference_number in the deposit log

    view: revenue_wire_matching {
      derived_table: {
        sql:
                WITH payments as (
                  SELECT
                    transaction_id
                    , sum(amount) payment_amount
                  FROM current.payment
                  WHERE payment_method in ('cc','chck','et') and voided_by_payment_id is null
                  GROUP BY 1)

                SELECT
                  payments.transaction_id
                  , payments.payment_amount
                  , bank.deposit_amt
                  , bank.pkey bank_pkey
                  , bank.deposit_date
                  , bank.ref_pay
                FROM payments
                INNER JOIN ${bank_statement_deposits.SQL_TABLE_NAME} bank on trim(leading '0' from bank.bank_ref) = trim(leading '0' from payments.transaction_id)
                LEFT JOIN ${revenue_payment_matching.SQL_TABLE_NAME} payment on payment.bank_pkey = bank.pkey
                WHERE bank.deposit_date > '2017-12-31' and payment.bank_pkey is null
                ;;
        sql_trigger_value: select count(*) from ${bank_statement_deposits.SQL_TABLE_NAME} ;;
      }
      dimension: bank_pkey {
        type: string
        sql: ${TABLE}.bank_pkey ;;
      }
      dimension: transaction_id {
        sql: ${TABLE}.transaction_id ;;
      }
      dimension: deposit_amt {
        type: number
        sql: ${TABLE}.deposit_amt ;;
      }
    }

# REVENUE_VERAFUND_MATCHING
#   CTE to compile all payments made via payment model from Verafund lockbox
#   Note: Matching requires updates to the .csv file from Verafund (ZirMed) to translate lockbox payments (uploads.verafund_translator)

    view: revenue_verafund_matching {
      derived_table: {
        sql:
                  WITH payments as (
                    SELECT
                      substring(transaction_id from position('-' in transaction_id) + 1) transaction_id_trunc
                      , transaction_id
                      , deposit_date
                      , sum(payment.amount) amount_paid
                      --, sum(value) eob_batch_adjs
                    FROM current.payment
                    INNER JOIN
                      (SELECT check_number, deposit_date from uploads.verafund_translator group by 1,2) vt on vt.check_number = substring(trim(leading '0' from transaction_id) from position('-' in transaction_id) + 1)
                    GROUP BY 1,2,3)

                  , eob_payments as (
                    SELECT
                      check_or_eft_trace_number
                      , deposit_date
                      , amount_paid eob_paid
                      , sum(value) eob_batch_adjs
                    FROM current.eobbatch
                    INNER JOIN
                      (SELECT check_number, deposit_date from uploads.verafund_translator group by 1,2) vt on vt.check_number = substring(trim(leading '0' from check_or_eft_trace_number) from position('-' in check_or_eft_trace_number) + 1)
                    LEFT JOIN current.eobbatchadjustment eba on eba.eob_batch_id = eobbatch.id
                    LEFT JOIN uploads.duplicate_eob_batches dup on dup.eob_batch = eobbatch.id
                    WHERE duplicate_of_eob_batch_id is null and dup.eob_batch is null and abs(deposit_date - date_paid) < 30
                    GROUP BY 1,2,3)

                  SELECT
                    check_or_eft_trace_number transaction_id
                    , eob_paid amount_paid
                    , bank.deposit_amt
                    , bank.pkey bank_pkey
                    , bank.deposit_date
                    , bank.ref_pay
                  FROM eob_payments
                  INNER JOIN ${bank_statement_deposits.SQL_TABLE_NAME} bank on bank.deposit_date = eob_payments.deposit_date and left(bank.text_desc,9) = 'VERA-FUND'
                  WHERE bank.deposit_date > '2017-12-31'

                  UNION ALL

                  SELECT
                    transaction_id
                    , amount_paid
                    , bank.deposit_amt
                    , bank.pkey bank_pkey
                    , bank.deposit_date
                    , bank.ref_pay
                  FROM payments
                  LEFT JOIN eob_payments on trim(leading '0' from check_or_eft_trace_number) = trim(leading '0' from transaction_id)
                  INNER JOIN ${bank_statement_deposits.SQL_TABLE_NAME} bank on bank.deposit_date = eob_payments.deposit_date and left(bank.text_desc,9) = 'VERA-FUND'
                  WHERE bank.deposit_date > '2017-12-31' and eob_payments.check_or_eft_trace_number is null

                  ;;
        sql_trigger_value: select count(*) from uploads.verafund_translator ;;
      }
      dimension: bank_pkey {
        type: string
        sql: ${TABLE}.bank_pkey ;;
      }
      dimension: check_or_eft_trace_number {
        sql: ${TABLE}.transaction_id ;;
      }
      dimension: deposit_amt {
        type: number
        sql: ${TABLE}.deposit_amt ;;
      }
      measure: eob_paid {
        type: sum
        sql: ${TABLE}.amount_paid ;;
      }
    }

# REVENUE_MANUAL_BEACON_MATCHING
#   This is a query that handles two edge-case deposits from UHC/Beacon Labs which we never received ERA
#   The payment information is stored in uploads.manual_beacon_recon based on .csv received from the payer in lieu of ERA

    view: revenue_manual_beacon_matching {
      derived_table: {
        sql:
                  SELECT
                    CASE WHEN bank.pkey = 'current.deposittransaction000000000030016704648' THEN 'COU52319'
                      WHEN bank.pkey = 'current.deposittransaction000000000022020537663' THEN 'COU51946' ELSE eob_id::text END eob_id
                    , beacon_payments as amount_paid
                    , bank.deposit_amt
                    , bank.pkey bank_pkey
                    , 'eob'::text as payment_type
                    , bank.deposit_date
                    , bank.ref_pay
                  FROM ${bank_statement_deposits.SQL_TABLE_NAME} bank
                  LEFT JOIN uploads.manual_beacon_recon on bank.pkey = manual_beacon_recon.bank_pkey
                  WHERE (manual_beacon_recon.bank_pkey is not null or bank.pkey in ('current.deposittransaction000000000030016704648','current.deposittransaction000000000022020537663')) and deposit_date > '2017-12-31'
                  ;;
        sql_trigger_value: select count(*) from uploads.manual_beacon_recon ;;
      }
      dimension: bank_pkey {
        type: string
        sql: ${TABLE}.bank_pkey ;;
      }
      dimension: eob_id {
        sql: ${TABLE}.eob_id ;;
      }
      dimension: deposit_amt {
        type: number
        sql: ${TABLE}.deposit_amt ;;
      }
      measure: eob_paid {
        type: sum
        sql: ${TABLE}.amount_paid ;;
      }
    }

    view: revenue_matched_bank_pkeys {
      derived_table: {
        sql:
                  SELECT
                    bank_pkey
                    , deposit_amt
                    , eob_batch_id::text p_id
                    , eob_batch_adjs
                    , 'EOB Batch Adjs' as eob_batch_adj_type
                    , deposit_date
                    , ref_pay
                    , 'eob' as source
                    , 'eob' as description
                  FROM ${revenue_eob_matching.SQL_TABLE_NAME} eob
                  UNION ALL
                  SELECT
                    bank_pkey
                    , deposit_amt
                    , transaction_id
                    , eob_batch_adjs
                    , 'EOB Batch Adjs' as eob_batch_adj_type
                    , deposit_date
                    , ref_pay
                    , 'payment' as source
                    , 'payment' as description
                  FROM ${revenue_payment_matching.SQL_TABLE_NAME} payment
                  UNION ALL
                  SELECT
                    bank_pkey::text
                    , deposit_amt
                    , transaction_id p_id
                    , fee as eob_batch_adjs
                    , 'Stripe Fee' as eob_batch_adj_type
                    , deposit_date
                    , ref_pay
                    , 'payment' as source
                    , 'stripe payment' as description
                  FROM ${revenue_stripe_matching.SQL_TABLE_NAME} payment
                  WHERE ref_pay = 'Payment'
                  UNION ALL
                  SELECT
                    bank_pkey::text
                    , deposit_amt
                    , transaction_id p_id
                    , fee as eob_batch_adjs
                    , 'Stripe Fee' as eob_batch_adj_type
                    , deposit_date
                    , ref_pay
                    , 'payment' as source
                    , 'stripe refund' as description
                  FROM ${revenue_stripe_matching.SQL_TABLE_NAME} payment
                  WHERE ref_pay = 'Refund'
                  UNION ALL
                  SELECT
                    bank_pkey::text
                    , deposit_amt
                    , transaction_id p_id
                    , 0 as eob_batch_adjs
                    , 'EOB Batch Adjs' as eob_batch_adj_type
                    , deposit_date
                    , ref_pay
                    , 'payment' as source
                    , 'wire' as description
                  FROM ${revenue_wire_matching.SQL_TABLE_NAME} payment
                  UNION ALL
                  SELECT
                    bank_pkey::text
                    , deposit_amt
                    , transaction_id p_id
                    , 0 as eob_batch_adjs
                    , 'EOB Batch Adjs' as eob_batch_adj_type
                    , deposit_date
                    , ref_pay
                    , 'payment' as source
                    , 'verafund' as description
                  FROM ${revenue_verafund_matching.SQL_TABLE_NAME} payment
                  UNION ALL
                  SELECT
                    bank_pkey
                    , deposit_amt
                    , eob_id p_id
                    , 0 as eob_batch_adjs
                    , 'EOB Batch Adjs' as eob_batch_adj_type
                    , deposit_date
                    , ref_pay
                    , 'eob' as source
                    , 'manual_beacon' as description
                  FROM ${revenue_manual_beacon_matching.SQL_TABLE_NAME} payment
                  WHERE payment_type = 'eob'
                  GROUP BY 1,2,3,4,5,6,7,8
                  ;;

          sql_trigger_value: select count(*) from ${revenue_eob_matching.SQL_TABLE_NAME} eob ;;
          indexes: ["source","description"]
        }
        dimension: bank_pkey {
          type: string
          primary_key: yes
          sql: ${TABLE}.bank_pkey ;;
        }
        dimension: trn {
          sql: ${TABLE}.trn ;;
        }
        dimension: p_id {
          sql: ${TABLE}.p_id ;;
        }
        dimension: deposit_amt {
          type: number
          sql: ${TABLE}.deposit_amt ;;
        }
        dimension: source {
          sql: ${TABLE}.source ;;
        }
        dimension: description {
          sql: ${TABLE}.description ;;
        }
        measure: count {
          type: count
          sql: ${bank_pkey} ;;
        }
        measure: total_deposits {
          type: sum
          sql: ${deposit_amt} ;;
        }
      }

      view: revenue_all_matched_transactions {
        derived_table: {
          sql:
                    WITH eob_hra_sub as (
                      SELECT
                        pkeys.bank_pkey
                        , pkeys.deposit_date
                        , pkeys.ref_pay AS payment_method
                        , pkeys.deposit_amt
                        , pkeys.eob_batch_adjs
                        , pkeys.eob_batch_adj_type
                        , o.billing_clinic_id AS clinic_id
                        , eob.claim_id
                        , claim.order_id
                        , eob.paid + coalesce(hra.hra_payment,0) AS transaction_amount
                        , claim.payer_invoice_id AS invoice_id
                        , invoice.invoice_number
                        , 'Insurer' AS invoice_type
                        , eob.date_recorded AS payment_date
                        , pkeys.description
                        , concat(p_id,' ',source) AS pkey
                      FROM ${revenue_matched_bank_pkeys.SQL_TABLE_NAME} AS pkeys
                      INNER JOIN current.eob on eob.eob_batch_id::text = pkeys.p_id
                      INNER JOIN current.insuranceclaim claim on claim.id = eob.claim_id
                      INNER JOIN ${order.SQL_TABLE_NAME} AS o on o.id = claim.order_id
                      LEFT JOIN current.invoice on invoice.id = claim.payer_invoice_id
                      LEFT JOIN ${hra_payments_via_eob.SQL_TABLE_NAME} AS hra on hra.eob_id = eob.id
                      WHERE source = 'eob' and description <> 'manual_beacon'

                      UNION ALL
                      SELECT
                        pkeys.bank_pkey
                        , pkeys.deposit_date
                        , pkeys.ref_pay AS payment_method
                        , pkeys.deposit_amt
                        , pkeys.eob_batch_adjs
                        , pkeys.eob_batch_adj_type
                        , o.billing_clinic_id AS clinic_id
                        , eob.claim_id
                        , claim.order_id
                        , hra_payment * -1 AS transaction_amount
                        , claim.patient_invoice_id AS invoice_id
                        , invoice_number
                        , 'Customer' AS invoice_type
                        , eob.date_recorded AS payment_date
                        , 'hra eob' AS description
                        , concat(p_id,' ',source) AS pkey
                      FROM ${revenue_matched_bank_pkeys.SQL_TABLE_NAME} AS pkeys
                      INNER JOIN current.eob on eob.eob_batch_id::text = pkeys.p_id
                      INNER JOIN current.insuranceclaim claim on claim.id = eob.claim_id
                      INNER JOIN ${order.SQL_TABLE_NAME} AS o on o.id = claim.order_id
                      INNER JOIN current.invoice on invoice.id = claim.patient_invoice_id
                      INNER JOIN ${hra_payments_via_eob.SQL_TABLE_NAME} AS hra on hra.eob_id = eob.id
                      WHERE source = 'eob' and description <> 'manual_beacon')

                    , sub1 AS (SELECT * FROM eob_hra_sub)

                    , all_trans AS (

                      SELECT
                        pkeys.bank_pkey
                        , pkeys.deposit_date
                        , pkeys.ref_pay AS payment_method
                        , pkeys.deposit_amt
                        , pkeys.eob_batch_adjs
                        , pkeys.eob_batch_adj_type
                        , o.billing_clinic_id AS clinic_id
                        , claim.id AS claim_id
                        , o.id order_id
                        , payment.amount AS transaction_amount
                        , ii.invoice_id
                        , ii.invoice_number
                        , ii.invoice_type
                        , payment.timestamp AS payment_date
                        , pkeys.description
                        , concat(p_id,' ',source) AS pkey
                      FROM ${revenue_matched_bank_pkeys.SQL_TABLE_NAME} AS pkeys
                      INNER JOIN current.payment on trim(leading '0' from payment.transaction_id) = trim(leading'0' from pkeys.p_id)
                      INNER JOIN (SELECT invoice_id, invoice_number, order_id, invoice_type from current.invoiceitem GROUP BY 1,2,3,4) ii on ii.invoice_id = payment.invoice_id
                      INNER JOIN ${order.SQL_TABLE_NAME} AS o on o.id = ii.order_id
                      LEFT JOIN current.insuranceclaim claim on claim.order_id = o.id
                      WHERE
                        source = 'payment'
                        and description not in ('manual_beacon','stripe payment','stripe refund')
                        and CASE WHEN payment_method in ('cc','et','chck') and ii.invoice_type = 'Customer' THEN abs(payment.timestamp::date - pkeys.deposit_date::date) < 45 ELSE true END
                        and ii.invoice_type <> 'Physician'
                        and payment.voided_by_payment_id is null
                        and payment.payment_method in ('cc','chck','et','ref')

                      UNION ALL
                      SELECT
                        pkeys.bank_pkey
                        , pkeys.deposit_date
                        , pkeys.ref_pay AS payment_method
                        , pkeys.deposit_amt
                        , pkeys.eob_batch_adjs
                        , pkeys.eob_batch_adj_type
                        , ii.clinic_id
                        , null claim_id
                        , null order_id
                        , payment.amount AS transaction_amount
                        , ii.invoice_id
                        , ii.invoice_number
                        , ii.invoice_type
                        , payment.timestamp AS payment_date
                        , pkeys.description
                        , concat(p_id,' ',source) AS pkey
                      FROM ${revenue_matched_bank_pkeys.SQL_TABLE_NAME} AS pkeys
                      INNER JOIN current.payment on trim(leading '0' from payment.transaction_id) = trim(leading '0' from pkeys.p_id)
                      INNER JOIN (SELECT invoice_id, invoice_number, invoice_type, max(billing_clinic_id) clinic_id from current.invoiceitem INNER JOIN ${order.SQL_TABLE_NAME} o on o.id = invoiceitem.order_id GROUP BY 1,2,3) ii on ii.invoice_id = payment.invoice_id
                      WHERE
                        source = 'payment'
                        and description not in ('manual_beacon','stripe payment','stripe refund')
                        and ii.invoice_type = 'Physician'
                        and payment.voided_by_payment_id is null
                        --and abs(payment.timestamp::date - pkeys.deposit_date::date) < 30
                        and payment.payment_method in ('cc','chck','et','ref')

                      UNION ALL
                      SELECT
                        pkeys.bank_pkey
                        , pkeys.deposit_date
                        , pkeys.ref_pay AS payment_method
                        , pkeys.deposit_amt
                        , pkeys.eob_batch_adjs
                        , pkeys.eob_batch_adj_type
                        , ii.clinic_id
                        , claim.id claim_id
                        , o.id order_id
                        , payment.amount / count(o.id) over (partition by pkeys.bank_pkey, ii.invoice_id) AS transaction_amount
                        , ii.invoice_id
                        , ii.invoice_number
                        , ii.invoice_type
                        , payment.timestamp AS payment_date
                        , pkeys.description
                        , concat(p_id,' ',source) AS pkey
                      FROM ${revenue_matched_bank_pkeys.SQL_TABLE_NAME} AS pkeys
                      INNER JOIN current.payment on payment.transaction_id::text = pkeys.p_id
                      INNER JOIN (SELECT invoice_id, invoice_number, billing_clinic_id clinic_id, order_id, invoice_type from current.invoiceitem INNER JOIN ${order.SQL_TABLE_NAME} o on o.id = invoiceitem.order_id GROUP BY 1,2,3,4,5) ii on ii.invoice_id = payment.invoice_id
                      INNER JOIN current.order o on o.id = ii.order_id
                      LEFT JOIN current.insuranceclaim claim on claim.order_id = o.id
                      WHERE
                        description in ('stripe payment','stripe refund')
                        and payment.voided_by_payment_id is null
                        and CASE WHEN pkeys.description = 'stripe payment' THEN payment.payment_method = 'cc' ELSE payment.payment_method = 'ref' END

                      UNION ALL
                      SELECT
                        pkeys.bank_pkey
                        , pkeys.deposit_date
                        , pkeys.ref_pay AS payment_method
                        , pkeys.deposit_amt
                        , 0 AS eob_batch_adjs
                        , 'EOB Batch Adjs' AS eob_batch_adj_type
                        , o.billing_clinic_id clinic_id
                        , eob.claim_id
                        , o.id order_id
                        , pkeys.amount_paid AS transaction_amount
                        , claim.payer_invoice_id AS invoice_id
                        , invoice_number
                        , 'Insurer' AS invoice_type
                        , eob.date_recorded AS payment_date
                        , 'manual_beacon' AS description
                        , concat(eob_id,' ','manual beacon upload') AS pkey
                      FROM ${revenue_manual_beacon_matching.SQL_TABLE_NAME} AS pkeys
                      INNER JOIN current.eob on eob.id::text = pkeys.eob_id
                      INNER JOIN current.insuranceclaim claim on claim.id = eob.claim_id
                      INNER JOIN current.invoice on invoice.id = claim.payer_invoice_id
                      INNER JOIN ${order.SQL_TABLE_NAME} AS o on o.id = claim.order_id

                      UNION ALL
                      SELECT
                        pkeys.bank_pkey
                        , pkeys.deposit_date
                        , pkeys.ref_pay AS payment_method
                        , pkeys.deposit_amt
                        , 0 as eob_batch_adjs
                        , pkeys.eob_batch_adj_type
                        , o.billing_clinic_id AS clinic_id
                        , claim.id claim_id
                        , o.id order_id
                        , beacon_payments.payment_amount AS transaction_amount
                        , claim.payer_invoice_id AS invoice_id
                        , invoice.invoice_number
                        , 'Insurer' AS invoice_type
                        , beacon_payments.invoice_date AS payment_date
                        , 'manual_beacon' AS description
                        , concat(beacon_payments.invoice_number,' ','missing beacon payments') AS pkey
                      FROM (SELECT patient_control_number, invoice_date, CASE WHEN invoice_number = '170503I26A' THEN 'COU51946' ELSE 'COU52319' END invoice_number, sum(would_pay) payment_amount from uploads.beacon_payments WHERE invoice_number in ('170503I26A') GROUP BY 1,2,3) beacon_payments
                      INNER JOIN ${revenue_matched_bank_pkeys.SQL_TABLE_NAME} AS pkeys on pkeys.p_id = invoice_number
                      INNER JOIN current.insuranceclaim claim on claim.id = patient_control_number
                      INNER JOIN current.invoice on invoice.id = claim.payer_invoice_id
                      INNER JOIN current.insurancepayer payer on payer.id = claim.payer_id
                      INNER JOIN ${order.SQL_TABLE_NAME} AS o on o.id = claim.order_id

                      UNION ALL
                      SELECT
                        interest.pkey AS bank_pkey
                        , bank.deposit_date
                        , bank.ref_pay AS payment_method
                        , bank.deposit_amt
                        , null as eob_batch_adjs
                        , 'Interest Only' AS eob_batch_adj_type
                        , null as clinic_id
                        , null as claim_id
                        , null as order_id
                        , interest.interest AS transaction_amount
                        , null as invoice_id
                        , null as invoice_number
                        , null as invoice_type
                        , bank.deposit_date AS payment_date
                        , concat(interest.pkey,' ','interest only') AS pkey
                        , 'interest only' AS description
                      FROM uploads.interest
                      INNER JOIN ${bank_statement_deposits.SQL_TABLE_NAME} AS bank on bank.pkey = interest.pkey
                      WHERE bank.deposit_date > '2017-12-31'

                      UNION ALL
                      SELECT
                        bank.pkey AS bank_pkey
                        , bank.deposit_date
                        , bank.ref_pay AS payment_method
                        , bank.deposit_amt
                        , coalesce(recon.eob_batch_adjs,0) AS eob_batch_adjs
                        , 'EOB Batch Adjs' AS eob_batch_adj_type
                        , o.billing_clinic_id AS clinic_id
                        , eob.claim_id
                        , claim.order_id
                        , eob.paid AS transaction_amount
                        , claim.payer_invoice_id AS invoice_id
                        , invoice.invoice_number
                        , 'Insurer' AS invoice_type
                        , eob.date_recorded payment_date
                        , concat(recon.eob_batch_id,' ','manual eob recon') AS pkey
                        , 'manual upload eob' AS description
                      FROM uploads.manual_recon_file recon
                      INNER JOIN ${bank_statement_deposits.SQL_TABLE_NAME} AS bank on bank.pkey = recon.pkey
                      INNER JOIN current.eob on eob.eob_batch_id::text = recon.eob_batch_id::text
                      LEFT JOIN ${revenue_matched_bank_pkeys.SQL_TABLE_NAME} AS pkeys on pkeys.bank_pkey = bank.pkey
                      LEFT JOIN current.insuranceclaim claim on claim.id = eob.claim_id
                      LEFT JOIN ${order.SQL_TABLE_NAME} AS o on o.id = claim.order_id
                      LEFT JOIN current.invoice on invoice.id = claim.payer_invoice_id
                      WHERE pkeys.bank_pkey is null and bank.deposit_date > '2017-12-31'

                      UNION ALL
                      SELECT
                        bank.pkey bank_pkey
                        , bank.deposit_date
                        , bank.ref_pay AS payment_method
                        , bank.deposit_amt
                        , coalesce(recon.eob_batch_adjs,0) AS eob_batch_adjs
                        , 'EOB Batch Adjs' AS eob_batch_adj_type
                        , o.billing_clinic_id AS clinic_id
                        , claim.id claim_id
                        , o.id order_id
                        , payment.amount AS transaction_amount
                        , invoice.id AS invoice_id
                        , invoice.invoice_number
                        , invoice."type" AS invoice_type
                        , payment.timestamp AS payment_date
                        , concat(recon.eob_batch_id,' ','manual payment recon') AS pkey
                        , 'manual upload payment' as description
                      FROM uploads.manual_recon_file recon
                      INNER JOIN ${bank_statement_deposits.SQL_TABLE_NAME} AS bank on bank.pkey = recon.pkey
                      INNER JOIN ${payment.SQL_TABLE_NAME} AS payment on payment.transaction_id = recon.transaction_id
                      LEFT JOIN ${revenue_matched_bank_pkeys.SQL_TABLE_NAME} AS pkeys on pkeys.bank_pkey = bank.pkey
                      INNER JOIN current.invoice on invoice.id = payment.invoice_id
                      INNER JOIN ${invoiceitem.SQL_TABLE_NAME} AS ii on ii.invoice_id = invoice.id
                      INNER JOIN ${order.SQL_TABLE_NAME} AS o on o.id = ii.order_id
                      LEFT JOIN current.insuranceclaim claim on claim.order_id = o.id
                      WHERE pkeys.bank_pkey is null and bank.deposit_date > '2017-12-31'

                      UNION ALL
                      SELECT
                        null AS bank_pkey
                        , null AS deposit_date
                        , 'comp' AS payment_method
                        , null AS deposit_amt
                        , null AS eob_batch_adjs
                        , null AS eob_batch_adj_type
                        , o.clinic_id
                        , claim.id AS claim_id
                        , o.id AS order_id
                        , payment.amount AS transaction_amount
                        , payment.invoice_id
                        , invoice.invoice_number
                        , invoice."type" AS invoice_type
                        , payment.timestamp AS payment_date
                        , 'comp' AS description
                        , concat(payment.id,'comp') AS pkey
                      FROM ${payment.SQL_TABLE_NAME} AS payment
                      INNER JOIN current.insuranceclaim claim on claim.patient_invoice_id = payment.invoice_id
                      INNER JOIN current.invoice on invoice.id = claim.patient_invoice_id
                      INNER JOIN ${order.SQL_TABLE_NAME} AS o on o.id = claim.order_id
                      WHERE payment.timestamp > '2017-12-31' and payment.payment_method = 'comp'

                      UNION ALL SELECT * FROM sub1)

                    SELECT
                      all_trans.*
                      , o.completed_on
                      , o.latest_barcode::text barcode
                      , product::text
                      , testing_methodology::integer
                      , bill_type::text
                      , payer.name::text AS payer_name
                      , CASE WHEN o.bill_type = 'in' THEN coalesce(inn.network_status,'OON') ELSE null END network_status
                      , bank.rev_trn::text
                      , CASE
                            WHEN (inn.network_status = 'OON' or inn.network_status is null)
                              AND (o.completed_on is not null and all_trans.deposit_date is not null)
                              THEN
                              CASE
                                WHEN o.completed_on::date >= all_trans.deposit_date THEN o.completed_on::date
                                WHEN  all_trans.deposit_date > o.completed_on::date THEN all_trans.deposit_date ELSE null
                              END
                            WHEN inn.network_status = 'In Net' THEN
                              CASE
                                WHEN o.completed_on is null THEN '2020-01-01'::date ELSE o.completed_on END
                            ELSE o.completed_on END AS rev_rec_date
                      , sum(transaction_amount) over (partition by bank_pkey) AS total_recorded_for_deposit
                      , max(eob_batch_adjs) over (partition by bank_pkey) AS eob_batch_adj
                      , row_number() over (partition by bank_pkey) AS order_count
                    FROM all_trans
                    LEFT JOIN current.order o on o.id = all_trans.order_id
                    LEFT JOIN current.insuranceclaim claim on claim.order_id = o.id
                    LEFT JOIN current.insurancepayer payer on payer.id = claim.payer_id
                    LEFT JOIN ${finance_in_network_order_ids.SQL_TABLE_NAME} AS inn on inn.order_id = o.id
                    LEFT JOIN ${bank_statement_deposits.SQL_TABLE_NAME} AS bank on bank.pkey = all_trans.bank_pkey

                    UNION ALL
                    SELECT
                      match.bank_pkey
                      , match.deposit_date
                      , match.payment_method
                      , match.deposit_amt
                      , match.eob_batch_adjs
                      , match.eob_batch_adj_type
                      , match.clinic_id
                      , match.claim_id
                      , match.order_id
                      , match.transaction_amount
                      , match.invoice_id
                      , match.invoice_number
                      , match.invoice_type
                      , match.payment_date
                      , match.pkey
                      , match.description
                      , o.completed_on
                      , o.latest_barcode::text AS barcode
                      , o.product
                      , o.testing_methodology::integer
                      , o.bill_type::text
                      , payer.name::text AS payer_name
                      , CASE WHEN o.bill_type = 'in' THEN coalesce(inn.network_status,'OON') ELSE null END network_status
                      , match.rev_trn
                      , match.rev_rec_date
                      , match.total_recorded_for_deposit
                      , match.eob_batch_adj
                      , match.order_count
                    FROM uploads.revenue_all_matched_as_of_20180104 AS match
                    LEFT JOIN current.order o on o.id = match.order_id
                    LEFT JOIN current.insuranceclaim claim on claim.order_id = o.id
                    LEFT JOIN current.insurancepayer payer on payer.id = claim.payer_id
                    LEFT JOIN ${finance_in_network_order_ids.SQL_TABLE_NAME} AS inn on inn.order_id = o.id
                    WHERE deposit_date < '2018-01-01' OR (deposit_date IS NULL AND payment_date::date < '2018-01-01')
                  ;;

            sql_trigger_value: select count(*) from ${revenue_matched_bank_pkeys.SQL_TABLE_NAME};;
          }
          dimension: bank_pkey {
            type: string
            sql: ${TABLE}.bank_pkey ;;
          }

          dimension: pkey {
            type: string
            sql: ${TABLE}.pkey ;;
          }
          dimension: deposit_amt {
            type: number
            sql: ${TABLE}.deposit_amt ;;
          }
          dimension: eob_batch_adj {
            type: number
            sql: coalesce(${TABLE}.eob_batch_adj,0) ;;
          }
          dimension: eob_batch_adj_type {
            sql: ${TABLE}.eob_batch_adj_type ;;
          }
          dimension: claim_id {
            type: number
            hidden:  yes
            sql: ${TABLE}.claim_id ;;
          }
          dimension: clinic_id {
            type: number
            hidden:  yes
            sql: ${TABLE}.clinic_id ;;
          }
          dimension: order_id {
            type: number
            hidden:  yes
            sql: ${TABLE}.order_id ;;
          }
          dimension: transaction_amount {
            type: number
            sql: ${TABLE}.transaction_amount ;;
          }
          dimension: source_description {
            sql: ${TABLE}.description ;;
          }
          dimension: invoice_id {
            type: number
            sql: ${TABLE}.invoice_id ;;
          }
          dimension: network_status {
            hidden: yes
            sql: ${TABLE}.network_status ;;
          }
          dimension: rev_trn {
            sql: ${TABLE}.rev_trn ;;
          }
          dimension: payment_method {
            alias: [ref_pay]
            sql: ${TABLE}.payment_method ;;
          }
          dimension: barcode {
            sql: ${TABLE}.barcode ;;
          }
          dimension_group: completed_on {
            type: time
            timeframes: [date, month, quarter, year]
            sql: ${TABLE}.completed_on ;;
          }

        dimension_group: deposit_date {
          type: time
          timeframes: [date, month, quarter, year]
          sql: ${TABLE}.deposit_date ;;
        }

          dimension: invoice_type {
            type: string
            sql: ${TABLE}.invoice_type ;;
          }
          dimension: invoice_number {
            sql: ${TABLE}.invoice_number ;;
          }
          dimension: payer_name {
            type: string
            sql: ${TABLE}.payer_name ;;
          }
          dimension: payment_date {
            type: date
            sql: ${TABLE}.payment_date ;;
          }
          dimension: total_recorded_for_deposit {
            type: number
            sql: ${TABLE}.total_recorded_for_deposit ;;
          }
          dimension: order_count {
            type: number
            hidden:  yes
            sql: ${TABLE}.order_count ;;
          }
          dimension: match_type {
            case: {
              when: {
                label: "Matched No Var"
                sql: abs(${total_recorded_for_deposit} - coalesce(${eob_batch_adj},0) - ${deposit_amt}) < 5 ;;
              }
              when: {
                label: "Matched With Var"
                sql: abs(${total_recorded_for_deposit} - coalesce(${eob_batch_adj},0) - ${deposit_amt}) >= 5 ;;
              }
              else: "Unmatched"
            }
          }
          dimension: primary_key {
            primary_key: yes
            type: string
            sql: concat(${bank_pkey},${invoice_id},${order_id},${payment_date},${transaction_amount},${source_description},${order_count}) ;;
          }
        measure: avg_cash_collected_within_15_yield {
          label: "Yield: Avg. Cash Collected In 15 Days"
          description: "Yield curve for average cash collected within 15 days from completed date"
          type: number
          value_format_name: usd
          sql: sum(CASE WHEN current_date - ${completed_on_date} < 15 THEN NULL
                    WHEN ${deposit_date_date} - ${completed_on_date} <= 15 THEN transaction_amount ELSE 0 END) / CASE WHEN current_date - (${order.completed_week}::date + 5) > 15 THEN nullif(${yield_15_denominator},0) ELSE null END
                   ;;
        }

        measure: yield_15_denominator {
          hidden: yes
          type: number
          sql: count(distinct CASE WHEN current_date - ${order.completed_date} >= 15 THEN ${claim.id} ELSE NULL END)
            ;;
        }

        measure: avg_cash_collected_within_30_yield {
          label: "Yield: Avg. Cash Collected In 30 Days"
          description: "Yield curve for average cash collected within 30 days from completed date"
          type: number
          value_format_name: usd
          sql: sum(CASE WHEN current_date - ${completed_on_date} < 30 THEN NULL
                    WHEN ${deposit_date_date} - ${completed_on_date} <= 30 THEN transaction_amount ELSE 0 END) / CASE WHEN current_date - (${order.completed_week}::date + 5) > 30 THEN nullif(${yield_30_denominator},0) ELSE null END
                   ;;
        }

        measure: yield_30_denominator {
          hidden: yes
          type: number
          sql: count(distinct CASE WHEN current_date - ${order.completed_date} >= 30 THEN ${claim.id} ELSE NULL END)
            ;;
        }

        measure: avg_cash_collected_within_45_yield {
          label: "Yield: Avg. Cash Collected In 45 Days"
          description: "Yield curve for average cash collected within 45 days from completed date"
          type: number
          value_format_name: usd
          sql: sum(CASE WHEN current_date - ${order.completed_date} < 45 THEN NULL
                    WHEN ${deposit_date_date} - ${completed_on_date} <= 45 THEN transaction_amount ELSE 0 END) / CASE WHEN current_date - (${order.completed_week}::date + 5) > 45 THEN nullif(${yield_45_denominator},0) ELSE null END
                   ;;
        }

        measure: yield_45_denominator {
          hidden: yes
          type: number
          sql: count(distinct CASE WHEN current_date - ${order.completed_date} >= 45 THEN ${claim.id} ELSE NULL END)
            ;;
        }

        measure: avg_cash_collected_within_60_yield {
          label: "Yield: Avg. Cash Collected In 60 Days"
          description: "Yield curve for average cash collected within 60 days from completed date"
          type: number
          value_format_name: usd
          sql: sum(CASE WHEN current_date - ${order.completed_date} < 60 THEN NULL
                    WHEN ${deposit_date_date} - ${completed_on_date} <= 60 THEN transaction_amount ELSE 0 END) / CASE WHEN current_date - (${order.completed_week}::date + 5) > 60 THEN nullif(${yield_60_denominator},0) ELSE null END
                   ;;
        }

        measure: yield_60_denominator {
          hidden: yes
          type: number
          sql: count(distinct CASE WHEN current_date - ${order.completed_date} >= 60 THEN ${claim.id} ELSE NULL END)
            ;;
        }

        measure: avg_cash_collected_within_90_yield {
          label: "Yield: Avg. Cash Collected In 90 Days"
          description: "Yield curve for average cash collected within 90 days from completed date"
          type: number
          value_format_name: usd
          sql: sum(CASE WHEN current_date - ${order.completed_date} < 90 THEN NULL
                    WHEN ${deposit_date_date} - ${completed_on_date} <= 90 THEN transaction_amount ELSE 0 END) / CASE WHEN current_date - (${order.completed_week}::date + 5) > 90 THEN nullif(${yield_90_denominator},0) ELSE null END
                   ;;
        }

        measure: yield_90_denominator {
          hidden: yes
          type: number
          sql: count(distinct CASE WHEN current_date - ${order.completed_date} >= 90 THEN ${claim.id} ELSE NULL END)
            ;;
        }

        measure: avg_cash_collected_within_120_yield {
          label: "Yield: Avg. Cash Collected In 120 Days"
          description: "Yield curve for average cash collected within 120 days from completed date"
          type: number
          value_format_name: usd
          sql: sum(CASE WHEN current_date - ${order.completed_date} < 120 THEN NULL
                    WHEN ${deposit_date_date} - ${completed_on_date} <= 120 THEN transaction_amount ELSE 0 END) / CASE WHEN current_date - (${order.completed_week}::date + 5) > 120 THEN nullif(${yield_120_denominator},0) ELSE null END
                   ;;
        }

        measure: yield_120_denominator {
          hidden: yes
          type: number
          sql: count(distinct CASE WHEN current_date - ${order.completed_date} >= 120 THEN ${claim.id} ELSE NULL END)
            ;;
        }

        measure: avg_cash_collected_within_180_yield {
          label: "Yield: Avg. Cash Collected In 180 Days"
          description: "Yield curve for average cash collected within 180 days from completed date"
          type: number
          value_format_name: usd
          sql: sum(CASE WHEN current_date - ${order.completed_date} < 180 THEN NULL
                    WHEN ${deposit_date_date} - ${completed_on_date} <= 180 THEN transaction_amount ELSE 0 END) / CASE WHEN current_date - (${order.completed_week}::date + 5) > 180 THEN nullif(${yield_180_denominator},0) ELSE null END
                   ;;
        }

        measure: yield_180_denominator {
          hidden: yes
          type: number
          sql: count(distinct CASE WHEN current_date - ${order.completed_date} >= 180 THEN ${claim.id} ELSE NULL END)
            ;;
        }

        measure: avg_cash_collected_within_365_yield {
          label: "Yield: Avg. Cash Collected In 365 Days"
          description: "Yield curve for average cash collected within 365 days from completed date"
          type: number
          value_format_name: usd
          sql: sum(CASE WHEN current_date - ${order.completed_date} < 365 THEN NULL
                    WHEN ${deposit_date_date} - ${completed_on_date} <= 365 THEN transaction_amount ELSE 0 END) / CASE WHEN current_date - (${order.completed_week}::date + 5) > 365 THEN nullif(${yield_365_denominator},0) ELSE null END
                   ;;
        }

        measure: yield_365_denominator {
          hidden: yes
          type: number
          sql: count(distinct CASE WHEN current_date - ${order.completed_date} >= 365 THEN ${claim.id} ELSE NULL END)
            ;;
        }

        measure: cash_collected_within_15_yield {
          label: "Yield: Total Cash Collected In 15 Days"
          description: "Yield curve for total cash collected within 15 days from completed date"
          type: number
          value_format_name: usd_0
          sql: sum(CASE WHEN ${deposit_date_date} - ${completed_on_date} <= 15 THEN transaction_amount ELSE 0 END)
            ;;
        }

        measure: cash_collected_within_30_yield {
          label: "Yield: Total Cash Collected In 30 Days"
          description: "Yield curve for total cash collected within 30 days from completed date"
          type: number
          value_format_name: usd_0
          sql: sum(CASE WHEN ${deposit_date_date} - ${completed_on_date} <= 30 THEN transaction_amount ELSE 0 END)
            ;;
        }

        measure: cash_collected_within_45_yield {
          label: "Yield: Total Cash Collected In 45 Days"
          description: "Yield curve for total cash collected within 45 days from completed date"
          type: number
          value_format_name: usd_0
          sql: sum(CASE WHEN ${deposit_date_date} - ${completed_on_date} <= 45 THEN transaction_amount ELSE 0 END)
            ;;
        }

        measure: cash_collected_within_60_yield {
          label: "Yield: Total Cash Collected In 60 Days"
          description: "Yield curve for total cash collected within 60 days from completed date"
          type: number
          value_format_name: usd_0
          sql: sum(CASE WHEN ${deposit_date_date} - ${completed_on_date} <= 60 THEN transaction_amount ELSE 0 END)
            ;;
        }

        measure: cash_collected_within_90_yield {
          label: "Yield: Total Cash Collected In 90 Days"
          description: "Yield curve for total cash collected within 90 days from completed date"
          type: number
          value_format_name: usd_0
          sql: sum(CASE WHEN ${deposit_date_date} - ${completed_on_date} <= 90 THEN transaction_amount ELSE 0 END)
            ;;
        }

        measure: cash_collected_within_120_yield {
          label: "Yield: Total Cash Collected In 120 Days"
          description: "Yield curve for cash collected within 120 days from completed date"
          type: number
          value_format_name: usd_0
          sql: sum(CASE WHEN ${deposit_date_date} - ${completed_on_date} <= 120 THEN transaction_amount ELSE 0 END)
            ;;
        }

        measure: cash_collected_within_180_yield {
          label: "Yield: Total Cash Collected In 180 Days"
          description: "Yield curve for total cash collected within 180 days from completed date"
          type: number
          value_format_name: usd_0
          sql: sum(CASE WHEN ${deposit_date_date} - ${completed_on_date} <= 180 THEN transaction_amount ELSE 0 END)
            ;;
        }

        measure: cash_collected_within_365_yield {
          label: "Yield: Total Cash Collected In 365 Days"
          description: "Yield curve for total cash collected within 365 days from completed date"
          type: number
          value_format_name: usd_0
          sql: sum(CASE WHEN ${deposit_date_date} - ${completed_on_date} <= 365 THEN transaction_amount ELSE 0 END)
            ;;
        }


          measure: total_transaction_recorded {
            type: sum
            value_format_name: usd
            sql: ${transaction_amount};;
          }
          measure: matched_variance {
            type: sum_distinct
            value_format_name: usd
            sql: bank_statement_deposits.deposit_amt - coalesce(${total_recorded_for_deposit},0) + coalesce(${eob_batch_adj},0) ;;
            sql_distinct_key: bank_statement_deposits.pkey ;;
          }
        }
