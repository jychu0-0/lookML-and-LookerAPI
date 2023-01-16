view: ledgerentry {
  sql_table_name: current.ledgerentry ;;

  dimension: id {
    primary_key: yes
    type: number
    sql: ${TABLE}.id ;;
  }

  dimension: action_type {
    type: string
    sql: ${TABLE}.action_type ;;
  }

  dimension: amount {
    type: number
    sql: ${TABLE}.amount ;;
  }

  dimension: entry_id {
    type: string
    sql: ${TABLE}.entry_id ;;
  }

  dimension: ledger_id {
    type: number
    # hidden: true
    sql: ${TABLE}.ledger_id ;;
  }

  dimension: transaction_id {
    type: number
    # hidden: true
    sql: ${TABLE}.transaction_id ;;
  }

  measure: count {
    type: count
    drill_fields: [id, transaction.id, ledger.name, ledger.id]
  }
}
