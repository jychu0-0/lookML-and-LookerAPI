
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
