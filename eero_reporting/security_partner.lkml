
view: sub_base_cte {
  derived_table: {
    sql:
      SELECT
        eero_user_id::integer AS eero_user_id
        , eero_user_email
        , stripe_customer_id
        , stripe_subscription_id
        , CASE
          WHEN subscription_status ILIKE 'canceled' OR subscription_canceled IS NOT NULL THEN 'Canceled User'
          WHEN stripe_plan_id = 4 THEN 'Free User'
          WHEN subscription_start < previous_period_start THEN 'Existing User'
          ELSE 'New User' END AS eero_user_type
        , stripe_plan_id
        , stripe_plan_name
        , subscription_start
        , subscription_canceled
        , trial_end
        , subscription_status
          , previous_period_start
          , previous_period_end
          , upcoming_period_start
          , upcoming_period_end
        , network_id
        , network_status
        , organization_id
        , partner_name
        , isp
        , org_deleted
        , price
        , subscription_interval
        , netsuite_item_id

      FROM (
        SELECT
          sc.id AS stripe_customer_id
          , ss.id AS stripe_subscription_id
          , sp.id AS stripe_plan_id
          , sp.name AS stripe_plan_name
          , (sp.amount::float/100) AS price
          , ss.created::date AS subscription_start
          , ss.ended_at::date AS subscription_canceled
          , (EXTRACT(YEAR FROM ADD_MONTHS(current_date,-1)) || '-' || EXTRACT(MONTH FROM ADD_MONTHS(current_date, - 1)) || '-1')::date AS previous_period_start
          , ((EXTRACT(YEAR FROM current_date) || '-' || EXTRACT(MONTH FROM current_date) || '-1')::date - 1)::date AS previous_period_end
          , (EXTRACT(YEAR FROM current_date) || '-' || EXTRACT(MONTH FROM current_date) || '-1')::date AS upcoming_period_start
          , ((EXTRACT(YEAR FROM ADD_MONTHS(current_date,+1))  || '-' || EXTRACT(MONTH FROM ADD_MONTHS(current_date,+1)) || '-1')::date - 1)::date AS upcoming_period_end
          , initcap(ss.status)::varchar(13) AS subscription_status
          , ss.trial_start
          , MIN(ss.trial_end) AS trial_end
          , ss.is_deleted
          , sp.interval AS subscription_interval
          , sp.metadata_netsuite_service_sale_item_id AS netsuite_item_id
        FROM stripe2.customers sc
        INNER JOIN stripe2.subscriptions ss
          ON sc.id = ss.customer_id -- to get subscription dates for calculations
        LEFT OUTER JOIN stripe2.plans sp
          ON ss.plan_id = sp.id  -- to determine if the subscription is on isp/trial/normal
        WHERE stripe_subscription_id IS NOT NULL -- or is that eero Plus users have a stripe2.subscription, not stripe2.customer
          AND stripe_plan_name NOT IN ('mark.test','Test plan - Internal use ONLY') -- excluding non-real subscription plans
        GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,15,16,17


      ) stripe_base




      INNER JOIN (
        SELECT
          id AS eero_user_id
          , stripe_id
          , email AS eero_user_email
        FROM core.users
        WHERE env = 'PROD'

      ) core_sub
        ON stripe_base.stripe_customer_id = core_sub.stripe_id


      LEFT JOIN (

      SELECT DISTINCT
        cn.primary_user_id
        , cn.id AS network_id
        , isp.organization_id
        , isp.partner_name
        , isp.org_deleted
        , cn.isp
        , (CASE
              WHEN cn.status = 'valid' then 'Active'
              ELSE initcap(cn.status)
            END)::varchar(13) AS network_status
      FROM core.networks cn


      LEFT JOIN (
        SELECT DISTINCT
    cona.organization_id
    , co.name AS partner_name
    , cona.network_id
    , cona.deleted::date AS org_deleted
  FROM (
    SELECT organization_id, network_id, deleted::date AS deleted, env
    FROM core.organization_network_admins
    WHERE env = 'PROD'
    AND deleted IS NULL

    UNION

    SELECT organization_id, network_id, max(deleted)::date AS deleted, env
    FROM core.organization_network_admins
    WHERE env = 'PROD'
    AND ( (deleted::date < ((EXTRACT(YEAR FROM current_date) || '-' || EXTRACT(MONTH FROM current_date) || '-1')::date) AND deleted::date >= (EXTRACT(YEAR FROM ADD_MONTHS(current_date,-1)) || '-' || EXTRACT(MONTH FROM ADD_MONTHS(current_date, - 1)) || '-1')::date) OR deleted::date >= ((EXTRACT(YEAR FROM current_date) || '-' || EXTRACT(MONTH FROM current_date) || '-1')::date) )
    AND network_id NOT IN (SELECT network_id
    FROM core.organization_network_admins
    WHERE env = 'PROD'
    AND deleted IS NULL)
    GROUP BY 1,2,4) cona
  LEFT JOIN (
    SELECT *
    FROM core.organizations
    WHERE (deleted IS NULL OR deleted = 0)
      AND owns_eeros = 1
      AND env = 'PROD'
      AND name not IN ('eero-tools')
          ) co
    ON cona.organization_id = co.id
  LEFT JOIN core.network_admins cna
    ON cona.network_id = cna.network_id
      AND cona.env = cna.env
  WHERE cna.env = 'PROD'
          ) isp
            ON isp.network_id = cn.id
        WHERE cn.env = 'PROD'
--AND isp.organization_id IS NOT NULL ***
GROUP BY 1,2,3,4,5,6,7) details_sub ON details_sub.primary_user_id = core_sub.eero_user_id
             ;;
    sql_trigger_value: select count(*) from stripe2.subscriptions ;;
    distribution_style: even
    indexes: ["eero_user_id","subscription_start","subscription_canceled","partner_name","stripe_plan_id"]
  }

  dimension: partner_name {
    type: string
    sql: ${TABLE}.partner_name ;;
  }
  dimension: isp {
    type: string
    sql: ${TABLE}.isp ;;
  }
  dimension: eero_user_id {
    type: number
    sql: ${TABLE}.eero_user_id ;;
  }
  dimension: network_id {
    type: number
    sql: ${TABLE}.network_id ;;
  }
  dimension: stripe_customer_id {
    type: string
    sql: ${TABLE}.stripe_customer_id ;;
  }
  dimension: eero_user_type {
    type: string
    sql: ${TABLE}.eero_user_type ;;
  }
  dimension: stripe_subscription_id {
    type: string
    sql: ${TABLE}.stripe_subscription_id ;;
  }
  dimension: stripe_plan_name {
    type: string
    sql: ${TABLE}.stripe_plan_name ;;
  }
  dimension: stripe_plan_id {
    type: string
    sql: ${TABLE}.stripe_plan_id ;;
  }
  dimension: price {
    type: number
    sql: ${TABLE}.price ;;
  }
  dimension: subscription_status {
    type: string
    sql: ${TABLE}.subscription_status ;;
  }
  dimension: network_status {
    type: string
    sql: ${TABLE}.network_status ;;
  }
  dimension: subscription_start {
    type: date
    sql: ${TABLE}.subscription_start ;;
  }
  dimension: subscription_canceled {
    type: date
    sql: ${TABLE}.subscription_canceled ;;
  }
##  dimension: eeros_per_user {
##    type: number
##    sql: ${TABLE}.eeros_per_user ;;
##  }
##  dimension: days_to_bill {
##    type: number
##    sql: ${TABLE}.days_to_bill ;;
##  }
  dimension: previous_period_start {
    type: date
    sql: ${TABLE}.previous_period_start ;;
  }
  dimension: previous_period_end {
    type: date
    sql: ${TABLE}.previous_period_end ;;
  }
  dimension: upcoming_period_start {
    type: date
    sql: ${TABLE}.upcoming_period_start ;;
  }
  dimension: upcoming_period_end {
    type: date
    sql: ${TABLE}.upcoming_period_end ;;
  }
##  dimension: previous_month_amount {
##    type: number
##    sql: ${TABLE}.previous_month_amount ;;
##  }
##  dimension: upcoming_month_amount {
##    type: number
##    sql: ${TABLE}.upcoming_month_amount ;;
##  }
##  dimension: source_type {
##    type: string
##    sql: ${TABLE}.source_type ;;
##  }
  dimension: org_deleted {
    type: date
    sql: ${TABLE}.org_deleted ;;
  }
  dimension: organization_id {
    type: number
    sql: ${TABLE}.organization_id ;;
  }
}

