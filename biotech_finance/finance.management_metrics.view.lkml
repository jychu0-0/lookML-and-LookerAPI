
view: net_tests_created {
  derived_table: {
    sql:  SELECT
            day::date AS date
            , all_dates.product
            , coalesce(create_count,0) AS create_count
            , coalesce(complete_count,0) AS complete_count
            , coalesce(create_count,0) - coalesce(complete_count,0) AS net_created
          FROM ${product_day_cross.SQL_TABLE_NAME} AS all_dates
          LEFT JOIN
            (SELECT
              count(o.id) AS create_count
              , create_date::date AS create_date
              , product
            FROM ${order.SQL_TABLE_NAME} AS o
            WHERE gaoc_order is FALSE
            GROUP BY 2,3) AS created_tests on all_dates.day::date = created_tests.create_date::date and all_dates.product = created_tests.product
            LEFT JOIN
            (SELECT
              count(o.id) AS complete_count
              , completed_on::date AS completed_on
              , product
            FROM ${order.SQL_TABLE_NAME} AS o
            WHERE gaoc_order is FALSE
            GROUP BY 2,3) AS completed_tests on all_dates.day::date = completed_tests.completed_on::date and all_dates.product = completed_tests.product
            GROUP BY 1,2,3,4,5


;;

    datagroup_trigger: etl_refresh
    #sql_trigger_value: select count(o.id) from ${order.SQL_TABLE_NAME} AS o ;;
    indexes: ["product", "date"]
  }

  # DIMENSIONS #

    measure: create_count {
      type: sum
      sql:  ${TABLE}.create_count ;;
    }
    measure: complete_count {
      type: sum
      sql: ${TABLE}.complete_count ;;
    }
  measure: net_created {
    label: "Net Tests Created"
    description: "Created tests less completed tests."
    type: sum
    sql: ${TABLE}.net_created ;;
  }

  dimension_group: date {
    description: "Date/Period of interest for metrics."
    type: time
    timeframes: [date, month, year, quarter, week]
    sql: ${TABLE}.date ;;
  }

  dimension: product {
    description: "Product of interest for metrics"
    sql: ${TABLE}.product ;;
  }
  }
