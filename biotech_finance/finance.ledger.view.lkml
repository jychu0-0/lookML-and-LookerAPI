view: ledger {
  sql_table_name: current.ledger ;;

  dimension: id {
    primary_key: yes
    type: number
    sql: ${TABLE}.id ;;
  }

  dimension: entity_content_type_id {
    type: number
    sql: ${TABLE}.entity_content_type_id ;;
  }

  dimension: entity_id {
    type: number
    sql: ${TABLE}.entity_id ;;
  }

  dimension: increased_by_debits {
    type: yesno
    sql: ${TABLE}.increased_by_debits ;;
  }

  dimension: name {
    type: string
    sql: ${TABLE}.name ;;
  }

  dimension: type {
    type: string
    sql: ${TABLE}.type ;;
  }

  measure: count {
    type: count
    drill_fields: [id, name, ledgerentry.count]
  }
}
