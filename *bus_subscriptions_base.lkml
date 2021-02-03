## cleanup of stripe subscriptions data and implementation of some business rules to split up the population reported to business partners

view: sub_base_cte {
  derived_table: {
    sql:
      SELECT
        eero_user_id::integer AS eero_user_id
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
        GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,15,16,17) stripe_base
      INNER JOIN (
        SELECT
          id AS eero_user_id
          , stripe_id
          --, email AS eero_user_email
        FROM core.users
        WHERE env = 'PROD') core_sub ON stripe_base.stripe_customer_id = core_sub.stripe_id
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
          SELECT
          DISTINCT cona.organization_id
            , co.name AS partner_name
            , cona.network_id
            , cona.deleted::date AS org_deleted
          FROM (
            SELECT organization_id, network_id, deleted::date AS deleted, env
            FROM core.organization_network_admins
            WHERE env = 'PROD' AND deleted IS NULL

            UNION

            SELECT organization_id, network_id, max(deleted)::date AS deleted, env
            FROM core.organization_network_admins
            WHERE env = 'PROD'
              AND ( (deleted::date < ((EXTRACT(YEAR FROM current_date) || '-' || EXTRACT(MONTH FROM current_date) || '-1')::date) AND deleted::date >= (EXTRACT(YEAR FROM ADD_MONTHS(current_date,-1)) || '-' || EXTRACT(MONTH FROM ADD_MONTHS(current_date, - 1)) || '-1')::date) OR deleted::date >= ((EXTRACT(YEAR FROM current_date) || '-' || EXTRACT(MONTH FROM current_date) || '-1')::date) )
              AND network_id NOT IN (
                SELECT network_id
                FROM core.organization_network_admins
                WHERE env = 'PROD' AND deleted IS NULL)
            GROUP BY 1,2,4) cona
          LEFT JOIN (
            SELECT *
            FROM core.organizations
            WHERE (deleted IS NULL OR deleted = 0)
              AND owns_eeros = 1
              AND env = 'PROD'
              AND name not IN ('eero-tools')) co ON cona.organization_id = co.id
          LEFT JOIN core.network_admins cna ON cona.network_id = cna.network_id AND cona.env = cna.env
          WHERE cna.env = 'PROD') isp ON isp.network_id = cn.id
        WHERE cn.env = 'PROD'
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
      WHERE (eero_user_type = 'Existing User' -- include users that are defined as exisiting
        AND cns.joined IS NOT NULL
        AND cns.revoked IS NULL)
          OR (eero_user_type = 'Canceled User' -- include users that are defined as canceled now, after month end, but were existing in the billing period
          AND cns.joined IS NOT NULL
        AND cns.revoked IS NULL
        AND subscription_start <= previous_period_start
        AND subscription_canceled > previous_period_end)
      GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22

      UNION ALL


      -------Exisiting with Cancellations with New Subscriptions------

      SELECT
        eero_user_id
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
        WHERE (eero_user_type = 'Canceled User' -- include users who canceled in the prior period and started a new subscription in the same period
          AND cns.joined IS NOT NULL
          AND sbc.eero_user_id  IN (
              SELECT eero_user_id
              FROM ${sub_base_cte.SQL_TABLE_NAME}  sbc
              WHERE eero_user_type = 'New User'
                AND subscription_start >= previous_period_start
                AND subscription_start <= previous_period_end))
            OR (eero_user_type = 'New User' -- include users who are new in the prior period and canceled a subscription in the same period
              AND cns.joined IS NOT NULL
              AND cns.revoked IS NULL
              AND sbc.eero_user_id IN (
              SELECT eero_user_id
              FROM ${sub_base_cte.SQL_TABLE_NAME}  sbc
              WHERE eero_user_type = 'Canceled User'
                AND subscription_canceled >= previous_period_start
                AND subscription_canceled <= previous_period_end))
        GROUP BY 1,2,4,5,10,11,12,13,14,15,16,17,18,19,20,21) sub
        WHERE max_subscription_start >= max_subscription_canceled
          AND max_subscription_start - max_subscription_canceled < 15 --  collapse where the period of cancellation and new subscription was < 15 days and treat as if subscription was not canceled.
        GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22
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
      WHERE eero_user_type = 'New User' -- this is to now include all remaining new users who weren't a part of the population of customers who canceled/started new subscriptions above
        AND cns.joined IS NOT NULL
        AND cns.revoked IS NULL
        AND subscription_start >= previous_period_start
        AND subscription_start <= previous_period_end
        AND sbc.eero_user_id NOT IN (
            SELECT eero_user_id
            FROM ${existing_cte.SQL_TABLE_NAME} existing)
      GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22

      UNION ALL


      -------Canceled Users with No New Subscriptions------ vetted

      SELECT
        eero_user_id
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
      WHERE eero_user_type = 'Canceled User' -- this is to now include all remaining canceled users who weren't a part of the population of customers who canceled/started new subscriptions above
        AND cns.joined IS NOT NULL
        AND cns.revoked IS NULL
        AND sbc.eero_user_id NOT IN (
            SELECT eero_user_id
            FROM ${existing_cte.SQL_TABLE_NAME} existing)
        AND subscription_canceled >= previous_period_start
      GROUP BY 1,2,3,4,5,6,9,10,11,12,13,14,15,16,17,18,19,20,21,22


      UNION ALL

      -------New Users with Cancellations with New Subscriptions------

      SELECT
        eero_user_id
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
        GROUP BY 1,2,3,4,5,6,7,8,13,14,15,16,17,18,19,20,21,22,23,24,25) sub
        WHERE max_subscription_start > max_subscription_canceled
          AND max_subscription_start - max_subscription_canceled >= 15 -- this is to separate out the users who had cancellations but new subscriptions >= 15 days and both subscriptions lines needing to be included
          AND subscription_start >= previous_period_start
            AND subscription_start <= previous_period_end
        GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22


      UNION ALL

      --------Free Users--------

      SELECT
        eero_user_id
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
      WHERE eero_user_type = 'Free User' -- pulling in free users who have active node sessions
        AND cns.joined IS NOT NULL
        AND cns.revoked IS NULL
        AND sbc.eero_user_id NOT IN (
            SELECT eero_user_id
            FROM ${existing_cte.SQL_TABLE_NAME} existing)
      GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22;;
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
      WHERE eero_user_type = 'Canceled User' -- every pdt above filters on having active node sessons. canceled users no longer have active node sessions if they return eeros to ISP in conjunctioin with ending secure. here i capture canceled subscriptiions with node sessions revoked in the month.
        AND cns.joined IS NOT NULL
        AND cns.revoked IS NOT NULL
        AND sbc.eero_user_id NOT IN (SELECT eero_user_id FROM ${norm_cases_cte.SQL_TABLE_NAME} norm_cases)
        AND subscription_canceled >= previous_period_start
        AND subscription_canceled <= previous_period_end
      GROUP BY 1,2,4,5,6,9,10,11,12,13,14,16,17,18,19,20,21,22
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
      WHERE eero_user_type IN ('Existing User','New User','Free User') -- we found that ISPs are not great at managing subscriptions. users would stop using eeros but the ISPs would not terminate the subscription. i'm pulling in active subscriptions with no active node sessions for reporting to the ISP on subscriptions that need to be cleaned up
        AND cns.joined IS NOT NULL
        AND cns.revoked IS NOT NULL
        AND subscription_status NOT IN ('Canceled')
        AND subscription_start <= previous_period_end
        AND sbc.eero_user_id NOT IN (SELECT eero_user_id FROM ${norm_cases_w_revoked_cancel_cte.SQL_TABLE_NAME} norm_cases_w_revoked_cancel_cte)
      GROUP BY 1,2,3,4,5,6,8,9,10,11,12,13,14,16,17,18,19,20,21,22;;
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
      WHERE eero_user_type IN ('Canceled User') -- found that some canceled users did not have revoked node sessions in the billing month, causing them to fall off. added this union to capture inactive subscriptions with on active/revoked node session in billing month.
        AND cns.joined IS NOT NULL
        AND subscription_canceled > previous_period_end
        AND sbc.eero_user_id NOT IN (SELECT eero_user_id FROM ${norm_w_revoked_inactive_cte.SQL_TABLE_NAME} norm_w_revoked_inactive)
      GROUP BY 1,2,3,4,5,6,8,9,10,11,12,13,14,16,17,18,19,20,21,22;;
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