view: existing_cte {
  derived_table: {
    sql:
      SELECT
        eero_user_id
        , eero_user_email
        , stripe_customer_id
        , stripe_subscription_id
        , CASE
            WHEN subscription_canceled > previous_period_end THEN 'Existing User'::varchar(25)
            ELSE eero_user_type::varchar(25) END AS eero_user_type
        , stripe_plan_id
        , stripe_plan_name
        , subscription_start
        , CASE
            WHEN subscription_canceled > previous_period_end THEN NULL
            ELSE subscription_canceled END AS subscription_canceled
        , trial_end
        , CASE
            WHEN subscription_canceled > previous_period_end THEN 'Active'::varchar(13)
            ELSE subscription_status::varchar(13) END as subscription_status
          , previous_period_start
          , previous_period_end
          , upcoming_period_start
          , upcoming_period_end
        , sbc.network_id
        , network_status
        , organization_id
        , partner_name
        , 'Existing Users with Active Node Session'::varchar(100) AS source_type
        , ce.serial_number AS unit_serial_number
        , org_deleted
        , price
      FROM ${sub_base_cte.SQL_TABLE_NAME}  sbc
      INNER JOIN core.node_sessions cns
        ON sbc.network_id = cns.network_id
      INNER JOIN core.eeros ce
        ON ce.id = cns.eero_id
      WHERE (eero_user_type = 'Existing User'
        AND cns.joined IS NOT NULL
        AND cns.revoked IS NULL)
          OR (eero_user_type = 'Canceled User'
          AND cns.joined IS NOT NULL
        AND cns.revoked IS NULL
        AND subscription_start <= previous_period_start
        AND subscription_canceled > previous_period_end)
      GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23

      UNION ALL


      -------Exisiting with Cancellations with New Subscriptions------

      SELECT
        eero_user_id
        , eero_user_email
        , stripe_customer_id
        , stripe_subscription_id
        , 'Existing User'::varchar(25) AS eero_user_type
        , stripe_plan_id
        , stripe_plan_name
        , min_subscription_start AS subscription_start
        , NULL::date AS subscription_canceled
        , trial_end
        , 'Active'::varchar(13) AS subscription_status
        , previous_period_start
        , previous_period_end
        , upcoming_period_start
        , upcoming_period_end
        , network_id
        , network_status
        , organization_id
        , partner_name
        , 'Existing Users with Cancellations'::varchar(100) AS source_type
        , unit_serial_number
        , org_deleted
        , price

      FROM (
        SELECT
          eero_user_id
          , eero_user_email
          , stripe_customer_id
          , MAX(stripe_subscription_id) AS stripe_subscription_id
          , stripe_plan_id
          , stripe_plan_name
          , MIN(subscription_start)::date AS min_subscription_start
          , MAX(subscription_start)::date AS max_subscription_start
          , MIN(subscription_canceled)::date AS min_subscription_canceled
          , MAX(subscription_canceled)::date AS max_subscription_canceled
          , trial_end
            , previous_period_start
            , previous_period_end
            , upcoming_period_start
            , upcoming_period_end
          , sbc.network_id
          , network_status
          , organization_id
          , partner_name
          , ce.serial_number AS unit_serial_number
          , org_deleted
          , price
        FROM ${sub_base_cte.SQL_TABLE_NAME}  sbc
        INNER JOIN core.node_sessions cns
          ON sbc.network_id = cns.network_id
        INNER JOIN core.eeros ce
          ON ce.id = cns.eero_id
        WHERE (eero_user_type = 'Canceled User'
          AND cns.joined IS NOT NULL
          --AND cns.revoked IS NULL -- need to check this ***
          AND sbc.eero_user_id  IN (
              SELECT eero_user_id
              FROM ${sub_base_cte.SQL_TABLE_NAME}  sbc
              WHERE eero_user_type = 'New User'
                AND subscription_start >= previous_period_start
                AND subscription_start <= previous_period_end))
            OR (eero_user_type = 'New User'
              AND cns.joined IS NOT NULL
              AND cns.revoked IS NULL
              AND sbc.eero_user_id IN (
              SELECT eero_user_id
              FROM ${sub_base_cte.SQL_TABLE_NAME}  sbc
              WHERE eero_user_type = 'Canceled User'
                AND subscription_canceled >= previous_period_start
                AND subscription_canceled <= previous_period_end))
        GROUP BY 1,2,3,5,6,11,12,13,14,15,16,17,18,19,20,21,22) sub
        WHERE max_subscription_start >= max_subscription_canceled
          AND max_subscription_start - max_subscription_canceled < 15
        GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23
             ;;
    sql_trigger_value: select count(*) from ${sub_base_cte.SQL_TABLE_NAME} sbc ;;
    distribution_style: even
    indexes: ["eero_user_id","subscription_start","subscription_canceled","partner_name","stripe_plan_id"]
  }
}

