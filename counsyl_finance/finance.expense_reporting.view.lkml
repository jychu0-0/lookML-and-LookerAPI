## headcount term stuff
## summarized view when i have time
## export old and new reports and push to production
## sql_triggers need update



view: field_sales_staff {
  derived_table: {
    sql:
      SELECT
        employee_id
        , ter.email
        , rep_name
        , region
        , job_title AS role
        , supervisor_id
        , supervisor_name
        , status
        , hire_date
      FROM costing.territories AS ter
      LEFT JOIN costing.employee AS emp on emp.email = ter.email
      WHERE job_title ILIKE '%Clinical Account%'
      GROUP BY 1,2,3,4,5,6,7,8,9  ;;

      datagroup_trigger: etl_refresh
      indexes: ["employee_id","email"]
    }

  dimension: employee_id {
    type: number
    sql: ${TABLE}.employee_id ;;
  }

  dimension: rep_name {
    type: string
    sql: ${TABLE}.rep_name ;;
  }

  dimension: email {
    type: string
    sql: ${TABLE}.email ;;
  }

  dimension: region {
    type: string
    sql: ${TABLE}.region ;;
  }
}

view: field_sales_expenses {
  derived_table: {
    sql:
      SELECT
        con.employee_id
        , emp.email
        , emp.rep_name
        , emp.role
        , emp.region
        , emp.status
        , con.cost_center
        , con.department
        , con.expense_type
        , con.account_code
        , con.transaction_date
        , EXTRACT(year FROM transaction_date)::text || '-' || (
              CASE WHEN EXTRACT(month FROM transaction_date) IN (10,11,12) THEN EXTRACT(month FROM transaction_date)::text
              ELSE '0' || EXTRACT(month FROM transaction_date)::text END) AS join_month
        , con.approval_status
        , ref.caption AS expense_category
        , SUM(con.expense_amount) AS total_expense
       FROM costing.concur AS con
      LEFT JOIN ${field_sales_staff.SQL_TABLE_NAME} AS emp ON emp.employee_id = con.employee_id
      LEFT JOIN
        (SELECT gl_account, caption from costing.concur_reference_table GROUP BY 1,2) AS ref ON ref.gl_account = con.account_code
      GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14 ;;
    datagroup_trigger: etl_refresh
    indexes: ["employee_id","email","rep_name","region","cost_center","department","expense_type","account_code","approval_status","expense_category"]
  }
  dimension: region {
    type: string
    sql: ${TABLE}.region;;
  }
  dimension: employee_id {
    type: string
    sql: ${TABLE}.employee_id ;;
  }
  dimension: role {
    type: string
    sql: ${TABLE}.role ;;
  }
  dimension: rep_status {
    type: string
    sql: ${TABLE}.status ;;
  }
  dimension: rep_name {
    type: string
    sql: ${TABLE}.rep_name ;;
  }

  dimension: expense_type {
    type: string
    sql: ${TABLE}.expense_type ;;
  }
  dimension_group: transaction_date {
    type: time
    timeframes: [date,month,year,quarter]
    sql: ${TABLE}.transaction_date ;;
  }
  measure: total_expense {
    type: sum
    sql: ${TABLE}.total_expense ;;
  }
}


view: field_sales_volume {
  derived_table: {
    sql:
        SELECT
          emp.employee_id
          , emp.rep_name
          , emp.email
          , emp.region
          , emp.role
          , emp.status
          , ord.completed_on
          , EXTRACT(year FROM completed_on)::text || '-' || (
              CASE WHEN EXTRACT(month FROM completed_on) IN (10,11,12) THEN EXTRACT(month FROM completed_on)::text
              ELSE '0' || EXTRACT(month FROM completed_on)::text END) AS join_month
          , cli.specialty
          , COUNT(DISTINCT ord.id) AS volume
        FROM ${order.SQL_TABLE_NAME} AS ord
        LEFT JOIN ${ordering_clinic.SQL_TABLE_NAME} AS cli ON ord.clinic_id = cli.id
        LEFT JOIN costing.rep_id_map AS map ON cli.outside_salesperson = map.rep
        LEFT JOIN ${field_sales_staff.SQL_TABLE_NAME} AS emp ON emp.employee_id = map.employee_id
        GROUP BY 1,2,3,4,5,6,7,8,9;;

      indexes: ["employee_id","rep_name","email","region","role","status"]
      datagroup_trigger: etl_refresh

    }

    dimension: employee_id {
      type: number
      sql: ${TABLE}.employee_id ;;
    }

    dimension: rep_name {
      type: string
      sql: ${TABLE}.rep_name ;;
    }

    dimension: email {
      type: string
      sql: ${TABLE}.email ;;
    }

    dimension: region {
      type: string
      sql: ${TABLE}.region ;;
    }

    dimension: role {
      type: string
      sql: ${TABLE}.role ;;
    }

    dimension: specialty {
      type: string
      sql: ${TABLE}.specialty;;
    }

    dimension: status {
      type: string
      sql: ${TABLE}.status;;
    }

    dimension_group: completed_on {
      type: time
      timeframes: [date,month,quarter,year]
      sql: ${TABLE}.completed_on ;;
    }

    measure: volume {
      type: sum
      sql: ${TABLE}.volume ;;
    }
  }


