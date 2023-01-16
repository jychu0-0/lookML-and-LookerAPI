# Finance Lookback Freezing

## Step 1: Pull down local copy of the production Looker instance

 * Open Terminal and cd to your desktop:
   * `$ cd ~/Desktop`
 * Git Clone a local copy of the production Looker instance onto your desktop:
   * `$ git clone --bare https://github.counsyl.com/dev/looker.git`

## Step 2: Create Lookback repository in /analytics

 * Open [/analytics](https://github.counsyl.com/analytics) in your browser
 * Click `New Repository`
 * Name repository: `lookback_yyyy_mm_dd`, which should correspond to the dated schema you are freezing (i.e. `finance_export_20170203_0040`)
 * Repository is `Public`
 * Click `Create Repository`

## Step 3: Push local copy of production Looker instance into the new repository

 * In Terminal, cd into the new local copy of the Looker git folder:
   * `$ cd looker.git`
 * Git Push looker.git to new repository
   * `$ git push --mirror https://github.counsyl.com/analytics/new_repository_name.git` (replace `new_repository_name` with the name used above)

## Step 4: Configure new Looker Database Connection for the new Lookback Project

 * In [Looker Connections](https://looker.counsyl.com/admin/connections), edit the Connection you are going to replace:
   * We only maintain 3 months of active lookbacks, so look for the connection from 3 months ago
   * E.g. if today's freeze is for `2017_03_03`, find the connection for `2016_12_02`
   * Note: whatever connection you are updating, this will correspond to the project in Looker you will be deleting as well. Remember this.
   * Also note: **Always check with Robert Choye or Greg Simbro before deleting any lookbacks, as there may be a reason to keep any given lookback (i.e. End of Year or End of Quarter freezes)**
 * Now that you've confirmed with Finance:
   * Rename connection: `lookback_yyyy_mm_dd`
   * Set the `Schema` and `Temp Database` to the corresponding schema you are freezing (`finance_export_yyyymmdd_hhmm`)
   * Test Connection
   * Update Connection

## Step 5: Configure new LookML Project for the Lookback

 * In [Looker LookML Projects](https://looker.counsyl.com/projects), create a new project
 * Project Name: `lookback_yyyy_mm_dd`
 * New LookML
 * **UNCHECK Generate Model & Views**
 * Create Project

## Step 6: Configure Git for Lookback

 * Click `Configure Git` in new project
 * Enter Git URL to point Looker at the new Lookback Repository
   * `git@github.counsyl.com:analytics/lookback_yyyy_mm_dd.git`
 * Confirm Git Hosting Service as `Github Github/Enterprise`
 * Add Deploy Key to Github Repository
   * Copy the Deploy Key shown in Looker
   * Back in Github, navigate to Settings-->Deploy Keys-->Add Deploy Key
     * Paste the Deploy Key there
     * Name it `looker_key`
     * **Check Allow Write Access**
     * Add Key
 * Back in Looker, click `Continue Setup`
 * Click `Sync Developer Mode`
 * Access the `Project Settings` by clicking the arrow in the top left of the project panel (next to "Up to Date with Production", "Pull From Production" or "Commit Changes")
 * Under `Code Quality`, uncheck `Require LookML Validation to Commit`
 * Under `Github Integration`, select `Pull Requests Recommended`
   * Copy the webhook (`https://looker.counsyl.com/webhooks/projects/lookback_yyyy_mm_dd/deploy`)
   * `Update Project Settings`
   * Back in GitHub, Settings-->Hooks & Services-->Add Webhook
   * Paste webhook in `Payload URL`
   * **Disable SSL Verification** and accept the warning
     * We are not passing any actual data through the webhook, so SSL is not required--and SSL breaks the hook. Pending future fix!
   * Add webhook

## Step 7: Delete unnecessary LookML files from project (advanced...be careful)

 * Using GitHub Desktop, clone the new lookback repository to your Desktop
 * Create a new branch from master
 * Navigate to the repository folder in Finder
 * Search for "# Delete this file for freeze"--limit results to only that folder
 * Move all files that show up in search to Trash
 * Commit deleted files to your branch in GitHub Desktop
 * Create PR via GitHub Desktop
 * Merge PR in GitHub
 * Disconnect GitHub Desktop from project and delete the folder on your desktop

## Step 8: Schema Replacement & Model Configuration

 * Schema Replacement
   * Find " current." in project
   * Replace with " finance_export_yyyymmdd_hhmm."
   * **Note: you want to include the space preceding and the "." following here to avoid errant replacements**
 * Model Configuration
   * Delete all LookML Model files (e.g. `Production`, `sandbox`, etc.)
   * Add New Model File
     * Name: `lookback_yyyy_mm_dd`
     * LookML:

```
connection: "lookback_yyyy_mm_dd"

label: "Lookback_yyyy_mm_dd"

include: "*.view"       # include all the views
include: "*.dashboard"  # include all the dashboards
case_sensitive: no

datagroup: etl_refresh {
  sql_trigger: select * from current.finance_export_current_schema ;;
  max_cache_age: "12 hours"
}


explore: patient_refunds {}


explore: revenue_all_matched_transactions {
  join: bank_statement_deposits {
    sql_on: ${bank_statement_deposits.pkey} = ${revenue_all_matched_transactions.bank_pkey} ;;
    relationship: many_to_one
  }
}

explore: bank_statement_deposits {
  join: revenue_all_matched_transactions {
    sql_on: ${bank_statement_deposits.pkey} = ${revenue_all_matched_transactions.bank_pkey} ;;
    relationship: one_to_many
  }
}



explore: all_revenue {
  label: "All Revenue (New Method)"
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

explore: order_finance {
  view_label: "Order (Finance)"
  view_name: order

  join: booked_revenue_order_level {
    sql_on: ${booked_revenue_order_level.order_id} = ${order.id} ;;
    view_label: "Order Revenue (Do Not Use w/ Booked Revenue)"
    relationship: one_to_one
  }

  join: booked_revenue {
    sql_on: ${booked_revenue.order_id} = ${order.id} ;;
    relationship:  one_to_many
    view_label: "Booked Revenue (Do Not Use w/ Order Revenue)"
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

  join: claim_status_eob_payments {
    view_label: "Claim Dates"
    sql_on: ${claim.id} = ${claim_status_eob_payments.claim_id} ;;
    relationship: one_to_one
  }
  join: billing_in_network_contract_dates {
    sql_on: ${billing_in_network_contract_dates.payer_id} = ${claim.payer_id} ;;
    relationship: many_to_one
  }

  join: insurancepayer {
    sql_on: ${insurancepayer.id} = ${claim.payer_id} ;;
    relationship: many_to_one
  }

  join: revenue_all_matched_transactions {
    sql_on: ${revenue_all_matched_transactions.order_id} = ${order.id} ;;
    relationship: one_to_many
  }

  join: invoiceitem {
    view_label: "InvoiceItems"
    sql_on: ${invoiceitem.order_id} = ${order.id} ;;
    relationship: many_to_one
  }

  join: invoice {
    sql_on: ${invoice.invoice_number} = ${invoiceitem.invoice_number} ;;
    relationship: many_to_one
  }

  join: payment {
    view_label: "Payment Table Transactions"
    sql_on: ${payment.invoice_number} = ${invoice.invoice_number} ;;
    relationship: one_to_many
  }

  join: pricingestimate {
    sql_on: ${pricingestimate.claim_id} = ${claim.id} AND ${pricingestimate.is_current} = TRUE  ;;
    relationship: many_to_one
  }

  join: disease_count_in_panel {
    sql_on: ${disease_count_in_panel.diseasepanel_id} = ${order.diseasepanel_id} ;;
    relationship: many_to_one
  }

  join: billingpolicy {
    view_label: "Billing Policy"
    sql_on: ${claim.billing_policy_id} = ${billingpolicy.id} ;;
    relationship: many_to_one
  }

  join: notable_diagnoses {
    view_label: "Notable Diagnoses"
    sql_on: ${notable_diagnoses.order_id} = ${order.id} ;;
    relationship: one_to_one
  }

  join: patient_refunds {
    view_label: "Patient Refunds"
    sql_on: ${patient_refunds.invoice_id} = ${invoice.id} ;;
    relationship: many_to_one
  }

  join: eob {
    view_label: "EOB"
    sql_on: ${eob.claim_id} = ${claim.id} ;;
    relationship: one_to_many
  }

  join: eobbatch {
    view_label: "EOB Batch"
    sql_on: ${eobbatch.id} = ${eob.eob_batch_id} ;;
    relationship: many_to_one
  }

}
explore: outsourced_lab_fees {}
explore: revenue_charge_cap {}
```
**NOTE: Update connection & label to correct lookback reference**

## Step 9: Other Table Configurations
The following table need to be copied they are not automatically maintained in each finance export schema. Note that creating these frozen tables will return the following error, despite being executed correctly:
```
Error Running SQL
No results were returned by the query.
```

 * EOB No Duplicates Creation
   * In SQL runner:

```
CREATE OR REPLACE VIEW finance_export_yyyymmdd_hhmm.eob_no_duplicate_eob_batches AS
 SELECT eob.id,
    eob.status_code,
    eob.status_msg,
    eob.patient_responsibility,
    eob.charged,
    eob.paid,
    eob.allowed_amount,
    eob.date_claim_received,
    eob.date_processed_by_payer,
    eob.date_recorded,
    eob.last_process_date,
    eob.claim_id,
    eob.order_id,
    eob.profile_external_id,
    eob.retraction_of_id,
    eob.eob_batch_id
   FROM finance_export_yyymmdd_hhmm.eob
     JOIN finance_export_yyymmdd_hhmm.eobbatch ON eobbatch.id = eob.eob_batch_id
  WHERE eobbatch.duplicate_of_eob_batch_id IS NULL;
```
 * Accrued Consignment Accounts
   * In SQL runner:
```
CREATE TABLE uploads.accrued_consignment_clinics_yyyy_mm_dd_lookback AS TABLE uploads.accrued_consignment_clinics
```
   * Find `accrued_consignment_clinics` and replace with `accrued_consignment_clinics_yyyy_mm_dd_lookback`

 * Delinquent Accounts
   * In SQL runner:
```
CREATE TABLE uploads.delinquent_consignment_clinics_w_terminal_yyyy_mm_dd_lookback AS TABLE uploads.delinquent_consignment_clinics_w_terminal
```
   * Find `uploads.delinquent_consignment_clinics_w_terminal` and replace with `delinquent_consignment_clinics_w_terminal_yyyy_mm_dd_lookback`

 * In Network Dates
   * In SQL runner:
```
CREATE TABLE uploads.in_network_dates_w_terminal_yyyy_mm_dd_lookback AS TABLE uploads.in_network_dates_w_terminal
```
   * Find `uploads.in_network_dates_w_terminal` and replace with `in_network_dates_w_terminal_yyyy_mm_dd_lookback`

 * etc.

## Step 10: User Permissions

 * Add new lookback project to [Finance User: Lookbacks Model Set](https://looker.counsyl.com/admin/model_sets/5/edit)

## Step 11: Archive

 * Rename the `looker.git` folder that exists on your desktop (the original clone of production) to `yyyymmdd_logic_freeze.git`
 * Move it to [this folder in Google Drive](https://drive.google.com/drive/u/0/folders/0B1F2oEu48JHFR00yclJOZFdaeUU)

## Step 12: Delete Old LookML Project

 * Once you've confirmed with Robert Choye or Greg Simbro that the replaced lookback is no longer needed, delete the LookML project from [Looker LookML Projects](https://looker.counsyl.com/projects)