view: norm_cases_cte {
  derived_table: {
    sql:
      SELECT * FROM ${existing_cte.SQL_TABLE_NAME} existing

      UNION ALL

      -------New Users with No Cancellations------ vetted

      SELECT
        eero_user_id
        , eero_user_email
        , stripe_customer_id
        , stripe_subscription_id
        , eero_user_type
        , stripe_plan_id
        , stripe_plan_name
        , subscription_start
        , subscription_canceled
        , trial_end
        , subscription_status
          , previous_period_start
          , previous_period_end
          , upcoming_period_start
          , upcoming_period_end
        , sbc.network_id
        , network_status
        , organization_id
        , partner_name
        , 'New Users with No Cancellations'::varchar(100) AS source_type
        , ce.serial_number AS unit_serial_number
        , org_deleted
        , price
      FROM ${sub_base_cte.SQL_TABLE_NAME}  sbc
      INNER JOIN core.node_sessions cns
        ON sbc.network_id = cns.network_id
      INNER JOIN core.eeros ce
        ON ce.id = cns.eero_id
      WHERE eero_user_type = 'New User'
        AND cns.joined IS NOT NULL
        AND cns.revoked IS NULL
        AND subscription_start >= previous_period_start
        AND subscription_start <= previous_period_end
        --AND sbc.eero_user_id NOT IN ( -- ***
        --    SELECT eero_user_id
        --    FROM ${sub_base_cte.SQL_TABLE_NAME}  sbc
        --    WHERE eero_user_type = 'Canceled User'
        --      AND subscription_canceled >= previous_period_start
        --      AND subscription_canceled <= previous_period_end)
        AND sbc.eero_user_id NOT IN (
            SELECT eero_user_id
            FROM ${existing_cte.SQL_TABLE_NAME} existing)
      GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23

      UNION ALL


      -------Canceled Users with No New Subscriptions------ vetted

      SELECT
        eero_user_id
        , eero_user_email
        , stripe_customer_id
        , stripe_subscription_id
        , eero_user_type
        , stripe_plan_id
        , stripe_plan_name
        , MIN(subscription_start) AS subscription_start
        , MAX(subscription_canceled) AS subscription_canceled
        , trial_end
        , subscription_status
          , previous_period_start
          , previous_period_end
          , upcoming_period_start
          , upcoming_period_end
        , sbc.network_id
        , network_status
        , organization_id
        , partner_name
        , 'Canceled Users with Active Node Session and No New Subscriptions'::varchar(100) AS source_type
        , ce.serial_number AS unit_serial_number
        , org_deleted
        , price
      FROM ${sub_base_cte.SQL_TABLE_NAME} sbc
      INNER JOIN core.node_sessions cns
        ON sbc.network_id = cns.network_id
      INNER JOIN core.eeros ce
        ON ce.id = cns.eero_id
      WHERE eero_user_type = 'Canceled User'
        AND cns.joined IS NOT NULL
        AND cns.revoked IS NULL
        AND sbc.eero_user_id NOT IN (
            SELECT eero_user_id
            FROM ${existing_cte.SQL_TABLE_NAME} existing) -- ***
        AND subscription_canceled >= previous_period_start
       -- AND subscription_canceled <= previous_period_end  -- ***
      GROUP BY 1,2,3,4,5,6,7,10,11,12,13,14,15,16,17,18,19,20,21,22,23

      UNION ALL

      -------New Users with Cancellations with New Subscriptions------

      SELECT
        eero_user_id
        , eero_user_email
        , stripe_customer_id
        , stripe_subscription_id
        , eero_user_type
        , stripe_plan_id
        , stripe_plan_name
        , subscription_start
        , subscription_canceled
        , trial_end
        , subscription_status
        , previous_period_start
        , previous_period_end
        , upcoming_period_start
        , upcoming_period_end
        , network_id
        , network_status
        , organization_id
        , partner_name
        , 'New Users with Cancellations'::varchar(100) AS source_type
        , unit_serial_number
        , org_deleted
        , price
      FROM (
        SELECT
          eero_user_id
          , eero_user_email
          , stripe_customer_id
          , stripe_subscription_id
          , eero_user_type
          , stripe_plan_id
          , stripe_plan_name
          , subscription_start
          , subscription_canceled
          , MIN(subscription_start)::date AS min_subscription_start
          , MAX(subscription_start)::date AS max_subscription_start
          , MIN(subscription_canceled)::date AS min_subscription_canceled
          , MAX(subscription_canceled)::date AS max_subscription_canceled
          , trial_end
          , subscription_status
            , previous_period_start
            , previous_period_end
            , upcoming_period_start
            , upcoming_period_end
          , sbc.network_id
          , network_status::varchar(25)
          , organization_id
          , partner_name
          , ce.serial_number AS unit_serial_number
          , org_deleted
          , price
        FROM ${sub_base_cte.SQL_TABLE_NAME} sbc
        INNER JOIN core.node_sessions cns
          ON sbc.network_id = cns.network_id
        INNER JOIN core.eeros ce
          ON ce.id = cns.eero_id
        WHERE (eero_user_type = 'Canceled User'
          AND cns.joined IS NOT NULL
          --AND cns.revoked IS NULL -- need to check -- ***
          AND sbc.eero_user_id  IN (
              SELECT eero_user_id
              FROM ${sub_base_cte.SQL_TABLE_NAME} sbc
              WHERE eero_user_type = 'New User'
                AND subscription_start >= previous_period_start
                AND subscription_start <= previous_period_end))
            OR (eero_user_type = 'New User'
              AND cns.joined IS NOT NULL
              AND cns.revoked IS NULL
              AND sbc.eero_user_id IN (
              SELECT eero_user_id
              FROM ${sub_base_cte.SQL_TABLE_NAME} sbc
              WHERE eero_user_type = 'Canceled User'
                AND subscription_canceled >= previous_period_start
                AND subscription_canceled <= previous_period_end))
        GROUP BY 1,2,3,4,5,6,7,8,9,14,15,16,17,18,19,20,21,22,23,24,25,26) sub
        WHERE max_subscription_start > max_subscription_canceled
          AND max_subscription_start - max_subscription_canceled >= 15
          AND subscription_start >= previous_period_start
            AND subscription_start <= previous_period_end
        GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23


      UNION ALL

      --------Free Users--------

      SELECT
        eero_user_id
        , eero_user_email
        , stripe_customer_id
        , stripe_subscription_id
        , eero_user_type
        , stripe_plan_id
        , stripe_plan_name
        , subscription_start
        , subscription_canceled
        , trial_end
        , subscription_status
          , previous_period_start
          , previous_period_end
          , upcoming_period_start
          , upcoming_period_end
        , sbc.network_id
        , network_status::varchar(25)
        , organization_id
        , partner_name
        , 'Free Users with Active Node Session'::varchar(100) AS source_type
        , ce.serial_number AS unit_serial_number
        , org_deleted
        , price
      FROM ${sub_base_cte.SQL_TABLE_NAME} sbc
      INNER JOIN core.node_sessions cns
        ON sbc.network_id = cns.network_id
      INNER JOIN core.eeros ce
        ON ce.id = cns.eero_id
      WHERE eero_user_type = 'Free User'
        AND cns.joined IS NOT NULL
        AND cns.revoked IS NULL
        AND sbc.eero_user_id NOT IN (
            SELECT eero_user_id
            FROM ${existing_cte.SQL_TABLE_NAME} existing)
      GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23;;
    sql_trigger_value: select count(*) from ${existing_cte.SQL_TABLE_NAME} existing ;;
    distribution_style: even
    indexes: ["eero_user_id","subscription_start","subscription_canceled","partner_name","stripe_plan_id"]
  }
}

