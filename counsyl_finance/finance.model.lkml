connection: "finance_db_aws"


# views included
include: "general.*.view"
include: "billing.*.view"
include: "clinical.*.view"
include: "finance.*.view"



#so that explores here can extend those in production
include: "base.model.lkml"


# include all dashboards in this project
include: "*.dashboard"




label: "Finance"


case_sensitive: no

explore: patient_collections {}

explore: patient_collections_trend {}

explore: patient_collections_trend2 {}

explore: patient_collections_trend_no_tier {}

explore: patient_refunds {}



explore: bank_statement_deposits {
  join: revenue_all_matched_transactions {
    sql_on: ${bank_statement_deposits.pkey} = ${revenue_all_matched_transactions.bank_pkey} ;;
    relationship: one_to_many
  }

  join: order {
    sql_on: ${revenue_all_matched_transactions.order_id} = ${order.id} ;;
    relationship: many_to_one
    fields: [finance_bill_type, create_date, latest_barcode, id, order.product_name, order.completed_month, order.completed_quarter, completed_date, order.completed_year, order.bill_type, order.testing_methodology]
  }

  join: claim {
    sql_on: ${claim.order_id} = ${order.id} ;;
    relationship: many_to_one
    fields: [claim.network_status, cash_or_insurance, status_name]
  }

  join: ordering_clinic {
    sql_on: ${order.clinic_id} = ${ordering_clinic.id} ;;
    relationship: many_to_one
    fields: [id, name, region, country, city, state, outside_salesperson]
  }

  join: insurancepayer {
    sql_on: ${insurancepayer.id} = ${claim.payer_id} ;;
    relationship: many_to_one
    fields: [id, pretty_payer_name, name, gov_or_commercial, health_plan_family, is_gov_sponsored, payer_family]
  }

  join: billing_in_network_contract_dates {
    sql_on: ${billing_in_network_contract_dates.payer_id} = ${claim.payer_id} ;;
    relationship: many_to_one
    fields: []
  }
}

explore: pricingestimateaccruals {
  label: "All Revenue (Pricing Estimate Accrual Test)"
  description:  "POC for using pricing estimates as the driver for our revenue model"
  join: order {
    sql_on: ${pricingestimateaccruals.order_id} = ${order.id} ;;
    relationship: one_to_one
  }

  join: claim {
    sql_on: ${claim.order_id} = ${order.id} ;;
    relationship: many_to_one
  }

  join: insurancepayer {
    sql_on: ${insurancepayer.id} = ${claim.payer_id} ;;
    relationship: many_to_one
  }
}

explore: all_revenue {
  label: "All Revenue (New Revenue Standard)"
  description: "Used for querying on the recurring revenue model, and running some revenue analyses"
  join: order {
    sql_on: ${order.id} = ${all_revenue.order_id} ;;
    relationship: many_to_one
  }

  join: final_allowed {
    view_label: "Allowed Metrics"
    sql_on: ${order.id} = ${final_allowed.order_id} ;;
    relationship: one_to_one
  }

  join: ordering_clinic {
    sql_on: ${order.clinic_id} = ${ordering_clinic.id} ;;
    relationship: many_to_one
  }

  join: billing_clinic {
    sql_on: ${order.billing_clinic_id} = ${billing_clinic.id} ;;
    relationship: many_to_one
  }

  join: claim {
    sql_on: ${claim.order_id} = ${order.id} ;;
    relationship: many_to_one
  }

  join: billing_in_network_contract_dates {
    sql_on: ${billing_in_network_contract_dates.payer_id} = ${claim.payer_id} ;;
    relationship: many_to_one
  }

  join: claim_status_eob_payments {
    sql_on: ${claim.id} = ${claim_status_eob_payments.claim_id} ;;
    relationship: one_to_one
  }

  join: insurancepayer {
    sql_on: ${insurancepayer.id} = ${claim.payer_id} ;;
    relationship: many_to_one
  }
}

explore: rev_rec_booked_revenue {
  extends: [booked_revenue]
  label: "Booked Revenue"
  description: "Barcode level revenue based on revenue recognition date"
}

explore: order_level_booked_revenue {
  extends: [order_finance]
  label: "Order (Finance)"
  description: "The order table with revenue recognized on test complete date"
}

explore: percent_to_plan {
  view_name: percent_to_plan
  label: "Percent to Plan"
  description: "Count of completed orders as a percentage of forecasted orders"
}

explore: revenue_charge_cap {}

explore: eobbatchadjustment {
  label: "EOB Batch Adjustments"
  description: "All EOB Batch Adjustments"

  join: eobbatch {
    view_label: "eobbatch"
    sql_on: ${eobbatchadjustment.eob_batch_id} = ${eobbatch.id} ;;
    relationship: many_to_one
  }


}

explore: management_metrics {
  view_name: net_tests_created
}
explore: outsourced_lab_fees {}
explore: material_requirements_planning {}

explore: field_sales_expenses {}
explore: field_sales_volume {}
explore: field_sales_revenue {}
explore: field_sales_staff{}

explore: expense_summary {
  join: field_sales_staff {
    sql_on: ${expense_summary.employee_id} = ${field_sales_staff.employee_id} ;;
  }
}

explore: finance_asp {
  label:"Finance ASP"
}


# Delete this file for freeze
