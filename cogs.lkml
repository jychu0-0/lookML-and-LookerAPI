## COGS for each account divided by LIVE test complete. workbook currently uses test complete booked in Rev Recon

explore: cogs_per_test {}

view: cogs_per_test {
  derived_table: {
    sql: SELECT
        cog.month
        , gl_account
        , category
        , rev_exp_id
        , rev_exp_name
        , variable_fixed_id
        , variable_fixed_name
        , sub_headers_id
        , sub_headers
        , fps1 AS fps1_total
        , fps1_complete AS fps1_count
        , fps2 AS fps2_total
        , fps2_complete AS fps2_count
        , ics AS ics_total
        , ics_complete AS ics_count
        , ips AS ips_total
        , ips_complete AS ips_count
      FROM ${cogs.SQL_TABLE_NAME} AS cog
      INNER JOIN ${test_per_month.SQL_TABLE_NAME} AS tpm on cog.month = tpm.month

       ;;
    sql_trigger_value: select current_date ;;
    indexes: ["month", "gl_account"]
  }

  dimension_group: month {
    type: time
    timeframes: [month, quarter, year]
    sql: ${TABLE}.month ;;
  }

  dimension: gl_account {
    group_label: "Account Details"
    type: string
    sql: ${TABLE}.gl_account ;;
  }

  dimension:  account_count {
    hidden: yes
    type:  number
    sql:  COUNT(DISTINCT(${gl_account})) ;;
  }

  dimension: category {
    group_label: "Account Details"
    type: string
    sql: ${TABLE}.category ;;
  }

  dimension: rev_exp_id {
    group_label: "Account Details"
    hidden: yes
    type: number
    sql: ${TABLE}.rev_exp_id ;;
  }

  dimension: rev_exp_name {
    order_by_field: rev_exp_id
    group_label: "Account Details"
    type: string
    sql: ${TABLE}.rev_exp_name ;;
  }

  dimension: variable_fixed_id {
    group_label: "Account Details"
    hidden:  yes
    type: number
    sql: ${TABLE}.variable_fixed_id ;;
  }

  dimension: variable_fixed_name {
    order_by_field: variable_fixed_id
    group_label: "Account Details"
    type: string
    sql: ${TABLE}.variable_fixed_name ;;
  }

  dimension: sub_headers_id {
    group_label: "Account Details"
    hidden: yes
    type: number
    sql: ${TABLE}.sub_headers_id ;;
  }

  dimension: sub_headers {
    group_label: "Account Details"
    order_by_field: sub_headers_id
    type: string
    sql: ${TABLE}.sub_headers ;;
  }

  measure: fps1_total {
    hidden: yes
    type: sum
    value_format_name: usd
    sql: coalesce(${TABLE}.fps1_total,0);;
  }

  measure:  fps1_count {
    hidden: yes
    type: sum
    sql: ${TABLE}.fps1_count  ;;
  }

  measure: fps1_true_count {
    hidden: yes
    type: number
    sql: ${fps1_count} / ${account_count} ;;
  }

  measure: fps2_total {
    hidden: yes
    type: sum
    value_format_name: usd
    sql: coalesce(${TABLE}.fps2_total,0) ;;
  }

  measure:  fps2_count {
    hidden: yes
    type: sum
    sql: ${TABLE}.fps2_count  ;;
  }

  measure: fps2_true_count {
    hidden: yes
    type: number
    sql: ${fps2_count} / ${account_count} ;;
  }

  measure: ics_total {
    hidden: yes
    type: sum
    value_format_name: usd
    sql: coalesce(${TABLE}.ics_total,0) ;;
  }

  measure:  ics_count {
    hidden: yes
    type: sum
    sql: ${TABLE}.ics_count  ;;
  }

  measure: ics_true_count {
    hidden: yes
    type: number
    sql: ${ics_count} / ${account_count} ;;
  }

  measure: ips_total {
    hidden: yes
    type: sum
    value_format_name: usd
    sql: coalesce(${TABLE}.ips_total,0);;
  }

  measure:  ips_count {
    hidden: yes
    type: sum
    sql: ${TABLE}.ips_count  ;;
  }

  measure: ips_true_count {
    hidden: yes
    type: number
    sql: ${ips_count} / ${account_count} ;;
  }

  measure: fps1_cpt {
    type:  number
    value_format_name: usd
    sql:  ${fps1_total} / ${fps1_true_count} ;;
  }

  measure: fps2_cpt {
    type:  number
    value_format_name: usd
    sql:  ${fps2_total} / ${fps2_true_count} ;;
  }
  measure: ics_cpt {
    type:  number
    value_format_name: usd
        sql:  ${ics_total} / ${ics_true_count} ;;
  }

  measure: ips_cpt {
    type:  number
    value_format_name: usd
    sql:  ${ips_total} / ${ips_true_count} ;;
  }

  }

## UNIONS the cost_of_sales account allocations with allocations where the cost_of_sales view is an input.

view: cogs {
  derived_table: {
    sql: -- Cost of Sales

      SELECT
        month
        , gl_account
        , category
        , rev_exp_id
        , rev_exp_name
        , variable_fixed_id
        , variable_fixed_name
        , sub_headers_id
        , sub_headers
        , fps1
        , fps2
        , ics
        , ips
      FROM ${cost_of_sales.SQL_TABLE_NAME} as cost_of_sales

      UNION

      -- Inventory Freight Tax

      SELECT
        month
        , gl_account
        , category
        , rev_exp_id
        , rev_exp_name
        , variable_fixed_id
        , variable_fixed_name
        , sub_headers_id
        , sub_headers
        , fps1
        , fps2
        , ics
        , ips
      FROM ${inventory_freight_tax.SQL_TABLE_NAME} as inventory_freight_tax

      UNION

      -- COGs reclass

      SELECT
        reclass.month AS month
        , gl_account
        , category
        , rev_exp_id
        , rev_exp_name
        , variable_fixed_id
        , variable_fixed_name
        , sub_headers_id
        , sub_headers
        , CASE
          WHEN gl_account =  '5121 - Direct Labor Lab - COGS Reclass' THEN fps1 + coalesce(fps1_5121,0)
          WHEN gl_account = '8100 - Non-COGs OpEx' THEN fps1 + coalesce(fps1_8100,0) ELSE fps1 END AS fps1
        , CASE
          WHEN gl_account =  '5121 - Direct Labor Lab - COGS Reclass' THEN fps2 + coalesce(fps2_5121,0)
          WHEN gl_account = '8100 - Non-COGs OpEx' THEN fps2 + coalesce(fps2_8100,0) ELSE fps2 END AS fps2
        , CASE
          WHEN gl_account =  '5121 - Direct Labor Lab - COGS Reclass' THEN ics + coalesce(ics_5121,0)
          WHEN gl_account = '8100 - Non-COGs OpEx' THEN ics + coalesce(ics_8100,0) ELSE ics END AS ics
        , CASE
          WHEN gl_account =  '5121 - Direct Labor Lab - COGS Reclass' THEN ips + coalesce(ips_5121,0)
          WHEN gl_account = '8100 - Non-COGs OpEx' THEN ips + coalesce(ips_8100,0) ELSE ips END AS ips
      FROM ${reclass.SQL_TABLE_NAME} as reclass
      INNER JOIN costing.reclassallocations ON reclass.month = reclassallocations.month

      UNION

      -- Bring In Revenue Accounts

      SELECT
        pandl.month
        , gl_account
        , category
        , rev_exp_id
        , rev_exp_name
        , variable_fixed_id
        , variable_fixed_name
        , sub_headers_id
        , sub_headers
        , CASE WHEN account_number IN (4001,4101) THEN coalesce(pandl.amount,0) END AS fps1
        , CASE WHEN account_number IN (4002,4102) THEN coalesce(pandl.amount,0) END AS fps2
        , CASE WHEN account_number IN (4003,4103) THEN coalesce(pandl.amount,0) END AS ics
        , CASE WHEN account_number IN (4004,4104) THEN coalesce(pandl.amount,0) END AS ips
      FROM costing.updatedpandl AS pandl
      INNER JOIN costing.calcassignments ON calcassignments.account_name = pandl.gl_account
      WHERE calcassignments.calc_type = 'revenue_calc'

       ;;
    sql_trigger_value: select sum(total_count) from (select sum(total_kit_count) as total_count from ${kit_usage.SQL_TABLE_NAME}) union (select sum(total_count) as total_count from ${samples_accessioned.SQL_TABLE_NAME}) union (select sum(total_count) as total_count from ${samples_ran.SQL_TABLE_NAME}) as foo ;;
    indexes: ["month", "gl_account"]
  }

  dimension_group: month {
    type: time
    timeframes: [month, quarter, year]
    sql: ${TABLE}.month ;;
  }

  dimension: gl_account {
    group_label: "Account Details"
    sql: ${TABLE}.gl_account ;;
  }

  dimension: category {
    group_label: "Account Details"
    sql: ${TABLE}.category ;;
  }

  dimension: rev_exp_id {
    group_label: "Account Details"
    hidden: yes
    type: number
    sql: ${TABLE}.rev_exp_id ;;
  }

  dimension: rev_exp_name {
    order_by_field: rev_exp_id
    group_label: "Account Details"
    type: string
    sql: ${TABLE}.rev_exp_name ;;
  }

  dimension: variable_fixed_id {
    group_label: "Account Details"
    hidden:  yes
    type: number
    sql: ${TABLE}.variable_fixed_id ;;
  }

  dimension: variable_fixed_name {
    order_by_field: variable_fixed_id
    group_label: "Account Details"
    type: string
    sql: ${TABLE}.variable_fixed_name ;;
  }

  dimension: sub_headers_id {
    group_label: "Account Details"
    hidden: yes
    type: number
    sql: ${TABLE}.sub_headers_id ;;
  }

  dimension: sub_headers {
    group_label: "Account Details"
    order_by_field: sub_headers_id
    type: string
    sql: ${TABLE}.sub_headers ;;
  }

  measure: fps1 {
    type: sum
    value_format_name: usd
    sql: ${TABLE}.fps1 ;;
  }

  measure: fps2 {
    type: sum
    value_format_name: usd
    sql: ${TABLE}.fps2 ;;
  }

  measure: ics {
    type: sum
    value_format_name: usd
    sql: ${TABLE}.ics ;;
  }

  measure: ips {
    type: sum
    value_format_name: usd
    sql: ${TABLE}.ips ;;
  }
}