view: norm_cases_w_revoked_cancel_cte {
  derived_table: {
    sql:
      SELECT * FROM ${norm_cases_cte.SQL_TABLE_NAME} norm_cases

      UNION ALL

      -------Canceled Users with Revoked Node Sessions Only For Missing User IDs------

      SELECT
        eero_user_id
        , eero_user_email
        , stripe_customer_id
        , MAX(stripe_subscription_id) AS stripe_subscription_id
        , eero_user_type
        , stripe_plan_id
        , stripe_plan_name
        , MIN(subscription_start) AS subscription_start
        , MAX(subscription_canceled) AS subscription_canceled
        , trial_end
        , subscription_status
          , previous_period_start
          , previous_period_end
          , upcoming_period_start
          , upcoming_period_end
        , MAX(sbc.network_id) AS network_id
        , 'Inactive'::varchar(25) AS network_status
        , organization_id
        , partner_name
        , 'Canceled Users with No Active Node Session'::varchar(100) AS source_type
        , ce.serial_number AS unit_serial_number
        , org_deleted
        , price
      FROM ${sub_base_cte.SQL_TABLE_NAME} sbc
      INNER JOIN core.node_sessions cns
        ON sbc.network_id = cns.network_id
      INNER JOIN core.eeros ce
        ON ce.id = cns.eero_id
      WHERE eero_user_type = 'Canceled User'
        AND cns.joined IS NOT NULL
        AND cns.revoked IS NOT NULL
        AND sbc.eero_user_id NOT IN (SELECT eero_user_id FROM ${norm_cases_cte.SQL_TABLE_NAME} norm_cases)
        --AND ce.serial_number NOT IN (SELECT unit_serial_number FROM ${norm_cases_cte.SQL_TABLE_NAME} norm_cases WHERE eero_user_type IN ('Existing User')) -- ***
        AND subscription_canceled >= previous_period_start
        AND subscription_canceled <= previous_period_end
      GROUP BY 1,2,3,5,6,7,10,11,12,13,14,15,17,18,19,20,21,22,23
      ;;
    sql_trigger_value: select count(*) from ${norm_cases_cte.SQL_TABLE_NAME} norm_cases_cte ;;
    distribution_style: even
    indexes: ["eero_user_id","subscription_start","subscription_canceled","partner_name","stripe_plan_id"]
  }
}

