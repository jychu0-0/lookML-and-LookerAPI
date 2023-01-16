view: transactionrelatedobject {
  sql_table_name: current.transactionrelatedobject ;;

  dimension: id {
    primary_key: yes
    type: number
    sql: ${TABLE}.id ;;
  }

  dimension: order_id {
    type: number
    # hidden: true
    sql: ${TABLE}.order_id ;;
  }

  dimension: payment_gateway_transfer_transaction_id {
    type: number
    sql: ${TABLE}.payment_gateway_transfer_transaction_id ;;
  }

  dimension: primary {
    type: yesno
    sql: ${TABLE}."primary" ;;
  }

  dimension: related_object_content_type_id {
    type: number
    sql: ${TABLE}.related_object_content_type_id ;;
  }

  dimension: related_object_id {
    type: number
    sql: ${TABLE}.related_object_id ;;
  }

  dimension: transaction_id {
    type: number
    # hidden: true
    sql: ${TABLE}.transaction_id ;;
  }

  measure: count {
    type: count
    drill_fields: [id, transaction.id, order.id]
  }
}