## All account allocations that are independent of other accounts.

view: cost_of_sales {
  derived_table: {
    sql: -- 5001 - lab inventory
      SELECT
        lab_inventory.month
        , '5001 - Lab Inventory'::text AS gl_account
        , 'Ordinary Income/Expense'::text AS category
        , 2 AS rev_exp_id
        , 'Cost of Sales'::text AS rev_exp_name
        , 1 AS variable_fixed_id
        , 'Direct Materials'::text AS variable_fixed_name
        , 1 AS sub_headers_id
        , 'Direct Materials' AS sub_headers
        , SUM(CASE WHEN test = 'fps1' THEN 1.0 * total_cogs + (fps1_overall_percent * total_variance) ELSE 0 END) AS fps1
        , SUM(CASE WHEN test = 'fps2' THEN 1.0 * total_cogs + (fps2_overall_percent * total_variance) ELSE 0 END) AS fps2
        , SUM(CASE WHEN test = 'ics' THEN 1.0 * total_cogs + (ics_overall_percent * total_variance) ELSE 0 END) AS ics
        , SUM(CASE WHEN test = 'ips' THEN 1.0 * total_cogs + (ips_overall_percent * total_variance) ELSE 0 END) AS ips
      FROM ${lab_inventory_totals.SQL_TABLE_NAME} AS lab_inventory
      INNER JOIN ${lab_inventory_variance.SQL_TABLE_NAME} AS lab_inventory_variance ON lab_inventory_variance.month = lab_inventory.month
      INNER JOIN ${samples_ran.SQL_TABLE_NAME} AS samples_ran ON samples_ran.month = lab_inventory.month
      GROUP BY 1,2,3,4,5,6

      -- numbers for lab inventory are spot on in month 1 but become increasingly divergent because of what assays are included and which are zeroed out is inconsistent

      UNION
      -- 5002 - kits

      SELECT
        kitusage.month
        , '5002 - Kits'::text AS gl_account
        , 'Ordinary Invoice/Expense'::text AS category
        , 2 AS rev_exp_id
        , 'Cost of Sales'::text AS rev_exp_name
        , 1 AS variable_fixed_id
        , 'Direct Materials'::text AS variable_fixed_name
        , 1 AS sub_headers_id
        , 'Direct Materials' AS sub_headers
        , kitusage.fps1_blood_cost+kitusage.fps1_saliva_cost AS fps1
        , kitusage.fps2_blood_cost+kitusage.fps2_saliva_cost AS fps2
        , kitusage.ics_blood_cost+kitusage.ics_saliva_cost AS ics
        , kitusage.ips_kit_cost AS ips
      FROM ${kit_usage.SQL_TABLE_NAME} AS kitusage

      UNION
      -- GC Call Log %

      SELECT
        gc_call_log.month
        , gl_account
        , category
        , rev_exp_id
        , rev_exp_name
        , variable_fixed_id
        , variable_fixed_name
        , sub_headers_id
        , sub_headers
        , 1.0 * coalesce(pandl.amount,0) * gc_call_log.percent_fps1 AS fps1
        , 1.0 * coalesce(pandl.amount,0) * gc_call_log.percent_fps2 AS fps2
        , 1.0 * coalesce(pandl.amount,0) * gc_call_log.percent_ics AS ics
        , 1.0 * coalesce(pandl.amount,0) * gc_call_log.percent_ips AS ips
      FROM costing.updatedpandl AS pandl
      INNER JOIN ${gc_call_log.SQL_TABLE_NAME} AS gc_call_log ON gc_call_log.month = pandl.month
      INNER JOIN costing.calcassignments ON calcassignments.account_name = pandl.gl_account
      WHERE calcassignments.calc_type = 'gc_call_log'

      UNION
      -- Variance Curation % Allocation

      SELECT
        vc_allocation.month
        , gl_account
        , category
        , rev_exp_id
        , rev_exp_name
        , variable_fixed_id
        , variable_fixed_name
        , sub_headers_id
        , sub_headers
        , 0 AS fps1
        , CASE
            WHEN account_number = 5371 THEN 1.0 * coalesce(pandl.amount,0) * vc_allocation.fps2_5371_allocation
            ELSE 1.0 * coalesce(pandl.amount,0) * vc_allocation.fps2_allocation END AS fps2
        , CASE
            WHEN account_number = 5371 THEN 1.0 * coalesce(pandl.amount,0) * vc_allocation.ics_5371_allocation
            ELSE 1.0 * coalesce(pandl.amount,0) * vc_allocation.ics_allocation END AS ics
        , 0 AS ips
      FROM costing.updatedpandl AS pandl
      INNER JOIN costing.updatedvariantcurationallocation AS vc_allocation ON vc_allocation.month = pandl.month
      INNER JOIN costing.calcassignments ON calcassignments.account_name = pandl.gl_account
      WHERE calcassignments.calc_type = 'vc_tickets'

      UNION
      -- Phlebotomoy

      SELECT
        pandl.month
        , gl_account
        , category
        , rev_exp_id
        , rev_exp_name
        , variable_fixed_id
        , variable_fixed_name
        , sub_headers_id
        , sub_headers
        , fps1_percent * fps_blood_percent_w_ips * amount AS fps1
        , fps2_percent * fps_blood_percent_w_ips * amount AS fps2
        , ics_blood_percent_w_ips * amount AS ics
        , ips_blood_percent_w_ips * amount AS ips
      FROM costing.updatedpandl AS pandl
      LEFT JOIN ${samples_accessioned.SQL_TABLE_NAME} AS sampacc ON sampacc.month = pandl.month
      LEFT JOIN ${samples_ran.SQL_TABLE_NAME} AS sampran ON sampran.month = pandl.month
      WHERE pandl.gl_account = '5004 - Phlebotomy'


      UNION

      -- Freight Kits

      SELECT
        freight_kits.month
        , gl_account
        , category
        , rev_exp_id
        , rev_exp_name
        , variable_fixed_id
        , variable_fixed_name
        , sub_headers_id
        , sub_headers
        , fps1
        , fps2
        , ics
        , ips
      FROM ${freight_kits.SQL_TABLE_NAME} as freight_kits

      UNION

      -- 5007 - royalties

      SELECT
        pandl.month
        , gl_account
        , category
        , rev_exp_id
        , rev_exp_name
        , variable_fixed_id
        , variable_fixed_name
        , sub_headers_id
        , sub_headers
        , samplesran.fps1_stanford_percent * (pandl.amount - ips_royalties.royalty) AS fps1
        , samplesran.fps2_stanford_percent * (pandl.amount - ips_royalties.royalty) AS fps2
        , samplesran.ics_stanford_percent * (pandl.amount - ips_royalties.royalty) AS ics
        , ips_royalties.royalty AS ips
      FROM costing.updatedpandl AS pandl
      INNER JOIN costing.calcassignments ON pandl.gl_account = calcassignments.account_name
      INNER JOIN ${ips_royalties.SQL_TABLE_NAME} AS ips_royalties ON pandl.month = ips_royalties.month
      INNER JOIN ${samples_ran.SQL_TABLE_NAME} AS samplesran ON samplesran.month = pandl.month
      WHERE account_number = 5007

      UNION

      -- 5010 - Outsourced Lab


      SELECT
        pandl.month
        , gl_account
        , category
        , rev_exp_id
        , rev_exp_name
        , variable_fixed_id
        , variable_fixed_name
        , sub_headers_id
        , sub_headers
        , CASE WHEN pandl.month < '2016-03-01' THEN samplesran.fps1_overall_percent * (pandl.amount - ipsactthe.verinata_est)
          ELSE samplesran.fps1_percent * (pandl.amount - ipsactthe.verinata_est) END AS fps1
        , CASE WHEN pandl.month < '2016-03-01' THEN samplesran.fps2_overall_percent * (pandl.amount - ipsactthe.verinata_est)
          ELSE samplesran.fps2_percent * (pandl.amount - ipsactthe.verinata_est) END AS fps2
        , CASE WHEN pandl.month < '2016-03-01' THEN samplesran.ics_overall_percent * (pandl.amount - ipsactthe.verinata_est) ELSE 0 END AS ics
        , ipsactthe.verinata_est AS ips
      FROM costing.updatedpandl AS pandl
      INNER JOIN costing.calcassignments ON pandl.gl_account = calcassignments.account_name
      INNER JOIN costing.updatedipsactthe AS ipsactthe ON pandl.month = ipsactthe.month
      INNER JOIN ${samples_ran.SQL_TABLE_NAME} AS samplesran ON pandl.month = samplesran.month
      WHERE account_number = 5010


      UNION

      -- Overall % Usage

      SELECT
        samplesran.month
        , gl_account
        , category
        , rev_exp_id
        , rev_exp_name
        , variable_fixed_id
        , variable_fixed_name
        , sub_headers_id
        , sub_headers
        , 1.0 * coalesce(pandl.amount,0) * samplesran.fps1_overall_percent AS fps1
        , 1.0 * coalesce(pandl.amount,0) * samplesran.fps2_overall_percent AS fps2
        , 1.0 * coalesce(pandl.amount,0) * samplesran.ics_overall_percent AS ics
        , 1.0 * coalesce(pandl.amount,0) * samplesran.ips_overall_percent AS ips
      FROM costing.updatedpandl AS pandl
      INNER JOIN
        ${samples_ran.SQL_TABLE_NAME} AS samplesran ON pandl.month = samplesran.month
      INNER JOIN
        costing.calcassignments ON calcassignments.account_name = pandl.gl_account
      WHERE calcassignments.calc_type = 'overall_percent'

      UNION
      -- Total % Usage

      SELECT
        samplesran.month
        , gl_account
        , category
        , rev_exp_id
        , rev_exp_name
        , variable_fixed_id
        , variable_fixed_name
        , sub_headers_id
        , sub_headers
        , 1.0 * coalesce(pandl.amount,0) * samplesran.fps1_total_percent AS fps1
        , 1.0 * coalesce(pandl.amount,0) * samplesran.fps2_total_percent AS fps2
        , 1.0 * coalesce(pandl.amount,0) * samplesran.ics_total_percent AS ics
        , 1.0 * coalesce(pandl.amount,0) * samplesran.ips_total_percent AS ips
      FROM costing.updatedpandl AS pandl
      INNER JOIN
        ${samples_ran.SQL_TABLE_NAME} AS samplesran ON pandl.month = samplesran.month
      INNER JOIN
        costing.calcassignments ON calcassignments.account_name = pandl.gl_account
      WHERE calcassignments.calc_type = 'total_percent'

      GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13
       ;;
    sql_trigger_value: select sum(total_count) from (select sum(total_kit_count) as total_count from ${kit_usage.SQL_TABLE_NAME}) union (select sum(total_count) as total_count from ${samples_accessioned.SQL_TABLE_NAME}) union (select sum(total_count) as total_count from ${samples_ran.SQL_TABLE_NAME}) as foo ;;
    indexes: ["month", "gl_account"]
  }

  dimension_group: month {
    type: time
    timeframes: [month, year]
    sql: ${TABLE}.month ;;
  }

  dimension: gl_account {
    group_label: "Account Details"
    sql: ${TABLE}.gl_account ;;
  }

  dimension: category {
    group_label: "Account Details"
    sql: ${TABLE}.category ;;
  }

  dimension: rev_exp_id {
    group_label: "Account Details"
    hidden: yes
    type: number
    sql: ${TABLE}.rev_exp_id ;;
  }

  dimension: rev_exp_name {
    order_by_field: rev_exp_id
    group_label: "Account Details"
    type: string
    sql: ${TABLE}.rev_exp_name ;;
  }

  dimension: variable_fixed_id {
    group_label: "Account Details"
    hidden:  yes
    type: number
    sql: ${TABLE}.variable_fixed_id ;;
  }

  dimension: variable_fixed_name {
    order_by_field: variable_fixed_id
    group_label: "Account Details"
    type: string
    sql: ${TABLE}.variable_fixed_name ;;
  }

  dimension: sub_headers_id {
    group_label: "Account Details"
    hidden: yes
    type: number
    sql: ${TABLE}.sub_headers_id ;;
  }

  dimension: sub_headers {
    group_label: "Account Details"
    order_by_field: sub_headers_id
    type: string
    sql: ${TABLE}.sub_headers ;;
  }

  dimension: fps1 {
    type: number
    value_format_name: usd
    sql: ${TABLE}.fps1 ;;
  }

  dimension: fps2 {
    type: number
    value_format_name: usd
    sql: ${TABLE}.fps2 ;;
  }

  dimension: ics {
    type: number
    value_format_name: usd
    sql: ${TABLE}.ics ;;
  }

  dimension: ips {
    type: number
    value_format_name: usd
    sql: ${TABLE}.ips ;;
  }
}

