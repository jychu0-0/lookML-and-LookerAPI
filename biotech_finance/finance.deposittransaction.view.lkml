view: deposittransaction {
  derived_table: {
    sql: SELECT
        deposittransaction.id
        , deposittransaction.account_id
        , deposittransaction.amount
        , deposittransaction.bank_reference
        , deposittransaction.created_at AT TIME ZONE 'PST' as created_at
        , deposittransaction.customer_reference
        , deposittransaction.detail
        , deposittransaction.funds_type
        , deposittransaction.group_id
        , deposittransaction.lockbox_file_id
        , deposittransaction.modified_at AT TIME ZONE 'PST' as modified_at
        , deposittransaction.payment_gateway_transfer_id
        , deposittransaction.reconciliation_key
        , deposittransaction.type_code
        , deposittransaction.requires_reconciliation
        , as_of_datetime at time zone 'pst' as as_of_datetime
      FROM
        current.deposittransaction
      LEFT JOIN current.depositgroup ON depositgroup.id = deposittransaction.group_id
       ;;
    datagroup_trigger: etl_refresh
  }

  dimension: id {
    primary_key: yes
    description: "Primary key representing unique deposits to a Counsyl bank account"
    type: number
    sql: ${TABLE}.id ;;
  }

  dimension: account_id {
    description: "The number identifying the bank account that a deposit is made to"
    type: number
    sql: ${TABLE}.account_id ;;
  }

  dimension: deposit_date {
    description: "The date on which a bank deposit was recorded to the account"
    type: date
    sql: ${TABLE}.as_of_datetime ;;
  }

  dimension: amount {
    description: "The dollar amount that was deposited to the bank account in this transaction"
    type: number
    value_format_name: usd
    sql: ${TABLE}.amount ;;
  }

  dimension: bank_reference {
    description: "Unique key created by the bank for individual deposit items"
    type: string
    sql: ${TABLE}.bank_reference ;;
  }

  dimension_group: created {
    description: " The date the deposit file was created. Differs from deposit date in for the large backlog of deposit files from prior periods."
    type: time
    timeframes: [time, date, week, month]
    sql: ${TABLE}.created_at ;;
  }


  dimension: detail {
    description: "The string which contains electronic or check payment information details"
    type: string
    sql: ${TABLE}.detail ;;
  }

  dimension: funds_type {
    description: "Machine-readable JSON output from which deposit data was gleaned"
    type: string
    sql: ${TABLE}.funds_type ;;
  }

  dimension: group_id {
    description: "Foreign key to the depositgroup table"
    type: number
    sql: ${TABLE}.group_id ;;
  }

  dimension: lockbox_file_id {
    description: "Foreign key to the lockboxfile table"
    type: number
    sql: ${TABLE}.lockbox_file_id ;;
  }

  dimension_group: modified {
    type: time
    description: "Date the deposit transaction report was modified"
    timeframes: [time, date, week, month]
    sql: ${TABLE}.modified_at ;;
  }

  dimension: payment_gateway_transfer_id {
    description: "Foreign key to the payment gateway transfer table"
    type: number
    sql: ${TABLE}.payment_gateway_transfer_id ;;
  }

  dimension: reconciliation_key {
    description: "The parsed-out transaction ID from detail, and represents the check number, EFT number, etc. of the payment. This is used to key against the custom_hybrid_file.transaction_id in reconciling deposits to payments logged in website."
    type: string
    sql: ${TABLE}.reconciliation_key ;;
  }

  dimension: requires_reconciliation {
    description: "Flags whether this is a deposit that corresponds to revenue, and needs to be reconciled against payments in website."
    type: yesno
    sql: ${TABLE}.requires_reconciliation ;;
  }

  dimension: type_code {
    description: "The numeric code identifying the BAI file format used for reporting"
    type: string
    sql: ${TABLE}.type_code ;;
  }

  measure: count {
    description: "The number of unique deposit transactions made"
    type: count
    drill_fields: [id]
  }
}