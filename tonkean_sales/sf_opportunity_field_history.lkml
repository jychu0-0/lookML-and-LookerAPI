view: sf_opportunity_field_history {
  derived_table: {
    sql:
      WITH iarr_sub
      AS (
        SELECT
          id
          , opportunity_id
          , created_date
          , new_value AS new_iarr
          , old_value AS old_iarr
        FROM salesforce.opportunity_field_history
        WHERE field = 'Incremental_ARR__c'
          AND (new_value IS NOT NULL OR old_value IS NOT NULL)
          AND NOT is_deleted
        GROUP BY 1,2,3,4,5)

      , arr_sub
      AS (
        SELECT
          id
          , opportunity_id
          , created_date
          , new_value AS new_arr
          , old_value AS old_arr
        FROM salesforce.opportunity_field_history
        WHERE field = 'ARR__c'
          AND (new_value IS NOT NULL OR old_value IS NOT NULL)
          AND NOT is_deleted
        GROUP BY 1,2,3,4,5)

      , amount_sub
      AS (
        SELECT
          id
          , opportunity_id
          , created_date
          , new_value AS new_amount
          , old_value AS old_amount
        FROM salesforce.opportunity_field_history
        WHERE field = 'Amount'
          AND (new_value IS NOT NULL OR old_value IS NOT NULL)
          AND NOT is_deleted
        GROUP BY 1,2,3,4,5)

      , stage_sub
      AS (
        SELECT
          id
          , opportunity_id
          , created_date
          , new_value AS new_stage
          , old_value AS old_stage
        FROM salesforce.opportunity_field_history
        WHERE field = 'StageName'
          AND (new_value IS NOT NULL OR old_value IS NOT NULL)
          AND NOT is_deleted
        GROUP BY 1,2,3,4,5)

      , forecast_category_sub
      AS (
        SELECT
          id
          , opportunity_id
          , created_date
          , new_value AS new_forecast_category
          , old_value AS old_forecast_category
        FROM salesforce.opportunity_field_history
        WHERE field = 'ForecastCategoryName'
          AND (new_value IS NOT NULL OR old_value IS NOT NULL)
          AND NOT is_deleted
        GROUP BY 1,2,3,4,5)

      , close_date_sub
      AS (
        SELECT * FROM (
          SELECT
            id
            , opportunity_id
            , created_date
            , MAX(new_value) OVER (PARTITION BY opportunity_id,created_date) AS new_close_date -- sfdc has 24 instances of multiple opportunity_field_history lines with same created_date timestamp. defaulting to later dates for more conservative forecasting calcs
            , MIN(old_value) OVER (PARTITION BY opportunity_id,created_date) AS old_close_date
          FROM salesforce.opportunity_field_history
          WHERE field = 'CloseDate'
            AND (new_value IS NOT NULL OR old_value IS NOT NULL)
            AND NOT is_deleted
        )
        GROUP BY 1,2,3,4,5
      )

      , pivot_sfofh
      AS (
        SELECT
          sfofh.opportunity_id
          , sfofh.created_date
          , new_iarr::numeric
          , old_iarr::numeric
          , new_arr::numeric
          , old_arr::numeric
          , new_amount::numeric
          , old_amount::numeric
          , new_stage::text
          , old_stage::text
          , new_close_date::date
          , old_close_date::date
          , new_forecast_category::text
          , old_forecast_category::text
          , sfofh.created_date::date AS start_date
        FROM salesforce.opportunity_field_history sfofh
        LEFT JOIN iarr_sub ON sfofh.opportunity_id = iarr_sub.opportunity_id AND sfofh.created_date = iarr_sub.created_date
        LEFT JOIN arr_sub ON sfofh.opportunity_id = arr_sub.opportunity_id AND sfofh.created_date = arr_sub.created_date
        LEFT JOIN amount_sub ON sfofh.opportunity_id = amount_sub.opportunity_id AND sfofh.created_date = amount_sub.created_date
        LEFT JOIN stage_sub ON sfofh.opportunity_id = stage_sub.opportunity_id AND sfofh.created_date = stage_sub.created_date
        LEFT JOIN forecast_category_sub ON sfofh.opportunity_id = forecast_category_sub.opportunity_id AND sfofh.created_date = forecast_category_sub.created_date
        LEFT JOIN close_date_sub ON sfofh.opportunity_id = close_date_sub.opportunity_id AND sfofh.created_date = close_date_sub.created_date
        WHERE NOT (
          new_iarr IS NULL
          AND old_iarr IS NULL
          AND new_arr IS NULL
          AND old_arr IS NULL
          AND new_amount IS NULL
          AND old_amount IS NULL
          AND new_stage IS NULL
          AND old_stage IS NULL
          AND new_close_date IS NULL
          AND old_close_date IS NULL
          AND new_forecast_category IS NULL
          AND old_forecast_category IS NULL)
        GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
      )

      , iarr_piv_seq
      AS (
        SELECT
          *
          , ROW_NUMBER() OVER (PARTITION BY opportunity_id ORDER BY created_date) AS piv_asc
        FROM pivot_sfofh WHERE new_iarr IS NOT NULL OR old_iarr IS NOT NULL
        GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15


      )

      , arr_piv_seq
      AS (
        SELECT
          *
          , ROW_NUMBER() OVER (PARTITION BY opportunity_id ORDER BY created_date) AS piv_asc
        FROM pivot_sfofh
        WHERE new_arr IS NOT NULL OR old_arr IS NOT NULL
        GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15


      )

      , amount_piv_seq
      AS (
        SELECT
          *
          , ROW_NUMBER() OVER (PARTITION BY opportunity_id ORDER BY created_date) AS piv_asc
        FROM pivot_sfofh WHERE new_amount IS NOT NULL OR old_amount IS NOT NULL
        GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15


      )

      , stage_piv_seq
      AS (
        SELECT
          *
          , ROW_NUMBER() OVER (PARTITION BY opportunity_id ORDER BY created_date) AS piv_asc
        FROM pivot_sfofh WHERE new_stage IS NOT NULL OR old_stage IS NOT NULL
        GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15


      )

      , close_date_piv_seq
      AS (
        SELECT
          *
          , ROW_NUMBER() OVER (PARTITION BY opportunity_id ORDER BY created_date) AS piv_asc
        FROM pivot_sfofh WHERE new_close_date IS NOT NULL OR old_close_date IS NOT NULL
        GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15


      )

      , forecast_category_piv_seq
      AS (
        SELECT
          *
          , ROW_NUMBER() OVER (PARTITION BY opportunity_id ORDER BY created_date) AS piv_asc
        FROM pivot_sfofh WHERE new_forecast_category IS NOT NULL OR old_forecast_category IS NOT NULL
        GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15


      )

      , first_piv
      AS (
        SELECT
          opportunity.id
          , iarr_piv_seq.new_iarr::numeric
          , iarr_piv_seq.old_iarr::numeric
          , arr_piv_seq.new_arr::numeric
          , arr_piv_seq.old_arr::numeric
          , amount_piv_seq.new_amount::numeric
          , amount_piv_seq.old_amount::numeric
          , stage_piv_seq.new_stage::text
          , stage_piv_seq.old_stage::text
          , close_date_piv_seq.new_close_date::date
          , close_date_piv_seq.old_close_date::date
          , forecast_category_piv_seq.new_forecast_category::text
          , forecast_category_piv_seq.old_forecast_category::text
          , iarr_piv_seq.piv_asc AS iarr_piv_seq
          , arr_piv_seq.piv_asc AS arr_piv_seq
          , amount_piv_seq.piv_asc AS amount_piv_seq
          , stage_piv_seq.piv_asc AS stage_piv_seq
          , close_date_piv_seq.piv_asc AS close_date_piv_seq
          , forecast_category_piv_seq.piv_asc AS forecast_category_piv_seq

        FROM salesforce.opportunity
        LEFT JOIN iarr_piv_seq ON iarr_piv_seq.opportunity_id = opportunity.id
        LEFT JOIN arr_piv_seq ON arr_piv_seq.opportunity_id = opportunity.id
        LEFT JOIN amount_piv_seq ON amount_piv_seq.opportunity_id = opportunity.id
        LEFT JOIN stage_piv_seq ON stage_piv_seq.opportunity_id = opportunity.id
        LEFT JOIN close_date_piv_seq ON close_date_piv_seq.opportunity_id = opportunity.id
        LEFT JOIN forecast_category_piv_seq ON forecast_category_piv_seq.opportunity_id = opportunity.id
        WHERE (iarr_piv_seq.piv_asc = 1 OR iarr_piv_seq.piv_asc IS NULL)
          AND (arr_piv_seq.piv_asc = 1 OR arr_piv_seq.piv_asc IS NULL)
          AND (amount_piv_seq.piv_asc = 1 OR amount_piv_seq.piv_asc IS NULL)
          AND (stage_piv_seq.piv_asc = 1 OR stage_piv_seq.piv_asc IS NULL)
          AND (close_date_piv_seq.piv_asc = 1 OR close_date_piv_seq.piv_asc IS NULL)
          AND (forecast_category_piv_seq.piv_asc = 1 OR forecast_category_piv_seq.piv_asc IS NULL)

     )



      , union_pivs
      AS (
        SELECT
          opportunity_id
          , created_date
          , new_iarr AS new_iarr
          , old_iarr AS old_iarr
          , new_arr AS new_arr
          , old_arr AS old_arr
          , new_amount AS new_amount
          , old_amount AS old_amount
          , new_stage AS new_stage
          , old_stage AS old_stage
          , new_close_date AS new_close_date
          , old_close_date AS old_close_date
          , new_forecast_category AS new_forecast_category
          , old_forecast_category AS old_forecast_category
          , start_date

        FROM pivot_sfofh
        WHERE new_iarr IS NOT NULL
          OR old_iarr IS NOT NULL
          OR new_arr IS NOT NULL
          OR old_arr IS NOT NULL
          OR new_amount IS NOT NULL
          OR old_amount IS NOT NULL
          OR new_stage IS NOT NULL
          OR old_stage IS NOT NULL
          OR new_close_date IS NOT NULL
          OR old_close_date IS NOT NULL
          OR new_forecast_category IS NOT NULL
          OR old_forecast_category IS NOT NULL


        UNION ALL

        SELECT
          so.id
          , DATEADD(SECOND,-1,so.created_date)
          , CASE WHEN old_iarr IS NULL THEN so.incremental_arr_c::numeric ELSE old_iarr::numeric END AS new_iarr
          , NULL::numeric AS old_iarr
          , CASE WHEN old_arr IS NULL THEN so.arr_c::numeric ELSE old_arr::numeric END AS new_arr
          , NULL::numeric AS old_arr
          , CASE WHEN old_amount IS NULL THEN so.amount::numeric ELSE old_amount::numeric END AS new_amount
          , NULL::numeric AS old_amount
          , CASE WHEN old_stage IS NULL THEN so.stage_name::text ELSE old_stage::text END AS new_stage
          , NULL::text AS old_stage
          , CASE WHEN old_close_date IS NULL THEN so.close_date::date ELSE old_close_date::date END AS new_close_date
          , NULL::date AS old_close_date
          , CASE WHEN old_forecast_category IS NULL THEN so.forecast_category::text ELSE old_forecast_category::text END AS new_forecast_category
          , NULL::text AS old_forecast_category
          , so.created_date::date AS start_date
        FROM salesforce.opportunity so
        LEFT JOIN first_piv fp ON fp.id = so.id

      )




      , partition_pop
      AS (
        SELECT
          opportunity_id
          , created_date
          , start_date
          , CASE
              WHEN LAG(created_date) over (PARTITION BY opportunity_id ORDER BY created_date DESC)::date - 1 IS NOT NULL THEN LAG(created_date) over (PARTITION BY opportunity_id ORDER BY created_date DESC)::date - 1
              ELSE getdate()::date
              END AS end_date
          , new_iarr
          , FIRST_VALUE(new_iarr) OVER (PARTITION BY opportunity_id, new_iarr_partition ORDER BY created_date ROWS UNBOUNDED PRECEDING) AS last_new_iarr
          , old_iarr
          , FIRST_VALUE(old_iarr) OVER (PARTITION BY opportunity_id, old_iarr_partition ORDER BY created_date ROWS UNBOUNDED PRECEDING) AS last_old_iarr
          , new_arr
          , FIRST_VALUE(new_arr) OVER (PARTITION BY opportunity_id, new_arr_partition ORDER BY created_date ROWS UNBOUNDED PRECEDING) AS last_new_arr
          , old_arr
          , FIRST_VALUE(old_arr) OVER (PARTITION BY opportunity_id, old_arr_partition ORDER BY created_date ROWS UNBOUNDED PRECEDING) AS last_old_arr
          , new_amount
          , FIRST_VALUE(new_amount) OVER (PARTITION BY opportunity_id, new_amount_partition ORDER BY created_date ROWS UNBOUNDED PRECEDING) AS last_new_amount
          , old_amount
          , FIRST_VALUE(old_amount) OVER (PARTITION BY opportunity_id, old_amount_partition ORDER BY created_date ROWS UNBOUNDED PRECEDING) AS last_old_amount
          , new_stage
          , FIRST_VALUE(new_stage) OVER (PARTITION BY opportunity_id, new_stage_partition ORDER BY created_date ROWS UNBOUNDED PRECEDING) AS last_new_stage
          , old_stage
          , FIRST_VALUE(old_stage) OVER (PARTITION BY opportunity_id, old_stage_partition ORDER BY created_date ROWS UNBOUNDED PRECEDING) AS last_old_stage
          , new_close_date
          , FIRST_VALUE(new_close_date) OVER (PARTITION BY opportunity_id, new_close_date_partition ORDER BY created_date ROWS UNBOUNDED PRECEDING) AS last_new_close_date
          , old_close_date
          , FIRST_VALUE(old_close_date) OVER (PARTITION BY opportunity_id, old_close_date_partition ORDER BY created_date ROWS UNBOUNDED PRECEDING) AS last_old_close_date
          , new_forecast_category
          , FIRST_VALUE(new_forecast_category) OVER (PARTITION BY opportunity_id, new_forecast_category_partition ORDER BY created_date ROWS UNBOUNDED PRECEDING) AS last_new_forecast_category
          , old_forecast_category
          , FIRST_VALUE(old_forecast_category) OVER (PARTITION BY opportunity_id, old_forecast_category_partition ORDER BY created_date ROWS UNBOUNDED PRECEDING) AS last_old_forecast_category

        FROM (
          SELECT
            opportunity_id
            , created_date
            , start_date
            , new_iarr
            , SUM(CASE WHEN new_iarr IS NULL THEN 0 ELSE 1 END) OVER (PARTITION BY opportunity_id ORDER BY created_date ROWS UNBOUNDED PRECEDING) AS new_iarr_partition
            , old_iarr
            , SUM(CASE WHEN old_iarr IS NULL THEN 0 ELSE 1 END) OVER (PARTITION BY opportunity_id ORDER BY created_date ROWS UNBOUNDED PRECEDING) AS old_iarr_partition
            , new_arr
            , SUM(CASE WHEN new_arr IS NULL THEN 0 ELSE 1 END) OVER (PARTITION BY opportunity_id ORDER BY created_date ROWS UNBOUNDED PRECEDING) AS new_arr_partition
            , old_arr
            , SUM(CASE WHEN old_arr IS NULL THEN 0 ELSE 1 END) OVER (PARTITION BY opportunity_id ORDER BY created_date ROWS UNBOUNDED PRECEDING) AS old_arr_partition
            , new_amount
            , SUM(CASE WHEN new_amount IS NULL THEN 0 ELSE 1 END) OVER (PARTITION BY opportunity_id ORDER BY created_date ROWS UNBOUNDED PRECEDING) AS new_amount_partition
            , old_amount
            , SUM(CASE WHEN old_amount IS NULL THEN 0 ELSE 1 END) OVER (PARTITION BY opportunity_id ORDER BY created_date ROWS UNBOUNDED PRECEDING) AS old_amount_partition
            , new_stage
            , SUM(CASE WHEN new_stage IS NULL THEN 0 ELSE 1 END) OVER (PARTITION BY opportunity_id ORDER BY created_date ROWS UNBOUNDED PRECEDING) AS new_stage_partition
            , old_stage
            , SUM(CASE WHEN old_stage IS NULL THEN 0 ELSE 1 END) OVER (PARTITION BY opportunity_id ORDER BY created_date ROWS UNBOUNDED PRECEDING) AS old_stage_partition
            , new_close_date
            , SUM(CASE WHEN new_close_date IS NULL THEN 0 ELSE 1 END) OVER (PARTITION BY opportunity_id ORDER BY created_date ROWS UNBOUNDED PRECEDING) AS new_close_date_partition
            , old_close_date
            , SUM(CASE WHEN old_close_date IS NULL THEN 0 ELSE 1 END) OVER (PARTITION BY opportunity_id ORDER BY created_date ROWS UNBOUNDED PRECEDING) AS old_close_date_partition
            , new_forecast_category
            , SUM(CASE WHEN new_forecast_category IS NULL THEN 0 ELSE 1 END) OVER (PARTITION BY opportunity_id ORDER BY created_date ROWS UNBOUNDED PRECEDING) AS new_forecast_category_partition
            , old_forecast_category
            , SUM(CASE WHEN old_forecast_category IS NULL THEN 0 ELSE 1 END) OVER (PARTITION BY opportunity_id ORDER BY created_date ROWS UNBOUNDED PRECEDING) AS old_forecast_category_partition

          FROM union_pivs
          GROUP BY 1,2,3,4,6,8,10,12,14,16,18,20,22,24,26
          ORDER BY start_date ASC
            ) sub
        )




      , date_group
      AS (
        SELECT
          *
          , ROW_NUMBER() OVER (PARTITION BY start_date, opportunity_id ORDER BY created_date DESC) AS seqnum_desc
        FROM partition_pop
      )

      , change_log
      AS (
        SELECT * FROM date_group WHERE 1 IN (seqnum_desc)
      )


      SELECT
        so.id
        , so.name
        , so.account_id
        , so.owner_id
        , so.incremental_arr_c AS current_iarr
        , so.arr_c AS current_arr
        , so.amount AS current_amount
        , so.stage_name AS current_stage
        , so.forecast_category AS current_forecast_category
        , so.close_date AS current_close_date
        , cl.*
        , sfa.name AS account_name
      FROM salesforce.opportunity AS so
      LEFT JOIN change_log cl ON so.id = cl.opportunity_id
      LEFT JOIN salesforce.account AS sfa ON sfa.id = so.account_id
      WHERE NOT so.is_deleted;;

  }

  dimension: primary_key {
    type: string
    sql: ${TABLE}.id||${TABLE}.created_date ;;
    primary_key: yes
  }

  dimension: opportunity_id{
    type: string
    sql:  ${TABLE}.id ;;
  }

  dimension: opportunity_name{
    type: string
    sql:  ${TABLE}.name ;;
  }


  dimension: account_id{
    type: string
    sql:  ${TABLE}.account_id ;;
    hidden: yes
  }

  dimension: account_name{
    type: string
    sql:  ${TABLE}.account_name ;;
  }

  dimension: owner_id{
    type: string
    sql:  ${TABLE}.owner_id ;;
  }

  dimension_group: created {
    type: time
    timeframes: [
      raw,
      time,
      date,
      week,
      month,
      quarter,
      year,
      fiscal_month_num,
      fiscal_quarter,
      fiscal_quarter_of_year,
      fiscal_year
    ]
    sql: ${TABLE}.created_date ;;
  }

  dimension: start_date {
    type: date
    sql: ${TABLE}.start_date ;;
  }

  dimension: end_date {
    type: date
    sql: ${TABLE}.end_date ;;
  }

  dimension_group: snapshot_close {
    type: time
    timeframes: [
      raw,
      time,
      date,
      week,
      month,
      quarter,
      year,
      fiscal_month_num,
      fiscal_quarter,
      fiscal_quarter_of_year,
      fiscal_year
    ]
    sql: CASE WHEN ${TABLE}.last_new_close_date IS NULL AND ${TABLE}.last_old_close_date IS NULL THEN ${TABLE}.current_close_date ELSE ${TABLE}.last_new_close_date END;;
  }

  dimension: snapshot_forecast_category {
    type: string
    sql: CASE WHEN ${TABLE}.last_new_forecast_category IS NULL AND ${TABLE}.last_old_forecast_category IS NULL THEN ${TABLE}.current_forecast_category ELSE ${TABLE}.last_new_forecast_category END;;
  }

  dimension: snapshot_stage {
    type: string
    sql: CASE WHEN ${TABLE}.last_new_stage IS NULL AND ${TABLE}.last_old_stage IS NULL THEN ${TABLE}.current_stage ELSE ${TABLE}.last_new_stage END ;;
  }

  measure: snapshot_iarr {
    type: sum
    sql: CASE WHEN ${TABLE}.last_new_iarr IS NULL AND ${TABLE}.last_old_iarr IS NULL THEN ${TABLE}.current_iarr ELSE ${TABLE}.last_new_iarr END ;;
  }

  measure: snapshot_arr {
    type: sum
    sql: CASE WHEN ${TABLE}.last_new_arr IS NULL AND ${TABLE}.last_old_arr IS NULL THEN ${TABLE}.current_arr ELSE ${TABLE}.last_new_arr END ;;
  }

  measure: snapshot_amount {
    type: sum
    sql: CASE WHEN ${TABLE}.last_new_amount IS NULL AND ${TABLE}.last_old_amount IS NULL THEN ${TABLE}.current_amount ELSE ${TABLE}.last_new_amount END ;;
  }

}