## Allocates out the inbound and outbound freight costs to each product.

view: freight_kits {
  derived_table: {
    sql: SELECT
        sub.month
        , gl_account
        , category
        , rev_exp_id
        , rev_exp_name
        , variable_fixed_id
        , variable_fixed_name
        , sub_headers_id
        , sub_headers
        , fps1_percent_both_wo_ips * (amount - ips) AS fps1
        , fps2_percent_both_wo_ips * (amount - ips) AS fps2
        , ics_percent_both_wo_ips * (amount - ips) AS ics
        , ips
      FROM(
        SELECT
          pandl.month
        , gl_account
        , category
        , rev_exp_id
        , rev_exp_name
        , variable_fixed_id
        , variable_fixed_name
        , sub_headers_id
        , sub_headers
          , amount
          , fps1_percent_both_wo_ips
          , fps2_percent_both_wo_ips
          , ics_percent_both_wo_ips
          , CASE
              WHEN pandl.gl_account = '5011 - Outbound Freight (Kits)' THEN ips_kit_percent * amount
              WHEN pandl.gl_account = '5012 - Inbound Freight (Kits)' THEN 18.85 * ips_blood_count END AS ips -- $18.85 is cost of shipping for IPS
        FROM costing.updatedpandl AS pandl
        LEFT JOIN ${kit_usage.SQL_TABLE_NAME} AS kit ON kit.month = pandl.month
        LEFT JOIN ${samples_accessioned.SQL_TABLE_NAME} AS sampacc ON sampacc.month = pandl.month
        WHERE pandl.gl_account = '5011 - Outbound Freight (Kits)' OR pandl.gl_account = '5012 - Inbound Freight (Kits)') AS sub
       ;;
    sql_trigger_value: select current_date ;;
    indexes: ["month", "gl_account"]
  }
}

## takes the lab_inventory allocations as a percent of total and applies those percentages for each product to 5003 - Inventory Freight/Taxes

view: inventory_freight_tax {
  derived_table: {
    sql: SELECT
        pandl.month
        , gl_account
        , category
        , rev_exp_id
        , rev_exp_name
        , variable_fixed_id
        , variable_fixed_name
        , sub_headers_id
        , sub_headers
        , fps1_allocation * amount AS fps1
        , fps2_allocation * amount AS fps2
        , ics_allocation * amount AS ics
        , ips_allocation * amount AS ips
      FROM costing.updatedpandl AS pandl
      LEFT JOIN (
        SELECT
          month
          , 1.0 * fps1 / (fps1 + fps2 + ics + ips) AS fps1_allocation
          , 1.0 * fps2 / (fps1 + fps2 + ics + ips) AS fps2_allocation
          , 1.0 * ics / (fps1 + fps2 + ics + ips) AS ics_allocation
          , 1.0 * ips / (fps1 + fps2 + ics + ips) AS ips_allocation
        FROM ${cost_of_sales.SQL_TABLE_NAME} AS cos
        WHERE gl_account = '5001 - Lab Inventory') AS lab_inv_allocation on lab_inv_allocation.month = pandl.month
      WHERE pandl.gl_account = '5003 - Inventory Freight/Taxes'
       ;;
    sql_trigger_value: select current_date ;;
    indexes: ["month", "gl_account"]
  }
}

## Simple allocation of GC cost related accounts based on product mix for GC call volume.

explore: gc_call_log {}

view: gc_call_log {
  derived_table: {
    sql: SELECT
        month
        , fps1_calls
        , fps2_calls
        , ics_calls
        , ips_calls
        , total_calls
        , 1.0 * fps1_calls / total_calls AS percent_fps1
        , 1.0 * fps2_calls / total_calls AS percent_fps2
        , 1.0 * ics_calls / total_calls AS percent_ics
        , 1.0 * ips_calls / total_calls AS percent_ips
      FROM (
        SELECT
          month
          , fps1_calls
          , fps2_calls
          , ics_calls
          , ips_calls
          , coalesce(fps1_calls,0) + coalesce(fps2_calls,0) + coalesce(ics_calls,0) + coalesce(ips_calls,0) AS total_calls
        FROM costing.gccalllog) AS sub
       ;;
  }

  dimension: fps1_calls {
    type: number
    sql: ${TABLE}.fps1_calls ;;
  }

  dimension: fps2_calls {
    type: number
    sql: ${TABLE}.fps2_calls ;;
  }

  dimension: ics_calls {
    type: number
    sql: ${TABLE}.ics_calls ;;
  }

  dimension: ips_calls {
    type: number
    sql: ${TABLE}.ips_calls ;;
  }

  dimension: total_calls {
    type: number
    sql: ${TABLE}.total_calls ;;
  }

  dimension: percent_fps1 {
    type: number
    value_format: "0.00\%"
    sql: ${TABLE}.percent_fps1 ;;
  }

  dimension: percent_fps2 {
    type: number
    value_format: "0.00\%"
    sql: ${TABLE}.percent_fps2 ;;
  }

  dimension: percent_ics {
    type: number
    value_format: "0.00\%"
    sql: ${TABLE}.percent_ics ;;
  }

  dimension: percent_ips {
    type: number
    value_format: "0.00\%"
    sql: ${TABLE}.percent_ips ;;
  }

  dimension_group: month {
    type: time
    timeframes: [date, week, month]
    convert_tz: no
    sql: ${TABLE}.month ;;
  }

  measure: count {
    type: count
    drill_fields: []
  }
}

## kit_usage takes the counts of different test kits and derives a few percentages and totals
## that are used in various parts COGs

explore: kit_usage {}

