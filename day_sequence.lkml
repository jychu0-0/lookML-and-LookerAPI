view: day_sequence {
  derived_table: {
    sql: SELECT
        day::date AS day
      FROM generate_series(date '2012-01-01', current_date, interval '1 day') AS day
       ;;
    sql_trigger_value: SELECT current_date ;;
    indexes: ["day"]
  }


}

view: week_sequence {
  derived_table: {
    sql: SELECT
        DATE(TO_CHAR(DATE_TRUNC('week', week),'YYYY-MM-DD')) AS week
      FROM generate_series(date '2014-01-01', current_date, interval '1 week') AS week
       ;;
    sql_trigger_value: SELECT current_date ;;
    indexes: ["week"]
  }


}

view: month_sequence {
  derived_table: {
    sql: SELECT
        DATE(TO_CHAR(month, 'YYYY-MM')|| '-01') AS month
      FROM generate_series(date '2013-12-01', current_date, interval '1 month') AS month
       ;;
    sql_trigger_value: SELECT current_date ;;
    indexes: ["month"]
  }

}

view: unique_accounts {
  derived_table: {
    sql: SELECT
        DISTINCT id AS clinic_id
      FROM current.clinic
       ;;
    sql_trigger_value: SELECT current_date ;;
    indexes: ["clinic_id"]
  }


}

view: account_day_cross {
  derived_table: {
    sql: select
      clinic_id
      ,day
      FROM ${day_sequence.SQL_TABLE_NAME} CROSS JOIN ${unique_accounts.SQL_TABLE_NAME}
      WHERE day >= '2014-01-01'::date
      ORDER BY 1,2
       ;;
    sql_trigger_value: SELECT current_date ;;
    indexes: ["day", "clinic_id"]
  }

dimension: clinic_id {
  sql: ${TABLE}.clinic_id ;;
}

}


view: account_day_cross_w_key {
  derived_table: {
    sql: SELECT
    day
    , clinic_id
    , day::text || ' ' || clinic_id::text AS pkey
    , day - 90 AS ninety_day_date
    FROM ${account_day_cross.SQL_TABLE_NAME} AS a

       ;;
    sql_trigger_value: SELECT current_date ;;
    indexes: ["pkey"]
  }

  dimension: pkey {
    sql: ${TABLE}.pkey ;;
  }

}


#- explore: account_id_week_cross


view: account_id_week_cross {
  derived_table: {
    sql: select
      clinic.id AS clinic_id
      ,week
      FROM ${week_sequence.SQL_TABLE_NAME} CROSS JOIN current.clinic AS clinic
      ORDER BY 1,2
       ;;
  }

  #sql_trigger_value: SELECT current_date
  #indexes: [week, clinic_id]

}

view: account_week_cross {
  derived_table: {
    sql: select
      account_name
      ,week
      FROM ${week_sequence.SQL_TABLE_NAME} CROSS JOIN ${unique_accounts.SQL_TABLE_NAME}
      ORDER BY 1,2
       ;;
  }

  #sql_trigger_value: SELECT current_date
  #indexes: [week, account_name]



}

#- explore: account_month_cross

view: account_month_cross {
  derived_table: {
    sql: select
      account_name
      ,month
      FROM ${month_sequence.SQL_TABLE_NAME} CROSS JOIN ${unique_accounts.SQL_TABLE_NAME}
      ORDER BY 1,2
       ;;
  }

  #sql_trigger_value: SELECT current_date
  #indexes: [month, account_name]


}

#- explore: unique_NPI
view: unique_NPI {
  derived_table: {
    sql: SELECT
         distinct healthcareprofile.id::int AS npi
      FROM current.healthcareprofile
      LEFT JOIN ${order.SQL_TABLE_NAME} AS ord ON healthcareprofile.id = ord.ordering_healthcare_profile_id
      WHERE create_date >= current_date - interval '12 month'
       ;;
    sql_trigger_value: SELECT current_date ;;
    indexes: ["npi"]
  }

}

#- explore: month_sequence_limited
view: month_sequence_limited {
  derived_table: {
    sql: SELECT
        (DATE(TO_CHAR(current_date, 'YYYY-MM')|| '-01') - month)/30 + 1 AS month_id
        ,month
      FROM
      (

        SELECT
          DATE(TO_CHAR(month, 'YYYY-MM')|| '-01') AS month
        FROM generate_series(current_date - interval '12 month', current_date, interval '1 month') AS month ) AS foo
       ;;
    sql_trigger_value: SELECT current_date ;;
    indexes: ["month_id", "month"]
  }

}

#- explore: week_sequence_limited
view: week_sequence_limited {
  derived_table: {
    sql: SELECT
        (((DATE(TO_CHAR(DATE_TRUNC('week', current_date),'YYYY-MM-DD')) - week)/7)+1)::smallint AS week_id
        , week
      FROM
        (
          SELECT
            DATE(TO_CHAR(DATE_TRUNC('week', week),'YYYY-MM-DD')) AS week
          FROM generate_series(current_date - interval '12 month', current_date, interval '1 week') AS week
        ) AS foo
       ;;
    sql_trigger_value: SELECT current_date ;;
    indexes: ["week_id", "week"]
  }

}

#- explore: NPI_week_cross

view: NPI_week_cross {
  derived_table: {
    sql: select
      npi
      ,week_id
      ,week
      FROM ${week_sequence_limited.SQL_TABLE_NAME} CROSS JOIN ${unique_NPI.SQL_TABLE_NAME}
      ORDER BY 1,2
       ;;
    sql_trigger_value: SELECT current_date ;;
    indexes: ["week_id", "npi"]
  }

}

#- explore: NPI_month_cross

view: NPI_month_cross {
  derived_table: {
    sql: select
      npi
      ,month_id
      ,month
      FROM ${month_sequence_limited.SQL_TABLE_NAME} CROSS JOIN ${unique_NPI.SQL_TABLE_NAME}
      ORDER BY 1,2
       ;;
    sql_trigger_value: SELECT current_date ;;
    indexes: ["month_id", "npi"]
  }


}

view: product_day_cross {
  derived_table: {
    sql: SELECT
            day::date AS day
            , product_name AS product
            FROM ${day_sequence.SQL_TABLE_NAME} as day
            CROSS JOIN uploads.products
            ;;
    sql_trigger_value: SELECT current_date ;;
    indexes: ["day", "product"]
}

}


# Delete this file for freeze
