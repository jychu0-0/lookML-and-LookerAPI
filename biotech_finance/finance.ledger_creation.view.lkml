view: ledger_creation {
  derived_table: {
    sql: select
        ledger_id
        , sum(ledger_amount) as ledger_amount
      from

      -- Step 1

        (select
          pgxx.id
          , ledgerentry.ledger_id
          ,concat('ledgerentry_',ledgerentry.id::text) as ledger_entry_id
          , CASE
              WHEN ledgerentry.ledger_id = 2 and type = 'Reconciliation' THEN ledgerentry.amount - (fee/c.transaction_count)* -1
              WHEN ledgerentry.ledger_id = 2 and type = 'Automatic' THEN ledgerentry.amount - fee
              WHEN ledgerentry.ledger_id = 3 THEN ledgerentry.amount - fee/c.transaction_count
              WHEN ledgerentry.ledger_id = 1 THEN ledgerentry.amount
              ELSE 999999999
            END as ledger_amount
          from current.ledgerentry
          inner join current.transaction on transaction.id = ledgerentry.transaction_id
          inner join current.transactionrelatedobject as tro on tro.transaction_id = transaction.id
          inner join current.paymentgatewaytransfertransaction as pgxx on pgxx.id = tro.payment_gateway_transfer_transaction_id
          inner join current.paymentgatewaytransfer as pgx on pgx.id = pgxx.transfer_id
          inner join
            (select
              pgxx.id
              , count(tro.id) as transaction_count
            from
              current.paymentgatewaytransfertransaction as pgxx
            inner join
              current.transactionrelatedobject as tro on tro.payment_gateway_transfer_transaction_id = pgxx.id
            where
              tro.primary = 'f'
            group by
              1
            ) as c on c.id = pgxx.id
          where transaction_type != 'transfer' and expected_transfer_date > '2015-12-01' and expected_transfer_date < '2016-02-01'

      -- Step 2
      union
        select
          pgxx.id
          , 6 as ledger_id
          , concat('step_2_',pgxx.id::text) as ledger_entry_id
          , fee as ledger_amount
        from
          current.paymentgatewaytransfertransaction as pgxx
        inner join current.paymentgatewaytransfer as pgx on pgx.id = pgxx.transfer_id
        where transaction_type != 'transfer' and expected_transfer_date > '2015-12-01' and expected_transfer_date < '2016-02-01'

      -- Step 3
      union
        select
          pgxx.id
          , 3 as ledger_id
          , concat('step_3_',pgxx.id::text) as ledger_entry_id
          , pgxx.net * -1 as ledger_amount
        from
          current.paymentgatewaytransfertransaction as pgxx
        inner join
          current.paymentgatewaytransfer as pgx on pgx.id = pgxx.transfer_id
        where transaction_type != 'transfer' and expected_transfer_date > '2015-12-01' and expected_transfer_date < '2016-02-01'

      -- Step 4
      union
        select
          pgxx.id
          , 4 as ledger_id
          , concat('step_4_',pgxx.id::text) as ledger_entry_id
          , pgxx.net as ledger_amount

        from
          current.paymentgatewaytransfertransaction as pgxx
        inner join
          current.paymentgatewaytransfer as pgx on pgx.id = pgxx.transfer_id
        where transaction_type != 'transfer' and expected_transfer_date > '2015-12-01' and expected_transfer_date < '2016-02-01'

      --Step 5
      union
        select
          pgxx.id
          , 4 as ledger_id
          , concat('step_5_',pgxx.id) as ledger_entry_id
          , pgxx.net * -1 as ledger_amount
        from
          current.paymentgatewaytransfertransaction as pgxx
        inner join current.paymentgatewaytransfer as pgx on pgx.id = pgxx.transfer_id
        inner join
          current.deposittransaction as dep on dep.payment_gateway_transfer_id = pgxx.transfer_id
        where
          transaction_type != 'transfer' and expected_transfer_date > '2015-12-01' and expected_transfer_date < '2016-02-01'

      --Step 6
      union
        select
          pgxx.id
          , 5 as ledger_id
          , concat('step_6_',pgxx.id) as ledger_entry_id
          , pgxx.net as ledger_amount
        from
          current.paymentgatewaytransfertransaction as pgxx
        inner join current.paymentgatewaytransfer as pgx on pgx.id = pgxx.transfer_id
        inner join
          current.deposittransaction as dep on dep.payment_gateway_transfer_id = pgxx.transfer_id
        where
          transaction_type != 'transfer' and expected_transfer_date > '2015-12-01' and expected_transfer_date < '2016-02-01'

        ) as subquery

        group by 1
        order by 1 asc


      limit 100
       ;;
  }

  measure: count {
    type: count
    drill_fields: [detail*]
  }

  dimension: ledger_id {
    type: number
    sql: ${TABLE}.ledger_id ;;
  }

  dimension: ledger_amount {
    type: number
    sql: ${TABLE}.ledger_amount ;;
  }

  set: detail {
    fields: [ledger_id, ledger_amount]
  }
}