view: kit_usage {
  derived_table: {
    sql: SELECT
        kitusage.month
        , blood_kit_cost
        , saliva_kit_cost
        , ips_kit_cost
        , coalesce(blood_kit_cost,0) + coalesce(ips_kit_cost,0) + coalesce(saliva_kit_cost,0) AS total_kit_cost
        , blood_kit_count
        , saliva_kit_count
        , ips_kit_count
        , coalesce(blood_kit_count,0) + coalesce(ips_kit_count,0) + coalesce(saliva_kit_count,0) AS total_kit_count
        , 1.0 * coalesce(blood_kit_cost,0)* samplesaccessioned.fps_blood_percent * samplesran.fps1_percent AS fps1_blood_cost
        , 1.0 * coalesce(blood_kit_cost,0) * samplesaccessioned.fps_blood_percent * samplesran.fps2_percent AS fps2_blood_cost
        , 1.0 * coalesce(blood_kit_cost,0) * samplesaccessioned.ics_blood_percent AS ics_blood_cost
        , 1.0 * coalesce(saliva_kit_cost,0) * samplesaccessioned.fps_saliva_percent * samplesran.fps1_percent AS fps1_saliva_cost
        , 1.0 * coalesce(saliva_kit_cost,0) * samplesaccessioned.fps_saliva_percent * samplesran.fps2_percent AS fps2_saliva_cost
        , 1.0 * coalesce(saliva_kit_cost,0) * samplesaccessioned.ics_saliva_percent AS ics_saliva_cost
        , 1.0 * coalesce(blood_kit_count,0) / (coalesce(blood_kit_count,0) + coalesce(ips_kit_count,0) + coalesce(saliva_kit_count,0)) AS blood_kit_percent
        , 1.0 * coalesce(saliva_kit_count,0) / (coalesce(blood_kit_count,0) + coalesce(ips_kit_count,0) + coalesce(saliva_kit_count,0)) AS saliva_kit_percent
        , 1.0 * coalesce(ips_kit_count,0) / (coalesce(blood_kit_count,0) + coalesce(ips_kit_count,0) + coalesce(saliva_kit_count,0)) AS ips_kit_percent
      FROM costing.kitusage
      LEFT JOIN
        ${samples_ran.SQL_TABLE_NAME} AS samplesran ON samplesran.month = kitusage.month
      LEFT JOIN
        ${samples_accessioned.SQL_TABLE_NAME} AS samplesaccessioned ON samplesaccessioned.month = kitusage.month
       ;;
    sql_trigger_value: select sum(total_kit_cost) + sum(total_kit_count) from ${kit_usage.SQL_TABLE_NAME} ;;
    indexes: ["month"]
  }

  dimension: blood_kit_cost {
    type: number
    value_format_name: usd
    sql: ${TABLE}.blood_kit_cost ;;
  }

  dimension: blood_kit_percent {
    type: number
    sql: ${TABLE}.blood_kit_percent ;;
  }

  dimension: fps1_blood_cost {
    type: number
    value_format_name: usd
    sql: ${TABLE}.fps1_blood_cost ;;
  }

  dimension: fps2_blood_cost {
    type: number
    value_format_name: usd
    sql: ${TABLE}.fps2_blood_cost ;;
  }

  dimension: ics_blood_cost {
    type: number
    value_format_name: usd
    sql: ${TABLE}.ics_blood_cost ;;
  }

  dimension: fps1_saliva_cost {
    type: number
    value_format_name: usd
    sql: ${TABLE}.fps1_saliva_cost ;;
  }

  dimension: fps2_saliva_cost {
    type: number
    value_format_name: usd
    sql: ${TABLE}.fps2_saliva_cost ;;
  }

  dimension: ics_saliva_cost {
    type: number
    value_format_name: usd
    sql: ${TABLE}.ics_saliva_cost ;;
  }

  dimension: blood_kit_count {
    type: number
    sql: ${TABLE}.blood_kit_count ;;
  }

  dimension: ips_kit_cost {
    type: number
    value_format_name: usd
    sql: ${TABLE}.ips_kit_cost ;;
  }

  dimension: ips_kit_count {
    type: number
    sql: ${TABLE}.ips_kit_count ;;
  }

  dimension: total_kit_count {
    type: number
    sql: ${TABLE}.total_kit_count ;;
  }

  dimension: total_kit_cost {
    type: number
    value_format_name: usd
    sql: ${TABLE}.total_kit_cost ;;
  }

  dimension_group: month {
    type: time
    timeframes: [date, week, month]
    sql: ${TABLE}.month ;;
  }

  dimension: saliva_kit_cost {
    type: number
    value_format_name: usd
    sql: ${TABLE}.saliva_kit_cost ;;
  }

  dimension: saliva_kit_count {
    type: number
    sql: ${TABLE}.saliva_kit_count ;;
  }

  dimension: saliva_kit_percent {
    type: number
    sql: ${TABLE}.saliva_kit_percent ;;
  }

  dimension: ips_kit_percent {
    type: number
    sql: ${TABLE}.ips_kit_percent ;;
  }
}

## lab_inventory_variance is calculated in the workbook and plugged back into the cogs model to ensure that everything ties NS

explore: lab_inventory_variance {}

view: lab_inventory_variance {
  derived_table: {
    sql: SELECT
        sub.month
        , cogs
        , 1.0 * pandl.amount - cogs AS total_variance
      FROM (
        SELECT
          lab_inventory_cogs.month
          , SUM(coalesce(base,0)) + SUM(coalesce(rerun,0)) + SUM(coalesce(blood_extraction,0)) + SUM(coalesce(saliva_extraction,0)) + SUM(coalesce(fragilex,0)) + SUM(coalesce(sma,0)) AS cogs
        FROM ${lab_inventory_cost.SQL_TABLE_NAME} AS lab_inventory_cogs
        GROUP BY 1) AS sub
      INNER JOIN costing.updatedpandl AS pandl ON pandl.month = sub.month WHERE pandl.gl_account = '5001 - Lab Inventory'
       ;;
    sql_trigger_value: select current_date ;;
    indexes: ["month"]
  }

  dimension: month {
    type: date
    sql: ${TABLE}.month ;;
  }

  dimension: cogs {
    type: number
    sql: ${TABLE}.cogs ;;
  }

  dimension: total_variance {
    type: number
    sql: ${TABLE}.total_variance ;;
  }
}

## lab_inventory_totals sums up each component of testing across all products, the last section of the "Protocol Cost" tab in the Costing workbook.

explore: lab_inventory_totals {}

view: lab_inventory_totals {
  derived_table: {
    sql: SELECT
        lab_inventory_totals.month AS month
        , test
        , total_base
        , total_rerun
        , total_blood_ext
        , total_saliva_ext
        , total_fx
        , total_sma
        , 1.0 * total_base + total_rerun + total_blood_ext + total_saliva_ext + total_fx + total_sma AS total_cogs
      FROM (
        SELECT
          lab_inventory_cogs.month
          , test
          , SUM(coalesce(base,0)) AS total_base
          , SUM(coalesce(rerun,0)) AS total_rerun
          , SUM(coalesce(blood_extraction,0)) AS total_blood_ext
          , SUM(coalesce(saliva_extraction,0)) AS total_saliva_ext
          , SUM(coalesce(fragilex,0)) AS total_fx
          , SUM(coalesce(sma,0)) AS total_sma
        FROM ${lab_inventory_cost.SQL_TABLE_NAME} AS lab_inventory_cogs
        GROUP BY 1,2) AS lab_inventory_totals
       ;;
    sql_trigger_value: select current_date ;;
    indexes: ["month", "test"]
  }

  dimension: month {
    type: date
    sql: ${TABLE}.month ;;
  }

  dimension: test {
    type: string
    sql: ${TABLE}.test ;;
  }

  dimension: total_base {
    type: number
    sql: ${TABLE}.total_base ;;
  }

  dimension: total_rerun {
    type: number
    sql: ${TABLE}.total_rerun ;;
  }

  dimension: total_blood_ext {
    type: number
    sql: ${TABLE}.total_blood_ext ;;
  }

  dimension: total_saliva_ext {
    type: number
    sql: ${TABLE}.total_saliva_ext ;;
  }

  dimension: total_fx {
    type: number
    sql: ${TABLE}.total_fx ;;
  }

  dimension: total_sma {
    type: number
    sql: ${TABLE}.total_sma ;;
  }

  dimension: total_cogs {
    type: number
    sql: ${TABLE}.total_cogs ;;
  }
}

## lab_inventory_cost sums up the different components of running a test for a month, the section right below what protocol_costs is reproducing in the costing workbook.

explore: lab_inventory_cost {}

