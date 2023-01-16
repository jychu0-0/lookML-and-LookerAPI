connection: "redacted"

include: "/2.Views/Salesforce/*.view.lkml"
include: "/2.Views/References/*.view.lkml"
include: "/2.Views/Platform/*.view.lkml"
include: "/2.Views/Marketo/*.view.lkml"

fiscal_month_offset: 1

explore: opportunity_snapshot {
  # aliased as Opportunity to avoid collision with above explore declaration
  label: "Opportunity Snapshot v2"
  group_label: "Salesforce"
  from: sf_opportunity
  fields: [ALL_FIELDS*,-opportunity_snapshot.carr_per_rep]
  # removed opportunity.carr_per_rep to avoid empty reference to the sf_opportunity_owner in the sf_opportunity_view
  always_filter: {
    filters: [snapshot_date.snapshot_date: "today"]
  }

  join: sf_opportunity_field_history {
    view_label: "Opportunity Snapshot History"
    type: left_outer
    relationship: one_to_many
    sql_on:
      ${opportunity_snapshot.id} = ${sf_opportunity_field_history.opportunity_id}
        AND ${snapshot_date.snapshot_date} BETWEEN ${sf_opportunity_field_history.start_date} AND ${sf_opportunity_field_history.end_date};;
  }

  join: snapshot_date {
    view_label: "Snapshot Dates"
    sql: RIGHT JOIN refs.date_ref AS snapshot_date ON 1=1 ;;
    relationship: many_to_many
  }

  join: sf_record_type {
    view_label:  "Opportunity Record Type"
    type: left_outer
    relationship: many_to_one
    sql_on: ${opportunity_snapshot.record_type_id} = ${sf_record_type.id} ;;
  }
}
