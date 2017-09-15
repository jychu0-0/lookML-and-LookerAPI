
view: precuration_reclass_summary {
  derived_table: {
    sql:   SELECT
            DISTINCT ts.flow_id
            , CASE
              WHEN (ts.event_type = 'Submit') AND (ts.labels ILIKE '%Production%') AND (ts.product = 'family-prep-screen') THEN 'FPS Curated'
              WHEN (ts.event_type = 'Submit') AND (ts.labels ILIKE '%Production%') AND (ts.product = 'inherited-cancer-screen') THEN 'ICS Curated'
              WHEN (ts.event_type = 'Submit') AND (ts.labels ILIKE '%FPS Refresh Precuration%') THEN 'FPS PreCurated'
              WHEN (ts.event_type = 'Submit') AND (ts.labels ILIKE '%ICS Expansion%') THEN 'ICS PreCuration'
              WHEN (ts.event_type = 'Submit') AND ((ts.labels ILIKE '%Recuration%') AND (ts.labels NOT ILIKE '%precuration%' OR ts.labels IS NULL)) AND (ts.product = 'family-prep-screen') THEN 'FPS ReCurated'
              WHEN (ts.event_type = 'Submit') AND (ts.labels ILIKE '%Recuration%') AND (ts.product = 'inherited-cancer-screen') THEN 'ICS ReCurated'
              END AS reclass_status
            , max(event_time) AS event_date
            FROM public.ticket_stats AS ts
            GROUP BY 1,2;;
  }

  dimension_group: event_date {
    type: time
    timeframes: [time, date, week, month]
    sql: ${TABLE}.event_date ;;
  }

  dimension: reclass_status {
    type: string
    sql: ${TABLE}.reclass_status ;;
  }

  dimension: flow_id {
    type: string
    sql: ${TABLE}.flow_id ;;
  }

  measure: ticket_count {
    type:  count_distinct
    sql: ${TABLE}.flow_id ;;
  }

  measure: percent_of_total {
    type: percent_of_total
    sql: count(${reclass_status}) ;;
  }

}