view: norm_w_revoked_inactive_cte {
  derived_table: {
    sql:
      SELECT * FROM ${norm_cases_w_revoked_cancel_cte.SQL_TABLE_NAME} norm_cases_w_revoked_cancel_cte

      UNION ALL

      ---------------- Active Subscriptions with No Active Node Session----------

      SELECT
        eero_user_id
        , eero_user_email
        , stripe_customer_id
        , stripe_subscription_id
        , eero_user_type
        , stripe_plan_id
        , stripe_plan_name
        , MIN(subscription_start) AS subscription_start
        , NULL::date AS subscription_canceled
        , trial_end
        , subscription_status
          , previous_period_start
          , previous_period_end
          , upcoming_period_start
          , upcoming_period_end
        , MAX(sbc.network_id) AS network_id
        , 'Inactive'::varchar(25) AS network_status
        , organization_id
        , partner_name
        , 'Active Subscriptions with No Active Node Session'::varchar(100) AS source_type
        , ce.serial_number AS unit_serial_number
        , org_deleted
        , price
      FROM ${sub_base_cte.SQL_TABLE_NAME} sbc
      INNER JOIN core.node_sessions cns
        ON sbc.network_id = cns.network_id
      INNER JOIN core.eeros ce
        ON ce.id = cns.eero_id
      WHERE eero_user_type IN ('Existing User','New User','Free User')
        AND cns.joined IS NOT NULL
        AND cns.revoked IS NOT NULL
        AND subscription_status NOT IN ('Canceled')
        AND subscription_start <= previous_period_end
        AND sbc.eero_user_id NOT IN (SELECT eero_user_id FROM ${norm_cases_w_revoked_cancel_cte.SQL_TABLE_NAME} norm_cases_w_revoked_cancel_cte)
      --  AND ce.serial_number NOT IN (SELECT unit_serial_number FROM ${norm_cases_w_revoked_cancel_cte.SQL_TABLE_NAME} norm_cases_w_revoked_cancel_cte WHERE eero_user_type IN ('Existing User','New User','Free User'))-- potentially remove -- ***
      GROUP BY 1,2,3,4,5,6,7,9,10,11,12,13,14,15,17,18,19,20,21,22,23;;
    sql_trigger_value: select count(*) from ${norm_cases_w_revoked_cancel_cte.SQL_TABLE_NAME} norm_cases_w_revoked_cancel_cte ;;
    distribution_style: even
    indexes: ["eero_user_id","subscription_start","subscription_canceled","partner_name","stripe_plan_id"]
  }
}

