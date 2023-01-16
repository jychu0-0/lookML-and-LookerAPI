  view: percent_to_plan {
    derived_table: {
      sql:
       SELECT
          date_trunc('week', completed_on) as week_starting,
          o.product,
          count(o.*) as weekly_volume,
          fv.forecasted_volume as forecasted_weekly_volume
        FROM
          current.order o
        JOIN
          uploads.forecasted_volume fv
          on date_trunc('week', o.completed_on) = fv.week_starting and o.product = fv.product
        GROUP BY
          1,2,4
      ;;

      }
      dimension: week_starting {
        description: "start of week date"
        type: date
        sql: ${TABLE}.week_starting ;;
      }

      dimension: product {
        description: "name of counsyl product"
        type: string
        sql: ${TABLE}.product ;;
      }

      measure: weekly_volume  {
        description: "number of completed orders in week"
        type: sum
        sql: ${TABLE}.weekly_volume ;;
      }

      measure: forecasted_volume_weekly  {
        description: "forecasted number of completed weekly orders"
        type: sum
        sql: ${TABLE}.forecasted_weekly_volume ;;
      }
    }

