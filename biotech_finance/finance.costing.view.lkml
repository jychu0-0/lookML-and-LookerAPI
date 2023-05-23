
view: outsourced_lab_fees {
  derived_table: {
    sql:
        SELECT
        id
        , latest_barcode
        , product
        , complete_date
        , completed_on
        , invoice_number
        , invoice_date
        , name
        , country
        , state
        , city
        , CASE WHEN invoice_number IS NULL THEN FALSE ELSE TRUE END AS is_invoiced
        FROM (
          SELECT
          o.id
          , latest_barcode
          , product
          , completed_on
          , clinic.name
          , clinic.country
          , clinic.state
          , clinic.city
          FROM ${order.SQL_TABLE_NAME} AS o
          INNER JOIN ${ordering_clinic.SQL_TABLE_NAME} AS clinic ON o.clinic_id = clinic.id) AS oo
        LEFT JOIN costing.verinatainvoices AS vi ON vi.barcode::varchar = oo.latest_barcode::varchar ;;
    datagroup_trigger: etl_refresh
    indexes: ["id", "product", "complete_date","completed_on", "invoice_number", "invoice_date"]
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

  dimension_group: complete_date {
    label: "Verinata Complete"
    type: time
    timeframes: [date, month, quarter, year]
    sql: ${TABLE}.complete_date ;;
  }

  dimension_group: completed_on {
    label: "Counsyl Complete"
    type: time
    timeframes: [date, month, quarter, year]
    sql: ${TABLE}.completed_on ;;
  }

  dimension: name  {
    group_label: "Clinic"
    sql: ${TABLE}.name ;;
  }

  dimension: country {
    group_label: "Clinic"
    sql: ${TABLE}.country ;;
  }

  dimension: city {
    group_label: "Clinic"
    sql: ${TABLE}.city ;;
  }

  dimension: state {
    group_label: "Clinic"
    sql: ${TABLE}.state ;;
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
    datagroup_trigger: etl_refresh
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


  filter: scenario_a_fps1_input{
    default_value: "1"
  }

  filter: scenario_a_fps2_input{
    default_value: "1"
  }

  filter: scenario_a_ics_input{
    default_value: "1"
  }

  filter: scenario_a_ips_input{
    default_value: "1"
  }


  measure: total_usage_a {
    type: number
    sql: ${usage_per_batch} * (${batch_size} - ${control}) * ${yield} * (cast({% parameter scenario_a_fps1_input %} AS numeric) + cast({% parameter scenario_a_fps2_input %} AS numeric) + cast({% parameter scenario_a_ics_input %} AS numeric) + cast({% parameter scenario_a_ips_input %} AS numeric))  ;;

  }


  filter: scenario_b_fps1_input{
    default_value: "1"
  }

  filter: scenario_b_fps2_input{
    default_value: "1"

  }

  filter: scenario_b_ics_input{
    default_value: "1"
  }

  filter: scenario_b_ips_input{
    default_value: "1"
  }

  measure: total_usage_b {
    type: number
    sql: ${usage_per_batch} * (${batch_size} - ${control}) * ${yield} * (cast({% parameter scenario_b_fps1_input %} AS numeric) + cast({% parameter scenario_b_fps2_input %} AS numeric) + cast({% parameter scenario_b_ics_input %} AS numeric) + cast({% parameter scenario_b_ips_input %} AS numeric)) ;;

  }


  filter: scenario_c_fps1_input{
    default_value: "1"
  }

  filter: scenario_c_fps2_input{
    default_value: "1"
  }

  filter: scenario_c_ics_input{
    default_value: "1"
  }

  filter: scenario_c_ips_input{
    default_value: "1"
  }


  measure: total_usage_c {
    type: number
    sql: ${usage_per_batch} * (${batch_size} - ${control}) * ${yield} * (cast({% parameter scenario_c_fps1_input %} AS numeric) + cast({% parameter scenario_c_fps2_input %} AS numeric) + cast({% parameter scenario_c_ics_input %} AS numeric) + cast({% parameter scenario_c_ips_input %} AS numeric))  ;;
  }

}