view: subscriptions {
  derived_table: {
    sql:
      SELECT * FROM ${norm_w_revoked_inactive_cte.SQL_TABLE_NAME} norm_w_revoked_inactive

      UNION ALL

      ---------------- Inactive Subscriptions with No Active Node Session----------

      SELECT
        eero_user_id
        , eero_user_email
        , stripe_customer_id
        , stripe_subscription_id
        , CASE
            WHEN eero_user_type = 'Canceled User' AND subscription_start < previous_period_start THEN 'Existing User'::varchar(25)
            WHEN eero_user_type = 'Canceled User' AND subscription_start >= previous_period_start THEN 'New User'::varchar(25)
            ELSE eero_user_type::varchar(25) END AS eero_user_type
        , stripe_plan_id
        , stripe_plan_name
        , MIN(subscription_start) AS subscription_start
        , NULL::date AS subscription_canceled
        , trial_end
        , subscription_status
          , previous_period_start
          , previous_period_end
          , upcoming_period_start
          , upcoming_period_end
        , MAX(sbc.network_id) AS network_id
        , 'Inactive'::varchar(25) AS network_status
        , organization_id
        , partner_name
        , 'Inactive Subscriptions with No Active Node Session'::varchar(100) AS source_type
        , ce.serial_number AS unit_serial_number
        , org_deleted
        , price
      FROM ${sub_base_cte.SQL_TABLE_NAME} sbc
      INNER JOIN core.node_sessions cns
        ON sbc.network_id = cns.network_id
      INNER JOIN core.eeros ce
        ON ce.id = cns.eero_id
      WHERE eero_user_type IN ('Canceled User')
        AND cns.joined IS NOT NULL
      --  AND cns.revoked IS NOT NULL
        AND subscription_canceled > previous_period_end
        AND sbc.eero_user_id NOT IN (SELECT eero_user_id FROM ${norm_w_revoked_inactive_cte.SQL_TABLE_NAME} norm_w_revoked_inactive)
      GROUP BY 1,2,3,4,5,6,7,9,10,11,12,13,14,15,17,18,19,20,21,22,23;;
    sql_trigger_value: select count(*) from ${norm_w_revoked_inactive_cte.SQL_TABLE_NAME} norm_w_revoked_inactive ;;
    distribution_style: even
    indexes: ["eero_user_id","subscription_start","subscription_canceled","partner_name","stripe_plan_id"]
  }

  dimension: eero_user_id {
    type: number
    sql: ${TABLE}.eero_user_id ;;
  }
  dimension: network_id {
    type: number
    sql: ${TABLE}.network_id ;;
  }
  dimension: stripe_plan_id {
    type: number
    sql: ${TABLE}.stripe_plan_id ;;
  }
  dimension: unit_serial_number {
    type: string
    sql: ${TABLE}.unit_serial_number ;;
  }
  dimension: eero_user_type {
    type: string
    sql: ${TABLE}.eero_user_type ;;
  }
  dimension: stripe_subscription_id {
    type: string
    sql: ${TABLE}.stripe_subscription_id ;;
  }
  dimension: stripe_plan_name {
    type: string
    sql: ${TABLE}.stripe_plan_name ;;
  }
  dimension: subscription_status {
    type: string
    sql: ${TABLE}.subscription_status ;;
  }
  dimension: network_status {
    type: string
    sql: ${TABLE}.network_status ;;
  }
  dimension: subscription_start {
    type: date
    sql: ${TABLE}.subscription_start ;;
  }
  dimension: subscription_canceled {
    type: date
    sql: ${TABLE}.subscription_canceled ;;
  }
  dimension: stripe_customer_id {
    type: string
    sql: ${TABLE}.stripe_customer_id ;;
  }
  dimension: partner_name {
    type: number
    sql: ${TABLE}.partner_name ;;
  }
  dimension: source_type {
    type: string
    sql: ${TABLE}.source_type ;;
  }
  dimension: organization_id {
    type: number
    sql: ${TABLE}.organization_id ;;
  }
}