view: lab_inventory_cost {
  derived_table: {
    sql: SELECT
        test
        , CASE WHEN test IS NOT NULL THEN protocol_costs.month END AS month
        , SUM(CASE WHEN assay ~~* '%first_run' AND test IS NOT NULL THEN actual END) AS base
        , SUM(CASE WHEN (assay ~~* '%reprep_act' OR assay ~~* '%rerun') AND test IS NOT NULL THEN actual END) AS rerun
        , CASE
          WHEN test = 'fps1' THEN fps_blood_percent * fps1_percent * blood_extraction_base
          WHEN test = 'fps2' THEN fps_blood_percent * fps2_percent * blood_extraction_base
          WHEN test = 'ics' THEN ics_blood_percent * blood_extraction_base
          ELSE null END AS blood_extraction
      , CASE
          WHEN test = 'fps1' THEN fps_saliva_percent * fps1_percent * saliva_extraction_base
          WHEN test = 'fps2' THEN fps_saliva_percent * fps2_percent * saliva_extraction_base
          WHEN test = 'ics' THEN ics_saliva_percent * saliva_extraction_base
          ELSE null END AS saliva_extraction
      , CASE
          WHEN test = 'fps1' THEN fps1_percent * fragilex_base
          WHEN test = 'fps2' THEN fps2_percent * fragilex_base
          ELSE null END AS fragilex
      , CASE
          WHEN test = 'fps1' THEN fps1_percent * sma_base
          WHEN test = 'fps2' THEN fps2_percent * sma_base
          ELSE null END AS sma
      , SUM(CASE WHEN assay ~~* '%first_run' AND test IS NOT NULL THEN theoretical END) AS theoretical_base
      , SUM(CASE WHEN (assay ~~* '%rerun' OR assay ~~* '%reprep') AND test IS NOT NULL THEN theoretical END) AS theoretical_rerun
      FROM ${protocol_costs.SQL_TABLE_NAME} AS protocol_costs
      LEFT JOIN
        (SELECT
          month
          , SUM(CASE WHEN assay = 'Tecan blood extraction' OR assay = 'Qiasymphony blood 400' THEN actual END) AS blood_extraction_base
          , SUM(CASE WHEN assay = 'Qiasymphony saliva extraction' THEN actual END) AS saliva_extraction_base
          , SUM(CASE WHEN assay = 'FragileX V2 first_run' THEN actual END) AS fragilex_base
          , SUM(CASE WHEN assay = 'TaqMan SMA_v2 first_run' THEN actual END) AS sma_base
        FROM ${protocol_costs.SQL_TABLE_NAME} AS protocol_base
        GROUP BY 1) AS base ON base.month = protocol_costs.month
      LEFT JOIN ${samples_accessioned.SQL_TABLE_NAME} AS samples_accessioned ON samples_accessioned.month = protocol_costs.month
      LEFT JOIN ${samples_ran.SQL_TABLE_NAME} AS samples_ran ON samples_ran.month = protocol_costs.month
      GROUP BY 1,2,5,6,7,8
       ;;
    sql_trigger_value: sum(actual) FROM ${protocol_costs.SQL_TABLE_NAME} ;;
    indexes: ["month", "test"]
  }

  dimension: test {
    type: string
    sql: ${TABLE}.test ;;
  }

  dimension: month {
    type: date
    sql: ${TABLE}.month ;;
  }

  dimension: base {
    type: number
    sql: ${TABLE}.base ;;
  }

  dimension: rerun {
    type: number
    sql: ${TABLE}.rerun ;;
  }

  dimension: blood_extraction {
    type: number
    sql: ${TABLE}.blood_extraction ;;
  }

  dimension: saliva_extraction {
    type: number
    sql: ${TABLE}.saliva_extraction ;;
  }

  dimension: fragilex {
    type: number
    sql: ${TABLE}.fragilex ;;
  }

  dimension: sma {
    type: number
    sql: ${TABLE}.sma ;;
  }

  dimension: theoretical_base {
    type: number
    sql: ${TABLE}.theoretical_base ;;
  }

  dimension: theoretical_rerun {
    type: number
    sql: ${TABLE}.theoretical_rerun ;;
  }

  measure: actual_total_cost {
    type: sum
    sql: coalesce(${base},0) + coalesce(${rerun},0) + coalesce(${blood_extraction},0) + coalesce(${saliva_extraction},0) + coalesce(${fragilex},0) + coalesce(${sma},0) ;;
  }
}

## This recreates the top portion of: https://docs.google.com/spreadsheets/d/1sZf5jVAUEd4qj7EQLqQ4nw4xhnyb9NlpHGc0AEG2z9c/edit#gid=1394047678
## which shows the wells per batch, run count, cost per sample, actual and theoretical amounts for each assay.

view: protocol_costs {
  derived_table: {
    sql: SELECT
        test
        , protocol
        , assay
        , sub2.month
        , run_count
        , wells_per_batch
        , cost_per_sample
        , CASE
            WHEN assay = 'Tecan blood extraction'
              OR assay = 'Qiasymphony blood 400'
              OR assay = 'Qiasymphony saliva extraction'
              OR assay = 'FragileX V2 first_run'
              OR assay = 'TaqMan SMA_v2 first_run' THEN cost_per_sample * run_count
            WHEN assay = 'NIPS_v2 first_run' THEN ips_actual
            ELSE (89.0 / wells_per_batch * cost_per_sample) * run_count END AS actual
        , CASE
            WHEN assay = 'Tecan blood extraction'
              OR assay = 'Qiasymphony blood 400'
              OR assay = 'Qiasymphony saliva extraction'
              OR assay = 'FragileX V2 first_run'
              OR assay = 'TaqMan SMA_v2 first_run' THEN null
            WHEN assay = 'NIPS_v2 first_run' THEN ips_theoretical
            ELSE cost_per_sample * run_count END AS theoretical
      FROM (
        SELECT
          sub.test
          , sub.protocol
          , sub.assay
          , sub.month
          , sub.run_count
          , sub.wells_per_batch
          , -1.0 * SUM(CASE WHEN sub.run_count IS NOT NULL THEN protocol_build.cost_per_sample ELSE NULL END) AS cost_per_sample
        FROM (
          SELECT
            CASE
              WHEN assay_name ~~* 'LTC_v3 - HiSeq - 192 - LP_v%' THEN 'fps1'
              WHEN assay_name ~~* 'DTS_v%' THEN 'fps2'
              WHEN assay_name ~~* 'DTS_HC%' THEN 'ics'
              WHEN assay_name ~~* 'NIPS%' THEN 'ips' END AS test
            , CASE
                WHEN assay_name ~~* 'DTS_HC_v%' THEN 'DTS_HC_v2 - HiSeq'
                WHEN assay_name ~~* 'DTS_v1%' THEN 'DTS_v1 - HiSeq - LP_v2'
                WHEN assay_name ~~* 'DTS_v2%' THEN 'DTS_v2 - HiSeq'
                WHEN assay_name ~~* 'FragileX V2%' THEN 'FragileX V2'
                WHEN assay_name ~~* 'LTC_v3 - HiSeq - 192 - LP_v%' THEN 'LTC_v3 - HiSeq - 192 - LP_v2'
                WHEN assay_name ~~* 'Tecan blood extraction' THEN 'Lysis Plate Filling'
                WHEN assay_name ~~* 'NIPS_v%' THEN 'NIPS_v2'
                WHEN assay_name ~~* 'Qiasymphony blood 400' THEN 'QIAsymphony Blood 400 Extraction'
                WHEN assay_name ~~* 'Qiasymphony saliva extraction' THEN 'QIAsymphony Saliva Extraction'
                WHEN assay_name ~~* 'TaqMan SMA_v%' THEN 'TaqMan SMA_v2_r2' END AS protocol
                , assay_name AS assay
                , protocols_run.month AS month
                , run_count
                , wells_per_batch
          FROM costing.protocolsrun AS protocols_run
          LEFT JOIN costing.wellsperbatch AS wells_per_batch ON
            CASE WHEN protocols_run.assay_name = wells_per_batch.assay AND protocols_run.month = wells_per_batch.month THEN 1
            WHEN trim(trailing '_act' from protocols_run.assay_name) = wells_per_batch.assay AND protocols_run.month = wells_per_batch.month THEN 1
            ELSE 0 END = 1) AS sub
        LEFT JOIN ${protocol_build.SQL_TABLE_NAME} AS protocol_build ON protocol_build.protocol = sub.protocol AND protocol_build.month = sub.month
        GROUP BY 1,2,3,4,5,6) AS sub2
      LEFT JOIN costing.updatedipsactthe AS ipsactthe ON ipsactthe.month = sub2.month
       ;;
    sql_trigger_value: sum(run_count) FROM costing.protocolsrun ;;
    indexes: ["test", "protocol", "month"]
  }

  dimension: test {
    type: string
    sql: ${TABLE}.test ;;
  }

  dimension: protocol {
    type: string
    sql: ${TABLE}.protocol ;;
  }

  dimension: assay {
    type: string
    sql: ${TABLE}.assay ;;
  }

  dimension: month {
    type: date
    sql: ${TABLE}.month ;;
  }

  dimension: run_count {
    type: number
    sql: ${TABLE}.run_count ;;
  }

  dimension: wells_per_batch {
    type: number
    sql: ${TABLE}.wells_per_batch ;;
  }

  dimension: cost_per_sample {
    type: number
    sql: ${TABLE}.cost_per_sample ;;
  }

  dimension: actual {
    type: number
    sql: ${TABLE}.actual ;;
  }

  dimension: theoretical {
    type: number
    sql: ${TABLE}.theoretical ;;
  }
}

## protocol_build joins to protocolbuild upload and the itemcosts upload tables.
## This PDT contains a waterfall, wherein if there is no cost for an item, the calc falls back
## to the most recent month that has a cost for up to 12 months.

