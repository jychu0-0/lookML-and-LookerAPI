
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
