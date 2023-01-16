##view: custom_hybrid_file_build {
##  derived_table: {
##    sql:
##      WITH last_update as (select serial_id, payment_method from uploads.custom_hybrid_file)
##
##      , custom_hybrid_file as
##        (INSERT INTO uploads.custom_hybrid_file
##          SELECT
##            eob_batch_id
##            , claim_id
##            , order_id
##            , payer_name
##            , clinic.name as clinic_name
##            , latest_barcode
##            , replace(trim(both ' ' from transaction_id),' ','')::text as transaction_id
##            , transaction_amount
##            , date_recorded
##            , max(source) as source
##            , payment_method
##            , min(invoice_id) as invoice_id
##            , min(invoice_type) as invoice_type
##            , serial_id
##            , CASE WHEN latest_barcode is null THEN concat(serial_id,'-',invoice_id) ELSE concat(serial_id,'-',latest_barcode) END as pkey
##            , CASE WHEN latest_barcode is null THEN 'Invoice' ELSE 'Barcode' END as pkey_type
##            , ref_pay
##          FROM
##            (SELECT
##              eob_batch_id
##              , claim_id
##              , order_id
##              , billing_clinic_id
##              , payer_name
##              , latest_barcode
##              , transaction_id
##              , CASE WHEN source in ('eob1', 'eob2', 'hra-era', 'beacon-era') THEN eob_amount ELSE payment_table_amount END as transaction_amount
##              , CASE WHEN source in ('eob1', 'eob2', 'hra-era') THEN eob_date_recorded ELSE payment_date_recorded END as date_recorded
##              , source
##              , payment_method
##              , invoice_id
##              , invoice_type
##              , serial_id
##              , ref_pay
##            FROM
##
##            --==============================================================================================================
##            --=========================================== BEGIN STEP 1 =====================================================
##            --==============================================================================================================
##
##            --Start with all entries in /eob...
##
##              (SELECT
##                eobbatch.id as eob_batch_id
##                , eob.claim_id
##                , claim.order_id
##                , insurancepayer.name as payer_name
##                , CASE
##                  WHEN trim(leading '0' from eobbatch.check_or_eft_trace_number) = '' THEN eobbatch.check_or_eft_trace_number
##                  WHEN x12_payer_payer_id = 1275 THEN concat('Avalon_',trim(leading '0' from eobbatch.check_or_eft_trace_number))
##                  WHEN x12_payer_name = 'PROGYNY INC' THEN concat('Progyny_',trim(leading '0' from eobbatch.check_or_eft_trace_number)) ELSE trim(leading '0' from eobbatch.check_or_eft_trace_number) END as transaction_id
##                , sum(eob.paid) - coalesce(sum(hra.hra_payment*-1),0) as eob_amount
##                , NULL::numeric as payment_table_amount
##                , eob.date_recorded as eob_date_recorded
##                , null::timestamp as payment_date_recorded
##                , 'eob1' as source
##                , 'eob' as payment_method
##                , payer_invoice_id as invoice_id
##                , 'Insurer' as invoice_type
##                , eob.id::text as serial_id
##                , 'Payment' as ref_pay
##              FROM
##                current.eob_no_duplicate_eob_batches eob
##              INNER JOIN
##                current.insuranceclaim as claim on claim.id = eob.claim_id
##              INNER JOIN
##                current.eobbatch on eobbatch.id = eob.eob_batch_id
##              LEFT JOIN
##                current.insurancepayer AS insurancepayer ON insurancepayer.id = claim.payer_id
##              LEFT JOIN
##                uploads.duplicate_eob_batches as dupe on dupe.eob_batch = eob.eob_batch_id
##              LEFT JOIN
##                ${hra_payments_via_eob.SQL_TABLE_NAME} hra on hra.eob_id = eob.id
##              LEFT JOIN last_update on last_update.serial_id = eob.id::text and last_update.payment_method = 'eob'
##              WHERE
##                dupe.eob_batch is null and eob.id != 494295 and last_update.serial_id is null
##              GROUP BY
##                1,2,3,4,5,7,8,9,10,11,12,13,14,15
##
##
##            --==============================================================================================================
##            --=========================================== BEGIN STEP 2 =====================================================
##            --==============================================================================================================
##
##              --Start with all entries in /eob...
##
##              UNION
##                SELECT
##                  eobbatch.id as eob_batch_id
##                  , eob.claim_id
##                  , claim.order_id
##                  , insurancepayer.name as payer_name
##                  , CASE WHEN trim(leading '0' from eobbatch.check_or_eft_trace_number) = '' THEN eobbatch.check_or_eft_trace_number ELSE trim(leading '0' from eobbatch.check_or_eft_trace_number) END as transaction_id
##                  , sum(hra_payment*-1) as eob_amount
##                  , null::numeric as payment_table_amount
##                  , eob.date_recorded as eob_date_recorded
##                  , null::timestamp as payment_date_recorded
##                  , 'hra-era' as source
##                  , 'eob' as payment_method
##                  , patient_invoice_id as invoice_id
##                  , 'Customer' as invoice_type
##                  , eob.id::text as serial_id
##                  , 'Payment' as ref_pay
##                FROM
##                  current.eob_no_duplicate_eob_batches eob
##                INNER JOIN
##                  current.insuranceclaim as claim on claim.id = eob.claim_id
##                INNER JOIN
##                  current.eobbatch on eobbatch.id = eob.eob_batch_id
##                INNER JOIN
##                  ${hra_payments_via_eob.SQL_TABLE_NAME} hra on hra.eob_id = eob.id
##                LEFT JOIN
##                  current.insurancepayer AS insurancepayer ON insurancepayer.id = claim.payer_id
##                LEFT JOIN
##                  uploads.duplicate_eob_batches as dupe on dupe.eob_batch = eob.eob_batch_id
##                LEFT JOIN last_update on last_update.serial_id = eob.id::text and last_update.payment_method = 'eob'
##                WHERE
##                  dupe.eob_batch is null and eob.id != 494295 and last_update.serial_id is null
##                GROUP BY
##                  1,2,3,4,5,7,8,9,10,11,12,13,14,15
##
##
##
##              --==============================================================================================================
##              --=========================================== BEGIN STEP 3 =====================================================
##              --==============================================================================================================
##
##              --Start with all entries in /payments...
##
##              UNION
##                SELECT
##                  s2.eob_batch_id as eob_batch_id
##                  , s1.claim_id
##                  , s1.order_id
##                  , s1.payer_name
##                  , s1.transaction_id
##                  , 0 as eob_amount
##                  , s1.payment_amount as payment_table_amount
##                  , null::date as eob_date_recorded
##                  , s1.payment_date_recorded as payment_date_recorded
##                  , 'ins_payments_no_eob'::text as source
##                  , payment_method
##                  , invoice_id as invoice_id
##                  , invoice_type as invoice_type
##                  , s1.id::text as serial_id
##                  , CASE WHEN s1.payment_method = 'ref' THEN 'Refund' ELSE 'Payment' END as ref_pay
##                FROM
##                  (SELECT
##                    claim.id as claim_id
##                    , claim.order_id
##                    , insurancepayer.name AS payer_name
##                    , trim(both ' ' from CASE WHEN position('SPLIT_' in transaction_id) > 0 THEN CASE WHEN trim(leading '0' from substring(transaction_id for position('SPLIT_' in transaction_id)-2)) = '' THEN substring(transaction_id for position('SPLIT_' in transaction_id)-2) ELSE trim(leading '0' from substring(transaction_id for position('SPLIT_' in transaction_id)-2)) END
##                      WHEN position('NATIVE_TANDEM' in transaction_id) > 0 THEN CASE WHEN trim(leading '0' from substring(transaction_id for position('NATIVE_TANDEM' in transaction_id) - 2)) = '' THEN substring(transaction_id for position('NATIVE_TANDEM' in transaction_id) - 2) ELSE trim(leading '0' from substring(transaction_id for position('NATIVE_TANDEM' in transaction_id) - 2)) END
##                      ELSE CASE WHEN trim(leading '0' from transaction_id) = '' THEN transaction_id ELSE trim(leading '0' from transaction_id) END END) as transaction_id
##                    , payment.amount as payment_amount
##                    , payment.timestamp as payment_date_recorded
##                    , payment.id
##                    , paid_to_patient
##                    , payment.invoice_id
##                    , payment.invoice_type
##                    , payment.payment_method
##                  FROM
##                    ${payment.SQL_TABLE_NAME} as payment
##                  INNER JOIN
##                    current.insuranceclaim as claim on payment.invoice_id = claim.payer_invoice_id
##                  LEFT JOIN current.insurancepayer AS insurancepayer ON insurancepayer.id = claim.payer_id
##                  LEFT JOIN last_update on last_update.serial_id = payment.id::text and last_update.payment_method != 'eob'
##                  WHERE
##                    (payment.payment_method = 'cc' or
##                    payment.payment_method = 'chck' or
##                    payment.payment_method = 'et')
##                    and voided_by_payment_id is null
##                    and payment.id != 863743 --weird BCBS FL issue on invoice = 1033961
##                    and last_update.serial_id is null
##                  ) as s1
##
##                --...and keep only those transactions which are not present in /eob
##                --This first subquery matches /payments transaction_id with /eob transaction_id exactly...
##
##                LEFT JOIN
##                  (SELECT
##                    CASE WHEN trim(leading '0' from eobbatch.check_or_eft_trace_number) = '' THEN eobbatch.check_or_eft_trace_number ELSE trim(leading '0' from eobbatch.check_or_eft_trace_number) END as check_or_eft_trace_number
##                    , eobbatch.id as eob_batch_id
##                    , eob.claim_id
##                  FROM
##                    current.eobbatch
##                  INNER JOIN
##                    current.eob_no_duplicate_eob_batches eob on eob.eob_batch_id = eobbatch.id
##                  LEFT JOIN
##                    uploads.duplicate_eob_batches as dupe on dupe.eob_batch = eobbatch.id
##                  WHERE
##                    dupe.eob_batch is null
##                  ) as s2 on replace(trim(both ' ' from s1.transaction_id),' ','')::text = replace(trim(both ' ' from s2.check_or_eft_trace_number),' ','')::text and s1.claim_id = s2.claim_id
##
##                --...and this second subquery matches /eob transaction_id on /payments transaction_id after the "-" if a "-" is present in /Payments transaction_id
##
##                LEFT JOIN
##                  (SELECT
##                    CASE WHEN trim(leading '0' from eobbatch.check_or_eft_trace_number) = '' THEN eobbatch.check_or_eft_trace_number ELSE trim(leading '0' from eobbatch.check_or_eft_trace_number) END as check_or_eft_trace_number
##                    , eobbatch.id as eob_batch_id
##                    , eob.claim_id
##                  FROM
##                    current.eobbatch
##                  INNER JOIN
##                    current.eob_no_duplicate_eob_batches eob on eob.eob_batch_id = eobbatch.id
##                  LEFT JOIN
##                    uploads.duplicate_eob_batches as dupe on dupe.eob_batch = eobbatch.id
##                  WHERE
##                    dupe.eob_batch is null
##                  ) as s3 on substring(s1.transaction_id from position('-' in transaction_id) +1) = s3.check_or_eft_trace_number and s1.claim_id = s3.claim_id
##
##                --...and this third subquery matches /eob transaction_id on /payments transaction_id after the "C" if a "C" is present in /Payments transaction_id and the payer is HIP NY State
##
##                LEFT JOIN
##                  (SELECT
##                    trim(leading '0' from eobbatch.check_or_eft_trace_number) as check_or_eft_trace_number
##                    , eobbatch.id as eob_batch_id
##                    , eob.claim_id
##                  FROM
##                    current.eobbatch
##                  INNER JOIN
##                    current.eob_no_duplicate_eob_batches eob on eob.eob_batch_id = eobbatch.id
##                  INNER JOIN
##                    current.insuranceclaim on insuranceclaim.id = eob.claim_id
##                  LEFT JOIN
##                    current.insurancepayer on insurancepayer.id = insuranceclaim.payer_id
##                  LEFT JOIN
##                    uploads.duplicate_eob_batches as dupe on dupe.eob_batch = eobbatch.id
##                  WHERE
##                    insurancepayer.name = 'HIP NY State'
##                    and dupe.eob_batch is null
##                  ) as s4 on substring(s4.check_or_eft_trace_number from position('C' in s4.check_or_eft_trace_number) + 1) = s1.transaction_id
##                WHERE
##                  (s2.check_or_eft_trace_number is null and s3.check_or_eft_trace_number is null and s4.check_or_eft_trace_number is null) or (paid_to_patient > 0 and payer_name <> 'Blue Shield California')
##                GROUP BY
##                  1,2,3,4,5,7,8,9,10,11,12,13,14,15
##
##              --==============================================================================================================
##              --=========================================== BEGIN STEP 4 =====================================================
##              --==============================================================================================================
##
##              --Grab all entries in /payments on the Customer Invoice only...
##
##              UNION
##                SELECT
##                  NULL::int as eob_batch_id
##                  , s1.claim_id
##                  , s1.order_id
##                  , NULL as payer_name
##                  , s1.transaction_id
##                  , NULL::float as eob_amount
##                  , s1.payment_amount as payment_table_amount
##                  , NULL::timestamp as eob_date_recorded
##                  , s1.payment_date_recorded as payment_date_recorded
##                  , 'patient_payments'::text as source
##                  , s1.payment_method
##                  , invoice_id as invoice_id
##                  , invoice_type as invoice_type
##                  , s1.id::text as serial_id
##                  , CASE WHEN s1.payment_method = 'ref' THEN 'Refund' ELSE 'Payment' END as ref_pay
##                FROM
##                  (SELECT
##                    invoiceitem.claim_id as claim_id
##                    , invoiceitem.order_id
##                    , CASE WHEN position('SPLIT_' in transaction_id) > 0 THEN CASE WHEN trim(leading '0' from substring(transaction_id for position('SPLIT_' in transaction_id)-2)) = '' THEN substring(transaction_id for position('SPLIT_' in transaction_id)-2) ELSE trim(leading '0' from substring(transaction_id for position('SPLIT_' in transaction_id)-2)) END
##                      WHEN position('NATIVE_TANDEM' in transaction_id) > 0 THEN CASE WHEN trim(leading '0' from substring(transaction_id for position('NATIVE_TANDEM' in transaction_id) - 2)) = '' THEN substring(transaction_id for position('NATIVE_TANDEM' in transaction_id) - 2) ELSE trim(leading'0' from substring(transaction_id for position('NATIVE_TANDEM' in transaction_id) - 2)) END
##                      ELSE CASE WHEN trim(leading '0' from transaction_id) = '' THEN transaction_id ELSE trim(leading '0' from transaction_id) END END as transaction_id
##                    , payment.amount as payment_amount
##                    , payment.timestamp as payment_date_recorded
##                    , payment.id
##                    , payment.invoice_id
##                    , payment.invoice_type
##                    , payment.payment_method
##                  FROM
##                    ${payment.SQL_TABLE_NAME} as payment
##                  INNER JOIN
##                    current.invoice on payment.invoice_id = invoice.id
##                  INNER JOIN
##                    current.invoiceitem on invoiceitem.invoice_id = invoice.id
##                  LEFT JOIN
##                    (SELECT
##                      patient_invoice_id
##                      , check_or_eft_trace_number
##                    FROM
##                      current.insuranceclaim as claim
##                    INNER JOIN
##                      current.eob_no_duplicate_eob_batches eob on eob.claim_id = claim.id
##                    INNER JOIN
##                      current.eobbatch on eobbatch.id = eob.eob_batch_id
##                    LEFT JOIN
##                      uploads.duplicate_eob_batches as dupe on dupe.eob_batch = eobbatch.id
##                    WHERE
##                      dupe.eob_batch is null
##                    GROUP BY 1,2
##                    ) as sub on sub.patient_invoice_id = payment.invoice_id and sub.check_or_eft_trace_number = payment.transaction_id
##                  LEFT JOIN last_update on last_update.serial_id = payment.id::text and last_update.payment_method != 'eob'
##                  WHERE
##                    (payment.payment_method = 'cc'
##                    or payment.payment_method = 'chck'
##                    or (payment.payment_method = 'ref' and payment.status = 4)
##                    or payment.payment_method = 'et') and
##                    invoice.type = 'Customer'
##                    and voided_by_payment_id is null
##                    and voided_by_invoice_item_id is null
##                    and (sub.check_or_eft_trace_number is null or payment.invoice_id = 1253705) --random payment to exclude due to duplication unable to be fixed otherwise
##                    and last_update.serial_id is null
##
##                  UNION
##                    SELECT
##                      invoiceitem.claim_id as claim_id
##                      , invoiceitem.order_id
##                      , CASE WHEN position('SPLIT_' in transaction_id) > 0 THEN CASE WHEN trim(leading '0' from substring(transaction_id for position('SPLIT_' in transaction_id)-2)) = '' THEN substring(transaction_id for position('SPLIT_' in transaction_id)-2) ELSE trim(leading '0' from substring(transaction_id for position('SPLIT_' in transaction_id)-2)) END
##                        WHEN position('NATIVE_TANDEM' in transaction_id) > 0 THEN CASE WHEN trim(leading '0' from substring(transaction_id for position('NATIVE_TANDEM' in transaction_id) - 2)) = '' THEN substring(transaction_id for position('NATIVE_TANDEM' in transaction_id) - 2) ELSE trim(leading'0' from substring(transaction_id for position('NATIVE_TANDEM' in transaction_id) - 2)) END
##                        ELSE CASE WHEN trim(leading '0' from transaction_id) = '' THEN transaction_id ELSE trim(leading '0' from transaction_id) END END as transaction_id
##                      , payment.amount as payment_amount
##                      , payment.timestamp as payment_date_recorded
##                      , payment.id
##                      , payment.invoice_id
##                      , payment.invoice_type
##                      , payment.payment_method
##                    FROM
##                      ${payment.SQL_TABLE_NAME} as payment
##                    INNER JOIN
##                      current.invoice on payment.invoice_id = invoice.id
##                    INNER JOIN
##                      current.invoiceitem on invoiceitem.invoice_id = invoice.id
##                    LEFT JOIN last_update on last_update.serial_id = payment.id::text and last_update.payment_method != 'eob'
##                    WHERE
##                      payment.id in (733836)
##                      and last_update.serial_id is null
##
##
##
##                  ) as s1
##                GROUP BY
##                  1,2,3,4,5,7,8,9,10,11,12,13,14,15
##
##              --==============================================================================================================
##              --=========================================== BEGIN STEP 5 =====================================================
##              --==============================================================================================================
##
##              --Grab all entries in /payments on the Physician Invoice only...
##
##              UNION
##                SELECT
##                  NULL::int as eob_batch_id
##                  , s1.claim_id
##                  , null::int as order_id
##                  , null as payer_name
##                  , s1.transaction_id
##                  , NULL::float as eob_amount
##                  , s1.payment_amount as payment_table_amount
##                  , NULL::timestamp as eob_date_recorded
##                  , s1.payment_date_recorded as payment_date_recorded
##                  , 'cnsmt_payments'::text as source
##                  , s1.payment_method
##                  , s1.invoice_id as invoice_id
##                  , s1.invoice_type as invoice_type
##                  , s1.id::text as serial_id
##                  , CASE WHEN s1.payment_method = 'ref' THEN 'Refund' ELSE 'Payment' END as ref_pay
##                FROM
##                  (SELECT
##                    null::int as claim_id
##                    , CASE WHEN position('SPLIT_' in transaction_id) > 0 THEN CASE WHEN trim(leading '0' from substring(transaction_id for position('SPLIT_' in transaction_id)-2)) = '' THEN substring(transaction_id for position('SPLIT_' in transaction_id)-2) ELSE trim(leading '0' from substring(transaction_id for position('SPLIT_' in transaction_id)-2)) END
##                      WHEN position('NATIVE_TANDEM' in transaction_id) > 0 THEN CASE WHEN trim(leading'0' from substring(transaction_id for position('NATIVE_TANDEM' in transaction_id) - 2)) = '' THEN substring(transaction_id for position('NATIVE_TANDEM' in transaction_id) - 2) ELSE trim(leading'0' from substring(transaction_id for position('NATIVE_TANDEM' in transaction_id) - 2)) END
##                      ELSE CASE WHEN trim(leading '0' from transaction_id) = '' THEN transaction_id ELSE trim(leading '0' from transaction_id) END END as transaction_id
##                    , payment.amount as payment_amount
##                    , payment.timestamp as payment_date_recorded
##                    , invoice.id as invoice_id
##                    , invoice.type as invoice_type
##                    , payment.id
##                    , payment.payment_method
##                  FROM
##                    ${payment.SQL_TABLE_NAME} as payment
##                  INNER JOIN
##                    current.invoice as invoice on payment.invoice_id = invoice.id
##                  LEFT JOIN last_update on last_update.serial_id = payment.id::text and last_update.payment_method != 'eob'
##                  WHERE
##                    (payment.payment_method = 'cc' or
##                    payment.payment_method = 'chck' or
##                    payment.payment_method = 'et' or
##                    payment.payment_method = 'non'
##                    or payment.payment_method = 'ref') and
##                    invoice.type = 'Physician'
##                    and voided_by_payment_id is null
##                    and last_update.serial_id is null
##                  ) as s1
##                GROUP BY
##                  1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
##
##
##              --==============================================================================================================
##              --=========================================== BEGIN STEP 6 =====================================================
##              --==============================================================================================================
##
##              --Grab all comp entries in /payments on the Customer Invoice only...
##
##              UNION
##                SELECT
##                  NULL::int as eob_batch_id
##                  , s1.claim_id
##                  , s1.order_id as order_id
##                  , payer_name as payer_name
##                  , s1.transaction_id
##                  , NULL::float as eob_amount
##                  , s1.payment_amount as payment_table_amount
##                  , NULL::timestamp as eob_date_recorded
##                  , s1.payment_date_recorded as payment_date_recorded
##                  , 'patient_comps'::text as source
##                  , s1.payment_method
##                  , s1.invoice_id as invoice_id
##                  , s1.invoice_type as invoice_type
##                  , s1.id::text as serial_id
##                  , 'patient_comp' as ref_pay
##                FROM
##                  (SELECT
##                    null::int as claim_id
##                    , concat('patient_comp_',transaction_id) as transaction_id
##                    , payment.amount as payment_amount
##                    , payment.timestamp as payment_date_recorded
##                    , invoice.id as invoice_id
##                    , invoice.type as invoice_type
##                    , payment.id
##                    , payment.payment_method
##                    , payer.name as payer_name
##                    , o.id as order_id
##                  FROM
##                    ${payment.SQL_TABLE_NAME} as payment
##                  INNER JOIN
##                    current.invoice as invoice on payment.invoice_id = invoice.id
##                  INNER JOIN
##                    current.invoiceitem on invoiceitem.invoice_id = invoice.id
##                  LEFT JOIN
##                    current.order as o on o.id = invoiceitem.order_id
##                  LEFT JOIN
##                    current.insuranceclaim as claim on claim.patient_invoice_id = invoice.id
##                  LEFT JOIN
##                    current.insurancepayer as payer on payer.id = claim.payer_id
##                  LEFT JOIN last_update on last_update.serial_id = payment.id::text and last_update.payment_method != 'eob'
##                  WHERE
##                    payment.payment_method = 'comp'
##                    and invoice.type = 'Customer'
##                    and last_update.serial_id is null
##                  ) as s1
##                GROUP BY
##                  1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
##
##
##              UNION
##                SELECT
##                  eobbatch.id as eob_batch_id
##                  , eob.claim_id
##                  , claim.order_id
##                  , insurancepayer.name as payer_name
##                  , CASE WHEN trim(leading '0' from eobbatch.check_or_eft_trace_number) = '' THEN eobbatch.check_or_eft_trace_number ELSE trim(leading '0' from eobbatch.check_or_eft_trace_number) END as transaction_id
##                  , sum(beacon_payments) as eob_amount
##                  , null::numeric as payment_table_amount
##                  , eob.date_recorded as eob_date_recorded
##                  , eob.date_claim_received as payment_date_recorded
##                  , 'beacon-era' as source
##                  , 'eob' as payment_method
##                  , patient_invoice_id as invoice_id
##                  , 'Insurer' as invoice_type
##                  , concat(eob.id::text,'_beacon_') as serial_id
##                  , 'Payment' as ref_pay
##                FROM
##                  current.eob_no_duplicate_eob_batches eob
##                INNER JOIN
##                  current.insuranceclaim as claim on claim.id = eob.claim_id
##                INNER JOIN
##                  current.eobbatch on eobbatch.id = eob.eob_batch_id
##                INNER JOIN
##                  ${beacon_payments.SQL_TABLE_NAME} as beacon_payments on beacon_payments.eob_id = eob.id
##                LEFT JOIN
##                  current.insurancepayer AS insurancepayer ON insurancepayer.id = claim.payer_id
##                LEFT JOIN
##                  uploads.duplicate_eob_batches as dupe on dupe.eob_batch = eob.eob_batch_id
##                LEFT JOIN last_update on last_update.serial_id = concat(eob.id::text,'_beacon_') and last_update.payment_method = 'eob'
##                WHERE
##                  dupe.eob_batch is null and eob.id != 494295 and insurancepayer.id = 12 and last_update.serial_id is null
##                GROUP BY
##                  1,2,3,4,5,7,8,9,10,11,12,13,14,15
##
##              -- ADDING SECTION TO INCLUDE PAYMENTS FROM BEACON THAT WE NEVER RECEIVED ERAS FOR BUT DID RECEIVE
##              -- PAYMENT INFORMATION VIA CSV FROM THE PAYER. ERAS LIKELY NEVER ARRIVING PER PAYER.
##
##              UNION
##                SELECT
##                  null::int as eob_batch_id
##                  , patient_control_number as claim_id
##                  , o.id as order_id
##                  , payer.name as payer_name
##                  , CASE WHEN invoice_number = '170503I26A' THEN 'COU51946' ELSE 'COU52319' END transaction_id
##                  , 0 as eob_amount
##                  , sum(would_pay) as payment_table_amount
##                  , null::date as eob_date_recorded
##                  , uhc_claim_processed_date as payment_date_recorded
##                  , 'manual_beacon_upload'::text as source
##                  , 'manual_beacon_upload' payment_method
##                  , payer_invoice_id as invoice_id
##                  , 'Insurer' as invoice_type
##                  , concat('beacon_manual_',patient_control_number)::text as serial_id
##                  , 'Payment' as ref_pay
##                FROM uploads.beacon_payments
##                LEFT JOIN current.insuranceclaim claim on claim.id = patient_control_number
##                LEFT JOIN current.insurancepayer payer on payer.id = claim.payer_id
##                LEFT JOIN current.order o on o.id = claim.order_id
##                WHERE invoice_number in ('170503I26A','170511I16A')
##                GROUP BY 1,2,3,4,5,6,8,9,10,11,12,13
##            ) as subquery
##            LEFT JOIN
##              current.order as o on o.id = subquery.order_id) as sub2
##          LEFT JOIN
##            current.clinic on clinic.id = sub2.billing_clinic_id
##          GROUP BY
##            1,2,3,4,5,6,7,8,9,11,14,15,16,17
##          )
##        , delete_dupes as
##          (DELETE FROM uploads.custom_hybrid_file WHERE eob_batch_id IN (SELECT * FROM uploads.duplicate_eob_batches UNION ALL SELECT id from current.eobbatch where duplicate_of_eob_batch_id is not null) returning *)
##
##        , delete_voids as
##          (DELETE FROM uploads.custom_hybrid_file WHERE payment_method in ('et','chck','cc') and serial_id in (SELECT id::text FROM current.payment where payment_method = 'void' or voided_by_payment_id is not null) returning *)
##
##        , update_refunds as
##          (UPDATE uploads.custom_hybrid_file set transaction_id = payment.transaction_id FROM current.payment WHERE custom_hybrid_file.payment_method = 'ref' and custom_hybrid_file.transaction_id = '' and custom_hybrid_file.serial_id = payment.id::text returning *)
##
##        , update_barcodes as
##          (UPDATE uploads.custom_hybrid_file set latest_barcode = "order".latest_barcode FROM current.order where custom_hybrid_file.order_id = "order".id returning *)
##
##        , update_invoice_ids as
##          (UPDATE uploads.custom_hybrid_file set invoice_id = ii.invoice_id FROM current.invoiceitem ii inner join current.order o on o.id = ii.order_id where ii.invoice_type = custom_hybrid_file.invoice_type and custom_hybrid_file.invoice_id is null and custom_hybrid_file.order_id = o.id returning *)
##
##        SELECT current_time as updated
##        FROM (
##          SELECT count(*) from delete_dupes
##            UNION ALL SELECT count(*) from delete_voids
##            UNION ALL SELECT count(*) from update_refunds
##            UNION ALL SELECT count(*) from update_barcodes
##            UNION ALL SELECT count(*) from update_invoice_ids
##            ) sub group by 1
##
##       ;;
##    sql_trigger_value: select sum(trigger) from (select count(id) as trigger from current.payment union all select count(id) as trigger from current.eob union all select count(eob_batch) as trigger from uploads.duplicate_eob_batches union all select count(eob_id) as trigger from ${beacon_payments.SQL_TABLE_NAME} as beacon) as foo ;;
##  }
##  dimension: updated {
##    sql: ${TABLE}.updated ;;
##  }
##}
##
##view: custom_hybrid_file {
##sql_table_name: uploads.custom_hybrid_file ;;
##
##  dimension: eob_batch_id {
##    description: "Foreign key to the EOB Batch table"
##    type: number
##    sql: ${TABLE}.eob_batch_id ;;
##  }
##
##  dimension: claim_id {
##    description: "Foreign key to the insurnaceclaim table"
##    type: number
##    sql: ${TABLE}.claim_id ;;
##  }
##
##  dimension: pkey {
##    description: "Primary key representing distinct transactions occuring in relation to Counsyl orders"
##    primary_key: yes
##    sql: ${TABLE}.pkey ;;
##  }
##
##  dimension: transaction_id {
##    description: "Denotes the check number,  EFT number,or  wire transfer number for payment transactions"
##    sql: ${TABLE}.transaction_id ;;
##  }
##
##  dimension: invoice_id {
##    description: "Foreign key to the invoice table"
##    type: number
##    sql: ${TABLE}.invoice_id ;;
##  }
##
##  dimension: invoice_type {
##    description: "Identifies who the recipient of the invoice is, e.g. Customer, Insurer, Physician"
##    sql: ${TABLE}.invoice_type ;;
##  }
##
##  dimension: source {
##    description: "A text description detailing what data source evidence for this transaction came from"
##    type: string
##    sql: ${TABLE}.source ;;
##  }
##
##  dimension_group: date_recorded {
##    description: "The date on which this payment was recorded as having been received by Counsyl"
##    type: time
##    timeframes: [date, month, quarter, year]
##    sql: ${TABLE}.date_recorded ;;
##  }
##
##  dimension: latest_barcode {
##    description: "The most recent barcode assigned to an order"
##    sql: ${TABLE}.latest_barcode ;;
##  }
##
##  dimension: payment_method {
##    description: "Indicatest he medium of payment, e.g. - cc for credit card, eob for EOB/ERA payments, etc."
##    sql: ${TABLE}.payment_method ;;
##  }
##
##  dimension: order_id {
##    description: "Foreign key to the order table"
##    sql: ${TABLE}.order_id ;;
##  }
##
##  dimension: payer_name {
##    description: "If the order is associated with a claim, this field indiactes the name of the insurance payer"
##    sql: ${TABLE}.payer_name ;;
##  }
##
##  measure: transaction_amount {
##    description: "The sum total dollar amount transfered in this transaction"
##    type: sum
##    value_format_name: usd
##    sql: ${TABLE}.transaction_amount ;;
##  }
##
##  dimension: amount_dim {
##    description: "The dollar amount transfered in this transaction"
##    type: number
##    value_format_name: usd
##    sql: ${TABLE}.transaction_amount ;;
##  }
##
##  dimension: clinic_name {
##    description: "The name of the clinic from which the order originated (ordering clinic)"
##    sql: ${TABLE}.clinic_name ;;
##  }
##
##  dimension: ref_pay {
##    description: "Indicates whether or not a transaction corresponds to a payment or a refund"
##    sql: ${TABLE}.ref_pay ;;
##  }
##}
##
##view: beacon_payments {
##  derived_table: {
##    sql: SELECT
##          eob_id
##          , sum(value) as beacon_payments
##        FROM current.eobadjustment
##        INNER JOIN current.eob on eob.id = eobadjustment.eob_id
##        INNER JOIN
##          (SELECT
##            distinct claim_received_by_uhc_date
##          FROM
##            uploads.beacon_payments
##          ) bp on bp.claim_received_by_uhc_date = eob.date_claim_received
##        WHERE date_recorded > '2016-08-01' and type = 'CO' and code = '24' GROUP BY 1
##
##        -- ADDING THIS SECTION TO FIX A BROKEN ERA FROM THE PAYER WHERE WE RECEIVED THE CORRECT
##        -- INFORMATION FROM A CSV FROM THE PAYER
##
##        UNION ALL
##          SELECT
##            eob.id as eob_id
##            , sum(paid)
##          FROM current.eob
##          INNER JOIN current.eobbatch on eobbatch.id = eob.eob_batch_id
##          WHERE length(check_or_eft_trace_number) = 10 and right(check_or_eft_trace_number,1) = 'A'
##          GROUP BY 1;;
##    sql_trigger_value: select sum(trigger) from (select count(*) as trigger from current.eob union all select count(*) as trigger from uploads.beacon_payments) as sub ;;
##  }
##}
##