view: protocol_build {
  derived_table: {
    sql: SELECT
        order_number
        , month
        , protocol
        , samples
        , protocol_item
        , netsuite_item
        , bom
        , protocol_units_used
        , netsuite_units_used
        , units_per_sample
        , item_costs
        , 1.0 * units_per_sample * item_costs AS cost_per_sample
      FROM (
        SELECT
          order_number
          , month
          , protocol
          , samples
          , protocol_item
          , netsuite_item
          , bom
          , protocol_units_used
          , netsuite_units_used
          , 1.0 * coalesce(netsuite_units_used,0) / coalesce(samples,0) AS units_per_sample
          , CASE
              WHEN itemcosts.cost IS NOT NULL AND itemcosts.cost <> 0 THEN itemcosts.cost
              WHEN itemcosts.subcost1 IS NOT NULL AND itemcosts.subcost1 <> 0 THEN itemcosts.subcost1
              WHEN itemcosts.subcost2 IS NOT NULL AND itemcosts.subcost2 <> 0 THEN itemcosts.subcost2
              WHEN itemcosts.subcost3 IS NOT NULL AND itemcosts.subcost3 <> 0 THEN itemcosts.subcost3
              WHEN itemcosts.subcost4 IS NOT NULL AND itemcosts.subcost4 <> 0 THEN itemcosts.subcost4
              WHEN itemcosts.subcost5 IS NOT NULL AND itemcosts.subcost5 <> 0 THEN itemcosts.subcost5
              WHEN itemcosts.subcost6 IS NOT NULL AND itemcosts.subcost6 <> 0 THEN itemcosts.subcost6
              WHEN itemcosts.subcost7 IS NOT NULL AND itemcosts.subcost7 <> 0 THEN itemcosts.subcost7
              WHEN itemcosts.subcost8 IS NOT NULL AND itemcosts.subcost8 <> 0 THEN itemcosts.subcost8
              WHEN itemcosts.subcost9 IS NOT NULL AND itemcosts.subcost9 <> 0 THEN itemcosts.subcost9
              WHEN itemcosts.subcost10 IS NOT NULL AND itemcosts.subcost10 <> 0 THEN itemcosts.subcost10
              WHEN itemcosts.subcost11 IS NOT NULL AND itemcosts.subcost11 <> 0 THEN itemcosts.subcost11
              WHEN itemcosts.subcost12 IS NOT NULL AND itemcosts.subcost12 <> 0 THEN itemcosts.subcost12
              ELSE 0 END AS item_costs
        FROM costing.protocolbuild
        LEFT JOIN
          (SELECT
            itemcosts.item_number
            , itemcosts.display_name
            , itemcosts.month
            , itemcosts.cost
            , sub1.subcost AS subcost1
            , sub2.subcost AS subcost2
            , sub3.subcost AS subcost3
            , sub4.subcost AS subcost4
            , sub5.subcost AS subcost5
            , sub6.subcost AS subcost6
            , sub7.subcost AS subcost7
            , sub8.subcost AS subcost8
            , sub9.subcost AS subcost9
            , sub10.subcost AS subcost10
            , sub11.subcost AS subcost11
            , sub12.subcost AS subcost12
           FROM costing.itemcosts
           LEFT JOIN
            (SELECT
              item_number
              , display_name
              , TO_CHAR(month - INTERVAL '1 month', 'YYYY-MM-DD')::DATE AS month
              , cost AS subcost
              FROM costing.itemcosts) AS sub1 ON sub1.month = itemcosts.month AND sub1.item_number = itemcosts.item_number
            LEFT JOIN
              (SELECT
              item_number
              , display_name
              , TO_CHAR(month - INTERVAL '2 month', 'YYYY-MM-DD')::DATE AS month
              , cost AS subcost
              FROM costing.itemcosts) AS sub2 ON sub2.month = itemcosts.month AND sub2.item_number = itemcosts.item_number
            LEFT JOIN
              (SELECT
              item_number
              , display_name
              , TO_CHAR(month - INTERVAL '3 month', 'YYYY-MM-DD')::DATE AS month
              , cost AS subcost
              FROM costing.itemcosts) AS sub3 ON sub3.month = itemcosts.month AND sub3.item_number = itemcosts.item_number
            LEFT JOIN
              (SELECT
              item_number
              , display_name
              , TO_CHAR(month - INTERVAL '4 month', 'YYYY-MM-DD')::DATE AS month
              , cost AS subcost
              FROM costing.itemcosts) AS sub4 ON sub4.month = itemcosts.month AND sub4.item_number = itemcosts.item_number
            LEFT JOIN
              (SELECT
              item_number
              , display_name
              , TO_CHAR(month - INTERVAL '5 month', 'YYYY-MM-DD')::DATE AS month
              , cost AS subcost
              FROM costing.itemcosts) AS sub5 ON sub5.month = itemcosts.month AND sub5.item_number = itemcosts.item_number
            LEFT JOIN
              (SELECT
              item_number
              , display_name
              , TO_CHAR(month - INTERVAL '6 month', 'YYYY-MM-DD')::DATE AS month
              , cost AS subcost
              FROM costing.itemcosts) AS sub6 ON sub6.month = itemcosts.month AND sub6.item_number = itemcosts.item_number
            LEFT JOIN
              (SELECT
              item_number
              , display_name
              , TO_CHAR(month - INTERVAL '7 month', 'YYYY-MM-DD')::DATE AS month
              , cost AS subcost
              FROM costing.itemcosts) AS sub7 ON sub7.month = itemcosts.month AND sub7.item_number = itemcosts.item_number
            LEFT JOIN
              (SELECT
              item_number
              , display_name
              , TO_CHAR(month - INTERVAL '8 month', 'YYYY-MM-DD')::DATE AS month
              , cost AS subcost
              FROM costing.itemcosts) AS sub8 ON sub8.month = itemcosts.month AND sub8.item_number = itemcosts.item_number
            LEFT JOIN
              (SELECT
              item_number
              , display_name
              , TO_CHAR(month - INTERVAL '9 month', 'YYYY-MM-DD')::DATE AS month
              , cost AS subcost
              FROM costing.itemcosts) AS sub9 ON sub9.month = itemcosts.month AND sub9.item_number = itemcosts.item_number
            LEFT JOIN
              (SELECT
              item_number
              , display_name
              , TO_CHAR(month - INTERVAL '10 month', 'YYYY-MM-DD')::DATE AS month
              , cost AS subcost
              FROM costing.itemcosts) AS sub10 ON sub10.month = itemcosts.month AND sub10.item_number = itemcosts.item_number
            LEFT JOIN
              (SELECT
              item_number
              , display_name
              , TO_CHAR(month - INTERVAL '11 month', 'YYYY-MM-DD')::DATE AS month
              , cost AS subcost
              FROM costing.itemcosts) AS sub11 ON sub11.month = itemcosts.month AND sub11.item_number = itemcosts.item_number
            LEFT JOIN
              (SELECT
              item_number
              , display_name
              , TO_CHAR(month - INTERVAL '12 month', 'YYYY-MM-DD')::DATE AS month
              , cost AS subcost
              FROM costing.itemcosts) AS sub12 ON sub12.month = itemcosts.month AND sub12.item_number = itemcosts.item_number) AS itemcosts ON protocolbuild.item_name = itemcosts.item_number
        GROUP BY 1,2,3,4,5,6,7,8,9,11) AS subsub
       ;;
    sql_trigger_value: max(order_number) + sum(amount) FROM costing.protocolbuild LEFT JOIN costing.itemcosts ;;
    indexes: ["protocol"]
  }

  dimension: bom {
    type: yesno
    sql: ${TABLE}.bom ;;
  }

  dimension: month {
    type: date
    sql: ${TABLE}.month ;;
  }

  dimension: netsuite_item {
    type: string
    sql: ${TABLE}.netsuite_item ;;
  }

  dimension: netsuite_units_used {
    type: number
    sql: ${TABLE}.netsuite_units_used ;;
  }

  dimension: order_number {
    type: number
    sql: ${TABLE}.order_number ;;
  }

  dimension: protocol {
    type: string
    sql: ${TABLE}.protocol ;;
  }

  dimension: protocol_item {
    type: string
    sql: ${TABLE}.protocol_item ;;
  }

  dimension: protocol_units_used {
    type: number
    sql: ${TABLE}.protocol_units_used ;;
  }

  dimension: samples {
    type: number
    sql: ${TABLE}.samples ;;
  }

  dimension: item_costs {
    type: number
    value_format_name: usd
    sql: ${TABLE}.item_costs ;;
  }

  dimension: units_per_sample {
    type: number
    sql: ${TABLE}.units_per_sample ;;
  }

  dimension: cost_per_sample {
    type: number
    value_format_name: usd
    sql: ${TABLE}.cost_per_sample ;;
  }
}

## Final step of the COGs reclass takes the R&D cost components and volume from r_and_d and
## multiplies these out for the appropriate accounts, assigning them to the correct reclass account.


## - explore: reclass
view: reclass {
  derived_table: {
    sql: -- 8100 - reclass

      SELECT
        month
        , '8100 - Non-COGs OpEx'::text AS gl_account
        , 'Ordinary Income/Expense'::text AS category
        , 2 AS rev_exp_id
        , 'Cost of Sales'::text AS rev_exp_name
        , 4 AS variable_fixed_id
        , 'Overhead'::text AS variable_fixed_name
        , 8 AS sub_headers_id
        , 'Employee/Contractor Overheads' AS sub_headers
        , SUM(CASE WHEN test = 'fps1' THEN -1.0 * count * fps1_cpm ELSE 0 END) AS fps1
        , SUM(CASE WHEN test = 'fps2' THEN -1.0 * count * fps2_cpm ELSE 0 END) AS fps2
        , SUM(CASE WHEN test = 'ics' THEN -1.0 * count * ics_cpm ELSE 0 END) AS ics
        , SUM(CASE WHEN test = 'ips' THEN -1.0 * count * ips_cpm ELSE 0 END) AS ips
      FROM ${r_and_d.SQL_TABLE_NAME} AS RD
      WHERE account_number IN (5501, 5502, 5503, 5504, 5505, 5506, 8007, 8904, 8905)
      GROUP BY 1,2,3,4,5,6

      UNION

      -- 5121 - reclass


      SELECT
        month
        , '5121 - Direct Labor Lab - COGS Reclass'::text AS gl_account
        , 'Ordinary Income/Expense'::text AS category
        , 2 AS rev_exp_id
        , 'Cost of Sales'::text AS rev_exp_name
        , 3 AS variable_fixed_id
        , 'Labor'::text AS variable_fixed_name
        , 4 AS sub_headers_id
        , 'Direct Labor - Fulfillment'::text AS sub_headers
        , SUM(CASE WHEN test = 'fps1' THEN -1.0 * count * fps1_cpm ELSE 0 END) AS fps1
        , SUM(CASE WHEN test = 'fps2' THEN-1.0 * count * fps2_cpm ELSE 0 END) AS fps2
        , SUM(CASE WHEN test = 'ics' THEN -1.0 * count * ics_cpm ELSE 0 END) AS ics
        , SUM(CASE WHEN test = 'ips' THEN -1.0 * count * ips_cpm ELSE 0 END) AS ips
      FROM ${r_and_d.SQL_TABLE_NAME} AS RD
      WHERE account_number IN (5101, 5012, 5103 ,5104 ,5105 ,5106 ,5107, 5108)
      GROUP BY 1,2,3,4,5,6
       ;;
  }

  dimension_group: month {
    type: time
    timeframes: [month, year]
    sql: ${TABLE}.month ;;
  }

  dimension: gl_account {
    sql: ${TABLE}.gl_account ;;
  }

  dimension: category {
    sql: ${TABLE}.category ;;
  }

  dimension: rev_exp_name {
    sql: ${TABLE}.rev_exp_name ;;
  }

  dimension: variable_fixed_name {
    sql: ${TABLE}.variable_fixed_name ;;
  }

  dimension: sub_headers {
    sql: ${TABLE}.sub_headers ;;
  }

  dimension: fps1 {
    type: number
    sql: ${TABLE}.fps1 ;;
  }

  dimension: fps2 {
    type: number
    sql: ${TABLE}.fps2 ;;
  }

  dimension: ics {
    type: number
    sql: ${TABLE}.ics ;;
  }

  dimension: ips {
    type: number
    sql: ${TABLE}.ips ;;
  }
}

