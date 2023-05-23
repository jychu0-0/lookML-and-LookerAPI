### ============================================================================================================ #
### ==================================== IN NETWORK REVENUE CALCULATION ======================================== #
### ============================================================================================================ #
##
###  01. revenue_inn_target: Aggregates target data for all revenue periods for non cash/MOOP insurance claims
###  02. revenue_inn_lookback_base: Aggregates all lookback data for insurance and patient payments
###  03. revenue_inn_match_all_fields: Joins lookback data to target data to calculate historical revenue calcs
###                                   where the historical data matches all fields in target data
###  04. revenue_inn_match_payer_plantype_prod_dp: Joins lookback data to target data to calculate hisotiral revenue
###                                               calcs where hisotrical data matches all fields in target data
###                                               except plan name
###  05. revenue_inn_match_payer_planname_prod_dp: Joins lookback data to target data to calculate hisotiral revenue
###                                               calcs where hisotrical data matches all fields in target data
###                                               except plan type
###  06. revenue_inn_match_payer_prod_dp: Joins lookback data to target data to calculate hisotiral revenue
###                                      calcs where hisotrical data matches all fields in target dxata
###                                      except plan name and plan type
###  07. revenue_inn_match_payer_dp: Joins lookback data to target data to calculate historical revenue calcs where
###                                 historical data matches target data on payer and disease panel
###  08. revenue_inn_match_payer_prod: Joins lookback data to target data to calculate hisotiral revenue calcs where
###                                   hisotrical data matches target data on payer and product
###  09. revenue_inn_match_prod: Joins lookback data to target data to calculate hisotiral revenue calcs where historical
###                             data matches target data on product
###  10. revenue_inn_target_moop: Aggregates target data for all revenue periods for cash or MOOP claims only
###  11. revenue_inn_lookback_base_moop: Aggregates all lookback data for cash/MOOP patient payments
###  12. revenue_inn_match_payer_prod_moop: Joins lookback data to target data to calculate historical revenue calcs
###                                         where the historical data matches the target data on payer and product
###  13. revenue_inn_match_prod_moop: Joins lookback data to target data to calculate historical revenue calcs where
###                                  the historical data matches the target data on product
###  14. revenue_inn: Creates current revenue percent for insurance volume and average patient payment amounts for
###                   non-cash/MOOP patient volume for target periods, aggregated at the payer+planname+plantype+
###                   product+diseasepanel level. Uses the waterfall method to choose the highest level of specificity
###                   applicable for every combination in the target period
###  15. revenue_inn_moop: Creates average patient payment amount for cash/MOOP patient volume for target periods,
###                        aggregated at the payer+planname+plantype+product+diseasepanel level. Uses the waterfall method
###                        to choose the highest level of specificity applicable for every combination in the target period.
###  16. revenue_inn_moop_barcode: Applies the average patient payment amounts generated in revenue_inn_moop at the
###                                aggregated level to the applicable barcodes
###  17. revenue_inn_barcode: Applies the revenue percent, average patient payment, and average cash/MOOP payment amounts
###                           derived from prior queries at the aggregated level to the applicable barcodes. This is the
###                           final revenue query.
##
##
### ============================================================================================================ #
### ========================================= 01: revenue_inn_target =========================================== #
### ============================================================================================================ #
##
##view: revenue_inn_target {
##  derived_table: {
##    sql: SELECT
##        to_date(TO_CHAR(o.completed_on, 'YYYY-MM'),'YYYY-MM') AS completed_month
##        , to_date(TO_CHAR(o.completed_on - INTERVAL '3 month', 'YYYY-MM'),'YYYY-MM') AS sixth_period
##        , to_date(TO_CHAR(o.completed_on - INTERVAL '4 month', 'YYYY-MM'),'YYYY-MM') AS fifth_period
##        , to_date(TO_CHAR(o.completed_on - INTERVAL '5 month', 'YYYY-MM'),'YYYY-MM') AS fourth_period
##        , to_date(TO_CHAR(o.completed_on - INTERVAL '6 month', 'YYYY-MM'),'YYYY-MM') AS third_period
##        , to_date(TO_CHAR(o.completed_on - INTERVAL '7 month', 'YYYY-MM'),'YYYY-MM') AS second_period
##        , to_date(TO_CHAR(o.completed_on - INTERVAL '8 month', 'YYYY-MM'),'YYYY-MM') AS first_period
##        , CASE
##          WHEN has_ips_high_risk = TRUE and o.product_name = 'Prelude Prenatal Screen'  THEN 'Prelude Prenatal Screen - High Risk'
##          WHEN has_ips_high_risk = FALSE and o.product_name = 'Prelude Prenatal Screen'  THEN 'Prelude Prenatal Screen - Low Risk'
##          WHEN has_ips_high_risk is null and o.product_name = 'Prelude Prenatal Screen' THEN 'Prelude Prenatal Screen - Low Risk'
##          ELSE o.product_name END as product
##        , o.disease_panel
##        , CASE WHEN position('Medicare' in insurancepayer.name) = 1 THEN 'Medicare Group' ELSE insurancepayer.name END as payer_name
##        , insuranceclaim.plan_type
##        , insuranceclaim.plan_name
##        , CASE
##          WHEN o.product = 'Foresight Carrier Screen' and date_of_service >= inn.fps_date and date_of_service < coalesce(inn.fps_term,'2100-01-01'::date)
##            THEN 'In Net'
##          WHEN o.product = 'Reliant Cancer Screen' and date_of_service >= inn.ics_date and date_of_service < coalesce(inn.ics_term,'2100-01-01'::date)
##            THEN 'In Net'
##          WHEN o.product = 'Prelude Prenatal Screen' and date_of_service >= inn.ips_date and date_of_service < coalesce(inn.ips_term,'2100-01-01'::date)
##            THEN 'In Net'
##          ELSE 'OON'
##          END as network_status
##        , COUNT(DISTINCT o.id) AS order_count
##      FROM
##        ${order.SQL_TABLE_NAME} as o
##      LEFT JOIN
##        ${notable_diagnoses.SQL_TABLE_NAME} as nd on nd.order_id = o.id
##      LEFT JOIN
##        current.insuranceclaim as insuranceclaim ON insuranceclaim.order_id = o.id
##      LEFT JOIN
##        current.insurancepayer ON insurancepayer.id = insuranceclaim.payer_id
##      LEFT JOIN
##        uploads.in_network_dates_w_terminal inn on inn.id = insurancepayer.id
##
##
##      WHERE
##        (CASE
##          WHEN o.product = 'Foresight Carrier Screen' and date_of_service >= inn.fps_date and date_of_service < coalesce(inn.fps_term,'2100-01-01'::date)
##            THEN 'In Net'
##          WHEN o.product = 'Reliant Cancer Screen' and date_of_service >= inn.ics_date and date_of_service < coalesce(inn.ics_term,'2100-01-01'::date)
##            THEN 'In Net'
##          WHEN o.product = 'Prelude Prenatal Screen' and date_of_service >= inn.ips_date and date_of_service < coalesce(inn.ips_term,'2100-01-01'::date)
##            THEN 'In Net'
##          ELSE 'OON'
##          END) = 'In Net'
##        and o.bill_type = 'in'
##        and status_name <> 'Canceled Chose Cash'
##        and status_name <> 'Canceled Chose Consignment'
##        and status_name <> 'Maximum OOP - No Insurance'
##
##      GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13
##       ;;
##    sql_trigger_value: select count(*) from ${matched_report_2014_to_current.SQL_TABLE_NAME} ;;
##    indexes: ["completed_month", "product", "payer_name"]
##  }
##}
##
##view: revenue_inn_lookback_base {
##  derived_table: {
##    sql: SELECT
##        to_date(TO_CHAR(o.completed_on, 'YYYY-MM'),'YYYY-MM') AS completed_month
##        , CASE
##          WHEN has_ips_high_risk = TRUE and o.product_name = 'Prelude Prenatal Screen'  THEN 'Prelude Prenatal Screen - High Risk'
##          WHEN has_ips_high_risk = FALSE and o.product_name = 'Prelude Prenatal Screen'  THEN 'Prelude Prenatal Screen - Low Risk'
##          WHEN has_ips_high_risk is null and o.product_name = 'Prelude Prenatal Screen' THEN 'Prelude Prenatal Screen - Low Risk'
##          ELSE o.product_name END AS product
##        , o.disease_panel AS disease_panel
##        , CASE WHEN position('Medicare' in insurancepayer.name) = 1 THEN 'Medicare Group' ELSE insurancepayer.name END as payer_name
##        , insuranceclaim.plan_type
##        , insuranceclaim.plan_name
##        , sum(coalesce(payer_revenue_base_6,0) + coalesce(non_base_6,0)) as payer_revenue_base_6
##        , sum(coalesce(payer_revenue_base_5,0) + coalesce(non_base_5,0)) as payer_revenue_base_5
##        , sum(coalesce(payer_revenue_base_4,0) + coalesce(non_base_4,0)) as payer_revenue_base_4
##        , sum(coalesce(payer_revenue_base_3,0) + coalesce(non_base_3,0)) as payer_revenue_base_3
##        , sum(coalesce(payer_revenue_base_2,0) + coalesce(non_base_2,0)) as payer_revenue_base_2
##        , sum(coalesce(payer_revenue_base_1,0) + coalesce(non_base_1,0)) as payer_revenue_base_1
##        , sum(coalesce(patient_revenue_base_6,0)) as patient_revenue_base_6
##        , sum(coalesce(patient_revenue_base_5,0)) as patient_revenue_base_5
##        , sum(coalesce(patient_revenue_base_4,0)) as patient_revenue_base_4
##        , sum(coalesce(patient_revenue_base_3,0)) as patient_revenue_base_3
##        , sum(coalesce(patient_revenue_base_2,0)) as patient_revenue_base_2
##        , sum(coalesce(patient_revenue_base_1,0)) as patient_revenue_base_1
##        , SUM(insuranceclaim.total_charges) AS total_charges
##        , COUNT(DISTINCT o.id) AS order_count
##      FROM
##        ${order.SQL_TABLE_NAME} as o
##      LEFT JOIN
##        ${notable_diagnoses.SQL_TABLE_NAME} as nd on nd.order_id = o.id
##      LEFT JOIN
##        (SELECT
##          order_id
##          , SUM(CASE WHEN deposit_month <= TO_CHAR(completed_on + INTERVAL '7 month', 'YYYY-MM') THEN match.payer_payment_amount ELSE 0 END) AS payer_revenue_base_6
##          , SUM(CASE WHEN deposit_month <= TO_CHAR(completed_on + INTERVAL '6 month', 'YYYY-MM') THEN match.payer_payment_amount ELSE 0 END) AS payer_revenue_base_5
##          , SUM(CASE WHEN deposit_month <= TO_CHAR(completed_on + INTERVAL '5 month', 'YYYY-MM') THEN match.payer_payment_amount ELSE 0 END) AS payer_revenue_base_4
##          , SUM(CASE WHEN deposit_month <= TO_CHAR(completed_on + INTERVAL '4 month', 'YYYY-MM') THEN match.payer_payment_amount ELSE 0 END) AS payer_revenue_base_3
##          , SUM(CASE WHEN deposit_month <= TO_CHAR(completed_on + INTERVAL '3 month', 'YYYY-MM') THEN match.payer_payment_amount ELSE 0 END) AS payer_revenue_base_2
##          , SUM(CASE WHEN deposit_month <= TO_CHAR(completed_on + INTERVAL '2 month', 'YYYY-MM') THEN match.payer_payment_amount ELSE 0 END) AS payer_revenue_base_1
##          , SUM(CASE WHEN deposit_month <= TO_CHAR(completed_on + INTERVAL '7 month', 'YYYY-MM') THEN match.patient_payment_amount ELSE 0 END) AS patient_revenue_base_6
##          , SUM(CASE WHEN deposit_month <= TO_CHAR(completed_on + INTERVAL '6 month', 'YYYY-MM') THEN match.patient_payment_amount ELSE 0 END) AS patient_revenue_base_5
##          , SUM(CASE WHEN deposit_month <= TO_CHAR(completed_on + INTERVAL '5 month', 'YYYY-MM') THEN match.patient_payment_amount ELSE 0 END) AS patient_revenue_base_4
##          , SUM(CASE WHEN deposit_month <= TO_CHAR(completed_on + INTERVAL '4 month', 'YYYY-MM') THEN match.patient_payment_amount ELSE 0 END) AS patient_revenue_base_3
##          , SUM(CASE WHEN deposit_month <= TO_CHAR(completed_on + INTERVAL '3 month', 'YYYY-MM') THEN match.patient_payment_amount ELSE 0 END) AS patient_revenue_base_2
##          , SUM(CASE WHEN deposit_month <= TO_CHAR(completed_on + INTERVAL '2 month', 'YYYY-MM') THEN match.patient_payment_amount ELSE 0 END) AS patient_revenue_base_1
##        FROM
##          (SELECT
##            order_id
##            , completed_on
##            , to_char(deposit_date, 'YYYY-MM') as deposit_month
##            , SUM(CASE WHEN invoice_type = 'Insurer' THEN hybrid_transaction_amt ELSE 0 END) as payer_payment_amount
##            , SUM(CASE WHEN invoice_type = 'Customer' THEN hybrid_transaction_amt ELSE 0 END) as patient_payment_amount
##          FROM
##            ${matched_report_2014_to_current.SQL_TABLE_NAME} as m
##          WHERE
##            invoice_type = 'Insurer' or invoice_type = 'Customer'
##            and ref_pay != 'Refund'
##          GROUP BY
##            1,2,3
##          ) as match
##        GROUP BY
##          1
##        ) AS m ON m.order_id::int = o.id::int
##      LEFT JOIN
##        (SELECT
##          order_id
##          , SUM(CASE WHEN recorded_month <= TO_CHAR(completed_on + INTERVAL '7 month', 'YYYY-MM') THEN non_paid ELSE 0 END) AS non_base_6
##          , SUM(CASE WHEN recorded_month <= TO_CHAR(completed_on + INTERVAL '6 month', 'YYYY-MM') THEN non_paid ELSE 0 END) AS non_base_5
##          , SUM(CASE WHEN recorded_month <= TO_CHAR(completed_on + INTERVAL '5 month', 'YYYY-MM') THEN non_paid ELSE 0 END) AS non_base_4
##          , SUM(CASE WHEN recorded_month <= TO_CHAR(completed_on + INTERVAL '4 month', 'YYYY-MM') THEN non_paid ELSE 0 END) AS non_base_3
##          , SUM(CASE WHEN recorded_month <= TO_CHAR(completed_on + INTERVAL '3 month', 'YYYY-MM') THEN non_paid ELSE 0 END) AS non_base_2
##          , SUM(CASE WHEN recorded_month <= TO_CHAR(completed_on + INTERVAL '2 month', 'YYYY-MM') THEN non_paid ELSE 0 END) AS non_base_1
##        FROM
##          (SELECT
##            order_id
##            , completed_on
##            , to_char(eobbatch.date_recorded, 'YYYY-MM') as recorded_month
##            , sum(paid) as non_paid
##          FROM
##            current.eob_no_duplicate_eob_batches as eob
##          INNER JOIN
##            current.eobbatch on eobbatch.id = eob.eob_batch_id
##          INNER JOIN
##            ${order.SQL_TABLE_NAME} as o on o.id = eob.order_id
##          WHERE
##            eobbatch.payment_method = 'non'
##          GROUP BY
##            1,2,3
##          ) as non_eobs
##        GROUP BY
##          1
##        ) AS n ON n.order_id::int = o.id::int
##      LEFT JOIN
##        current.insuranceclaim as insuranceclaim ON insuranceclaim.order_id = o.id
##      LEFT JOIN
##        current.insurancepayer on insurancepayer.id = insuranceclaim.payer_id
##      LEFT JOIN
##        uploads.in_network_dates_w_terminal inn on inn.id = insurancepayer.id
##
##      WHERE
##        (CASE
##          WHEN o.product = 'Foresight Carrier Screen' and date_of_service >= inn.fps_date and date_of_service < coalesce(inn.fps_term,'2100-01-01'::date)
##            THEN 'In Net'
##          WHEN o.product = 'Reliant Cancer Screen' and date_of_service >= inn.ics_date and date_of_service < coalesce(inn.ics_term,'2100-01-01'::date)
##            THEN 'In Net'
##          WHEN o.product = 'Prelude Prenatal Screen' and date_of_service >= inn.ips_date and date_of_service < coalesce(inn.ips_term,'2100-01-01'::date)
##            THEN 'In Net'
##          ELSE 'OON'
##          END) = 'In Net'
##        and o.bill_type = 'in'
##        and status_name <> 'Canceled Chose Cash'
##        and status_name <> 'Canceled Chose Consignment'
##        and status_name <> 'Maximum OOP - No Insurance'
##      GROUP BY 1, 2, 3, 4, 5, 6
##       ;;
##    sql_trigger_value: select sum(order_count) from ${revenue_inn_target.SQL_TABLE_NAME} as rev ;;
##    indexes: ["product", "disease_panel", "plan_name", "plan_type", "payer_name"]
##  }
##}
##
##view: revenue_inn_match_all_fields {
##  derived_table: {
##    sql:
##      SELECT
##
##
##      --fields from the target month
##
##        o.completed_month
##        ,o.payer_name
##        ,o.plan_name
##        ,o.plan_type
##        ,o.disease_panel
##        ,o.product
##        ,o.order_count
##        ,o.sixth_period
##        ,o.fifth_period
##        ,o.fourth_period
##        ,o.third_period
##        ,o.second_period
##        ,o.first_period
##        ,'a_full' as lookback_type
##
##        --fields from full-criteria (PAYER-PLANTYPE-PLANNAME-DISEASEPANEL-METHODOLOGY-PRODUCT) level look-back
##
##        , sum(CASE WHEN f6.completed_month = o.first_period THEN coalesce(f6.payer_revenue_base_6/(1-six_month_payer),0) ELSE 0 END
##            + CASE WHEN f6.completed_month = o.second_period THEN coalesce(f6.payer_revenue_base_5/(1-five_month_payer),0) ELSE 0 END
##            + CASE WHEN f6.completed_month = o.third_period THEN coalesce(f6.payer_revenue_base_4/(1-four_month_payer),0) ELSE 0 END
##            + CASE WHEN f6.completed_month = o.fourth_period THEN coalesce(f6.payer_revenue_base_3/(1-three_month_payer),0) ELSE 0 END
##            + CASE WHEN f6.completed_month = o.fifth_period THEN coalesce(f6.payer_revenue_base_2/(1-two_month_payer),0) ELSE 0 END
##            + CASE WHEN f6.completed_month = o.sixth_period THEN coalesce(f6.payer_revenue_base_1/(1-one_month_payer),0) ELSE 0 END
##          ) as segment_payer_revenue
##        , sum(CASE WHEN f6.completed_month = o.first_period THEN coalesce(f6.patient_revenue_base_6/(1-six_month_patient),0) ELSE 0 END
##            + CASE WHEN f6.completed_month = o.second_period THEN coalesce(f6.patient_revenue_base_5/(1-five_month_patient),0) ELSE 0 END
##            + CASE WHEN f6.completed_month = o.third_period THEN coalesce(f6.patient_revenue_base_4/(1-four_month_patient),0) ELSE 0 END
##            + CASE WHEN f6.completed_month = o.fourth_period THEN coalesce(f6.patient_revenue_base_3/(1-three_month_patient),0) ELSE 0 END
##            + CASE WHEN f6.completed_month = o.fifth_period THEN coalesce(f6.patient_revenue_base_2/(1-two_month_patient),0) ELSE 0 END
##            + CASE WHEN f6.completed_month = o.sixth_period THEN coalesce(f6.patient_revenue_base_1/(1-one_month_patient),0) ELSE 0 END
##          ) as segment_patient_revenue
##        ,sum(CASE
##            WHEN f6.completed_month = o.sixth_period THEN coalesce(f6.total_charges,0)
##            WHEN f6.completed_month = o.fifth_period THEN coalesce(f6.total_charges,0)
##            WHEN f6.completed_month = o.fourth_period THEN coalesce(f6.total_charges,0)
##            WHEN f6.completed_month = o.third_period THEN coalesce(f6.total_charges,0)
##            WHEN f6.completed_month = o.second_period THEN coalesce(f6.total_charges,0)
##            WHEN f6.completed_month = o.first_period THEN coalesce(f6.total_charges,0)
##          ELSE 0 END) as segment_total_charges
##        ,sum(CASE
##            WHEN f6.completed_month = o.sixth_period THEN coalesce(f6.order_count,0)
##            WHEN f6.completed_month = o.fifth_period THEN coalesce(f6.order_count,0)
##            WHEN f6.completed_month = o.fourth_period THEN coalesce(f6.order_count,0)
##            WHEN f6.completed_month = o.third_period THEN coalesce(f6.order_count,0)
##            WHEN f6.completed_month = o.second_period THEN coalesce(f6.order_count,0)
##            WHEN f6.completed_month = o.first_period THEN coalesce(f6.order_count,0)
##          ELSE 0 END) as segment_order_count
##
##        FROM
##
##      -- compute values for target month
##
##      ${revenue_inn_target.SQL_TABLE_NAME} AS o
##
##      INNER JOIN
##        uploads.payment_lag_factors as lag on lag.month = o.completed_month
##
##      INNER JOIN
##
##      -- compute values for the sixth_period (3 month lookback) (f6)
##
##      ${revenue_inn_lookback_base.SQL_TABLE_NAME} AS f6
##        ON o.product = f6.product
##        AND o.disease_panel = f6.disease_panel
##        AND o.payer_name = f6.payer_name
##        AND o.plan_name = f6.plan_name
##        AND o.plan_type = f6.plan_type
##
##      GROUP BY
##        1,2,3,4,5,6,7,8,9,10,11,12,13,14
##       ;;
##    sql_trigger_value: select sum(order_count) from ${revenue_inn_lookback_base.SQL_TABLE_NAME} ;;
##  }
##}
##
##view: revenue_inn_match_payer_plantype_prod_dp {
##  derived_table: {
##    sql:
##      SELECT
##
##
##      --fields from the target month
##
##        o.completed_month
##        ,o.payer_name
##        ,o.plan_name
##        ,o.plan_type
##        ,o.disease_panel
##        ,o.product
##        ,o.order_count
##        ,o.sixth_period
##        ,o.fifth_period
##        ,o.fourth_period
##        ,o.third_period
##        ,o.second_period
##        ,o.first_period
##        ,'b_ppdmp' as lookback_type
##
##        --fields from PAYER-PLANTYPE-DISEASEPANEL-METHODOLOGY-PRODUCT level look-back (pppayer_dpp))
##
##        ,sum(CASE WHEN ppdmp6.completed_month = o.first_period THEN coalesce(ppdmp6.payer_revenue_base_6/(1-six_month_payer),0) ELSE 0 END
##            + CASE WHEN ppdmp6.completed_month = o.second_period THEN coalesce(ppdmp6.payer_revenue_base_5/(1-five_month_payer),0) ELSE 0 END
##            + CASE WHEN ppdmp6.completed_month = o.third_period THEN coalesce(ppdmp6.payer_revenue_base_4/(1-four_month_payer),0) ELSE 0 END
##            + CASE WHEN ppdmp6.completed_month = o.fourth_period THEN coalesce(ppdmp6.payer_revenue_base_3/(1-three_month_payer),0) ELSE 0 END
##            + CASE WHEN ppdmp6.completed_month = o.fifth_period THEN coalesce(ppdmp6.payer_revenue_base_2/(1-two_month_payer),0) ELSE 0 END
##            + CASE WHEN ppdmp6.completed_month = o.sixth_period THEN coalesce(ppdmp6.payer_revenue_base_1/(1-one_month_payer),0) ELSE 0 END
##          ) as segment_payer_revenue
##        ,sum(CASE WHEN ppdmp6.completed_month = o.first_period THEN coalesce(ppdmp6.patient_revenue_base_6/(1-six_month_patient),0) ELSE 0 END
##            + CASE WHEN ppdmp6.completed_month = o.second_period THEN coalesce(ppdmp6.patient_revenue_base_5/(1-five_month_patient),0) ELSE 0 END
##            + CASE WHEN ppdmp6.completed_month = o.third_period THEN coalesce(ppdmp6.patient_revenue_base_4/(1-four_month_patient),0) ELSE 0 END
##            + CASE WHEN ppdmp6.completed_month = o.fourth_period THEN coalesce(ppdmp6.patient_revenue_base_3/(1-three_month_patient),0) ELSE 0 END
##            + CASE WHEN ppdmp6.completed_month = o.fifth_period THEN coalesce(ppdmp6.patient_revenue_base_2/(1-two_month_patient),0) ELSE 0 END
##            + CASE WHEN ppdmp6.completed_month = o.sixth_period THEN coalesce(ppdmp6.patient_revenue_base_1/(1-one_month_patient),0) ELSE 0 END
##          ) as segment_patient_revenue
##        ,sum(CASE
##            WHEN ppdmp6.completed_month = o.sixth_period THEN coalesce(ppdmp6.total_charges,0)
##            WHEN ppdmp6.completed_month = o.fifth_period THEN coalesce(ppdmp6.total_charges,0)
##            WHEN ppdmp6.completed_month = o.fourth_period THEN coalesce(ppdmp6.total_charges,0)
##            WHEN ppdmp6.completed_month = o.third_period THEN coalesce(ppdmp6.total_charges,0)
##            WHEN ppdmp6.completed_month = o.second_period THEN coalesce(ppdmp6.total_charges,0)
##            WHEN ppdmp6.completed_month = o.first_period THEN coalesce(ppdmp6.total_charges,0)
##          ELSE 0 END) as segment_total_charges
##        ,sum(CASE
##            WHEN ppdmp6.completed_month = o.sixth_period THEN coalesce(ppdmp6.order_count,0)
##            WHEN ppdmp6.completed_month = o.fifth_period THEN coalesce(ppdmp6.order_count,0)
##            WHEN ppdmp6.completed_month = o.fourth_period THEN coalesce(ppdmp6.order_count,0)
##            WHEN ppdmp6.completed_month = o.third_period THEN coalesce(ppdmp6.order_count,0)
##            WHEN ppdmp6.completed_month = o.second_period THEN coalesce(ppdmp6.order_count,0)
##            WHEN ppdmp6.completed_month = o.first_period THEN coalesce(ppdmp6.order_count,0)
##          ELSE 0 END) as segment_order_count
##
##      FROM
##
##      -- compute values for target month
##
##      ${revenue_inn_target.SQL_TABLE_NAME} AS o
##
##      INNER JOIN
##        uploads.payment_lag_factors as lag on lag.month = o.completed_month
##
##      INNER JOIN
##
##      -- compute values for the sixth_period PAYER-PLANTYPE_DISEASEPANEL-METHODOLOGY-PRODUCT match (ppdmp6)
##
##        (SELECT
##          product
##          , disease_panel
##          , payer_name
##          , plan_type
##          , completed_month
##          , sum(coalesce(payer_revenue_base_6,0)) as payer_revenue_base_6
##          , sum(coalesce(payer_revenue_base_5,0)) as payer_revenue_base_5
##          , sum(coalesce(payer_revenue_base_4,0)) as payer_revenue_base_4
##          , sum(coalesce(payer_revenue_base_3,0)) as payer_revenue_base_3
##          , sum(coalesce(payer_revenue_base_2,0)) as payer_revenue_base_2
##          , sum(coalesce(payer_revenue_base_1,0)) as payer_revenue_base_1
##          , sum(coalesce(patient_revenue_base_6,0)) as patient_revenue_base_6
##          , sum(coalesce(patient_revenue_base_5,0)) as patient_revenue_base_5
##          , sum(coalesce(patient_revenue_base_4,0)) as patient_revenue_base_4
##          , sum(coalesce(patient_revenue_base_3,0)) as patient_revenue_base_3
##          , sum(coalesce(patient_revenue_base_2,0)) as patient_revenue_base_2
##          , sum(coalesce(patient_revenue_base_1,0)) as patient_revenue_base_1
##          , SUM(total_charges) AS total_charges
##          , sum(order_count) AS order_count
##        FROM
##          ${revenue_inn_lookback_base.SQL_TABLE_NAME}
##        GROUP BY
##          1,2,3,4,5
##        ) AS ppdmp6
##        ON o.product = ppdmp6.product
##        AND o.disease_panel = ppdmp6.disease_panel
##        AND o.payer_name = ppdmp6.payer_name
##        AND o.plan_type = ppdmp6.plan_type
##
##
##      GROUP BY
##        1,2,3,4,5,6,7,8,9,10,11,12,13,14
##       ;;
##    sql_trigger_value: select sum(order_count) from ${revenue_inn_lookback_base.SQL_TABLE_NAME} ;;
##  }
##}
##
##view: revenue_inn_match_payer_planname_prod_dp {
##  derived_table: {
##    sql:
##      SELECT
##
##
##      --fields from the target month
##
##        o.completed_month
##        ,o.payer_name
##        ,o.plan_name
##        ,o.plan_type
##        ,o.disease_panel
##        ,o.product
##        ,o.order_count
##        ,o.sixth_period
##        ,o.fifth_period
##        ,o.fourth_period
##        ,o.third_period
##        ,o.second_period
##        ,o.first_period
##        ,'c_ppldmp' as lookback_type
##
##        --fields from full-criteria (PAYER-PLANTYPE-PLANNAME-DISEASEPANEL-METHODOLOGY-PRODUCT) level look-back
##
##        ,sum(CASE WHEN ppldmp6.completed_month = o.first_period THEN coalesce(ppldmp6.payer_revenue_base_6/(1-six_month_payer),0) ELSE 0 END
##            + CASE WHEN ppldmp6.completed_month = o.second_period THEN coalesce(ppldmp6.payer_revenue_base_5/(1-five_month_payer),0) ELSE 0 END
##            + CASE WHEN ppldmp6.completed_month = o.third_period THEN coalesce(ppldmp6.payer_revenue_base_4/(1-four_month_payer),0) ELSE 0 END
##            + CASE WHEN ppldmp6.completed_month = o.fourth_period THEN coalesce(ppldmp6.payer_revenue_base_3/(1-three_month_payer),0) ELSE 0 END
##            + CASE WHEN ppldmp6.completed_month = o.fifth_period THEN coalesce(ppldmp6.payer_revenue_base_2/(1-two_month_payer),0) ELSE 0 END
##            + CASE WHEN ppldmp6.completed_month = o.sixth_period THEN coalesce(ppldmp6.payer_revenue_base_1/(1-one_month_payer),0) ELSE 0 END
##          ) as segment_payer_revenue
##        ,sum(CASE WHEN ppldmp6.completed_month = o.first_period THEN coalesce(ppldmp6.patient_revenue_base_6/(1-six_month_patient),0) ELSE 0 END
##            + CASE WHEN ppldmp6.completed_month = o.second_period THEN coalesce(ppldmp6.patient_revenue_base_5/(1-five_month_patient),0) ELSE 0 END
##            + CASE WHEN ppldmp6.completed_month = o.third_period THEN coalesce(ppldmp6.patient_revenue_base_4/(1-four_month_patient),0) ELSE 0 END
##            + CASE WHEN ppldmp6.completed_month = o.fourth_period THEN coalesce(ppldmp6.patient_revenue_base_3/(1-three_month_patient),0) ELSE 0 END
##            + CASE WHEN ppldmp6.completed_month = o.fifth_period THEN coalesce(ppldmp6.patient_revenue_base_2/(1-two_month_patient),0) ELSE 0 END
##            + CASE WHEN ppldmp6.completed_month = o.sixth_period THEN coalesce(ppldmp6.patient_revenue_base_1/(1-one_month_patient),0) ELSE 0 END
##          ) as segment_patient_revenue
##        ,sum(CASE
##            WHEN ppldmp6.completed_month = o.sixth_period THEN coalesce(ppldmp6.total_charges,0)
##            WHEN ppldmp6.completed_month = o.fifth_period THEN coalesce(ppldmp6.total_charges,0)
##            WHEN ppldmp6.completed_month = o.fourth_period THEN coalesce(ppldmp6.total_charges,0)
##            WHEN ppldmp6.completed_month = o.third_period THEN coalesce(ppldmp6.total_charges,0)
##            WHEN ppldmp6.completed_month = o.second_period THEN coalesce(ppldmp6.total_charges,0)
##            WHEN ppldmp6.completed_month = o.first_period THEN coalesce(ppldmp6.total_charges,0)
##          ELSE 0 END) as segment_total_charges
##        ,sum(CASE
##            WHEN ppldmp6.completed_month = o.sixth_period THEN coalesce(ppldmp6.order_count,0)
##            WHEN ppldmp6.completed_month = o.fifth_period THEN coalesce(ppldmp6.order_count,0)
##            WHEN ppldmp6.completed_month = o.fourth_period THEN coalesce(ppldmp6.order_count,0)
##            WHEN ppldmp6.completed_month = o.third_period THEN coalesce(ppldmp6.order_count,0)
##            WHEN ppldmp6.completed_month = o.second_period THEN coalesce(ppldmp6.order_count,0)
##            WHEN ppldmp6.completed_month = o.first_period THEN coalesce(ppldmp6.order_count,0)
##          ELSE 0 END) as segment_order_count
##
##
##      FROM
##
##      -- compute values for target month
##
##      ${revenue_inn_target.SQL_TABLE_NAME} AS o
##
##      INNER JOIN
##        uploads.payment_lag_factors as lag on lag.month = o.completed_month
##
##      INNER JOIN
##
##      -- compute values for the sixth_period PAYER-PLANNAME-DISEASEPANEL-METHODOLOGY-PRODUCT match (ppldmp6)
##
##        (SELECT
##          product
##          , disease_panel
##          , payer_name
##          , plan_name
##          , completed_month
##          , sum(coalesce(payer_revenue_base_6,0)) as payer_revenue_base_6
##          , sum(coalesce(payer_revenue_base_5,0)) as payer_revenue_base_5
##          , sum(coalesce(payer_revenue_base_4,0)) as payer_revenue_base_4
##          , sum(coalesce(payer_revenue_base_3,0)) as payer_revenue_base_3
##          , sum(coalesce(payer_revenue_base_2,0)) as payer_revenue_base_2
##          , sum(coalesce(payer_revenue_base_1,0)) as payer_revenue_base_1
##          , sum(coalesce(patient_revenue_base_6,0)) as patient_revenue_base_6
##          , sum(coalesce(patient_revenue_base_5,0)) as patient_revenue_base_5
##          , sum(coalesce(patient_revenue_base_4,0)) as patient_revenue_base_4
##          , sum(coalesce(patient_revenue_base_3,0)) as patient_revenue_base_3
##          , sum(coalesce(patient_revenue_base_2,0)) as patient_revenue_base_2
##          , sum(coalesce(patient_revenue_base_1,0)) as patient_revenue_base_1
##          , SUM(total_charges) AS total_charges
##          , sum(order_count) AS order_count
##        FROM
##          ${revenue_inn_lookback_base.SQL_TABLE_NAME}
##        GROUP BY
##          1,2,3,4,5
##      ) AS ppldmp6
##        ON o.product = ppldmp6.product
##        AND o.disease_panel = ppldmp6.disease_panel
##        AND o.payer_name = ppldmp6.payer_name
##        AND o.plan_name = ppldmp6.plan_name
##
##      GROUP BY
##        1,2,3,4,5,6,7,8,9,10,11,12,13,14
##       ;;
##    sql_trigger_value: select sum(order_count) from ${revenue_inn_lookback_base.SQL_TABLE_NAME} ;;
##  }
##}
##
##view: revenue_inn_match_payer_prod_dp {
##  derived_table: {
##    sql:
##      SELECT
##
##
##      --fields from the target month
##
##        o.completed_month
##        ,o.payer_name
##        ,o.plan_name
##        ,o.plan_type
##        ,o.disease_panel
##        ,o.product
##        ,o.order_count
##        ,o.sixth_period
##        ,o.fifth_period
##        ,o.fourth_period
##        ,o.third_period
##        ,o.second_period
##        ,o.first_period
##        ,'d_pdpmp' as lookback_type
##
##        --fields from full-criteria (PAYER-PLANTYPE-PLANNAME-DISEASEPANEL-METHODOLOGY-PRODUCT) level look-back
##
##        ,sum(CASE WHEN pdpmp6.completed_month = o.first_period THEN coalesce(pdpmp6.payer_revenue_base_6/(1-six_month_payer),0) ELSE 0 END
##            + CASE WHEN pdpmp6.completed_month = o.second_period THEN coalesce(pdpmp6.payer_revenue_base_5/(1-five_month_payer),0) ELSE 0 END
##            + CASE WHEN pdpmp6.completed_month = o.third_period THEN coalesce(pdpmp6.payer_revenue_base_4/(1-four_month_payer),0) ELSE 0 END
##            + CASE WHEN pdpmp6.completed_month = o.fourth_period THEN coalesce(pdpmp6.payer_revenue_base_3/(1-three_month_payer),0) ELSE 0 END
##            + CASE WHEN pdpmp6.completed_month = o.fifth_period THEN coalesce(pdpmp6.payer_revenue_base_2/(1-two_month_payer),0) ELSE 0 END
##            + CASE WHEN pdpmp6.completed_month = o.sixth_period THEN coalesce(pdpmp6.payer_revenue_base_1/(1-one_month_payer),0) ELSE 0 END
##          ) as segment_payer_revenue
##        ,sum(CASE WHEN pdpmp6.completed_month = o.first_period THEN coalesce(pdpmp6.patient_revenue_base_6/(1-six_month_patient),0) ELSE 0 END
##            + CASE WHEN pdpmp6.completed_month = o.second_period THEN coalesce(pdpmp6.patient_revenue_base_5/(1-five_month_patient),0) ELSE 0 END
##            + CASE WHEN pdpmp6.completed_month = o.third_period THEN coalesce(pdpmp6.patient_revenue_base_4/(1-four_month_patient),0) ELSE 0 END
##            + CASE WHEN pdpmp6.completed_month = o.fourth_period THEN coalesce(pdpmp6.patient_revenue_base_3/(1-three_month_patient),0) ELSE 0 END
##            + CASE WHEN pdpmp6.completed_month = o.fifth_period THEN coalesce(pdpmp6.patient_revenue_base_2/(1-two_month_patient),0) ELSE 0 END
##            + CASE WHEN pdpmp6.completed_month = o.sixth_period THEN coalesce(pdpmp6.patient_revenue_base_1/(1-one_month_patient),0) ELSE 0 END
##          ) as segment_patient_revenue
##        ,sum(CASE
##            WHEN pdpmp6.completed_month = o.sixth_period THEN coalesce(pdpmp6.total_charges,0)
##            WHEN pdpmp6.completed_month = o.fifth_period THEN coalesce(pdpmp6.total_charges,0)
##            WHEN pdpmp6.completed_month = o.fourth_period THEN coalesce(pdpmp6.total_charges,0)
##            WHEN pdpmp6.completed_month = o.third_period THEN coalesce(pdpmp6.total_charges,0)
##            WHEN pdpmp6.completed_month = o.second_period THEN coalesce(pdpmp6.total_charges,0)
##            WHEN pdpmp6.completed_month = o.first_period THEN coalesce(pdpmp6.total_charges,0)
##          ELSE 0 END) as segment_total_charges
##        ,sum(CASE
##            WHEN pdpmp6.completed_month = o.sixth_period THEN coalesce(pdpmp6.order_count,0)
##            WHEN pdpmp6.completed_month = o.fifth_period THEN coalesce(pdpmp6.order_count,0)
##            WHEN pdpmp6.completed_month = o.fourth_period THEN coalesce(pdpmp6.order_count,0)
##            WHEN pdpmp6.completed_month = o.third_period THEN coalesce(pdpmp6.order_count,0)
##            WHEN pdpmp6.completed_month = o.second_period THEN coalesce(pdpmp6.order_count,0)
##            WHEN pdpmp6.completed_month = o.first_period THEN coalesce(pdpmp6.order_count,0)
##          ELSE 0 END) as segment_order_count
##
##      FROM
##
##      -- compute values for target month
##
##      ${revenue_inn_target.SQL_TABLE_NAME} AS o
##
##      INNER JOIN
##        uploads.payment_lag_factors as lag on lag.month = o.completed_month
##
##      INNER JOIN
##
##      -- compute values for the sixth_period PAYER-DISEASEPANEL-METHODOLOGY-PRODUCT ONLY match (pdpmp6)
##
##        (SELECT
##          product
##          , disease_panel
##          , payer_name
##          , completed_month
##          , sum(coalesce(payer_revenue_base_6,0)) as payer_revenue_base_6
##          , sum(coalesce(payer_revenue_base_5,0)) as payer_revenue_base_5
##          , sum(coalesce(payer_revenue_base_4,0)) as payer_revenue_base_4
##          , sum(coalesce(payer_revenue_base_3,0)) as payer_revenue_base_3
##          , sum(coalesce(payer_revenue_base_2,0)) as payer_revenue_base_2
##          , sum(coalesce(payer_revenue_base_1,0)) as payer_revenue_base_1
##          , sum(coalesce(patient_revenue_base_6,0)) as patient_revenue_base_6
##          , sum(coalesce(patient_revenue_base_5,0)) as patient_revenue_base_5
##          , sum(coalesce(patient_revenue_base_4,0)) as patient_revenue_base_4
##          , sum(coalesce(patient_revenue_base_3,0)) as patient_revenue_base_3
##          , sum(coalesce(patient_revenue_base_2,0)) as patient_revenue_base_2
##          , sum(coalesce(patient_revenue_base_1,0)) as patient_revenue_base_1
##          , SUM(total_charges) AS total_charges
##          , sum(order_count) AS order_count
##        FROM
##          ${revenue_inn_lookback_base.SQL_TABLE_NAME}
##        GROUP BY
##          1,2,3,4
##        ) AS pdpmp6
##          ON o.product = pdpmp6.product
##          AND o.disease_panel = pdpmp6.disease_panel
##          AND o.payer_name = pdpmp6.payer_name
##
##      GROUP BY
##        1,2,3,4,5,6,7,8,9,10,11,12,13,14
##       ;;
##    sql_trigger_value: select sum(order_count) from ${revenue_inn_lookback_base.SQL_TABLE_NAME} ;;
##  }
##}
##
##view: revenue_inn_match_payer_dp {
##  derived_table: {
##    sql:
##      SELECT
##
##
##      --fields from the target month
##
##        o.completed_month
##        ,o.payer_name
##        ,o.plan_name
##        ,o.plan_type
##        ,o.disease_panel
##        ,o.product
##        ,o.order_count
##        ,o.sixth_period
##        ,o.fifth_period
##        ,o.fourth_period
##        ,o.third_period
##        ,o.second_period
##        ,o.first_period
##        ,'e_pdp' as lookback_type
##
##        --fields from full-criteria (PAYER-PLANTYPE-PLANNAME-DISEASEPANEL-METHODOLOGY-PRODUCT) level look-backs
##
##        ,sum(CASE WHEN pdp6.completed_month = o.first_period THEN coalesce(pdp6.payer_revenue_base_6/(1-six_month_payer),0) ELSE 0 END
##            + CASE WHEN pdp6.completed_month = o.second_period THEN coalesce(pdp6.payer_revenue_base_5/(1-five_month_payer),0) ELSE 0 END
##            + CASE WHEN pdp6.completed_month = o.third_period THEN coalesce(pdp6.payer_revenue_base_4/(1-four_month_payer),0) ELSE 0 END
##            + CASE WHEN pdp6.completed_month = o.fourth_period THEN coalesce(pdp6.payer_revenue_base_3/(1-three_month_payer),0) ELSE 0 END
##            + CASE WHEN pdp6.completed_month = o.fifth_period THEN coalesce(pdp6.payer_revenue_base_2/(1-two_month_payer),0) ELSE 0 END
##            + CASE WHEN pdp6.completed_month = o.sixth_period THEN coalesce(pdp6.payer_revenue_base_1/(1-one_month_payer),0) ELSE 0 END
##          ) as segment_payer_revenue
##        ,sum(CASE WHEN pdp6.completed_month = o.first_period THEN coalesce(pdp6.patient_revenue_base_6/(1-six_month_patient),0) ELSE 0 END
##            + CASE WHEN pdp6.completed_month = o.second_period THEN coalesce(pdp6.patient_revenue_base_5/(1-five_month_patient),0) ELSE 0 END
##            + CASE WHEN pdp6.completed_month = o.third_period THEN coalesce(pdp6.patient_revenue_base_4/(1-four_month_patient),0) ELSE 0 END
##            + CASE WHEN pdp6.completed_month = o.fourth_period THEN coalesce(pdp6.patient_revenue_base_3/(1-three_month_patient),0) ELSE 0 END
##            + CASE WHEN pdp6.completed_month = o.fifth_period THEN coalesce(pdp6.patient_revenue_base_2/(1-two_month_patient),0) ELSE 0 END
##            + CASE WHEN pdp6.completed_month = o.sixth_period THEN coalesce(pdp6.patient_revenue_base_1/(1-one_month_patient),0) ELSE 0 END
##          ) as segment_patient_revenue
##        ,sum(CASE
##            WHEN pdp6.completed_month = o.sixth_period THEN coalesce(pdp6.total_charges,0)
##            WHEN pdp6.completed_month = o.fifth_period THEN coalesce(pdp6.total_charges,0)
##            WHEN pdp6.completed_month = o.fourth_period THEN coalesce(pdp6.total_charges,0)
##            WHEN pdp6.completed_month = o.third_period THEN coalesce(pdp6.total_charges,0)
##            WHEN pdp6.completed_month = o.second_period THEN coalesce(pdp6.total_charges,0)
##            WHEN pdp6.completed_month = o.first_period THEN coalesce(pdp6.total_charges,0)
##          ELSE 0 END) as segment_total_charges
##        ,sum(CASE
##            WHEN pdp6.completed_month = o.sixth_period THEN coalesce(pdp6.order_count,0)
##            WHEN pdp6.completed_month = o.fifth_period THEN coalesce(pdp6.order_count,0)
##            WHEN pdp6.completed_month = o.fourth_period THEN coalesce(pdp6.order_count,0)
##            WHEN pdp6.completed_month = o.third_period THEN coalesce(pdp6.order_count,0)
##            WHEN pdp6.completed_month = o.second_period THEN coalesce(pdp6.order_count,0)
##            WHEN pdp6.completed_month = o.first_period THEN coalesce(pdp6.order_count,0)
##          ELSE 0 END) as segment_order_count
##
##      FROM
##
##      -- compute values for target month
##
##      ${revenue_inn_target.SQL_TABLE_NAME} AS o
##
##      INNER JOIN
##        uploads.payment_lag_factors as lag on lag.month = o.completed_month
##
##      INNER JOIN
##
##      -- compute values for the sixth_period PAYER-DISEASEPANEL ONLY match (pdp6)
##
##        (SELECT
##          disease_panel
##          , payer_name
##          , completed_month
##          , sum(coalesce(payer_revenue_base_6,0)) as payer_revenue_base_6
##          , sum(coalesce(payer_revenue_base_5,0)) as payer_revenue_base_5
##          , sum(coalesce(payer_revenue_base_4,0)) as payer_revenue_base_4
##          , sum(coalesce(payer_revenue_base_3,0)) as payer_revenue_base_3
##          , sum(coalesce(payer_revenue_base_2,0)) as payer_revenue_base_2
##          , sum(coalesce(payer_revenue_base_1,0)) as payer_revenue_base_1
##          , sum(coalesce(patient_revenue_base_6,0)) as patient_revenue_base_6
##          , sum(coalesce(patient_revenue_base_5,0)) as patient_revenue_base_5
##          , sum(coalesce(patient_revenue_base_4,0)) as patient_revenue_base_4
##          , sum(coalesce(patient_revenue_base_3,0)) as patient_revenue_base_3
##          , sum(coalesce(patient_revenue_base_2,0)) as patient_revenue_base_2
##          , sum(coalesce(patient_revenue_base_1,0)) as patient_revenue_base_1
##          , SUM(total_charges) AS total_charges
##          , sum(order_count) AS order_count
##        FROM
##          ${revenue_inn_lookback_base.SQL_TABLE_NAME}
##        GROUP BY
##          1,2,3
##        ) AS pdp6
##          ON o.disease_panel = pdp6.disease_panel
##          AND o.payer_name = pdp6.payer_name
##
##      GROUP BY
##        1,2,3,4,5,6,7,8,9,10,11,12,13,14
##       ;;
##    sql_trigger_value: select sum(order_count) from ${revenue_inn_lookback_base.SQL_TABLE_NAME} ;;
##  }
##}
##
##view: revenue_inn_match_payer_prod {
##  derived_table: {
##    sql:
##      SELECT
##
##
##      --fields from the target month
##
##        o.completed_month
##        ,o.payer_name
##        ,o.plan_name
##        ,o.plan_type
##        ,o.disease_panel
##        ,o.product
##        ,o.order_count
##        ,o.sixth_period
##        ,o.fifth_period
##        ,o.fourth_period
##        ,o.third_period
##        ,o.second_period
##        ,o.first_period
##        ,'f_pp' as lookback_type
##
##        --fields from full-criteria (PAYER-PLANTYPE-PLANNAME-DISEASEPANEL-METHODOLOGY-PRODUCT) level look-back
##
##        ,sum(CASE WHEN pp6.completed_month = o.first_period THEN coalesce(pp6.payer_revenue_base_6/(1-six_month_payer),0) ELSE 0 END
##            + CASE WHEN pp6.completed_month = o.second_period THEN coalesce(pp6.payer_revenue_base_5/(1-five_month_payer),0) ELSE 0 END
##            + CASE WHEN pp6.completed_month = o.third_period THEN coalesce(pp6.payer_revenue_base_4/(1-four_month_payer),0) ELSE 0 END
##            + CASE WHEN pp6.completed_month = o.fourth_period THEN coalesce(pp6.payer_revenue_base_3/(1-three_month_payer),0) ELSE 0 END
##            + CASE WHEN pp6.completed_month = o.fifth_period THEN coalesce(pp6.payer_revenue_base_2/(1-two_month_payer),0) ELSE 0 END
##            + CASE WHEN pp6.completed_month = o.sixth_period THEN coalesce(pp6.payer_revenue_base_1/(1-one_month_payer),0) ELSE 0 END
##          ) as segment_payer_revenue
##        ,sum(CASE WHEN pp6.completed_month = o.first_period THEN coalesce(pp6.patient_revenue_base_6/(1-six_month_patient),0) ELSE 0 END
##            + CASE WHEN pp6.completed_month = o.second_period THEN coalesce(pp6.patient_revenue_base_5/(1-five_month_patient),0) ELSE 0 END
##            + CASE WHEN pp6.completed_month = o.third_period THEN coalesce(pp6.patient_revenue_base_4/(1-four_month_patient),0) ELSE 0 END
##            + CASE WHEN pp6.completed_month = o.fourth_period THEN coalesce(pp6.patient_revenue_base_3/(1-three_month_patient),0) ELSE 0 END
##            + CASE WHEN pp6.completed_month = o.fifth_period THEN coalesce(pp6.patient_revenue_base_2/(1-two_month_patient),0) ELSE 0 END
##            + CASE WHEN pp6.completed_month = o.sixth_period THEN coalesce(pp6.patient_revenue_base_1/(1-one_month_patient),0) ELSE 0 END
##          ) as segment_patient_revenue
##        ,sum(CASE
##            WHEN pp6.completed_month = o.sixth_period THEN coalesce(pp6.total_charges,0)
##            WHEN pp6.completed_month = o.fifth_period THEN coalesce(pp6.total_charges,0)
##            WHEN pp6.completed_month = o.fourth_period THEN coalesce(pp6.total_charges,0)
##            WHEN pp6.completed_month = o.third_period THEN coalesce(pp6.total_charges,0)
##            WHEN pp6.completed_month = o.second_period THEN coalesce(pp6.total_charges,0)
##            WHEN pp6.completed_month = o.first_period THEN coalesce(pp6.total_charges,0)
##          ELSE 0 END) as segment_total_charges
##        ,sum(CASE
##            WHEN pp6.completed_month = o.sixth_period THEN coalesce(pp6.order_count,0)
##            WHEN pp6.completed_month = o.fifth_period THEN coalesce(pp6.order_count,0)
##            WHEN pp6.completed_month = o.fourth_period THEN coalesce(pp6.order_count,0)
##            WHEN pp6.completed_month = o.third_period THEN coalesce(pp6.order_count,0)
##            WHEN pp6.completed_month = o.second_period THEN coalesce(pp6.order_count,0)
##            WHEN pp6.completed_month = o.first_period THEN coalesce(pp6.order_count,0)
##          ELSE 0 END) as segment_order_count
##
##      FROM
##
##      -- compute values for target month
##
##      ${revenue_inn_target.SQL_TABLE_NAME} AS o
##
##      INNER JOIN
##        uploads.payment_lag_factors as lag on lag.month = o.completed_month
##
##      INNER JOIN
##
##      -- compute values for the sixth_period PAYER-PRODUCT-METHODOLOGY LEVEL match (pp6)
##
##        (SELECT
##          product
##          , payer_name
##          , completed_month
##          , sum(coalesce(payer_revenue_base_6,0)) as payer_revenue_base_6
##          , sum(coalesce(payer_revenue_base_5,0)) as payer_revenue_base_5
##          , sum(coalesce(payer_revenue_base_4,0)) as payer_revenue_base_4
##          , sum(coalesce(payer_revenue_base_3,0)) as payer_revenue_base_3
##          , sum(coalesce(payer_revenue_base_2,0)) as payer_revenue_base_2
##          , sum(coalesce(payer_revenue_base_1,0)) as payer_revenue_base_1
##          , sum(coalesce(patient_revenue_base_6,0)) as patient_revenue_base_6
##          , sum(coalesce(patient_revenue_base_5,0)) as patient_revenue_base_5
##          , sum(coalesce(patient_revenue_base_4,0)) as patient_revenue_base_4
##          , sum(coalesce(patient_revenue_base_3,0)) as patient_revenue_base_3
##          , sum(coalesce(patient_revenue_base_2,0)) as patient_revenue_base_2
##          , sum(coalesce(patient_revenue_base_1,0)) as patient_revenue_base_1
##          , SUM(total_charges) AS total_charges
##          , sum(order_count) AS order_count
##        FROM
##          ${revenue_inn_lookback_base.SQL_TABLE_NAME}
##        GROUP BY
##          1,2,3
##        ) AS pp6
##          ON o.product = pp6.product
##          AND o.payer_name = pp6.payer_name
##
##      GROUP BY
##        1,2,3,4,5,6,7,8,9,10,11,12,13,14
##       ;;
##    sql_trigger_value: select sum(order_count) from ${revenue_inn_lookback_base.SQL_TABLE_NAME} ;;
##  }
##}
##
##view: revenue_inn_match_prod {
##  derived_table: {
##    sql:
##      SELECT
##
##        o.completed_month
##        ,o.payer_name
##        ,o.plan_name
##        ,o.plan_type
##        ,o.disease_panel
##        ,o.product
##        ,o.order_count
##        ,o.sixth_period
##        ,o.fifth_period
##        ,o.fourth_period
##        ,o.third_period
##        ,o.second_period
##        ,o.first_period
##        ,'g_po' as lookback_type
##
##
##      --fields from full-criteria (PAYER-PLANTYPE-PLANNAME-DISEASEPANEL-METHODOLOGY-PRODUCT) level look-back
##
##        ,sum(CASE WHEN po6.completed_month = o.first_period THEN coalesce(po6.payer_revenue_base_6/(1-six_month_payer),0) ELSE 0 END
##            + CASE WHEN po6.completed_month = o.second_period THEN coalesce(po6.payer_revenue_base_5/(1-five_month_payer),0) ELSE 0 END
##            + CASE WHEN po6.completed_month = o.third_period THEN coalesce(po6.payer_revenue_base_4/(1-four_month_payer),0) ELSE 0 END
##            + CASE WHEN po6.completed_month = o.fourth_period THEN coalesce(po6.payer_revenue_base_3/(1-three_month_payer),0) ELSE 0 END
##            + CASE WHEN po6.completed_month = o.fifth_period THEN coalesce(po6.payer_revenue_base_2/(1-two_month_payer),0) ELSE 0 END
##            + CASE WHEN po6.completed_month = o.sixth_period THEN coalesce(po6.payer_revenue_base_1/(1-one_month_payer),0) ELSE 0 END
##          ) as segment_payer_revenue
##        ,sum(CASE WHEN po6.completed_month = o.first_period THEN coalesce(po6.patient_revenue_base_6/(1-six_month_patient),0) ELSE 0 END
##            + CASE WHEN po6.completed_month = o.second_period THEN coalesce(po6.patient_revenue_base_5/(1-five_month_patient),0) ELSE 0 END
##            + CASE WHEN po6.completed_month = o.third_period THEN coalesce(po6.patient_revenue_base_4/(1-four_month_patient),0) ELSE 0 END
##            + CASE WHEN po6.completed_month = o.fourth_period THEN coalesce(po6.patient_revenue_base_3/(1-three_month_patient),0) ELSE 0 END
##            + CASE WHEN po6.completed_month = o.fifth_period THEN coalesce(po6.patient_revenue_base_2/(1-two_month_patient),0) ELSE 0 END
##            + CASE WHEN po6.completed_month = o.sixth_period THEN coalesce(po6.patient_revenue_base_1/(1-one_month_patient),0) ELSE 0 END
##          ) as segment_patient_revenue
##        ,sum(CASE
##            WHEN po6.completed_month = o.sixth_period THEN coalesce(po6.total_charges,0)
##            WHEN po6.completed_month = o.fifth_period THEN coalesce(po6.total_charges,0)
##            WHEN po6.completed_month = o.fourth_period THEN coalesce(po6.total_charges,0)
##            WHEN po6.completed_month = o.third_period THEN coalesce(po6.total_charges,0)
##            WHEN po6.completed_month = o.second_period THEN coalesce(po6.total_charges,0)
##            WHEN po6.completed_month = o.first_period THEN coalesce(po6.total_charges,0)
##          ELSE 0 END) as segment_total_charges
##        ,sum(CASE
##            WHEN po6.completed_month = o.sixth_period THEN coalesce(po6.order_count,0)
##            WHEN po6.completed_month = o.fifth_period THEN coalesce(po6.order_count,0)
##            WHEN po6.completed_month = o.fourth_period THEN coalesce(po6.order_count,0)
##            WHEN po6.completed_month = o.third_period THEN coalesce(po6.order_count,0)
##            WHEN po6.completed_month = o.second_period THEN coalesce(po6.order_count,0)
##            WHEN po6.completed_month = o.first_period THEN coalesce(po6.order_count,0)
##          ELSE 0 END) as segment_order_count
##
##      FROM
##
##      -- compute values for target month
##
##      ${revenue_inn_target.SQL_TABLE_NAME} AS o
##
##      INNER JOIN
##        uploads.payment_lag_factors as lag on lag.month = o.completed_month
##
##      INNER JOIN
##
##      -- compute values for the sixth_period PAYER ONLY LEVEL match (po6)
##
##        (SELECT
##          product
##          , completed_month
##          , sum(coalesce(payer_revenue_base_6,0)) as payer_revenue_base_6
##          , sum(coalesce(payer_revenue_base_5,0)) as payer_revenue_base_5
##          , sum(coalesce(payer_revenue_base_4,0)) as payer_revenue_base_4
##          , sum(coalesce(payer_revenue_base_3,0)) as payer_revenue_base_3
##          , sum(coalesce(payer_revenue_base_2,0)) as payer_revenue_base_2
##          , sum(coalesce(payer_revenue_base_1,0)) as payer_revenue_base_1
##          , sum(coalesce(patient_revenue_base_6,0)) as patient_revenue_base_6
##          , sum(coalesce(patient_revenue_base_5,0)) as patient_revenue_base_5
##          , sum(coalesce(patient_revenue_base_4,0)) as patient_revenue_base_4
##          , sum(coalesce(patient_revenue_base_3,0)) as patient_revenue_base_3
##          , sum(coalesce(patient_revenue_base_2,0)) as patient_revenue_base_2
##          , sum(coalesce(patient_revenue_base_1,0)) as patient_revenue_base_1
##          , SUM(total_charges) AS total_charges
##          , sum(order_count) AS order_count
##        FROM
##          ${revenue_inn_lookback_base.SQL_TABLE_NAME}
##        GROUP BY
##          1,2
##        ) AS po6
##          ON o.product = po6.product
##
##      GROUP BY
##        1,2,3,4,5,6,7,8,9,10,11,12,13,14
##       ;;
##    sql_trigger_value: select sum(order_count) from ${revenue_inn_lookback_base.SQL_TABLE_NAME} ;;
##  }
##}
##
##view: revenue_inn_target_moop {
##  derived_table: {
##    sql: SELECT
##        to_date(TO_CHAR(o.completed_on, 'YYYY-MM'),'YYYY-MM') AS completed_month
##        , to_date(TO_CHAR(o.completed_on - INTERVAL '3 month', 'YYYY-MM'),'YYYY-MM') AS sixth_period
##        , to_date(TO_CHAR(o.completed_on - INTERVAL '4 month', 'YYYY-MM'),'YYYY-MM') AS fifth_period
##        , to_date(TO_CHAR(o.completed_on - INTERVAL '5 month', 'YYYY-MM'),'YYYY-MM') AS fourth_period
##        , to_date(TO_CHAR(o.completed_on - INTERVAL '6 month', 'YYYY-MM'),'YYYY-MM') AS third_period
##        , to_date(TO_CHAR(o.completed_on - INTERVAL '7 month', 'YYYY-MM'),'YYYY-MM') AS second_period
##        , to_date(TO_CHAR(o.completed_on - INTERVAL '8 month', 'YYYY-MM'),'YYYY-MM') AS first_period
##        , CASE
##          WHEN has_ips_high_risk = TRUE and o.product_name = 'Prelude Prenatal Screen'  THEN 'Prelude Prenatal Screen - High Risk'
##          WHEN has_ips_high_risk = FALSE and o.product_name = 'Prelude Prenatal Screen'  THEN 'Prelude Prenatal Screen - Low Risk'
##          WHEN has_ips_high_risk is null and o.product_name = 'Prelude Prenatal Screen' THEN 'Prelude Prenatal Screen - Low Risk'
##          ELSE o.product_name END as product
##        , CASE WHEN position('Medicare' in insurancepayer.name) = 1 THEN 'Medicare Group' ELSE insurancepayer.name END as payer_name
##        , CASE
##          WHEN o.product = 'Foresight Carrier Screen' and date_of_service >= inn.fps_date and date_of_service < coalesce(inn.fps_term,'2100-01-01'::date)
##            THEN 'In Net'
##          WHEN o.product = 'Reliant Cancer Screen' and date_of_service >= inn.ics_date and date_of_service < coalesce(inn.ics_term,'2100-01-01'::date)
##            THEN 'In Net'
##          WHEN o.product = 'Prelude Prenatal Screen' and date_of_service >= inn.ips_date and date_of_service < coalesce(inn.ips_term,'2100-01-01'::date)
##            THEN 'In Net'
##          ELSE 'OON'
##          END as network_status
##        , COUNT(DISTINCT o.id) AS order_count
##      FROM
##        ${order.SQL_TABLE_NAME} as o
##      LEFT JOIN
##        ${notable_diagnoses.SQL_TABLE_NAME} as nd on nd.order_id = o.id
##      INNER JOIN
##        current.insuranceclaim as insuranceclaim ON insuranceclaim.order_id = o.id
##      INNER JOIN
##        current.insurancepayer ON insurancepayer.id = insuranceclaim.payer_id
##      LEFT JOIN
##        uploads.in_network_dates_w_terminal inn on inn.id = insurancepayer.id
##
##      WHERE
##        (CASE
##          WHEN o.product = 'Foresight Carrier Screen' and date_of_service >= inn.fps_date and date_of_service < coalesce(inn.fps_term,'2100-01-01'::date)
##            THEN 'In Net'
##          WHEN o.product = 'Reliant Cancer Screen' and date_of_service >= inn.ics_date and date_of_service < coalesce(inn.ics_term,'2100-01-01'::date)
##            THEN 'In Net'
##          WHEN o.product = 'Prelude Prenatal Screen' and date_of_service >= inn.ips_date and date_of_service < coalesce(inn.ips_term,'2100-01-01'::date)
##            THEN 'In Net'
##          ELSE 'OON'
##          END) = 'In Net'
##        and o.bill_type = 'in'
##        and (status_name = 'Canceled Chose Cash'
##        or status_name = 'Canceled Chose Consignment'
##        or status_name = 'Maximum OOP - No Insurance')
##
##      GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
##       ;;
##    sql_trigger_value: select count(*) from ${matched_report_2014_to_current.SQL_TABLE_NAME} ;;
##  }
##}
##
##view: revenue_inn_lookback_base_moop {
##  derived_table: {
##    sql: SELECT
##        to_date(to_char(o.completed_on, 'YYYY-MM'),'YYYY-MM') AS completed_month
##        , CASE
##          WHEN has_ips_high_risk = TRUE and o.product_name = 'Prelude Prenatal Screen'  THEN 'Prelude Prenatal Screen - High Risk'
##          WHEN has_ips_high_risk = FALSE and o.product_name = 'Prelude Prenatal Screen'  THEN 'Prelude Prenatal Screen - Low Risk'
##          WHEN has_ips_high_risk is null and o.product_name = 'Prelude Prenatal Screen' THEN 'Prelude Prenatal Screen - Low Risk'
##          ELSE o.product_name END as product
##        , CASE WHEN position('Medicare' in insurancepayer.name) = 1 THEN 'Medicare Group' ELSE insurancepayer.name END as payer_name
##        , sum(coalesce(revenue_base_6,0)) as revenue_base_6
##        , sum(coalesce(revenue_base_5,0)) as revenue_base_5
##        , sum(coalesce(revenue_base_4,0)) as revenue_base_4
##        , sum(coalesce(revenue_base_3,0)) as revenue_base_3
##        , sum(coalesce(revenue_base_2,0)) as revenue_base_2
##        , sum(coalesce(revenue_base_1,0)) as revenue_base_1
##        , SUM(insuranceclaim.total_charges) AS total_charges
##        , COUNT(DISTINCT o.id) AS order_count
##      FROM
##        ${order.SQL_TABLE_NAME} as o
##      LEFT JOIN
##        ${notable_diagnoses.SQL_TABLE_NAME} as nd on nd.order_id = o.id
##      LEFT JOIN
##        (SELECT
##          order_id
##          , barcode
##          , claim_id
##          , SUM(CASE WHEN deposit_month <= TO_CHAR(completed_on + INTERVAL '7 month', 'YYYY-MM') THEN match.patient_payment_amount ELSE 0 END) AS revenue_base_6
##          , SUM(CASE WHEN deposit_month <= TO_CHAR(completed_on + INTERVAL '6 month', 'YYYY-MM') THEN match.patient_payment_amount ELSE 0 END) AS revenue_base_5
##          , SUM(CASE WHEN deposit_month <= TO_CHAR(completed_on + INTERVAL '5 month', 'YYYY-MM') THEN match.patient_payment_amount ELSE 0 END) AS revenue_base_4
##          , SUM(CASE WHEN deposit_month <= TO_CHAR(completed_on + INTERVAL '4 month', 'YYYY-MM') THEN match.patient_payment_amount ELSE 0 END) AS revenue_base_3
##          , SUM(CASE WHEN deposit_month <= TO_CHAR(completed_on + INTERVAL '3 month', 'YYYY-MM') THEN match.patient_payment_amount ELSE 0 END) AS revenue_base_2
##          , SUM(CASE WHEN deposit_month <= TO_CHAR(completed_on + INTERVAL '2 month', 'YYYY-MM') THEN match.patient_payment_amount ELSE 0 END) AS revenue_base_1
##        FROM
##          (SELECT
##            order_id
##            , barcode
##            , claim_id
##            , completed_on
##            , to_char(deposit_date, 'YYYY-MM') as deposit_month
##            , SUM( CASE WHEN invoice_type = 'Customer' THEN hybrid_transaction_amt ELSE 0 END) as patient_payment_amount
##          FROM
##            ${matched_report_2014_to_current.SQL_TABLE_NAME} as m
##          WHERE
##            ref_pay != 'Refund'
##          GROUP BY
##            1,2,3,4,5
##          ) as match
##        GROUP BY
##          1,2,3
##        ) AS m ON m.order_id::int = o.id::int
##        LEFT JOIN
##          current.insuranceclaim as insuranceclaim ON insuranceclaim.order_id = o.id
##        LEFT JOIN
##          current.insurancepayer on insurancepayer.id = insuranceclaim.payer_id
##        LEFT JOIN
##          uploads.in_network_dates_w_terminal inn on inn.id = insurancepayer.id
##
##      WHERE
##        (CASE
##          WHEN o.product = 'Foresight Carrier Screen' and date_of_service >= inn.fps_date and date_of_service < coalesce(inn.fps_term,'2100-01-01'::date)
##            THEN 'In Net'
##          WHEN o.product = 'Reliant Cancer Screen' and date_of_service >= inn.ics_date and date_of_service < coalesce(inn.ics_term,'2100-01-01'::date)
##            THEN 'In Net'
##          WHEN o.product = 'Prelude Prenatal Screen' and date_of_service >= inn.ips_date and date_of_service < coalesce(inn.ips_term,'2100-01-01'::date)
##            THEN 'In Net'
##          ELSE 'OON'
##          END) = 'In Net'
##        and o.bill_type = 'in'
##        and (status_name = 'Canceled Chose Cash'
##        or status_name = 'Canceled Chose Consignment'
##        or status_name = 'Maximum OOP - No Insurance')
##      GROUP BY 1, 2, 3
##       ;;
##    sql_trigger_value: select sum(order_count) from ${revenue_inn_target_moop.SQL_TABLE_NAME} as rev ;;
##  }
##}
##
##view: revenue_inn_match_payer_prod_moop {
##  derived_table: {
##    sql:
##      SELECT
##
##
##      --fields from the target month
##
##        o.completed_month
##        ,o.payer_name
##        ,o.product
##        ,o.order_count
##        ,o.sixth_period
##        ,o.fifth_period
##        ,o.fourth_period
##        ,o.third_period
##        ,o.second_period
##        ,o.first_period
##        ,'a_pp' as lookback_type
##
##        --fields from full-criteria (PAYER-PLANTYPE-PLANNAME-DISEASEPANEL-METHODOLOGY-PRODUCT) level look-back
##
##
##        ,sum(CASE WHEN pp6.completed_month = o.first_period THEN coalesce(pp6.revenue_base_6/(1-six_month_patient),0) ELSE 0 END
##            + CASE WHEN pp6.completed_month = o.second_period THEN coalesce(pp6.revenue_base_5/(1-five_month_patient),0) ELSE 0 END
##            + CASE WHEN pp6.completed_month = o.third_period THEN coalesce(pp6.revenue_base_4/(1-four_month_patient),0) ELSE 0 END
##            + CASE WHEN pp6.completed_month = o.fourth_period THEN coalesce(pp6.revenue_base_3/(1-three_month_patient),0) ELSE 0 END
##            + CASE WHEN pp6.completed_month = o.fifth_period THEN coalesce(pp6.revenue_base_2/(1-two_month_patient),0) ELSE 0 END
##            + CASE WHEN pp6.completed_month = o.sixth_period THEN coalesce(pp6.revenue_base_1/(1-one_month_patient),0) ELSE 0 END
##          ) as segment_revenue
##        ,sum(CASE
##            WHEN pp6.completed_month = o.sixth_period THEN coalesce(pp6.total_charges,0)
##            WHEN pp6.completed_month = o.fifth_period THEN coalesce(pp6.total_charges,0)
##            WHEN pp6.completed_month = o.fourth_period THEN coalesce(pp6.total_charges,0)
##            WHEN pp6.completed_month = o.third_period THEN coalesce(pp6.total_charges,0)
##            WHEN pp6.completed_month = o.second_period THEN coalesce(pp6.total_charges,0)
##            WHEN pp6.completed_month = o.first_period THEN coalesce(pp6.total_charges,0)
##          ELSE 0 END) as segment_total_charges
##        ,sum(CASE
##            WHEN pp6.completed_month = o.sixth_period THEN coalesce(pp6.order_count,0)
##            WHEN pp6.completed_month = o.fifth_period THEN coalesce(pp6.order_count,0)
##            WHEN pp6.completed_month = o.fourth_period THEN coalesce(pp6.order_count,0)
##            WHEN pp6.completed_month = o.third_period THEN coalesce(pp6.order_count,0)
##            WHEN pp6.completed_month = o.second_period THEN coalesce(pp6.order_count,0)
##            WHEN pp6.completed_month = o.first_period THEN coalesce(pp6.order_count,0)
##          ELSE 0 END) as segment_order_count
##
##      FROM
##
##      -- compute values for target month
##
##      ${revenue_inn_target_moop.SQL_TABLE_NAME} AS o
##
##      INNER JOIN
##        uploads.payment_lag_factors as lag on lag.month = o.completed_month
##
##      INNER JOIN
##
##      -- compute values for the sixth_period PAYER-PRODUCT-METHODOLOGY LEVEL match (pp6)
##
##        (SELECT
##          completed_month
##          , product
##          , payer_name
##          , sum(revenue_base_6) as revenue_base_6
##          , sum(revenue_base_5) as revenue_base_5
##          , sum(revenue_base_4) as revenue_base_4
##          , sum(revenue_base_3) as revenue_base_3
##          , sum(revenue_base_2) as revenue_base_2
##          , sum(revenue_base_1) as revenue_base_1
##          , sum(total_charges) as total_charges
##          , sum(order_count) as order_count
##        FROM
##          ${revenue_inn_lookback_base_moop.SQL_TABLE_NAME}
##        GROUP BY
##          1,2,3
##        ) AS pp6
##          ON o.product = pp6.product
##          AND o.payer_name = pp6.payer_name
##
##      GROUP BY
##        1,2,3,4,5,6,7,8,9,10,11
##       ;;
##    sql_trigger_value: select sum(order_count) from  ${revenue_inn_lookback_base_moop.SQL_TABLE_NAME} ;;
##  }
##}
##
##view: revenue_inn_match_prod_moop {
##  derived_table: {
##    sql:
##      SELECT
##
##        o.completed_month
##        ,o.payer_name
##        ,o.product
##        ,o.order_count
##        ,o.sixth_period
##        ,o.fifth_period
##        ,o.fourth_period
##        ,o.third_period
##        ,o.second_period
##        ,o.first_period
##        ,'b_po' as lookback_type
##
##
##      --fields from full-criteria (PAYER-PLANTYPE-PLANNAME-DISEASEPANEL-METHODOLOGY-PRODUCT) level look-back
##
##
##        ,sum(CASE WHEN po6.completed_month = o.first_period THEN coalesce(po6.revenue_base_6/(1-six_month_patient),0) ELSE 0 END
##            + CASE WHEN po6.completed_month = o.second_period THEN coalesce(po6.revenue_base_5/(1-five_month_patient),0) ELSE 0 END
##            + CASE WHEN po6.completed_month = o.third_period THEN coalesce(po6.revenue_base_4/(1-four_month_patient),0) ELSE 0 END
##            + CASE WHEN po6.completed_month = o.fourth_period THEN coalesce(po6.revenue_base_3/(1-three_month_patient),0) ELSE 0 END
##            + CASE WHEN po6.completed_month = o.fifth_period THEN coalesce(po6.revenue_base_2/(1-two_month_patient),0) ELSE 0 END
##            + CASE WHEN po6.completed_month = o.sixth_period THEN coalesce(po6.revenue_base_1/(1-one_month_patient),0) ELSE 0 END
##          ) as segment_revenue
##        ,sum(CASE
##            WHEN po6.completed_month = o.sixth_period THEN coalesce(po6.total_charges,0)
##            WHEN po6.completed_month = o.fifth_period THEN coalesce(po6.total_charges,0)
##            WHEN po6.completed_month = o.fourth_period THEN coalesce(po6.total_charges,0)
##            WHEN po6.completed_month = o.third_period THEN coalesce(po6.total_charges,0)
##            WHEN po6.completed_month = o.second_period THEN coalesce(po6.total_charges,0)
##            WHEN po6.completed_month = o.first_period THEN coalesce(po6.total_charges,0)
##          ELSE 0 END) as segment_total_charges
##        ,sum(CASE
##            WHEN po6.completed_month = o.sixth_period THEN coalesce(po6.order_count,0)
##            WHEN po6.completed_month = o.fifth_period THEN coalesce(po6.order_count,0)
##            WHEN po6.completed_month = o.fourth_period THEN coalesce(po6.order_count,0)
##            WHEN po6.completed_month = o.third_period THEN coalesce(po6.order_count,0)
##            WHEN po6.completed_month = o.second_period THEN coalesce(po6.order_count,0)
##            WHEN po6.completed_month = o.first_period THEN coalesce(po6.order_count,0)
##          ELSE 0 END) as segment_order_count
##
##      FROM
##
##      -- compute values for target month
##
##      ${revenue_inn_target_moop.SQL_TABLE_NAME} AS o
##
##      INNER JOIN
##        uploads.payment_lag_factors as lag on lag.month = o.completed_month
##
##      INNER JOIN
##
##      -- compute values for the sixth_period PAYER ONLY LEVEL match (po6)
##
##        (SELECT
##          completed_month
##          , product
##          , sum(revenue_base_6) as revenue_base_6
##          , sum(revenue_base_5) as revenue_base_5
##          , sum(revenue_base_4) as revenue_base_4
##          , sum(revenue_base_3) as revenue_base_3
##          , sum(revenue_base_2) as revenue_base_2
##          , sum(revenue_base_1) as revenue_base_1
##          , sum(total_charges) as total_charges
##          , sum(order_count) as order_count
##        FROM
##          ${revenue_inn_lookback_base_moop.SQL_TABLE_NAME}
##        GROUP BY
##          1,2
##        ) AS po6
##        ON o.product = po6.product
##
##      GROUP BY
##        1,2,3,4,5,6,7,8,9,10,11
##       ;;
##    sql_trigger_value: select sum(order_count) from ${revenue_inn_lookback_base_moop.SQL_TABLE_NAME} ;;
##  }
##}
##
##view: revenue_inn_union_lookbacks {
##  derived_table: {
##    sql: WITH unions as
##        (SELECT * FROM ${revenue_inn_match_all_fields.SQL_TABLE_NAME} a where segment_order_count > 3
##          UNION ALL SELECT * FROM ${revenue_inn_match_payer_plantype_prod_dp.SQL_TABLE_NAME} b where segment_order_count > 3
##          UNION ALL SELECT * FROM ${revenue_inn_match_payer_planname_prod_dp.SQL_TABLE_NAME} c where segment_order_count > 3
##          UNION ALL SELECT * FROM ${revenue_inn_match_payer_prod_dp.SQL_TABLE_NAME} d where segment_order_count > 3
##          UNION ALL SELECT * FROM ${revenue_inn_match_payer_dp.SQL_TABLE_NAME} e where segment_order_count > 3
##          UNION ALL SELECT * FROM ${revenue_inn_match_payer_prod.SQL_TABLE_NAME} f where segment_order_count > 3
##          UNION ALL SELECT * FROM ${revenue_inn_match_prod.SQL_TABLE_NAME} g where segment_order_count > 3
##        )
##
##      SELECT *, row_number() over(partition by completed_month,product,plan_name,plan_type,disease_panel,payer_name order by lookback_type) as row_num FROM UNIONS
##       ;;
##    sql_trigger_value: select sum(trigger) from ( select sum(segment_order_count) as trigger from ${revenue_inn_match_all_fields.SQL_TABLE_NAME} union all select sum(segment_order_count) as trigger from ${revenue_inn_match_payer_plantype_prod_dp.SQL_TABLE_NAME} union all select sum(segment_order_count) as trigger from ${revenue_inn_match_payer_planname_prod_dp.SQL_TABLE_NAME} union all select sum(segment_order_count) as trigger from ${revenue_inn_match_payer_prod_dp.SQL_TABLE_NAME} union all select sum(segment_order_count) as trigger from ${revenue_inn_match_payer_dp.SQL_TABLE_NAME} union all select sum(segment_order_count) as trigger from ${revenue_inn_match_payer_prod.SQL_TABLE_NAME} union all select sum(segment_order_count) as trigger from ${revenue_inn_match_prod.SQL_TABLE_NAME}) as t ;;
##    indexes: ["row_num"]
##  }
##}
##
##view: revenue_inn_moop_union_lookbacks {
##  derived_table: {
##    sql: WITH unions as
##        (SELECT * FROM ${revenue_inn_match_payer_prod_moop.SQL_TABLE_NAME} a where segment_order_count > 3
##          UNION ALL SELECT * FROM ${revenue_inn_match_prod_moop.SQL_TABLE_NAME} b where segment_order_count > 3
##        )
##
##      SELECT *, row_number() over(partition by completed_month,product,payer_name order by lookback_type) as row_num FROM UNIONS
##       ;;
##    sql_trigger_value: select sum(trigger) from ( select sum(segment_order_count) as trigger from ${revenue_inn_match_payer_prod_moop.SQL_TABLE_NAME} union all select sum(segment_order_count) as trigger from ${revenue_inn_match_prod_moop.SQL_TABLE_NAME}) as t ;;
##    indexes: ["row_num"]
##  }
##}
##
##view: revenue_inn {
##  derived_table: {
##    sql: SELECT
##
##                    rb.product
##                    , rb.disease_panel
##                    , sum(rb.order_count) as order_count
##                    , rb.payer_name
##                    , rb.plan_name
##                    , rb.plan_type
##                    , rb.completed_month
##
##                    , SUM(rb.segment_payer_revenue)
##                    / (nullif(sum(rb.segment_total_charges),0)) as revenue_percent
##                    , SUM(rb.segment_patient_revenue)
##                    / (nullif(sum(rb.segment_order_count),0)) as avg_payment
##
##
##                  FROM ${revenue_inn_union_lookbacks.SQL_TABLE_NAME} as rb
##                  WHERE row_num = 1
##                  GROUP BY 1,2,4,5,6,7
##                   ;;
##    sql_trigger_value: select sum(segment_order_count) from ${revenue_inn_union_lookbacks.SQL_TABLE_NAME} ;;
##  }
##}
##
##view: revenue_inn_moop {
##  derived_table: {
##    sql: SELECT
##        rb.product
##        , sum(rb.order_count) as order_count
##        , rb.payer_name
##        , rb.completed_month
##
##        , SUM(rb.segment_revenue)
##        / (nullif(sum(rb.segment_order_count),0)) as avg_payment
##
##
##      FROM ${revenue_inn_moop_union_lookbacks.SQL_TABLE_NAME} as rb
##      WHERE row_num = 1
##      GROUP BY 1,3,4
##      ORDER BY 1 DESC
##       ;;
##    sql_trigger_value: select sum(segment_order_count) from ${revenue_inn_moop_union_lookbacks.SQL_TABLE_NAME} ;;
##  }
##}
##
##view: revenue_inn_moop_barcode {
##  derived_table: {
##    sql: SELECT
##        order_id
##        , claim_id
##        , completed_on
##        , latest_barcode
##        , o.payer_name
##        , o.product
##        , o.disease_panel
##        , o.plan_name
##        , o.plan_type
##        , CASE
##          WHEN o.bill_type = 'in'
##            and (status_name = 'Canceled Chose Cash'
##            or status_name = 'Canceled Chose Consignment'
##            or status_name = 'Maximum OOP - No Insurance') THEN avg_payment ELSE 0 END as revenue
##        , status_name
##
##      FROM
##        (SELECT
##          o.id as order_id
##          , insuranceclaim.id as claim_id
##          , completed_on
##          , latest_barcode
##          , CASE WHEN position('Medicare' in insurancepayer.name) = 1 THEN 'Medicare Group' ELSE insurancepayer.name END as payer_name
##          , CASE
##             WHEN has_ips_high_risk = TRUE and o.product_name = 'Prelude Prenatal Screen'  THEN 'Prelude Prenatal Screen - High Risk'
##             WHEN has_ips_high_risk = FALSE and o.product_name = 'Prelude Prenatal Screen'  THEN 'Prelude Prenatal Screen - Low Risk'
##             WHEN has_ips_high_risk is null and o.product_name = 'Prelude Prenatal Screen' THEN 'Prelude Prenatal Screen - Low Risk'
##             ELSE o.product_name END as product
##          , disease_panel
##          , plan_name
##          , plan_type
##          , insuranceclaim.status_name
##          , bill_type
##          , total_charges
##        FROM
##          ${order.SQL_TABLE_NAME} as o
##        LEFT JOIN
##          ${notable_diagnoses.SQL_TABLE_NAME} as nd on nd.order_id = o.id
##        INNER JOIN
##          current.insuranceclaim as insuranceclaim on insuranceclaim.order_id = o.id
##        INNER JOIN
##          current.insurancepayer on insurancepayer.id = insuranceclaim.payer_id
##        LEFT JOIN
##          uploads.in_network_dates_w_terminal inn on inn.id = insurancepayer.id
##        WHERE
##          (CASE
##            WHEN o.product = 'Foresight Carrier Screen' and date_of_service >= inn.fps_date and date_of_service < coalesce(inn.fps_term,'2100-01-01'::date)
##              THEN 'In Net'
##            WHEN o.product = 'Reliant Cancer Screen' and date_of_service >= inn.ics_date and date_of_service < coalesce(inn.ics_term,'2100-01-01'::date)
##              THEN 'In Net'
##            WHEN o.product = 'Prelude Prenatal Screen' and date_of_service >= inn.ips_date and date_of_service < coalesce(inn.ips_term,'2100-01-01'::date)
##              THEN 'In Net'
##            ELSE 'OON'
##            END) = 'In Net'
##
##          and o.clinic_id != 4005 and o.clinic_id != 3334 and o.clinic_id != 3458 and o.clinic_id != 10040
##        ) as o
##      LEFT JOIN
##        ${revenue_inn_moop.SQL_TABLE_NAME} as rev on rev.payer_name = o.payer_name
##          and rev.product = o.product
##          and to_char(rev.completed_month, 'YYYY-MM') = to_char(o.completed_on,'YYYY-MM')
##      GROUP BY
##        1,2,3,4,5,6,7,8,9,10,11
##       ;;
##    sql_trigger_value: select sum(avg_payment) from ${revenue_inn_moop.SQL_TABLE_NAME} ;;
##  }
##
##  dimension: order_id {
##    type: number
##    sql: ${TABLE}.order_id ;;
##  }
##
##  dimension: claim_id {
##    type: number
##    sql: ${TABLE}.claim_id ;;
##  }
##
##  dimension: claim_status {
##    sql: ${TABLE}.status_name ;;
##  }
##
##  dimension_group: completed_on {
##    type: time
##    timeframes: [quarter, date, month, year]
##    sql: ${TABLE}.completed_on ;;
##  }
##
##  dimension: barcode {
##    sql: ${TABLE}.latest_barcode ;;
##  }
##
##  dimension: product {
##    sql: ${TABLE}.product ;;
##  }
##
##  dimension: disease_panel {
##    sql: ${TABLE}.disease_panel ;;
##  }
##
##  dimension: methodology {
##    type: number
##    sql: ${TABLE}.testing_methodology ;;
##  }
##
##  dimension_group: test_completed {
##    type: time
##    timeframes: [quarter, month, year]
##    sql: ${TABLE}.completed_on ;;
##  }
##
##  dimension: payer_name {
##    sql: ${TABLE}.payer_name ;;
##  }
##
##  dimension: plan_name {
##    sql: ${TABLE}.plan_name ;;
##  }
##
##  dimension: plan_type {
##    sql: ${TABLE}.plan_type ;;
##  }
##
##  dimension: revenue {
##    type: number
##    value_format_name: usd_0
##    sql: ${TABLE}.revenue ;;
##  }
##
##  measure: total_revenue {
##    value_format_name: usd_0
##    type: sum
##    sql: ${revenue} ;;
##  }
##
##  measure: count {
##    type: count
##  }
##}
##
##view: revenue_inn_barcode {
##  view_label: " In-Network Revenue"
##
##  derived_table: {
##    sql: SELECT
##        o.order_id
##        , o.claim_id
##        , o.completed_on
##        , o.latest_barcode
##        , o.payer_name
##        , o.payer_id
##        , o.product
##        , o.disease_panel
##        , o.plan_name
##        , o.plan_type
##        , CASE
##          WHEN o.status_name = 'Canceled Chose Cash'
##            or o.status_name = 'Canceled Chose Consignment'
##            or o.status_name = 'Maximum OOP - No Insurance' THEN 0 ELSE rev.revenue_percent END as payer_revenue_percent
##        , CASE
##          WHEN o.status_name = 'Canceled Chose Cash'
##            or o.status_name = 'Canceled Chose Consignment'
##            or o.status_name = 'Maximum OOP - No Insurance' THEN 0 ELSE rev.revenue_percent * total_charges END as payer_revenue
##        , CASE WHEN clinic_id = 3334 or clinic_id = 4005 or clinic_id = 3458 or clinic_id = 10040 THEN 0 ELSE
##          CASE
##            WHEN o.status_name = 'Canceled Chose Cash'
##              or o.status_name = 'Canceled Chose Consignment'
##              or o.status_name = 'Maximum OOP - No Insurance' THEN 0 ELSE avg_payment END END as regular_patient_revenue
##        , CASE
##          WHEN o.status_name = 'Canceled Chose Cash'
##            or o.status_name = 'Canceled Chose Consignment'
##            or o.status_name = 'Maximum OOP - No Insurance' THEN moop_rev.revenue ELSE 0 END as moop_patient_revenue
##        , o.status_name
##        , o.order_status_name
##        , o.total_charges
##
##      FROM
##        (SELECT
##          o.id as order_id
##          , insuranceclaim.id as claim_id
##          , completed_on
##          , latest_barcode
##          , CASE WHEN position('Medicare' in insurancepayer.name) = 1 THEN 'Medicare Group' ELSE insurancepayer.name END as payer_name
##          , payer_id
##          , CASE
##              WHEN has_ips_high_risk = TRUE and o.product_name = 'Prelude Prenatal Screen'  THEN 'Prelude Prenatal Screen - High Risk'
##              WHEN has_ips_high_risk = FALSE and o.product_name = 'Prelude Prenatal Screen'  THEN 'Prelude Prenatal Screen - Low Risk'
##              WHEN has_ips_high_risk is null and o.product_name = 'Prelude Prenatal Screen' THEN 'Prelude Prenatal Screen - Low Risk'
##              ELSE o.product_name END as product
##          , disease_panel
##          , plan_name
##          , plan_type
##          , insuranceclaim.status_name
##          , total_charges
##          , clinic_id
##          , o.status AS order_status_name
##        FROM
##          ${order.SQL_TABLE_NAME} as o
##        LEFT JOIN
##          ${notable_diagnoses.SQL_TABLE_NAME} as nd on nd.order_id = o.id
##        INNER JOIN
##          current.insuranceclaim as insuranceclaim on insuranceclaim.order_id = o.id
##        INNER JOIN
##          current.insurancepayer on insurancepayer.id = insuranceclaim.payer_id
##        LEFT JOIN
##          uploads.in_network_dates_w_terminal inn on inn.id = insurancepayer.id
##
##        WHERE
##          (CASE
##            WHEN o.product = 'Foresight Carrier Screen' and date_of_service >= inn.fps_date and date_of_service < coalesce(inn.fps_term,'2100-01-01'::date)
##              THEN 'In Net'
##            WHEN o.product = 'Reliant Cancer Screen' and date_of_service >= inn.ics_date and date_of_service < coalesce(inn.ics_term,'2100-01-01'::date)
##              THEN 'In Net'
##            WHEN o.product = 'Prelude Prenatal Screen' and date_of_service >= inn.ips_date and date_of_service < coalesce(inn.ips_term,'2100-01-01'::date)
##              THEN 'In Net'
##            ELSE 'OON'
##            END) = 'In Net'
##          AND latest_barcode is not null
##        ) as o
##      LEFT JOIN
##        ${revenue_inn.SQL_TABLE_NAME} as rev on rev.payer_name = o.payer_name
##          and coalesce(rev.plan_name,'') = coalesce(o.plan_name,'')
##          and coalesce(rev.plan_type,'') = coalesce(o.plan_type,'')
##          and rev.product = o.product
##          and rev.disease_panel = o.disease_panel
##          and to_char(rev.completed_month, 'YYYY-MM') = to_char(o.completed_on,'YYYY-MM')
##      LEFT JOIN
##        ${revenue_inn_moop_barcode.SQL_TABLE_NAME} as moop_rev on moop_rev.order_id = o.order_id
##      GROUP BY
##        1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17
##       ;;
##    sql_trigger_value: select sum(trigger) from ( select sum(avg_payment) as trigger from ${revenue_inn.SQL_TABLE_NAME} union all select sum(revenue) as trigger from ${revenue_inn_moop_barcode.SQL_TABLE_NAME}) as t ;;
##    indexes: ["product", "disease_panel", "order_id"]
##  }
##
##  measure: dollar_divider {
##    label: "$ ==== $ $ $ VALUES ==== $"
##    type: string
##    sql: 'DO NOT USE'
##      ;;
##  }
##
##  measure: count_divider {
##    label: "# === # # # COUNT VALUES === #"
##    type: string
##    sql: 'DO NOT USE'
##      ;;
##  }
##
##  measure: time_divider {
##    label: ": == : : : TIME VALUES == :"
##    type: string
##    sql: 'DO NOT USE'
##      ;;
##  }
##
##  measure: percent_divider {
##    label: "% == % % % PERCENT VALUES == %"
##    type: string
##    sql: 'DO NOT USE'
##      ;;
##  }
##
##  measure: drill_divider {
##    label: "| == DRILL-DOWN-ONLY VALUES == |"
##    type: string
##    sql: 'DO NOT USE'
##      ;;
##  }
##
##  measure: dashboard_divider {
##    label: "~ = DASHBOARD-ONLY VALUES = ~"
##    type: string
##    sql: 'DO NOT USE'
##      ;;
##  }
##
##  dimension: total_charges {
##    sql: ${TABLE}.total_charges ;;
##  }
##
##  dimension: order_id {
##    primary_key: yes
##    type: number
##    sql: ${TABLE}.order_id ;;
##  }
##
##  dimension: claim_id {
##    type: number
##    sql: ${TABLE}.claim_id ;;
##  }
##
##  dimension: claim_status {
##    sql: ${TABLE}.status_name ;;
##  }
##
##  dimension_group: completed_on {
##    type: time
##    timeframes: [quarter, date, month, year]
##    sql: ${TABLE}.completed_on ;;
##  }
##
##  dimension: barcode {
##    sql: ${TABLE}.latest_barcode ;;
##  }
##
##  dimension: product {
##    sql: ${TABLE}.product ;;
##  }
##
##  dimension: disease_panel {
##    sql: ${TABLE}.disease_panel ;;
##  }
##
##  dimension_group: test_completed {
##    type: time
##    timeframes: [quarter, month, year]
##    sql: ${TABLE}.completed_on ;;
##  }
##
##  dimension: payer_name {
##    sql: ${TABLE}.payer_name ;;
##  }
##
##  dimension: plan_name {
##    sql: ${TABLE}.plan_name ;;
##  }
##
##  dimension: plan_type {
##    sql: ${TABLE}.plan_type ;;
##  }
##
##  dimension: payer_revenue {
##    type: number
##    value_format_name: usd
##    sql: ${TABLE}.payer_revenue ;;
##  }
##
##  dimension: payer_revenue_percent {
##    type: number
##    value_format_name: percent_2
##    sql: ${TABLE}.payer_revenue_percent ;;
##  }
##
##  measure: total_payer_revenue {
##    label: "$ Total Payer Revenue"
##    value_format_name: usd
##    type: sum
##    sql: ${payer_revenue} ;;
##  }
##
##  dimension: regular_patient_revenue {
##    type: number
##    value_format_name: usd
##    sql: ${TABLE}.regular_patient_revenue ;;
##  }
##
##  dimension: moop_patient_revenue {
##    label: "MOOP Patient Revenue"
##    type: number
##    value_format_name: usd
##    sql: ${TABLE}.moop_patient_revenue ;;
##  }
##
##  measure: total_moop_patient_revenue {
##    label: "$ Total MOOP Patient Revenue"
##    value_format_name: usd
##    type: sum
##    sql: ${moop_patient_revenue} ;;
##  }
##
##  measure: total_regular_patient_revenue {
##    label: "$ Total Non-MOOP Patient Revenue"
##    value_format_name: usd
##    type: sum
##    sql: ${regular_patient_revenue} ;;
##  }
##
##  measure: total_patient_revenue {
##    label: "$ Total Patient Revenue"
##    value_format_name: usd
##    type: sum
##    sql: coalesce(${regular_patient_revenue},0) + coalesce(${moop_patient_revenue},0) ;;
##  }
##
##  measure: total_revenue {
##    label: "$ Total Revenue"
##    value_format_name: usd
##    type: sum
##    sql: coalesce(${regular_patient_revenue},0) + coalesce(${moop_patient_revenue},0) + coalesce(${payer_revenue},0) ;;
##  }
##
##  measure: count {
##    type: count
##  }
##}
##
##view: flux_factor_applied_to_barcodes {
##  derived_table: {
##    sql: SELECT
##      ord.latest_barcode as barcode
##      , ord.id AS order_id
##      , ord.completed_on
##      , CASE
##          WHEN has_ips_high_risk = TRUE and ord.product_name = 'Prelude Prenatal Screen' THEN 'Prelude Prenatal Screen - High Risk'
##          WHEN has_ips_high_risk = FALSE and ord.product_name = 'Prelude Prenatal Screen' THEN 'Prelude Prenatal Screen - Low Risk'
##          WHEN has_ips_high_risk is null and ord.product_name = 'Prelude Prenatal Screen' THEN 'Prelude Prenatal Screen - Low Risk'
##          ELSE ord.product_name END as product
##      , order_status_name
##      , revenue_inn_barcode.moop_patient_revenue + revenue_inn_barcode.regular_patient_revenue as revenue_amount
##      , claim.payer_id
##      , invoice_flux_factor.flux_claim_state
##      , invoice_flux_factor.invoice_flux_factor
##      , coalesce((revenue_inn_barcode.moop_patient_revenue + revenue_inn_barcode.regular_patient_revenue)*invoice_flux_factor.invoice_flux_factor,revenue_inn_barcode.moop_patient_revenue + revenue_inn_barcode.regular_patient_revenue) AS revenue_amount_adjusted_for_flux
##      , ((revenue_inn_barcode.moop_patient_revenue + revenue_inn_barcode.regular_patient_revenue)*invoice_flux_factor.invoice_flux_factor) - (revenue_inn_barcode.moop_patient_revenue + revenue_inn_barcode.regular_patient_revenue) AS invoice_flux_revenue
##      FROM ${revenue_inn_barcode.SQL_TABLE_NAME} AS revenue_inn_barcode
##      INNER JOIN ${order.SQL_TABLE_NAME} AS ord ON ord.id = revenue_inn_barcode.order_id
##      LEFT JOIN
##        ${notable_diagnoses.SQL_TABLE_NAME} as nd on nd.order_id = ord.id
##      INNER JOIN current.insuranceclaim AS claim ON claim.order_id = ord.id
##      --WHERE revenue_type_disaggregated = 'INN Patient INCL MOOP' OR revenue_type_disaggregated = 'INN Patient XCL MOOP'
##      INNER JOIN ${flux_claim_state.SQL_TABLE_NAME} AS flux_claim_state ON flux_claim_state.status_name = claim.status_name
##      INNER JOIN ${invoice_flux_factor.SQL_TABLE_NAME} AS invoice_flux_factor
##        ON invoice_flux_factor.product =
##        (CASE
##          WHEN has_ips_high_risk = TRUE and ord.product_name = 'Prelude Prenatal Screen' THEN 'Prelude Prenatal Screen - High Risk'
##          WHEN has_ips_high_risk = FALSE and ord.product_name = 'Prelude Prenatal Screen' THEN 'Prelude Prenatal Screen - Low Risk'
##          WHEN has_ips_high_risk is null and ord.product_name = 'Prelude Prenatal Screen' THEN 'Prelude Prenatal Screen - Low Risk'
##          ELSE ord.product_name END)
##        AND invoice_flux_factor.completed_month  = to_char(ord.completed_on,'YYYY-MM')
##        AND invoice_flux_factor.flux_claim_state = flux_claim_state.flux_claim_state
##       ;;
##    sql_trigger_value: select count(*) from ${invoice_flux_factor.SQL_TABLE_NAME} ;;
##    indexes: ["barcode", "order_id"]
##  }
##
##  dimension: barcode {
##    sql: ${TABLE}.barcode ;;
##  }
##
##  dimension: product {
##    sql: ${TABLE}.product ;;
##  }
##
##  dimension: flux_claim_state {
##    sql: ${TABLE}.flux_claim_state ;;
##  }
##
##  dimension: original_revenue_amount {
##    sql: ${TABLE}.revenue_amount ;;
##  }
##
##  dimension: invoice_flux_factor {
##    sql: ${TABLE}.invoice_flux_factor ;;
##  }
##
##  dimension_group: completed {
##    type: time
##    timeframes: [quarter, date, week, month, year]
##    sql: ${TABLE}.completed_on ;;
##  }
##
##  dimension: revenue_amount_adjusted_for_flux {
##    sql: ${TABLE}.revenue_amount_adjusted_for_flux ;;
##  }
##
##  dimension: invoice_flux_revenue {
##    sql: ${TABLE}.invoice_flux_revenue ;;
##  }
##
##  measure: total_original_revenue_amount {
##    type: sum
##    sql: ${original_revenue_amount} ;;
##  }
##
##  measure: total_revenue_amount_adjusted_for_flux {
##    type: sum
##    sql: ${revenue_amount_adjusted_for_flux} ;;
##  }
##
##  measure: total_invoice_flux_revenue {
##    type: sum
##    sql: ${invoice_flux_revenue} ;;
##  }
##}
##
##view: invoice_flux_factor {
##  derived_table: {
##    sql: SELECT
##      product
##      ,flux_claim_state
##      ,completed_month
##      , average_net_invoice_amount
##      , lookback_average_net_invoice_amount
##      , CASE WHEN  (completed_month||'-01')::date >= '2015-04-01'::date THEN 1+((coalesce(average_net_invoice_amount,0)-coalesce(lookback_average_net_invoice_amount,0))/nullif(lookback_average_net_invoice_amount,0)) ELSE null END AS invoice_flux_factor
##      FROM ${invoice_flux_factor_inputs.SQL_TABLE_NAME} AS invoice_flux_factor_inputs
##       ;;
##    sql_trigger_value: select count(*) from ${invoice_flux_factor_inputs.SQL_TABLE_NAME} ;;
##    indexes: ["product", "completed_month", "average_net_invoice_amount", "lookback_average_net_invoice_amount", "invoice_flux_factor"]
##  }
##
##  dimension: product {
##    sql: ${TABLE}.product ;;
##  }
##
##  dimension: flux_claim_state {
##    sql: ${TABLE}.flux_claim_state ;;
##  }
##
##  dimension: completed_month {
##    sql: ${TABLE}.completed_month ;;
##  }
##
##  dimension: invoice_flux_factor {
##    sql: ${TABLE}.invoice_flux_factor ;;
##  }
##
##  measure: sum_invoice_flux_factor {
##    type: sum
##    sql: ${TABLE}.invoice_flux_factor ;;
##  }
##}
##
##view: invoice_flux_factor_inputs {
##  derived_table: {
##    sql:
##      SELECT
##        product
##        , flux_claim_state
##        , completed_month
##        , month_id
##        , average_net_invoice_amount
##        , lookback3_average_net_invoice_amount
##        , lookback4_average_net_invoice_amount
##        , lookback5_average_net_invoice_amount
##        , lookback6_average_net_invoice_amount
##        , lookback7_average_net_invoice_amount
##        , lookback8_average_net_invoice_amount
##
##        ,(
##            coalesce(lookback3_average_net_invoice_amount,0)
##            +
##            coalesce(lookback4_average_net_invoice_amount,0)
##            +
##            coalesce(lookback5_average_net_invoice_amount,0)
##            +
##            coalesce(lookback6_average_net_invoice_amount,0)
##            +
##            coalesce(lookback7_average_net_invoice_amount,0)
##            +
##            coalesce(lookback8_average_net_invoice_amount,0)
##
##            ) AS numerator
##
##          ,(array_length(array_remove(ARRAY[
##              lookback3_average_net_invoice_amount,
##              lookback4_average_net_invoice_amount,
##              lookback5_average_net_invoice_amount,
##              lookback6_average_net_invoice_amount,
##              lookback7_average_net_invoice_amount,
##              lookback8_average_net_invoice_amount
##            ], null), 1)) AS denominator
##
##              ,((
##                coalesce(lookback3_average_net_invoice_amount,0)
##                +
##                coalesce(lookback4_average_net_invoice_amount,0)
##                +
##                coalesce(lookback5_average_net_invoice_amount,0)
##                +
##                coalesce(lookback6_average_net_invoice_amount,0)
##                +
##                coalesce(lookback7_average_net_invoice_amount,0)
##                +
##                coalesce(lookback8_average_net_invoice_amount,0)
##                )
##                      /
##                (array_length(array_remove(ARRAY[
##                  lookback3_average_net_invoice_amount,
##                  lookback4_average_net_invoice_amount,
##                  lookback5_average_net_invoice_amount,
##                  lookback6_average_net_invoice_amount,
##                  lookback7_average_net_invoice_amount,
##                  lookback8_average_net_invoice_amount
##                ], null), 1)))
##
##
##        AS lookback_average_net_invoice_amount
##
##      FROM
##
##      ${net_invoice_lookback_table.SQL_TABLE_NAME} AS lookback_table
##      GROUP BY 1,2,3,4,5,6,7,8,9,10,11
##       ;;
##    sql_trigger_value: select count(*) from ${net_invoice_lookback_table.SQL_TABLE_NAME} ;;
##    indexes: ["product", "average_net_invoice_amount", "lookback_average_net_invoice_amount"]
##  }
##
##  dimension: product {
##    sql: ${TABLE}.product ;;
##  }
##
##  dimension: average_net_invoice_amount {
##    sql: ${TABLE}.average_net_invoice_amount ;;
##  }
##
##  measure: lookback_average_net_invoice_amount {
##    type: average
##    sql: ${TABLE}.lookback_average_net_invoice_amount ;;
##  }
##
##  dimension: completed_month {
##    sql: ${TABLE}.completed_month ;;
##  }
##
##  dimension: flux_claim_state {
##    sql: ${TABLE}.flux_claim_state ;;
##  }
##}
##
##view: net_invoice_lookback_table {
##  derived_table: {
##    sql:
##      SELECT
##
##        net_invoice_amounts.product
##        , net_invoice_amounts.flux_claim_state
##        , net_invoice_amounts.completed_month
##        , net_invoice_amounts.month_id
##        , net_invoice_amounts.average_net_invoice_amount
##
##
##        , lookback3.completed_month AS lookback3_completed_month
##        , lookback3.month_id AS lookback3_month_id
##        , lookback3.average_net_invoice_amount AS lookback3_average_net_invoice_amount
##
##        , lookback4.completed_month AS lookback4_completed_month
##        , lookback4.month_id AS lookback4_month_id
##        , lookback4.average_net_invoice_amount AS lookback4_average_net_invoice_amount
##
##        , lookback5.completed_month AS lookback5_completed_month
##        , lookback5.month_id AS lookback5_month_id
##        , lookback5.average_net_invoice_amount AS lookback5_average_net_invoice_amount
##
##        , lookback6.completed_month AS lookback6_completed_month
##        , lookback6.month_id AS lookback6_month_id
##        , lookback6.average_net_invoice_amount AS lookback6_average_net_invoice_amount
##
##        , lookback7.completed_month AS lookback7_completed_month
##        , lookback7.month_id AS lookback7_month_id
##        , lookback7.average_net_invoice_amount AS lookback7_average_net_invoice_amount
##
##        , lookback8.completed_month AS lookback8_completed_month
##        , lookback8.month_id AS lookback8_month_id
##        , lookback8.average_net_invoice_amount AS lookback8_average_net_invoice_amount
##
##      FROM
##        ${net_invoice_amounts.SQL_TABLE_NAME} AS net_invoice_amounts
##
##
##      LEFT JOIN ${net_invoice_amounts.SQL_TABLE_NAME} AS lookback3
##        ON lookback3.month_id = net_invoice_amounts.month_id+3
##        AND lookback3.product = net_invoice_amounts.product
##        AND lookback3.flux_claim_state = net_invoice_amounts.flux_claim_state
##
##      LEFT JOIN ${net_invoice_amounts.SQL_TABLE_NAME} AS lookback4
##        ON lookback4.month_id = net_invoice_amounts.month_id+4
##        AND lookback4.product = net_invoice_amounts.product
##        AND lookback4.flux_claim_state = net_invoice_amounts.flux_claim_state
##
##      LEFT JOIN ${net_invoice_amounts.SQL_TABLE_NAME} AS lookback5
##        ON lookback5.month_id = net_invoice_amounts.month_id+5
##        AND lookback5.product = net_invoice_amounts.product
##        AND lookback5.flux_claim_state = net_invoice_amounts.flux_claim_state
##
##      LEFT JOIN ${net_invoice_amounts.SQL_TABLE_NAME} AS lookback6
##        ON lookback6.month_id = net_invoice_amounts.month_id+6
##        AND lookback6.product = net_invoice_amounts.product
##        AND lookback6.flux_claim_state = net_invoice_amounts.flux_claim_state
##
##      LEFT JOIN ${net_invoice_amounts.SQL_TABLE_NAME} AS lookback7
##        ON lookback7.month_id = net_invoice_amounts.month_id+7
##        AND lookback7.product = net_invoice_amounts.product
##        AND lookback7.flux_claim_state = net_invoice_amounts.flux_claim_state
##
##      LEFT JOIN ${net_invoice_amounts.SQL_TABLE_NAME} AS lookback8
##        ON lookback8.month_id = net_invoice_amounts.month_id+8
##        AND lookback8.product = net_invoice_amounts.product
##        AND lookback8.flux_claim_state = net_invoice_amounts.flux_claim_state
##       ;;
##    sql_trigger_value: select count(*) from ${net_invoice_amounts.SQL_TABLE_NAME} ;;
##    indexes: ["product", "completed_month"]
##  }
##
##  dimension: product {
##    sql: ${TABLE}.product ;;
##  }
##
##  dimension: average_net_invoice_amount {
##    sql: ${TABLE}.average_net_invoice_amount ;;
##  }
##
##  measure: lookback_average_net_invoice_amount {
##    type: average
##    sql: ${TABLE}.average_net_invoice_amount ;;
##  }
##
##  dimension: completed_month {
##    sql: ${TABLE}.completed_month ;;
##  }
##
##  dimension: flux_claim_state {
##    sql: ${TABLE}.flux_claim_state ;;
##  }
##
##  dimension: lookback3_completed_month {
##    sql: ${TABLE}.lookback3_completed_month ;;
##  }
##
##  dimension: lookback4_completed_month {
##    sql: ${TABLE}.lookback4_completed_month ;;
##  }
##
##  dimension: lookback5_completed_month {
##    sql: ${TABLE}.lookback5_completed_month ;;
##  }
##
##  dimension: lookback6_completed_month {
##    sql: ${TABLE}.lookback6_completed_month ;;
##  }
##
##  dimension: lookback7_completed_month {
##    sql: ${TABLE}.lookback7_completed_month ;;
##  }
##
##  dimension: lookback8_completed_month {
##    sql: ${TABLE}.lookback8_completed_month ;;
##  }
##
##  dimension: lookback3_average_net_invoice_amount {
##    sql: ${TABLE}.lookback3_average_net_invoice_amount ;;
##  }
##
##  dimension: lookback4_average_net_invoice_amount {
##    sql: ${TABLE}.lookback4_average_net_invoice_amount ;;
##  }
##
##  dimension: lookback5_average_net_invoice_amount {
##    sql: ${TABLE}.lookback5_average_net_invoice_amount ;;
##  }
##
##  dimension: lookback6_average_net_invoice_amount {
##    sql: ${TABLE}.lookback6_average_net_invoice_amount ;;
##  }
##
##  dimension: lookback7_average_net_invoice_amount {
##    sql: ${TABLE}.lookback7_completed_month ;;
##  }
##
##  dimension: lookback8_average_net_invoice_amount {
##    sql: ${TABLE}.lookback8_average_net_invoice_amount ;;
##  }
##}
##
##view: net_invoice_amounts {
##  derived_table: {
##    sql: SELECT
##         product
##        , flux_claim_state
##        , completed_month
##        ,((DATE(TO_CHAR(current_date, 'YYYY-MM')|| '-01') - DATE(completed_month|| '-01'))/30 + 1)::int AS month_id
##        , AVG(net_invoice_amount) AS average_net_invoice_amount
##      FROM ${net_calc.SQL_TABLE_NAME} AS  net_calc
##      GROUP BY 1,2,3,4
##       ;;
##    sql_trigger_value: select count(*) from ${net_calc.SQL_TABLE_NAME} ;;
##    indexes: ["product", "average_net_invoice_amount"]
##  }
##
##  dimension: product {
##    sql: ${TABLE}.product ;;
##  }
##
##  dimension: flux_claim_state {
##    sql: ${TABLE}.flux_claim_state ;;
##  }
##
##  dimension: completed_month {
##    sql: ${TABLE}.completed_month ;;
##  }
##
##  dimension: average_net_invoice_amount {
##    sql: ${TABLE}.average_net_invoice_amount ;;
##  }
##
##  measure: average_net_invoice_amount_measure {
##    type: sum
##    sql: ${TABLE}.average_net_invoice_amount ;;
##  }
##}
##
##view: net_calc {
##  derived_table: {
##    sql:
##      SELECT
##        invoice_flux_patient_invoices.latest_barcode
##        , invoice_flux_patient_invoices.product
##        , invoice_flux_patient_invoices.status_name
##        , invoice_flux_patient_invoices.flux_claim_state
##        , invoice_flux_patient_invoices.completed_month
##        , coalesce(total_invoice_amount,0) AS total_invoice_amount
##        , SUM(coalesce(total_transaction_amount,0)) AS comps
##        , coalesce(total_invoice_amount,0) - SUM(coalesce(total_transaction_amount,0)) AS net_invoice_amount
##
##      FROM
##        ${invoice_flux_patient_invoices.SQL_TABLE_NAME} AS invoice_flux_patient_invoices
##      LEFT JOIN
##        ${invoice_flux_patient_comps.SQL_TABLE_NAME} AS invoice_flux_patient_comps ON invoice_flux_patient_comps.order_id =invoice_flux_patient_invoices.order_id
##      GROUP BY 1,2,3,4,5,6
##       ;;
##    sql_trigger_value: select count(*) from ${invoice_flux_patient_invoices.SQL_TABLE_NAME} ;;
##    indexes: ["product", "latest_barcode"]
##  }
##
##  dimension: product {
##    sql: ${TABLE}.product ;;
##  }
##
##  dimension: flux_claim_state {
##    sql: ${TABLE}.flux_claim_state ;;
##  }
##
##  dimension: completed_month {
##    sql: ${TABLE}.completed_month ;;
##  }
##
##  dimension: barcode {
##    sql: ${TABLE}.latest_barcode ;;
##  }
##
##  dimension: comps {
##    sql: ${TABLE}.comps ;;
##  }
##
##  dimension: total_invoice_amount {
##    sql: ${TABLE}.total_invoice_amount ;;
##  }
##}
##
##view: invoice_flux_patient_comps {
##  derived_table: {
##    sql: SELECT
##        latest_barcode
##        , order_id
##        , completed_date
##        , network_status
##        , payment_method
##        , (payment_timestamp) AS transaction_date
##        , invoice_number
##        , type
##        , SUM(COALESCE(payment_amount,0)) AS total_transaction_amount
##      FROM (
##        SELECT
##          "order".latest_barcode AS latest_barcode
##          , "order".id AS order_id
##          , DATE("order".completed_on) AS completed_date
##          , CASE
##            WHEN "order".product = 'Foresight Carrier Screen' and date_of_service >= inn.fps_date and date_of_service < coalesce(inn.fps_term,'2100-01-01'::date)
##              THEN 'In Net'
##            WHEN "order".product = 'Reliant Cancer Screen' and date_of_service >= inn.ics_date and date_of_service < coalesce(inn.ics_term,'2100-01-01'::date)
##              THEN 'In Net'
##            WHEN "order".product = 'Prelude Prenatal Screen' and date_of_service >= inn.ips_date and date_of_service < coalesce(inn.ips_term,'2100-01-01'::date)
##              THEN 'In Net'
##            ELSE 'OON'
##            END as network_status
##          , payment.payment_method AS payment_method
##          , payment.timestamp AS payment_timestamp
##          , invoice.invoice_number AS invoice_number
##          , invoice.type AS type
##          , payment.amount AS payment_amount
##        FROM ${order.SQL_TABLE_NAME} AS "order"
##        INNER JOIN current.insuranceclaim AS claim ON claim.order_id = ("order".id)
##        INNER JOIN ${invoiceitem.SQL_TABLE_NAME} AS invoiceitem ON invoiceitem.order_id = ("order".id)
##        INNER JOIN ${invoice.SQL_TABLE_NAME} AS invoice ON invoice.invoice_number = invoiceitem.invoice_number
##        INNER JOIN ${payment.SQL_TABLE_NAME} AS payment ON payment.invoice_number = invoice.invoice_number
##        LEFT JOIN uploads.in_network_dates_w_terminal inn on inn.id = claim.payer_id
##
##
##        WHERE
##          ("order".completed_on >= '2014-08-01'::date)
##          AND
##          (CASE
##          WHEN "order".product = 'Foresight Carrier Screen' and date_of_service >= inn.fps_date and date_of_service < coalesce(inn.fps_term,'2100-01-01'::date)
##            THEN 'In Net'
##          WHEN "order".product = 'Reliant Cancer Screen' and date_of_service >= inn.ics_date and date_of_service < coalesce(inn.ics_term,'2100-01-01'::date)
##            THEN 'In Net'
##          WHEN "order".product = 'Prelude Prenatal Screen' and date_of_service >= inn.ips_date and date_of_service < coalesce(inn.ips_term,'2100-01-01'::date)
##            THEN 'In Net'
##          ELSE 'OON'
##          END) = 'In Net'
##          AND
##          (payment.payment_method ILIKE 'comp')
##          AND
##          (invoice.type = 'Customer')
##        GROUP BY 1,2,3,4,5,6,7,8,9) AS sub
##      GROUP BY 1,2,3,4,5,6,7,8
##       ;;
##    sql_trigger_value: select count(*) from ${order.SQL_TABLE_NAME} ;;
##    indexes: ["latest_barcode", "completed_date", "invoice_number"]
##  }
##
##  dimension: latest_barcode {
##    sql: ${TABLE}.latest_barcode ;;
##  }
##
##  dimension: invoice_number {
##    sql: ${TABLE}.invoice_number ;;
##  }
##
##  dimension_group: transaction_date {
##    type: time
##    timeframes: [month]
##    sql: ${TABLE}.transaction_date ;;
##  }
##
##  dimension: total_transaction_amount {
##    sql: ${TABLE}.total_transaction_amount ;;
##  }
##
##  measure: sum_total_transaction_amount {
##    type: sum
##    sql: ${TABLE}.total_transaction_amount ;;
##  }
##}
##
##view: invoice_flux_patient_invoices {
##  derived_table: {
##    sql:
##      SELECT
##        invoice.type AS type
##        ,invoice.invoice_number AS invoice_number
##        ,DATE(invoice.sent) AS sent_date
##        ,insurancepayer.display_name AS pretty_payer_name
##        ,TO_CHAR(invoice.sent, 'YYYY-MM') AS sent_month
##        ,EXTRACT(YEAR FROM invoice.sent)::integer AS sent_year
##        ,"order".latest_barcode AS latest_barcode
##        ,"order".id AS order_id
##        ,DATE("order".completed_on) AS completed_date
##        ,claim.status_name
##        ,flux_claim_state
##        ,CASE
##          WHEN "order".product = 'Foresight Carrier Screen' and date_of_service >= inn.fps_date and date_of_service < coalesce(inn.fps_term,'2100-01-01'::date)
##            THEN 'In Net'
##          WHEN "order".product = 'Reliant Cancer Screen' and date_of_service >= inn.ics_date and date_of_service < coalesce(inn.ics_term,'2100-01-01'::date)
##            THEN 'In Net'
##          WHEN "order".product = 'Prelude Prenatal Screen' and date_of_service >= inn.ips_date and date_of_service < coalesce(inn.ips_term,'2100-01-01'::date)
##            THEN 'In Net'
##          ELSE 'OON'
##          END AS network_status
##        ,CASE
##          WHEN has_ips_high_risk = TRUE and "order".product_name = 'Prelude Prenatal Screen' THEN 'Prelude Prenatal Screen - High Risk'
##          WHEN has_ips_high_risk = FALSE and "order".product_name = 'Prelude Prenatal Screen' THEN 'Prelude Prenatal Screen - Low Risk'
##          WHEN has_ips_high_risk is null and "order".product_name = 'Prelude Prenatal Screen' THEN 'Prelude Prenatal Screen - Low Risk'
##          ELSE "order".product_name END AS product
##        ,TO_CHAR("order".completed_on, 'YYYY-MM') AS completed_month
##        ,invoice.patient_invoice_tier AS patient_invoice_amount_tier
##        ,SUM(COALESCE(invoiceitem.amount,0)) AS total_invoice_amount
##      FROM ${order.SQL_TABLE_NAME} AS "order"
##      LEFT JOIN ${notable_diagnoses.SQL_TABLE_NAME} as nd on nd.order_id = "order".id
##      INNER JOIN current.insuranceclaim AS claim ON claim.order_id = ("order".id)
##      INNER JOIN current.insurancepayer AS insurancepayer ON insurancepayer.id = claim.payer_id
##      INNER JOIN ${invoiceitem.SQL_TABLE_NAME} AS invoiceitem ON invoiceitem.order_id = ("order".id)
##      INNER JOIN ${invoice.SQL_TABLE_NAME} AS invoice ON invoice.invoice_number = invoiceitem.invoice_number
##      INNER JOIN ${flux_claim_state.SQL_TABLE_NAME} AS flux_claim_state ON flux_claim_state.status_name =claim.status_name
##      INNER JOIN uploads.in_network_dates_w_terminal inn on inn.id = insurancepayer.id
##
##      WHERE
##        ("order".completed_on >= '2014-08-01'::date)
##        AND
##        (CASE
##          WHEN "order".product = 'Foresight Carrier Screen' and date_of_service >= inn.fps_date and date_of_service < coalesce(inn.fps_term,'2100-01-01'::date)
##            THEN 'In Net'
##          WHEN "order".product = 'Reliant Cancer Screen' and date_of_service >= inn.ics_date and date_of_service < coalesce(inn.ics_term,'2100-01-01'::date)
##            THEN 'In Net'
##          WHEN "order".product = 'Prelude Prenatal Screen' and date_of_service >= inn.ips_date and date_of_service < coalesce(inn.ips_term,'2100-01-01'::date)
##            THEN 'In Net'
##          ELSE 'OON'
##          END) = 'In Net'
##        AND
##        (invoice.type ILIKE 'Customer')
##        AND
##        (payer_id not in (1575,1581))
##      GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
##       ;;
##    sql_trigger_value: select count(*) from ${order.SQL_TABLE_NAME} ;;
##    indexes: ["invoice_number", "latest_barcode", "status_name"]
##  }
##
##  dimension: latest_barcode {
##    sql: ${TABLE}.latest_barcode ;;
##  }
##
##  dimension: invoice_number {
##    sql: ${TABLE}.invoice_number ;;
##  }
##
##  dimension: product {
##    sql: ${TABLE}.product ;;
##  }
##
##  dimension: total_invoice_amount {
##    sql: ${TABLE}.total_invoice_amount ;;
##  }
##}
##
##view: flux_claim_state {
##  derived_table: {
##    sql: SELECT
##         status_name
##        , CASE
##            WHEN status_name = 'Canceled Chose Cash' THEN 'INN Patient INCL MOOP'
##            WHEN status_name = 'Canceled Chose Consignment' THEN 'INN Patient INCL MOOP'
##            WHEN status_name = 'Maximum OOP - No Insurance' THEN 'INN Patient INCL MOOP'
##          ELSE 'INN Patient XCL MOOP' END AS flux_claim_state
##      FROM
##        current.insuranceclaim AS claim
##      GROUP BY 1,2
##       ;;
##    sql_trigger_value: select current_date ;;
##  }
##
##  dimension: status_name {
##    sql: ${TABLE}.status_name ;;
##  }
##
##  dimension: flux_claim_state {
##    sql: ${TABLE}.flux_claim_state ;;
##  }
##}
##
