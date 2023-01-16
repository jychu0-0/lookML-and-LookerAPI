view: transaction {
  sql_table_name: current.transaction ;;

  dimension: id {
    primary_key: yes
    type: number
    sql: ${TABLE}.id ;;
  }

  dimension_group: _creation_timestamp {
    type: time
    timeframes: [time, date, week, month]
    sql: ${TABLE}._creation_timestamp ;;
  }

  dimension_group: _posted_timestamp {
    type: time
    timeframes: [time, date, week, month]
    sql: ${TABLE}._posted_timestamp ;;
  }

  dimension: created_by_id {
    type: number
    sql: ${TABLE}.created_by_id ;;
  }

  dimension: finalized {
    type: yesno
    sql: ${TABLE}.finalized ;;
  }

  dimension: notes {
    type: string
    sql: ${TABLE}.notes ;;
  }

  dimension: transaction_id {
    type: string
    # hidden: true
    sql: ${TABLE}.transaction_id ;;
  }

  dimension: type {
    type: string
    sql: ${TABLE}.type ;;
  }

  dimension: voids_id {
    type: number
    sql: ${TABLE}.voids_id ;;
  }

  measure: count {
    type: count
    drill_fields: [detail*]
  }

  # ----- Sets of fields for drilling ------
  set: detail {
    fields: [id, transaction.id, ledgerentry.count, lr3y1isefp5i7a8bwsh40cf_match_lockbox_hybrid_file_trunc_ids.count, lr3y5a1xkjviemvof9ja9fe_transaction_file.count, lr3y7oajvltiw1rckhmho4e_consignment_comp.count, lr3yakrtn7jgj1rot3r5fuh_custom_hybrid_file.count, lr3yaufx03jpgkytckbv1z_matched_barcodes_04_consignment_wires.count, lr3ybe0pg3f4hgxm7jjzs1c_payment.count, lr3ybe3id088phqzmjknzkg_match_lockbox_hybrid_file_trunc_ids.count, lr3ybw6jy7kcdd7zom4twmb_transaction_file.count, lr3ydmim5ruepsa63jpccfh_custom_hybrid_file.count, lr3yfdggsbb3n88ung3ymz_payment.count, lr3yks4jpnrfgsdsbz97uqh_match_lockbox_hybrid_file_trunc_ids.count, lr3ylrx31nl0vm22suravib_matched_barcodes_04_consignment_wires.count, lr3yoh5evvq118a651r426b_custom_hybrid_file.count, lr3yoxb32uj8ik7c0rromcg_matched_barcodes_04_consignment_wires.count, lr3yxkv6um02ooww3zy875e_matched_barcodes_04_consignment_wires.count, payment.count, paymentgatewaytransfertransaction.count, transaction.count, transactionrelatedobject.count]
  }
}