## r_and_d takes the non-production volume costing.randd and JOINs it to the cost_per_test PDT
## Because the previous month's cost_per_test is applied to the current month's R&D volume,
## you see the month + INTERVAL '1 month' on the JOINing field.

explore: r_and_d {}

view: r_and_d {
  derived_table: {
    sql: SELECT
        month
        , CASE
            WHEN assay ~~* 'LTC_v3 - HiSeq - 192 - LP_v%' THEN 'fps1'
            WHEN assay ~~* 'DTS_v%' THEN 'fps2'
            WHEN assay ~~* 'DTS_HC%' THEN 'ics'
            WHEN assay ~~* 'NIPS%' THEN 'ips' END AS test
        , account_number
        , fps1_cpm
        , fps2_cpm
        , ics_cpm
        , ips_cpm
        , SUM(count) AS count
      FROM costing.randd
      LEFT JOIN (
        SELECT
          TO_CHAR(month + INTERVAL '1 month', 'YYYY-MM-DD')::DATE AS prior_month
          , gl_account
          , category
          , rev_exp_id
          , rev_exp_name
          , variable_fixed_id
          , variable_fixed_name
          , sub_headers_id
          , sub_headers
          , fps1_cpm
          , fps2_cpm
          , ics_cpm
          , ips_cpm
        FROM ${cost_per_test.SQL_TABLE_NAME}) AS cpt ON cpt.prior_month = randd.month
      INNER JOIN costing.calcassignments AS calc ON calc.account_name = cpt.gl_account
      GROUP BY 1,2,3,4,5,6,7
       ;;
    sql_trigger_value: select current_date ;;
    indexes: ["month", "test", "account_number"]
  }

  dimension: test {
    type: string
    sql: ${TABLE}.test ;;
  }

  dimension: month {
    type: date
    sql: ${TABLE}.month ;;
  }

  dimension: count {
    sql: ${TABLE}.count ;;
  }

  dimension: account_number {
    type: number
    sql: ${TABLE}.account_number ;;
  }

  dimension: fps1_cpm {
    type: number
    sql: ${TABLE}.fps1_cpm ;;
  }

  dimension: fps2_cpm {
    type: number
    sql: ${TABLE}.fps2_cpm ;;
  }

  dimension: ics_cpm {
    type: number
    sql: ${TABLE}.ics_cpm ;;
  }

  dimension: ips_cpm {
    type: number
    sql: ${TABLE}.ips_cpm ;;
  }
}

## cost_per_test takes the accounts in the cost_of_sales PDT and divides the product allocation
## by the test complete for that product, each month to get the cost per for that month (cpm)

## - explore: cost_per_test
view: cost_per_test {
  derived_table: {
    sql: SELECT
        cos.month
        , gl_account
        , category
        , rev_exp_id
        , rev_exp_name
        , variable_fixed_id
        , variable_fixed_name
        , sub_headers_id
        , sub_headers
        , 1.0 * fps1 / fps1_complete AS fps1_cpm
        , 1.0 * fps2/ fps2_complete AS fps2_cpm
        , 1.0 * ics / ics_complete AS ics_cpm
        , 1.0 * ips / ips_complete AS ips_cpm
      FROM ${cost_of_sales.SQL_TABLE_NAME} AS cos
      INNER JOIN ${test_per_month.SQL_TABLE_NAME} AS tpm on cos.month = tpm.month
       ;;
    sql_trigger_value: select current_date ;;
    indexes: ["month", "gl_account"]
  }

  dimension_group: month {
    type: time
    timeframes: [month, quarter, year]
    sql: ${TABLE}.month ;;
  }

  dimension: gl_account {
    type: string
    sql: ${TABLE}.gl_account ;;
  }

  dimension: category {
    type: string
    sql: ${TABLE}.category ;;
  }

  dimension: rev_exp_name {
    type: string
    sql: ${TABLE}.rev_exp_name ;;
  }

  dimension: variable_fixed_name {
    type: string
    sql: ${TABLE}.variable_fixed_name ;;
  }

  dimension: sub_headers {
    type: string
    sql: ${TABLE}.sub_headers ;;
  }

  measure: fps1_cpm {
    type: sum
    sql: ${TABLE}.fps1_cpm ;;
  }

  measure: fps2_cpm {
    type: sum
    sql: ${TABLE}.fps2_cpm ;;
  }

  measure: ics_cpm {
    type: sum
    sql: ${TABLE}.ics_cpm ;;
  }

  measure: ips_cpm {
    type: sum
    sql: ${TABLE}.ips_cpm ;;
  }
}

## test_per_month computes test complete volume to be used as the denominator in the cost_per_test calculation.

explore: test_per_month {}

view: test_per_month {
  derived_table: {
    sql: SELECT
        TO_DATE(EXTRACT(year from completed_on)::text || '-' || EXTRACT(month from completed_on)::text, 'YYYY-MM') AS month
        , COUNT(CASE WHEN gaoc_reqs.barcode is null AND "order".product = 'Family Prep Screen' AND "order".testing_methodology = 0 THEN latest_barcode END) AS fps1_complete
        , COUNT(CASE WHEN gaoc_reqs.barcode is null AND "order".product = 'Family Prep Screen' AND "order".testing_methodology = 1 THEN latest_barcode END) AS fps2_complete
        , COUNT(CASE WHEN gaoc_reqs.barcode is null AND "order".product = 'Inherited Cancer Screen' THEN latest_barcode END) AS ics_complete
        , COUNT(CASE WHEN gaoc_reqs.barcode is null AND "order".product = 'Informed Pregnancy Screen' THEN latest_barcode END) AS ips_complete
      FROM current.order
      LEFT JOIN uploads.gaoc_reqs on uploads.gaoc_reqs.barcode = current.order.latest_barcode
      GROUP BY 1
       ;;
    sql_trigger_value: select current_date ;;
    indexes: ["month"]
  }

  dimension: month {
    type: date
    sql: ${TABLE}.month ;;
  }

  dimension: fps1_complete {
    sql: ${TABLE}.fps1_complete ;;
  }

  dimension: fps2_complete {
    sql: ${TABLE}.fps2_complete ;;
  }

  dimension: ics_complete {
    sql: ${TABLE}.ics_complete ;;
  }

  dimension: ips_complete {
    sql: ${TABLE}.ips_complete ;;
  }
}
## The complete royalty calculations requires many views that are housed in the "Counsyl" project
## and necessitate maintaining an upload for previous period calculations. For the time being,
## the calculation will be completed in Excel and the amount booked to the GL will be allocated
## to each product.


view: ips_royalties {
  derived_table: {
    sql: SELECT
        pandl.month
        , CASE
          WHEN inhouse_count < 50001 THEN inhouse_count * 90
          WHEN inhouse_count < 100001 THEN inhouse_count * 80
          WHEN inhouse_count < 300001 THEN inhouse_count * 75
          ELSE inhouse_count * 65 END AS royalty
        , (ips_count - inhouse_count) * 475 AS ny_royalty
      FROM costing.updatedpandl AS pandl
      INNER JOIN costing.samplesran AS samplesran ON pandl.month = samplesran.month
       ;;
  }
}

## samples_accessioned takes the counts of different tests run and derives a few percentages
## that are used in various parts COGs

explore: samples_accessioned {}

