view: bank_statement_deposits {
  derived_table: {
    sql: SELECT
        coid::text
        , trn::text
        , account::text
        , bai_code::text
        , bank_ref::text
        , data_type::text
        , sum(deposit_amt) deposit_amt
        , deposit_date
        , description::text
        , text_desc::text
        , pkey::text
        , NULL::int as stripe_id
        , known_var
        , rev_trn
        , ref_pay::text
      FROM
        ${bank_statement.SQL_TABLE_NAME} as bank
      GROUP BY 1,2,3,4,5,6,8,9,10,11,12,13,14,15
      UNION
        SELECT
          coid::text
          , trn::text
          , account::text
          , bai_code::text
          , bank_ref::text
          , data_type::text
          , deposit_amt
          , deposit_date
          , description::text
          , text_desc::text
          , pkey::text
          , stripe_id::int
          , known_var
          , rev_trn
          , ref_pay::text
        FROM
          ${stripe_deposits.SQL_TABLE_NAME}
       ;;
    sql_trigger_value: select sum(trigger) from (select sum(deposit_amt) as trigger from ${stripe_deposits.SQL_TABLE_NAME} union all select sum(deposit_amt) as trigger from ${bank_statement.SQL_TABLE_NAME}) as t ;;

    indexes: ["account", "bai_code", "deposit_date"]
  }

  dimension: coid {
    type: string
    sql: ${TABLE}.coid ;;
  }

  dimension: account {
    sql: ${TABLE}.account ;;
  }

  dimension: trn {
    label: "Transaction ID"
    sql: ${TABLE}.trn ;;
  }

  dimension: bai_code {
    label: "BAI Code"
    type: string
    sql: ${TABLE}.bai_code ;;
  }

  dimension: data_type {
    sql: ${TABLE}.data_type ;;
  }

  dimension: description {
    sql: ${TABLE}.description ;;
  }
  dimension: bank_ref {
    sql: ${TABLE}.bank_ref ;;
  }
  dimension_group: deposit {
    type: time
    timeframes: [quarter, date, week, month, year]
    sql: ${TABLE}.deposit_date ;;
  }

  dimension: text_desc {
    sql: ${TABLE}.text_desc ;;
  }

  dimension: deposit_amount {
    type: number
    sql: ${TABLE}.deposit_amt ;;
  }

  measure: dep_amt {
    type: sum
    sql: ${deposit_amount} ;;
  }

  dimension: pkey {
    primary_key: yes
    sql: ${TABLE}.pkey ;;
  }

  dimension: known_var {
    type: yesno
    sql: ${TABLE}.known_var ;;
  }

  dimension: rev_trn {
    sql: ${TABLE}.rev_trn ;;
  }

  dimension: ref_pay {
    sql: ${TABLE}.ref_pay ;;
  }
}