view: bus_security_partner_reporting {
  derived_table: {
    sql:
      SELECT
          user_id
          , eero_user_email
          , eero_user_type
          , stripe_plan_name
          , subscription_status
          , subscription_started
          , subscription_canceled
          , trial_end
          , paid_started
          , source_type
          , CASE
              WHEN subscription_status = 'Trialing' OR paid_started > previous_period_end OR (subscription_canceled IS NOT NULL AND paid_started > subscription_canceled) THEN 0
              WHEN paid_started >= previous_period_start AND subscription_canceled <= previous_period_end AND subscription_canceled IS NOT NULL THEN subscription_canceled - paid_started + 1
              WHEN paid_started < previous_period_start AND subscription_canceled IS NULL THEN days_in_previous_period
              WHEN paid_started >= previous_period_start AND (subscription_canceled IS NULL OR subscription_canceled > previous_period_end) THEN previous_period_end - paid_started + 1
              WHEN paid_started < previous_period_start AND subscription_canceled <= previous_period_end THEN subscription_canceled - previous_period_start + 1
              ELSE 99999 END AS active_paid_days
          , active_paid_days::float / days_in_previous_period::float AS prorate
          , CASE
              WHEN subscription_canceled >= previous_period_start AND subscription_canceled <= previous_period_end THEN 'Canceled User'
              WHEN paid_started > previous_period_end THEN 'Free User'
              WHEN paid_started < previous_period_start THEN 'Existing User'
              ELSE 'New User' END AS paid_start_eero_user_type

      FROM (
      SELECT
          eero_user_id AS user_id
          , eero_user_email
          , eero_user_type
          , stripe_plan_id
          , stripe_plan_name
          , subscription_status
          , subscription_canceled
          , trial_end::date
          , source_type
          , previous_period_start
          , previous_period_end
          , (previous_period_end - previous_period_start + 1) AS days_in_previous_period
          , MIN(subscription_start) AS subscription_started
          , MIN(CASE
                  WHEN trial_end IS NOT NULL THEN trial_end::date + 1
                  ELSE subscription_start END) AS paid_started
          , CASE
              WHEN eero_user_type = 'Existing User' THEN days_in_previous_period
              WHEN eero_user_type = 'New User' AND subscription_start = previous_period_start THEN days_in_previous_period
              WHEN eero_user_type = 'New User' THEN previous_period_end - subscription_start + 1
              WHEN eero_user_type = 'Canceled User' AND subscription_canceled = previous_period_start THEN 0
              WHEN eero_user_type = 'Canceled User' AND subscription_start > previous_period_start THEN (subscription_canceled - previous_period_end) + (previous_period_start - subscription_start)
              WHEN eero_user_type = 'Canceled User' THEN subscription_canceled - previous_period_end
              WHEN eero_user_type = 'Free User' THEN 0
              END AS days_to_bill



      FROM ${subscriptions.SQL_TABLE_NAME} subs
  --    WHERE org_deleted IS NULL OR org_deleted > subscription_start -- ***
      GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,15
      ) calc_sub
      GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13

             ;;
    persist_for: "24 hours"
    distribution_style: even
    indexes: ["user_id","subscription_started","subscription_canceled"]
  }

  dimension: company_name {
    type: string
    sql: ${TABLE}.company_name ;;
  }
  dimension: user_id {
    type: number
    sql: ${TABLE}.user_id ;;
  }
  dimension: network_id {
    type: number
    sql: ${TABLE}.network_id ;;
  }
  dimension: serial_number {
    type: string
    sql: ${TABLE}.serial_number ;;
  }
  dimension: eero_user_type {
    type: string
    sql: ${TABLE}.eero_user_type ;;
  }
  dimension: stripe_subscription_id {
    type: string
    sql: ${TABLE}.stripe_subscription_id ;;
  }
  dimension: stripe_plan_name {
    type: string
    sql: ${TABLE}.stripe_plan_name ;;
  }
  dimension: subscription_status {
    type: string
    sql: ${TABLE}.subscription_status ;;
  }
  dimension: network_status {
    type: string
    sql: ${TABLE}.network_status ;;
  }
  dimension: subscription_started {
    type: date
    sql: ${TABLE}.subscription_started ;;
  }
  dimension: subscription_canceled {
    type: date
    sql: ${TABLE}.subscription_canceled ;;
  }
  dimension: trial_end {
    type: date
    sql: ${TABLE}.trial_end ;;
  }
  dimension: eeros_per_user {
    type: number
    sql: ${TABLE}.eeros_per_user ;;
  }
  dimension: days_to_bill {
    type: number
    sql: ${TABLE}.days_to_bill ;;
  }
  dimension: previous_month_amount {
    type: number
    sql: ${TABLE}.previous_month_amount ;;
  }
  dimension: upcoming_month_amount {
    type: number
    sql: ${TABLE}.upcoming_month_amount ;;
  }
  dimension: source_type {
    type: string
    sql: ${TABLE}.source_type ;;
  }
  dimension: org_deleted {
    type: date
    sql: ${TABLE}.org_deleted ;;
  }
  measure: active_paid_days {
    type: sum
    sql: ${TABLE}.active_paid_days ;;
  }
}