view: samples_accessioned {
  derived_table: {
    sql: SELECT
        samplesaccessioned.month
        , fps_blood_count
        , fps_saliva_count
        , ics_blood_count
        , ics_saliva_count
        , ips_blood_count
        , coalesce(fps_blood_count,0) + coalesce(fps_saliva_count,0) + coalesce(ics_blood_count,0) + coalesce(ics_saliva_count+ips_blood_count,0) AS total_count
        , 1.0 * coalesce(fps_blood_count,0) / (coalesce(fps_blood_count,0) + coalesce(ics_blood_count,0)) AS fps_blood_percent
        , 1.0 * coalesce(ics_blood_count,0) / (coalesce(fps_blood_count,0) + coalesce(ics_blood_count,0)) AS ics_blood_percent
        , 1.0 * coalesce(fps_saliva_count,0) / (coalesce(fps_saliva_count,0) + coalesce(ics_saliva_count,0)) AS fps_saliva_percent
        , 1.0 * coalesce(ics_saliva_count,0) / (coalesce(fps_saliva_count,0) + coalesce(ics_saliva_count,0)) AS ics_saliva_percent
        , 1.0 * coalesce(fps_blood_count,0) / (coalesce(fps_blood_count,0) + coalesce(ics_blood_count+ips_blood_count,0)) AS fps_blood_percent_w_ips
        , 1.0 * coalesce(ics_blood_count,0) / (coalesce(fps_blood_count,0) + coalesce(ics_blood_count+ips_blood_count,0)) AS ics_blood_percent_w_ips
        , 1.0 * coalesce(ips_blood_count,0) / (coalesce(fps_blood_count,0) + coalesce(ics_blood_count+ips_blood_count,0)) AS ips_blood_percent_w_ips
        , 1.0 * samplesran.fps1_percent*((coalesce(fps_blood_count,0) + coalesce(fps_saliva_count,0)) / (coalesce(fps_blood_count,0) + coalesce(fps_saliva_count,0) + coalesce(ics_blood_count,0) + coalesce(ics_saliva_count,0))) AS fps1_percent_both_wo_ips
        , 1.0 * samplesran.fps2_percent*((coalesce(fps_blood_count,0) + coalesce(fps_saliva_count,0)) / (coalesce(fps_blood_count,0) + coalesce(fps_saliva_count,0) + coalesce(ics_blood_count,0) + coalesce(ics_saliva_count,0))) AS fps2_percent_both_wo_ips
        , 1.0 * (ics_blood_count+ics_saliva_count)/(fps_blood_count+fps_saliva_count+ics_blood_count+ics_saliva_count) AS ics_percent_both_wo_ips
      FROM costing.samplesaccessioned
      LEFT JOIN
        ${samples_ran.SQL_TABLE_NAME} AS samplesran ON samplesran.month = samplesaccessioned.month
       ;;
    sql_trigger_value: select sum(total_count) from ${samples_accessioned.SQL_TABLE_NAME} ;;
    indexes: ["month"]
  }

  dimension: fps_blood_count {
    type: number
    sql: ${TABLE}.fps_blood_count ;;
  }

  dimension: fps_saliva_count {
    type: number
    sql: ${TABLE}.fps_saliva_count ;;
  }

  dimension: ics_blood_count {
    type: number
    sql: ${TABLE}.ics_blood_count ;;
  }

  dimension: ics_saliva_count {
    type: number
    sql: ${TABLE}.ics_saliva_count ;;
  }

  dimension: ips_blood_count {
    type: number
    sql: ${TABLE}.ips_blood_count ;;
  }

  dimension: total_count {
    type: number
    sql: ${TABLE}.total_blood_count ;;
  }

  dimension_group: month {
    type: time
    timeframes: [date, week, month]
    sql: ${TABLE}.month ;;
  }

  dimension: fps_blood_percent {
    type: number
    sql: ${TABLE}.fps_blood_percent ;;
  }

  dimension: fps_saliva_percent {
    type: number
    sql: ${TABLE}.fps_saliva_percent ;;
  }

  dimension: ics_blood_percent {
    type: number
    sql: ${TABLE}.ics_blood_percent ;;
  }

  dimension: ics_saliva_percent {
    type: number
    sql: ${TABLE}.ics_saliva_percent ;;
  }

  dimension: fps_blood_percent_w_ips {
    type: number
    sql: ${TABLE}.fps_blood_percent_w_ips ;;
  }

  dimension: ics_blood_percent_w_ips {
    type: number
    sql: ${TABLE}.ics_blood_percent_w_ips ;;
  }

  dimension: ips_blood_percent_w_ips {
    type: number
    sql: ${TABLE}.ips_blood_percent_w_ips ;;
  }

  dimension: fps1_percent_both_wo_ips {
    type: number
    sql: ${TABLE}.fps1_percent_both_wo_ips ;;
  }

  dimension: fps2_percent_both_wo_ips {
    type: number
    sql: ${TABLE}.fps2_percent_both_wo_ips ;;
  }

  dimension: ics_percent_both_wo_ips {
    type: number
    sql: ${TABLE}.ics_percent_both_wo_ips ;;
  }
}

## samples_ran takes the counts of different tests run and derives a few percentages
## that are used in various parts COGs

explore: samples_ran {}

view: samples_ran {
  derived_table: {
    sql: SELECT
        month
        , fps1_count
        , fps2_count
        , ics_count
        , ips_count
        , inhouse_count
        , coalesce(fps1_count,0) + coalesce(fps2_count,0) + coalesce(ics_count,0) + coalesce(ips_count,0) AS total_count
        , 1.0 * coalesce(fps1_count,0) / (coalesce(fps2_count,0) + coalesce(fps1_count,0)) AS fps1_percent
        , 1.0 * coalesce(fps2_count,0) / (coalesce(fps2_count,0) + coalesce(fps1_count,0)) AS fps2_percent
        , 1.0 * coalesce(fps1_count,0) / (coalesce(fps1_count,0) + coalesce(fps2_count,0) + coalesce(ics_count,0) + coalesce(inhouse_count,0)) AS fps1_overall_percent
        , 1.0 * coalesce(fps2_count,0) / (coalesce(fps1_count,0) + coalesce(fps2_count,0) + coalesce(ics_count,0) + coalesce(inhouse_count,0)) AS fps2_overall_percent
        , 1.0 * coalesce(ics_count,0) / (coalesce(fps1_count,0) + coalesce(fps2_count,0) + coalesce(ics_count,0) + coalesce(inhouse_count,0)) AS ics_overall_percent
        , 1.0 * coalesce(inhouse_count,0) / (coalesce(fps1_count,0) + coalesce(fps2_count,0) + coalesce(ics_count,0) + coalesce(inhouse_count,0)) AS ips_overall_percent
        , 1.0 * coalesce(fps1_count,0) / (coalesce(fps1_count,0) + coalesce(fps2_count,0) + coalesce(ics_count,0) + coalesce(ips_count,0)) AS fps1_total_percent
        , 1.0 * coalesce(fps2_count,0) / (coalesce(fps1_count,0) + coalesce(fps2_count,0) + coalesce(ics_count,0) + coalesce(ips_count,0)) AS fps2_total_percent
        , 1.0 * coalesce(ics_count,0) / (coalesce(fps1_count,0) + coalesce(fps2_count,0) + coalesce(ics_count,0) + coalesce(ips_count,0)) AS ics_total_percent
        , 1.0 * coalesce(ips_count,0) / (coalesce(fps1_count,0) + coalesce(fps2_count,0) + coalesce(ics_count,0) + coalesce(ips_count,0)) AS ips_total_percent
        , 1.0 * coalesce(fps1_count,0) / (coalesce(fps1_count,0) + coalesce(fps2_count,0) + coalesce(ics_count,0)) AS fps1_stanford_percent
        , 1.0 * coalesce(fps2_count,0) / (coalesce(fps1_count,0) + coalesce(fps2_count,0) + coalesce(ics_count,0)) AS fps2_stanford_percent
        , 1.0 * coalesce(ics_count,0) / (coalesce(fps1_count,0) + coalesce(fps2_count,0) + coalesce(ics_count,0)) AS ics_stanford_percent
      FROM costing.samplesran
       ;;
    sql_trigger_value: select sum(total_count) from ${samples_ran.SQL_TABLE_NAME} ;;
    indexes: ["month"]
  }

  dimension: fps1_count {
    type: number
    sql: ${TABLE}.fps1_count ;;
  }

  dimension: fps2_count {
    type: number
    sql: ${TABLE}.fps2_count ;;
  }

  dimension: ics_count {
    type: number
    sql: ${TABLE}.ics_count ;;
  }

  dimension: inhouse_count {
    type: number
    sql: ${TABLE}.inhouse_count ;;
  }

  dimension: ips_count {
    type: number
    sql: ${TABLE}.ips_count ;;
  }

  dimension: total_count {
    type: number
    sql: ${TABLE}.total_count ;;
  }

  dimension_group: month {
    type: time
    timeframes: [date, week, month]
    sql: ${TABLE}.month ;;
  }

  dimension: fps1_percent {
    type: number
    value_format: "0.00\%"
    sql: ${TABLE}.fps1_percent ;;
  }

  dimension: fps2_percent {
    type: number
    value_format: "0.00\%"
    sql: ${TABLE}.fps2_percent ;;
  }

  dimension: fps1_overall_percent {
    type: number
    value_format: "0.00\%"
    sql: ${TABLE}.fps1_overall_percent ;;
  }

  dimension: fps2_overall_percent {
    type: number
    value_format: "0.00\%"
    sql: ${TABLE}.fps2_overall_percent ;;
  }

  dimension: ics_overall_percent {
    type: number
    value_format: "0.00\%"
    sql: ${TABLE}.ics_overall_percent ;;
  }

  dimension: ips_overall_percent {
    type: number
    value_format: "0.00\%"
    sql: ${TABLE}.ips_overall_percent ;;
  }

  dimension: fps1_total_percent {
    type: number
    value_format: "0.00\%"
    sql: ${TABLE}.fps1_total_percent ;;
  }

  dimension: fps2_total_percent {
    type: number
    value_format: "0.00\%"
    sql: ${TABLE}.fps2_total_percent ;;
  }

  dimension: ics_total_percent {
    type: number
    value_format: "0.00\%"
    sql: ${TABLE}.ics_total_percent ;;
  }

  dimension: ips_total_percent {
    type: number
    value_format: "0.00\%"
    sql: ${TABLE}.ips_total_percent ;;
  }
}
