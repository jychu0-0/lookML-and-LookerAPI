view: lockboxtransaction {
  derived_table: {
    sql: SELECT
      lbxtransaction.id AS id
      , account_number
      , batch_id
      , check_number
      , lbxtransaction.created_at
      , dollar_amount
      , lockbox_id
      FROM current.lockboxtransaction AS lbxtransaction
      INNER JOIN current.lockboxbatch AS lbxbatch ON lbxtransaction.batch_id = lbxbatch.id
      INNER JOIN current.lockboxlockboxrecord AS lbxlbxrecord ON lbxbatch.lockbox_record_id = lbxlbxrecord.id
       ;;
       datagroup_trigger: etl_refresh
    }

    dimension: id {
      primary_key: yes
      type: number
      sql: ${TABLE}.id ;;
    }

    dimension: account_number {
      type: string
      sql: ${TABLE}.account_number ;;
    }

    dimension: batch_id {
      type: number
      sql: ${TABLE}.batch_id ;;
    }

    dimension: check_number {
      type: string
      sql: ${TABLE}.check_number ;;
    }

    dimension_group: created {
      type: time
      timeframes: [time, date, week, month]
      sql: ${TABLE}.created_at ;;
    }

    dimension: dollar_amount {
      type: number
      sql: ${TABLE}.dollar_amount ;;
    }

    dimension: lockbox_id {
      type: number
      sql: ${TABLE}.lockbox_id ;;
    }
  }