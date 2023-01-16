view: lockbox {
  sql_table_name: uploads.lockbox ;;

  dimension: acct_num {
    sql: ${TABLE}.acct_num ;;
  }

  dimension: bank_number {
    type: number
    sql: ${TABLE}.bank_number ;;
  }

  dimension: batch {
    type: number
    sql: ${TABLE}.batch ;;
  }

  dimension: check_amt {
    type: number
    sql: ${TABLE}.check_amt ;;
  }

  dimension: check_num {
    sql: ${TABLE}.check_num ;;
  }

  dimension_group: deposit {
    type: time
    timeframes: [quarter, date, week, month]
    convert_tz: no
    sql: ${TABLE}.deposit_date ;;
  }

  dimension: lockbox_num {
    type: number
    sql: ${TABLE}.lockbox_num ;;
  }

  dimension: recorded {
    sql: ${TABLE}.recorded ;;
  }

  dimension: remitter {
    sql: ${TABLE}.remitter ;;
  }

  dimension: seq {
    type: number
    sql: ${TABLE}.seq ;;
  }

  dimension: trans_type {
    sql: ${TABLE}.trans_type ;;
  }

  measure: count {
    type: count
    drill_fields: []
  }
}