view: bus_security_partner_bill {
  derived_table: {
    sql:
      SELECT
        *
        ,CASE
          WHEN user_count <= 250000 THEN prorate * .25
          WHEN user_count <= 500000 THEN prorate * .24
          WHEN user_count <= 1000000 THEN prorate * .22
          ELSE prorate * .20 END AS amount_due

      FROM
      (SELECT
          user_id * 7 + 13 AS anon_id
          , eero_user_email
          , eero_user_type
          , stripe_plan_name
          , subscription_status
          , subscription_started
          , subscription_canceled
          , trial_end
          , paid_started
          , source_type
          , active_paid_days
          , prorate
          , paid_start_eero_user_type
          , ROW_NUMBER() OVER (ORDER BY paid_started ASC) AS user_count
      FROM ${bus_security_partner_reporting.SQL_TABLE_NAME} bspr
      WHERE paid_start_eero_user_type != 'Free User'
        AND stripe_plan_name != 'eero Plus - Complimentary Plan'
        AND active_paid_days != 0
        GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13) sub

             ;;
    persist_for: "24 hours"
    distribution_style: even
    indexes: ["anon_id","paid_start_eero_user_type","paid_started","subscription_canceled"]
  }


  dimension: anon_id {
    type: number
    sql: ${TABLE}.anon_id ;;
  }
  dimension: eero_user_type {
    type: string
    sql: ${TABLE}.eero_user_type ;;
  }
  dimension: stripe_plan_name {
    type: string
    sql: ${TABLE}.stripe_plan_name ;;
  }
  dimension: subscription_status {
    type: string
    sql: ${TABLE}.subscription_status ;;
  }
  dimension: subscription_started {
    type: date
    sql: ${TABLE}.subscription_started ;;
  }
  dimension: subscription_canceled {
    type: date
    sql: ${TABLE}.subscription_canceled ;;
  }
  dimension: trial_end {
    type: date
    sql: ${TABLE}.trial_end ;;
  }
  dimension: paid_started {
    type: date
    sql: ${TABLE}.paid_started ;;
  }
  dimension: user_count {
    type: number
    sql:  ${TABLE}.user_count ;;
  }
  dimension: source_type {
    type: string
    sql:  ${TABLE}.source_type ;;
  }
  dimension: prorate {
    type: number
    sql:  ${TABLE}.prorate ;;
  }
  dimension: paid_start_eero_user_type {
    type: string
    sql:  ${TABLE}.paid_start_eero_user_type ;;
  }
  measure: active_paid_days {
    type: sum
    sql: ${TABLE}.active_paid_days ;;
  }
  measure: amount_due {
    type: sum
    sql: ${TABLE}.amount_due ;;
  }

}
