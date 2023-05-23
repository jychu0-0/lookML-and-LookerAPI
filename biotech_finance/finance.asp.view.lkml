view: finance_asp {
  derived_table: {
    sql: WITH revenue as (
  SELECT
    date_trunc('day', rev_rec_date) as revenue_received_date,
    product,
    sum(revenue) as revenue_received_on_date
  FROM
    uploads.barcoderevenue_w_transid AS br
  LEFT JOIN
    current.order AS o
    on br.order_id = o.id
 GROUP BY
    1,2
  )

 SELECT
    o.id::integer as order_id,
    date_trunc('day', o.completed_on) as date,
    o.product,
    revenue_received_on_date
  FROM
    current.order AS o
  LEFT JOIN
    revenue AS r
    on date_trunc('day', o.completed_on) = revenue_received_date and o.product = r.product
  WHERE
    o.completed_on > '2015-01-01'
  GROUP BY
    1,2,3,4;;
  datagroup_trigger: etl_refresh
  }

   dimension: order_id {
    description: "Order table foreign key"
    hidden: yes
    primary_key: yes
    sql: ${TABLE}.order_id ;;
  }

  dimension: product {
    description: "Counsyl Product"
    sql: ${TABLE}.product ;;
  }

  dimension_group: date {
    label: "Order Completed Date"
    description: "A date in which an order can be completed or revenue received"
    type: time
    timeframes: [date, week, month, quarter, year]
    sql: ${TABLE}.date ;;
  }

  measure: order_count {
    label:  "# Count of orders completed"
    type: count
    sql: count(distinct(${TABLE}.order_id)) ;;
  }

  measure: total_revenue {
    label:"Sum of revenue received"
    type: number
    sql: sum(distinct(${TABLE}.revenue_received_on_date)) ;;
  }

  measure: asp {
    label: "Average Sales Price"
    type: number
    sql: sum(distinct(${TABLE}.revenue_received_on_date)) /  count(distinct(${TABLE}.order_id)) ;;
  }

  }
