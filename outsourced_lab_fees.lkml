
view: outsourced_lab_fees {
  derived_table: {
    sql:
        SELECT
        id
        , latest_barcode
        , product
        , completed_on
        , invoice_number
        , invoice_date
        , CASE WHEN invoice_number IS NULL THEN FALSE ELSE TRUE END AS is_invoiced
        FROM (
          SELECT
          o.id
          , latest_barcode
          , product
          , completed_on
          FROM ${order.SQL_TABLE_NAME} AS o
          INNER JOIN ${ordering_clinic.SQL_TABLE_NAME} AS clinic ON o.clinic_id = clinic.id
          WHERE clinic.state = 'NY' AND o.completed_on >= '2016-01-01' AND product = 'Prelude Prenatal Screen') AS oo
        LEFT JOIN costing.verinatainvoices AS vi ON vi.barcode::varchar = oo.latest_barcode::varchar ;;
    sql_trigger_value: select * from current.finance_export_current_schema ;;
    indexes: ["id", "product", "completed_on", "invoice_number", "invoice_date"]
  }
  dimension: latest_barcode {
    label: "Barcode"
    description: "The latest barcode for an order"
    value_format: "00"
    type: number
    sql: ${TABLE}.latest_barcode ;;
  }
  dimension: product {
    label: "Product"
    type: string
    sql: ${TABLE}.product ;;
  }

  dimension_group: completed_on {
    label: "Complete Date"
    type: time
    timeframes: [date, month, quarter, year]
    sql: ${TABLE}.completed_on ;;
  }

  dimension: invoice_number {
    label: "Verinata Invoice Number"
    value_format: "00"
    type: number
    sql: ${TABLE}.invoice_number ;;
  }

  dimension_group: invoice_date {
    label: "Verinata Invoice Date"
    type: time
    timeframes: [date, month, quarter, year]
    sql: ${TABLE}.invoice_date ;;
  }

  dimension: is_invoiced {
    label: "Has Verinata Invoiced?"
    type: yesno
    sql: ${TABLE}.is_invoiced ;;
  }

  measure: order_count {
    type: number
    sql: count(distinct ${TABLE}.id) ;;
  }
}

view: material_requirements_planning {
  derived_table: {
    sql:
        SELECT
        item
        , stage
        , usage_per_batch
        , batch_size
        , yield
        , control
        FROM costing.mrp;;
    sql_trigger_value: select * from current.finance_export_current_schema ;;
    indexes: ["item", "stage", "usage_per_batch", "yield", "control"]
  }
  dimension: item {
    type: string
    sql: ${TABLE}.item ;;
  }

  dimension: stage {
    type: string
    sql: ${TABLE}.stage ;;
  }

  dimension: usage_per_batch {
    type: number
    sql: ${TABLE}.usage_per_batch ;;
  }

  dimension: batch_size {
    type: number
    sql: ${TABLE}.batch_size ;;
  }

  dimension: control {
    type: number
    sql: ${TABLE}.control ;;
  }

  dimension: yield {
    type: number
    sql: ${TABLE}.yield ;;
  }


  filter: input_filter {
    default_value: "1"
  }

  measure: total_usage {
    type: number
    sql: ${usage_per_batch} * (${batch_size} - ${control}) * ${yield} * cast({% parameter input_filter %} AS numeric)  ;;
  }


}