view: bank_statement {
  derived_table: {
    sql: SELECT
        coid
        , CASE WHEN trim(leading '0' from trn) = '' THEN trn::text ELSE trim(trailing '!' from trim(leading '0' from trn))::text END as trn
        , account
        , bai_code
        , bank_ref
        , data_type
        , deposit_amt
        , deposit_date
        , description
        , text_desc
        , pkey::text
        , known_var
        , rev_trn
        , ref_pay
      FROM
        (SELECT
          CASE
            WHEN position('CO ID:' in text_desc) > 0
              THEN substring(text_desc from position('CO ID:' in text_desc) + 6 for position(' ' in substring(text_desc from position('CO ID:' in text_desc) + 6)))
            WHEN position('ch_' in text_desc) = 1
              THEN 'WFMSTRIPE1'
            WHEN bai_code::text = '115' and account::text != '1499186572'
              THEN account
            ELSE 'No COID' END as coid
          ,
          CASE WHEN source = 'uploads.bank_stmt' THEN
            CASE WHEN trim(leading '0' from text_desc) = '' THEN text_desc ELSE replace(trim(both ' ' from trim(leading '0' from trim(both '*' from
            CASE
              WHEN right(text_desc, 4) = 'RFB#'
                  THEN substring(text_desc from position('TRN#' in text_desc) + 4 for position('#' in substring(text_desc from position('TRN#' in text_desc) + 4)) - 1)
              WHEN position('36 TREAS 310 DES: MISC PAY ID:743238060360012' in text_desc) = 1
                THEN bank_ref
              WHEN bai_code::text = '195' and deposit_date >= '2015-10-01'
                THEN bank_ref
              WHEN position('HEALTH CARE AUTH' in text_desc) > 0
                THEN substring(text_desc from position('*1*' in text_desc) + 4 for position('*' in substring(text_desc from position('*1*' in text_desc) + 4)))
              WHEN position('HORIZON DES:TDU ACH PT ID:' in text_desc) > 0
                THEN substring(text_desc from position('PT ID:' in text_desc) + 11 for position(' ' in substring(text_desc from position('PT ID:' in text_desc) + 11)))
              WHEN position('RMR*IV*' in text_desc) > 0
                THEN substring(text_desc from position('RMR*IV*' in text_desc) + 7 for position('*' in substring(text_desc from position('RMR*IV*' in text_desc) + 7)))
              WHEN position('Medicaid-HCPF DES:HCCLAIMPMT ID:' in text_desc) > 0 and deposit_date < '2015-08-01'
                THEN substring(text_desc from position('ID:' in text_desc) + 8 for position(' ' in substring(text_desc from position('ID:' in text_desc) + 8)))
              WHEN position('Medicaid-HCPF DES:HCCLAIMPMT ID:' in text_desc) > 0 and deposit_date >= '2015-08-01'
                THEN substring(text_desc from position('TRN*1*TRN*1*' in text_desc) + 12 for position('*' in substring(text_desc from position('TRN*1*TRN*1*' in text_desc) + 12)))
              WHEN position('ET TRN:' in text_desc) > 0
                THEN substring(text_desc from position('ET TRN:' in text_desc) + 7 for position(' ' in substring(text_desc from position('ET TRN:' in text_desc) + 7)))



              WHEN position('TRN*1*PacificSource' in text_desc) > 0
                THEN substring(text_desc from position('TRN*1*PacificSource' in text_desc) + 19 for position('*' in substring(text_desc from position('TRN*1*PacificSource' in text_desc) + 19)))
              WHEN position('TRN*1*TRN*1*' in text_desc) > 0
                THEN substring(text_desc from position('TRN*1*TRN*1*' in text_desc) + 12 for position('*' in substring(text_desc from position('TRN*1*TRN*1*' in text_desc) + 12)))
              --WHEN position('\TRN*1*' in text_desc) > 0
                --THEN substring(text_desc from position('\TRN*' in text_desc) + 8 for position('\' in substring(text_desc from position('\TRN*' in text_desc) + 8)))
              WHEN position('TRN*1*' in text_desc) > 0
                THEN substring(text_desc from position('TRN*' in text_desc) + 6 for position('*' in substring(text_desc from position('TRN*' in text_desc) + 6)))
              WHEN position('TRN:*' in text_desc) > 0
                THEN substring(text_desc from position('TRN:*' in text_desc) + 7 for position('*' in substring(text_desc from position('TRN*' in text_desc) + 15)))



              WHEN bai_code::text = '115'
                THEN text_desc
              WHEN position('TRN1*' in text_desc) > 0
                THEN substring(text_desc from position('TRN1*' in text_desc) + 6 for position('*' in substring(text_desc from position('TRN1' in text_desc) + 6)))
              WHEN position('TRN1' in text_desc) > 0
                THEN substring(text_desc from position('TRN1' in text_desc) + 4 for position('*' in substring(text_desc from position('TRN1' in text_desc) + 4)))
              WHEN position('TRN*' in text_desc) > 0
                THEN substring(text_desc from position('TRN*' in text_desc) + 4 for position('*' in substring(text_desc from position('TRN*' in text_desc) + 4)))
              WHEN position('TRN|1|' in text_desc) > 0
                THEN substring(text_desc from position('TRN|' in text_desc) + 7 for position('|' in substring(text_desc from position('TRN|' in text_desc) + 8)))
              WHEN position('TRN02 = ' in text_desc) > 0
                THEN substring(text_desc from position('TRN02 = ' in text_desc) + 9 for position(' ' in substring(text_desc from position('TRN02 = ' in text_desc) + 9)))
              WHEN position('TRN# ' in text_desc) > 0
                THEN substring(text_desc from position('TRN# ' in text_desc) + 6 for position(' ' in substring(text_desc from position('TRN# ' in text_desc) + 6)))

              WHEN position('CCD PMT INFO:*1*' in text_desc) > 0 and substring(text_desc from 1 for 14) = 'BLUE SHIELD CA'
                THEN trim(trailing '0' from substring(text_desc from position('CCD PMT INFO:*1*' in text_desc) + 16 for position('-' in substring(text_desc from position('CCD PMT INFO:*1*' in text_desc) + 16))))
              WHEN position('CCD PMT INFO:*1*' in text_desc) > 0
                THEN substring(text_desc from position('CCD PMT INFO:*1*' in text_desc) + 16 for position('-' in substring(text_desc from position('CCD PMT INFO:*1*' in text_desc) + 16)))
              WHEN position('CCD PMT INFO:TRN*' in text_desc) > 0
                THEN substring(text_desc from position('CCD PMT INFO:TRN*' in text_desc) + 17 for position('*' in substring(text_desc from position('CCD PMT INFO:*' in text_desc) + 25)))
              WHEN position('CCD PMT INFO:*' in text_desc) > 0
                THEN substring(text_desc from position('CCD PMT INFO:*' in text_desc) + 14 for position('*' in substring(text_desc from position('CCD PMT INFO:*' in text_desc) + 14)))
              WHEN position('CCD PMT INFO:' in text_desc) > 0 and position('*' in substring(text_desc from position('CCD PMT INFO:*' in text_desc) + 14)) > 0
                THEN substring(text_desc from position('CCD PMT INFO:' in text_desc) + 14 for position('*' in substring(text_desc from position('PPD PMT INFO:*' in text_desc) + 14)))
              WHEN position('CCD PMT INFO:' in text_desc) > 0 and position(' ' in substring(text_desc from position('CCD PMT INFO:' in text_desc) + 14)) = 0
                THEN substr(text_desc, position('CCD PMT INFO:' in text_desc) + 14)







              WHEN position('ACH ID:' in text_desc) > 0
                THEN substring(text_desc from position('ACH ID:' in text_desc) + 7 for position(' ' in substring(text_desc from position('ACH ID:' in text_desc) + 7)))
              WHEN position('ACCTSPAY ID:' in text_desc) > 0
                THEN substring(text_desc from position('ACCTSPAY ID:' in text_desc) + 12 for position(' ' in substring(text_desc from position('ACCTSPAY ID:' in text_desc) + 12)))
              WHEN position('HCCLAIMPMT ID:' in text_desc) > 0
                THEN substring(text_desc from position('HCCLAIMPMT ID:' in text_desc) + 14 for position(' ' in substring(text_desc from position('HCCLAIMPMT ID:' in text_desc) + 14)))





              WHEN position('PPD PMT INFO:*' in text_desc) > 0
                THEN substring(text_desc from position('PPD PMT INFO:*' in text_desc) + 14 for position('*' in substring(text_desc from position('PPD PMT INFO:*' in text_desc) + 14)))
              WHEN position('TDU ACH PT ID:ACH' in text_desc) > 0
                THEN substring(text_desc from position('TDU ACH PT ID:ACH' in text_desc) + 19 for position(' ' in substring(text_desc from position('TDU ACH PT ID:ACH' in text_desc) + 19)))
              WHEN position('INSTAMED ID:' in text_desc) > 0
                THEN substring(text_desc from position('INSTAMED ID:' in text_desc) + 12 for position(' ' in substring(text_desc from position('INSTAMED ID:' in text_desc) + 12)))
              WHEN position('InstaMed DES:' in text_desc) > 0
                THEN substring(text_desc from 25 for 15)


              WHEN position('PT ID:PSET' in text_desc) > 0 and position('*' in substring(text_desc from position('PT ID:PSET' in text_desc) + 11)) > 0
                THEN substring(text_desc from position('PT ID:PSET' in text_desc) + 11 for position('*' in substring(text_desc from position('PT ID:PSET' in text_desc) + 11)))
              WHEN position('PT ID:PSET' in text_desc) > 0
                THEN substring(text_desc from position('PT ID:PSET' in text_desc) + 12 for position(' ' in substring(text_desc from position('PT ID:PSET' in text_desc) + 12)))


              WHEN position('ACHTRANS ID:' in text_desc) > 0
                THEN substring(text_desc from position('ACHTRANS ID:' in text_desc) + 12 for position(' ' in substring(text_desc from position('ACHTRANS ID:' in text_desc) + 4)))
              WHEN position('MISC PAY ID:' in text_desc) > 0
                THEN substring(text_desc from position('MISC PAY ID:' in text_desc) + 12 for position(' ' in substring(text_desc from position('MISC PAY ID:' in text_desc) + 12)))
              WHEN position('PAYMENT ID:' in text_desc) > 0
                THEN substring(text_desc from position('PAYMENT ID' in text_desc) + 11 for position(' ' in substring(text_desc from position('PAYMENT ID:' in text_desc) + 11)))
              WHEN position('EDI MISC ID:' in text_desc) > 0
                THEN substring(text_desc from position('EDI MISC ID:' in text_desc) + 12 for position(' ' in substring(text_desc from position('EDI MISC ID:' in text_desc) + 12)))
              WHEN position('REMITS ID:' in text_desc) > 0
                THEN substring(text_desc from position('REMITS ID:' in text_desc) + 10 for position(' ' in substring(text_desc from position('REMITS ID:' in text_desc) + 10)))
              WHEN position('CLAIMS PAY ID:' in text_desc) > 0
                THEN substring(text_desc from position('CLAIMS PAY ID:' in text_desc) + 14 for position(' ' in substring(text_desc from position('CLAIMS PAY ID:' in text_desc) + 14)))
              WHEN position('PAYMENTS ID:' in text_desc) > 0
                THEN substring(text_desc from position('PAYMENTS ID' in text_desc) + 12 for position(' ' in substring(text_desc from position('PAYMENTS ID:' in text_desc) + 12)))
              WHEN position('Claim Pymt ID:' in text_desc) > 0
                THEN substring(text_desc from position('Claim Pymt ID:' in text_desc) + 14 for position(' ' in substring(text_desc from position('Claim Pymt ID:' in text_desc) + 14)))


              WHEN position('AMERICAN EXPRESS SETTLEMENT' in text_desc) > 0
                THEN substring(text_desc from position('AMERICAN EXPRESS SETTLEMENT' in text_desc) + 28 for position(' ' in substring(text_desc from position('AMERICAN EXPRESS SETTLEMENT' in text_desc) + 4)))
              WHEN position('EC95B51 *' in text_desc) > 0
                THEN substring(text_desc from position('EC95B51 *' in text_desc) + 12 for position('*' in substring(text_desc from position('EC95b51' in text_desc) + 12)))
              WHEN position('EDI PYMNTS' in text_desc) > 0
                THEN substring(text_desc from position('EDI PYMNTS' in text_desc) + 11 for position(' ' in substring(text_desc from position('EDI PYMNTS' in text_desc) + 11)))
              WHEN position('PYMT NO = ' in text_desc) > 0
                THEN substr(text_desc, position('PYMT NO = ' in text_desc) + 10)
              WHEN position('BLUE SHIELD CA CLAIM PAY ' in text_desc) > 0
                THEN substring(text_desc from position('BLUE SHIELD CA CLAIM PAY ' in text_desc) + 26 for position(' ' in substring(text_desc from position('BLUE SHIELD CA CLAIM PAY ' in text_desc) + 26)))
              WHEN position('BLUE SHIELD CA BlueShield ' in text_desc) > 0
                THEN substring(text_desc from position('BLUE SHIELD CA BlueShield ' in text_desc) + 27 for position(' ' in substring(text_desc from position('BLUE SHIELD CA BlueShield ' in text_desc) + 27)))
              WHEN position('Blue Shield CA BlueShield ' in text_desc) > 0
                THEN substring(text_desc from position('Blue Shield CA BlueShield ' in text_desc) + 27 for position(' ' in substring(text_desc from position('Blue Shield CA BlueShield ' in text_desc) + 27)))
              WHEN position('NHPC INC CORP PYMNT ' in text_desc) > 0
                THEN substring(text_desc from position('NHPC INC CORP PYMNT ' in text_desc) + 21 for position(' ' in substring(text_desc from position('NHPC INC CORP PYMNT ' in text_desc) + 21)))
              WHEN position('PL DMS EFT ' in text_desc) > 0
                THEN substring(text_desc from position('PL DMS EFT ' in text_desc) + 11 for position(' ' in substring(text_desc from position('PL DMS EFT ' in text_desc) + 11)))
              WHEN position('00017556 ' in text_desc) > 0
                THEN substr(text_desc, position('00017556 ' in text_desc) + 10)
              WHEN position('00018049 ' in text_desc) > 0
                THEN substr(text_desc, position('00018049 ' in text_desc) + 10)
              WHEN position('00042733 ' in text_desc) > 0
                THEN substr(text_desc, position('00042733 ' in text_desc) + 10)
              WHEN position('PR6EE85CO EFT' in text_desc) > 0
                THEN substr(text_desc, position('PR6EE85CO EFT' in text_desc) + 14)
              WHEN position('SENTARA ' in text_desc) > 0
                THEN substring(text_desc from position('SENTARA ' in text_desc) + 9 for position(' ' in substring(text_desc from position('SENTARA ' in text_desc) + 9)))
              WHEN position('UHCGROUP PAYMENTS ' in text_desc) > 0
                THEN substring(text_desc from position('UHCGROUP PAYMENTS ' in text_desc) + 25 for position(' ' in substring(text_desc from position('UHCGROUP PAYMENTS ' in text_desc) + 25)))
              WHEN position('STATE OF MAINE ACCTSPAY ' in text_desc) > 0
                THEN substring(text_desc from position('STATE OF MAINE ACCTSPAY ' in text_desc) + 33 for position(' ' in substring(text_desc from position('STATE OF MAINE ACCTSPAY ' in text_desc) + 33)))
              WHEN position('ID:219252 ' in text_desc) > 0
                THEN substring(text_desc from position('ID:219252 ' in text_desc) + 11 for position(' ' in substring(text_desc from position('ID:219252 ' in text_desc) + 11)))
              WHEN position('CREDITS ' in text_desc) > 0
                THEN substring(text_desc from position('CREDITS ' in text_desc) + 9 for position(' ' in substring(text_desc from position('CREDITS ' in text_desc) + 9)))
              WHEN position('ch_' in text_desc) = 1
                THEN text_desc
              WHEN description = 'WF Authorize.net'
                THEN text_desc
              WHEN position('SHARP HEALTHCAR' in text_desc) = 1
                  THEN trim(trailing '-' from replace(substr(text_desc, position('INFO:' in text_desc) + 5 ),' ',''))
              WHEN position('NATERA' in text_desc) = 1
                THEN bank_ref
            ELSE text_desc END))),' ','') END
            ELSE

              --NEW LOGIC FOR HUNTER

              CASE
                WHEN position('DES:EDI PYMNTS ID:' in text_desc) > 0
                  THEN substring(text_desc from position('ID:' in text_desc) + 3 for 10)
                WHEN position('ST OF CONN' in text_desc) = 1
                  THEN concat('1190057121000358',substring(text_desc from position('TRN*1*' in text_desc) + 6 for 9))
                WHEN position('INSTAMED' in upper(text_desc)) = 1
                  THEN substring(text_desc from position('ID:' in text_desc) + 3 for 15)
                WHEN position('WA ST HCA' in text_desc) = 1
                  THEN concat(trim(trailing ' ' from trim(trailing '!' from substring(text_desc from position('TRN*1*' in text_desc) + 6 for 7))),'!')
                WHEN bai_code::text = '191'
                  THEN bank_ref
                WHEN left(replace(text_desc,' ',''),7) = '36TREAS'
                  THEN bank_ref
                WHEN position('SHARP HEALTHCAR' in text_desc) = 1
                  THEN trim(trailing '-' from replace(substr(text_desc, position('INFO:' in text_desc) + 5 ),' ',''))
                WHEN position('APACH ID' in text_desc) >0
                  THEN substring(text_desc from position('APACH ID' in text_desc) + 9 for 10)
                WHEN position('ASIA GENOMICS' in text_desc) > 0
                  THEN bank_ref
                WHEN position('AVALON' in text_desc) = 1
                  THEN concat('Avalon_',trim(leading '0' from substring(text_desc from position('TRN*1*' in text_desc) + 6 for 10)))
                WHEN account = '3301385741'
                  THEN concat('Progyny_',trim(leading '0' from text_desc))
                WHEN position('Harken Health' in text_desc) = 1
                  THEN substring(text_desc from position('TRN*' in text_desc) + 4 for position('*' in substring(text_desc from position('TRN*' in text_desc) + 4))-1)
                WHEN position('BEACON' in text_desc) = 1
                  THEN substring(text_desc from position('INFO:' in text_desc) + 5)

              --END NEW LOGIC FOR HUNTER

              ELSE reconciliation_key END END as trn
          , account
          , CASE
            WHEN description = 'WF Authorize.net'
              THEN 'WF Authorize.net' ELSE cast(bai_code as text) END as bai_code
          , bank_ref
          , data_type
          , deposit_amt
          , deposit_date
          , description
          , text_desc
          , bank.pkey
          , CASE
            WHEN position('Kaiser' in text_desc) != 0 or position('NATERA' in text_desc) != 0 or position('ENZO' in text_desc) != 0
              THEN TRUE
            WHEN account = '8800511761' or account = '4343921708' or account = '8800511704'
              THEN TRUE
            WHEN position('2014011500277840' in text_desc) > 0
              THEN TRUE
            ELSE FALSE
            END as known_var
          , CASE
            WHEN non.pkey is not null THEN 'Non-Revenue'
            WHEN gc.pkey is not null THEN 'GC Payment'
            WHEN bai_code is null and position('WT FED' in text_desc) + position('CLIENT ANALYSIS SRVC CHRG' in text_desc) + position('BILL PAYMENT RETURN' in text_desc) + position('BANKCARD CHARGEBACK' in text_desc) != 0
              THEN 'Non-Revenue'
            WHEN account = '10019297' and text_desc = '1148'
              THEN 'Non-Revenue'
            WHEN account = '108000079' or account = '39117601' or account = '3382587' or account = '182000000000' or account = '799816996' or bank.pkey = '684238'
              THEN 'Non-Revenue'
            WHEN bank.pkey = '693919' or bank.pkey = '697311' or bank.pkey = '697312' or bank.pkey = '697240' or bank.pkey = '109778'
              THEN 'Non-Revenue'
            ELSE 'Revenue'
            END as rev_trn
          , CASE WHEN position('Refund' in description) > 0 THEN 'Refund' ELSE 'Payment' END as ref_pay
        FROM ${all_bank_deposits.SQL_TABLE_NAME} as bank
        LEFT JOIN
          uploads.non_revenue_pkeys as non on non.pkey = bank.pkey
        LEFT JOIN
          uploads.gc_service_payments_pkeys as gc on gc.pkey = bank.pkey
        WHERE
        (position('Lockbox Deposit Credit' in description) != 1 or description is null)
        and position('STRIPE' in text_desc) != 1
        and position('BANKCARD' in text_desc) = 0
        and position('AMERICAN EXPRESS SETTLEMENT' in text_desc) = 0
        and bai_code::text != '475'
        and bai_code::text != '495'
        and bai_code::text != '661'
        and bai_code::text != '555'
        and bai_code::text != '699') as subquery
       ;;
    sql_trigger_value: select sum(trigger) from (select count(pkey) as trigger FROM ${all_bank_deposits.SQL_TABLE_NAME} UNION ALL SELECT count(pkey) as trigger from uploads.non_revenue_pkeys UNION ALL SELECT count(pkey) as trigger from uploads.gc_service_payments_pkeys) as t ;;
  }

  dimension: coid {
    type: string
    sql: ${TABLE}.coid ;;
  }

  dimension: account {
    sql: ${TABLE}.account ;;
  }

  dimension: trn {
    label: "Transaction ID"
    sql: ${TABLE}.trn ;;
  }

  dimension: bai_code {
    label: "BAI Code"
    type: string
    sql: ${TABLE}.bai_code ;;
  }

  dimension: data_type {
    sql: ${TABLE}.data_type ;;
  }

  dimension: description {
    sql: ${TABLE}.description ;;
  }

  dimension_group: deposit {
    type: time
    timeframes: [quarter, date, week, month, year]
    sql: ${TABLE}.deposit_date ;;
  }

  dimension: text_desc {
    sql: ${TABLE}.text_desc ;;
  }

  dimension: deposit_amount {
    type: number
    sql: ${TABLE}.deposit_amt ;;
  }

  measure: dep_amt {
    type: sum
    sql: ${deposit_amount} ;;
  }

  dimension: pkey {
    sql: ${TABLE}.pkey ;;
  }

  dimension: verafund_id {
    type: number
    sql: ${TABLE}.verafund_id ;;
  }

  dimension: known_var {
    type: yesno
    sql: ${TABLE}.known_var ;;
  }

  dimension: rev_trn {
    sql: ${TABLE}.rev_trn ;;
  }

  dimension: ref_pay {
    sql: ${TABLE}.ref_pay ;;
  }
}

view: all_bank_deposits {
  derived_table: {
    sql:
        SELECT
          deposit_date
          , currency
          , bank_id_type
          , bank_id
          , account
          , data_type
          , bai_code
          , description
          , deposit_amt
          , balance
          , customer_ref
          , immediate
          , one_day
          , two_day
          , bank_ref
          , text_desc
          , null AS reconciliation_key
          , 'uploads.bank_stmt' AS source
          , pkey::text
          FROM uploads.bank_stmt
          WHERE (deposit_date < '2016-01-01'::date AND account != '2')
            OR (deposit_date > '2016-01-01'::date AND
              (account = '2'
              OR description = 'Check Refund'))

        UNION

         SELECT

         (CASE WHEN credit_date < '2016-03-13' THEN credit_date AT TIME ZONE 'PST' ELSE credit_date END)::date AS deposit_date
         , null AS currency
         , null AS bank_id_type
         , null AS bank_id
         , account_number AS account
         , null AS data_type
         , '115' AS bai_code
         , 'Lockbox Items' AS description
         , dollar_amount AS deposit_amt
         , null AS balance
         , null AS customer_ref
         , null AS immediate
         , null AS one_day
         , null AS two_day
         , null AS bank_ref
         , check_number AS text_desc
         , check_number AS reconciliation_key
         , 'current.lockboxtransaction' AS source
         , 'current.lockboxtransaction'|| account_number::text || check_number::text AS pkey
         FROM current.lockboxtransaction
         LEFT JOIN current.lockboxbatch AS lockboxbatch ON lockboxbatch.id = lockboxtransaction.batch_id
         WHERE (credit_date AT TIME ZONE 'PST')::date >= '2016-01-01'::date

        UNION

         SELECT

         (depositgroup.as_of_datetime AT TIME ZONE 'PST')::date AS deposit_date
         , null AS currency
         , null AS bank_id_type
         , null AS bank_id
         , depositaccount.identifier::text AS account
         , null AS data_type
         , type_code AS bai_code
         , null AS description
         ,CASE
             WHEN deposittransaction.type_code = '115' THEN 0 --summaries of lockbox transaction'
             WHEN detail LIKE '%TRSF TO%' OR detail LIKE '%TRSF TO%' THEN 0 --indicated internal transfer
            --WHEN deposittransaction.type_code = '475' THEN -1.00*amount  --Check Paid, these $ should be exlcuded downstrean
            WHEN deposittransaction.type_code = '275' THEN 0  --ZBA Credit, these $ should be excluded downstream
            ELSE amount END AS deposit_amt
         , null AS balance
         , customer_reference::bigint AS customer_ref
         , null AS immediate
         , null AS one_day
         , null AS two_day
         , bank_reference AS bank_ref
         , detail AS text_desc
         , reconciliation_key
         , 'current.deposittransaction' AS source
         , 'current.deposittransaction' || customer_reference::text || bank_reference::text  AS pkey
         FROM current.deposittransaction
         LEFT JOIN current.depositgroup ON depositgroup.id = deposittransaction.group_id
         LEFT JOIN current.depositaccount ON depositaccount.id = deposittransaction.account_id
         WHERE (depositgroup.as_of_datetime AT TIME ZONE 'PST')::date >= '2016-01-01'::date and depositgroup.id != 956 --duplicate 11/23/2016 batch received from BofA

       ;;
    datagroup_trigger: etl_refresh
    indexes: ["pkey", "deposit_date"]
  }

  dimension_group: deposit_date {
    type: time
    timeframes: [date, month, year]
    sql: ${TABLE}.deposit_date ;;
  }

  dimension: currency {
    sql: ${TABLE}.currency ;;
  }

  dimension: bank_id_type {
    sql: ${TABLE}.bank_id_type ;;
  }

  dimension: bank_id {
    sql: ${TABLE}.bank_id ;;
  }

  dimension: account {
    sql: ${TABLE}.account ;;
  }

  dimension: data_type {
    sql: ${TABLE}.data_type ;;
  }

  dimension: bai_code {
    sql: ${TABLE}.bai_code ;;
  }

  dimension: description {
    sql: ${TABLE}.description ;;
  }

  dimension: deposit_amt {
    sql: ${TABLE}.deposit_amt ;;
  }

  dimension: balance {
    sql: ${TABLE}.balance ;;
  }

  dimension: customer_ref {
    sql: ${TABLE}.customer_ref ;;
  }

  dimension: immediate {
    sql: ${TABLE}.immediate ;;
  }

  dimension: one_day {
    sql: ${TABLE}.one_day ;;
  }

  dimension: two_day {
    sql: ${TABLE}.two_day ;;
  }

  dimension: bank_ref {
    sql: ${TABLE}.bank_ref ;;
  }

  dimension: text_desc {
    sql: ${TABLE}.text_desc ;;
  }

  dimension: reconciliation_key {
    sql: ${TABLE}.reconciliation_key ;;
  }

  dimension: source {
    sql: ${TABLE}.source ;;
  }

  dimension: pkey {
    sql: ${TABLE}.pkey ;;
  }

  measure: total_deposit_amount {
    type: sum
    value_format_name: usd_0
    sql: ${deposit_amt} ;;
  }
}

view: stripe_deposits {
  derived_table: {
    sql: SELECT
        'Stripe Transaction'::text as coid
        , CASE WHEN position('recurly transaction' in lower(description)) > 0
          THEN replace(substring(p.description from position('recurly transaction' in lower(p.description)) + 20),')','') ELSE charge_id END as trn
        , '1499186572' as account
        , '165' as bai_code
        , concat('transfer_id:', p.transfer_id::text) as bank_ref
        , 'Stripe Transaction' as data_type
        , net as deposit_amt
        , fee
        , expected_transfer_date as deposit_date
        , p.description as description
        , CASE WHEN position('recurly transaction' in lower(description)) > 0
          THEN replace(substring(p.description from position('recurly transaction' in lower(p.description)) + 20),')','') ELSE charge_id END as text_desc
        , concat('99999',p.id)::bigint as pkey
        , p.id as stripe_id
        , FALSE as known_var
        , 'Revenue' as rev_trn
        , CASE WHEN transaction_type = 'refund' THEN 'Refund'
          WHEN transaction_type = 'charge' THEN 'Payment'
          ELSE 'Other Stripe Type' END as ref_pay
      FROM
        current.paymentgatewaytransfertransaction as p
      INNER JOIN
        current.paymentgatewaytransfer as t on t.id = p.transfer_id
      INNER JOIN
        current.deposittransaction as d on CASE WHEN d.id = 5809 THEN 523 ELSE d.payment_gateway_transfer_id END = t.id
      WHERE
        transaction_type != 'refund' and transaction_type !='transfer' and expected_transfer_date >= '2015-10-01'
      UNION
        SELECT
          'Stripe Transaction'::text as coid
          , CASE WHEN position('recurly transaction' in lower(description)) > 0
            THEN replace(substring(p.description from position('recurly transaction' in lower(p.description)) + 20),')','') ELSE charge_id END as trn
          , '1499186572' as account
          , '165' as bai_code
          , concat('transfer_id:', p.transfer_id::text) as bank_ref
          , 'Stripe Transaction' as data_type
          , sum(net) as deposit_amt
          , sum(fee) as fee
          , expected_transfer_date::date as deposit_date
          , p.description as description
          , CASE WHEN position('recurly transaction' in lower(description)) > 0
            THEN replace(substring(p.description from position('recurly transaction' in lower(p.description)) + 20),')','') ELSE charge_id END as text_desc
          , concat('99999',min(p.id))::bigint as pkey
          , min(p.id) as stripe_id
          , FALSE as known_var
          , 'Revenue' as rev_trn
          , CASE WHEN transaction_type = 'refund' THEN 'Refund'
            WHEN transaction_type = 'charge' THEN 'Payment'
            ELSE 'Other Stripe Type' END as ref_pay
          FROM
            current.paymentgatewaytransfertransaction as p
          INNER JOIN
            current.paymentgatewaytransfer as t on t.id = p.transfer_id
          INNER JOIN
            current.deposittransaction as d on CASE WHEN d.id = 5809 THEN 523 ELSE d.payment_gateway_transfer_id END = t.id
          WHERE
            transaction_type = 'refund' and expected_transfer_date >= '2015-10-01'
          GROUP BY
            1,2,3,4,5,6,9,10,11,14,15,16

      UNION
        SELECT
          'Stripe Transaction'::text as coid
          , CASE WHEN position('recurly transaction' in lower(description)) > 0
            THEN replace(substring(p.description from position('recurly transaction' in lower(p.description)) + 20),')','') ELSE charge_id END as trn
          , '1499186572' as account
          , '165' as bai_code
          , concat('transfer_id:', p.transfer_id::text) as bank_ref
          , 'Stripe Transaction' as data_type
          , sum(net) as deposit_amt
          , sum(fee) as fee
          , expected_transfer_date::date as deposit_date
          , p.description as description
          , CASE WHEN position('recurly transaction' in lower(description)) > 0
            THEN replace(substring(p.description from position('recurly transaction' in lower(p.description)) + 20),')','') ELSE charge_id END as text_desc
          , concat('99999',min(p.id))::bigint as pkey
          , min(p.id) as stripe_id
          , FALSE as known_var
          , 'Revenue' as rev_trn
          , CASE WHEN transaction_type = 'refund' THEN 'Refund'
            WHEN transaction_type = 'charge' THEN 'Payment'
            ELSE 'Other Stripe Type' END as ref_pay
          FROM
            current.paymentgatewaytransfertransaction as p
          INNER JOIN
            current.paymentgatewaytransfer as t on t.id = p.transfer_id
          WHERE
            t.id = 946 and transaction_type !='transfer'
          GROUP BY
            1,2,3,4,5,6,9,10,11,14,15,16

       ;;
    datagroup_trigger: etl_refresh
  }
}