view: field_sales_revenue {
  derived_table: {
    sql:
      SELECT
        emp.employee_id
        , emp.rep_name
        , emp.email
        , emp.region
        , emp.role
        , emp.status
        , rev.rev_rec_date
        , EXTRACT(year FROM rev_rec_date)::text || '-' || (
            CASE WHEN EXTRACT(month FROM rev_rec_date) IN (10,11,12) THEN EXTRACT(month FROM rev_rec_date)::text
            ELSE '0' || EXTRACT(month FROM rev_rec_date)::text END) AS join_month
        , SUM(rev.revenue) AS revenue
      FROM ${order.SQL_TABLE_NAME} AS ord
      LEFT JOIN ${booked_revenue.SQL_TABLE_NAME} AS rev ON ord.id = rev.order_id
      LEFT JOIN ${ordering_clinic.SQL_TABLE_NAME} AS cli ON ord.clinic_id = cli.id
      LEFT JOIN costing.rep_id_map AS map ON cli.outside_salesperson = map.rep
      LEFT JOIN ${field_sales_staff.SQL_TABLE_NAME} AS emp ON emp.employee_id = map.employee_id
      GROUP BY 1,2,3,4,5,6,7,8;;
    indexes: ["employee_id","rep_name","email","region","role","status"]
    datagroup_trigger: etl_refresh

  }

  dimension: employee_id {
    type: number
    sql: ${TABLE}.employee_id ;;
  }

  dimension: rep_name {
    type: string
    sql: ${TABLE}.rep_name ;;
  }

  dimension: email {
    type: string
    sql: ${TABLE}.email ;;
  }

  dimension: region {
    type: string
    sql: ${TABLE}.region ;;
  }

  dimension: role {
    type: string
    sql: ${TABLE}.role ;;
  }

  dimension: specialty {
    type: string
    sql: ${TABLE}.specialty;;
  }

  dimension: status {
    type: string
    sql: ${TABLE}.status;;
  }

  dimension_group: rev_rec_date {
    type: time
    timeframes: [date,month,quarter,year]
    sql: ${TABLE}.rev_rec_date ;;
  }

  measure: revenue {
    type: sum
    value_format_name: usd_0
    sql: ${TABLE}.revenue ;;
  }
}

view: expense_summary {
  derived_table: {
    sql:
      SELECT
        crs.join_month
        , crs.employee_id
        , SUM(total_expense) AS expense
        , SUM(volume) AS volume
        , SUM(revenue) AS revenue
        , SUM(total_expense) / SUM(volume) AS expense_per_req
        , SUM(revenue) / SUM(volume) AS revenue_per_req
        , SUM(revenue) / SUM(total_expense) AS rev_exp_ratio
      FROM ${field_sales_month_cross.SQL_TABLE_NAME} AS crs
      LEFT JOIN (
        SELECT
          employee_id
          , join_month
          , SUM(total_expense) AS total_expense
        FROM ${field_sales_expenses.SQL_TABLE_NAME}
        GROUP BY 1,2) AS exp ON exp.join_month = crs.join_month AND exp.employee_id = crs.employee_id
      LEFT JOIN (
        SELECT
          employee_id
          , join_month
          , SUM(volume) AS volume
        FROM ${field_sales_volume.SQL_TABLE_NAME}
        GROUP BY 1,2) AS vol ON vol.join_month = exp.join_month AND vol.employee_id = exp.employee_id
      LEFT JOIN (
        SELECT
          employee_id
          , join_month
          , SUM(revenue) AS revenue
        FROM ${field_sales_revenue.SQL_TABLE_NAME}
        GROUP BY 1,2) AS rev ON rev.join_month = vol.join_month AND rev.employee_id = vol.employee_id
      GROUP BY 1,2
        ;;
    indexes: ["employee_id","join_month"]
    datagroup_trigger: etl_refresh

  }

  dimension: employee_id {
    type: number
    sql: ${TABLE}.employee_id ;;
  }

  dimension_group: join_month {
    type: time
    timeframes: [month,quarter,year]
    sql: TO_DATE(${TABLE}.join_month || '-01', 'YYYY-MM-DD') ;;
  }

  measure: expense {
    type: sum
    value_format_name: usd
    sql: ${TABLE}.expense ;;
  }

  measure: volume {
    type: sum
    sql: ${TABLE}.volume ;;
  }

  measure: revenue {
    type: sum
    value_format_name: usd
    sql: ${TABLE}.revenue ;;
  }

  measure: expense_per_req {
    type: sum
    value_format_name: usd
    sql:${TABLE}.expense_per_req;;
  }

  measure: revenue_per_req {
    type: sum
    value_format_name: usd
    sql:${TABLE}.revenue_per_req;;
  }
  measure: rev_exp_ratio {
    type: sum
    value_format_name: usd
    sql:${TABLE}.rev_exp_ratio;;
  }

}
