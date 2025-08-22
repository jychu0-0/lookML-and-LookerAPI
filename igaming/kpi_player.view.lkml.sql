## NOTE: many component PDTs have been migrated to dbt and the the views have been updated to reference the new dbt view.
# view: calendar_cte {
#   ## No dependencies, count = 2,532,251,475
#   derived_table: {
#     sql_trigger_value: select date(convert_timezone('UTC','America/Los_Angeles',current_timestamp)) ;;
#     cluster_keys: ["report_date","cage_code"]
#     sql:
#     SELECT
#       /*+ MATERIALIZE */
#       cage_code,
#       cage_player_id,
#       site_code,
#       report_date
#     FROM
#       reporting.players
#     LEFT JOIN
#       (
#         SELECT
#           dateadd(DAY, '-' || seq4(), CURRENT_DATE()) AS report_date
#         FROM
#           TABLE (generator(rowcount => 3670))
#       )
#       gs on DATE(signup_date) - 1 <= report_date
#     WHERE
#       internal = '0';;
#   }

#   dimension: primary_key {
#     primary_key: yes
#     hidden: yes
#     sql: ${TABLE}.report_date || ${TABLE}.cage_code || ${TABLE}.cage_player_id  ;;
#   }

#   dimension: report_date {
#     type: date
#   }
# }

view: non_internal_players_cte {
  sql_table_name: edw.kpi_players_non_internal_players ;;
  ## No dependencies, count = 3,580,988
  # derived_table: {
  #   sql_trigger_value: select date(convert_timezone('UTC','America/Los_Angeles',current_timestamp)) ;;
  #   cluster_keys: ["cage_code"]
  #   sql:
  #   SELECT
  #         /*+ MATERIALIZE */
  #         p.cage_code,
  #         p.cage_player_id,
  #         p.signup_date,
  #         p.account_status AS player_status,
  #         p.first_deposit_date,
  #         pl.current_level AS loyalty_level,
  #         p.vip_level,
  #         cp.first_kyc_pass_date
  #       FROM
  #         reporting.players p
  #         JOIN
  #           cage.cage_players cp
  #           ON p.cage_player_id = cp.cage_player_id
  #           AND p.cage_code = cp.cage_code
  #         LEFT JOIN
  #           (
  #             SELECT
  #               cage_code,
  #               cage_player_id,
  #               current_level
  #             FROM
  #               loyalty.player_levels
  #             WHERE
  #               product_code = 'COMBINED'
  #           )
  #           pl
  #           ON p.cage_code = pl.cage_code
  #           AND p.cage_player_id = pl.cage_player_id
  #       WHERE
  #         internal = '0';;
  # }

  dimension: cage_player_id {
    type: string
  }

  dimension: player_status {
    type: string
  }
}

view: game_type_pref_cte {
  sql_table_name: edw.kpi_player_game_type_pref ;;
  ## No dependencies, count = 2,216,968
  # derived_table: {
    # sql_trigger_value: select date(convert_timezone('UTC','America/Los_Angeles',current_timestamp)) ;;
  #   datagroup_trigger: daily
  #   cluster_keys: ["cage_code"]
  #   sql:
  #   SELECT
  #         /*+ MATERIALIZE */
  #         cage_code,
  #         cage_player_id,
  #         MAX(max_date) AS last_game_date,
  #         MIN(min_date) AS first_game_date,
  #         MIN(min_sb_date) AS first_sb_date,
  #         MIN(min_casino_date) AS first_casino_date,
  #         listagg(DISTINCT game_type_pref, ' | ') WITHIN GROUP (
  #       ORDER BY
  #         game_type_pref) AS game_types,
  #         listagg(game_type, ' | ') WITHIN GROUP (
  #       ORDER BY
  #         min_date) AS game_type_order,
  #         listagg(DISTINCT game_type, ' | ') WITHIN GROUP (
  #       ORDER BY
  #         game_type) AS game_type_pref,
  #         CASE WHEN LEFT(game_type_order, 5) = 'SBOOK' THEN 'Sportsbook'
  #             WHEN POSITION('|', game_type_order) > 0 THEN LEFT(game_type_order, POSITION(' |', game_type_order))
  #             ELSE game_type_order
  #             END
  #               AS first_game_played
  #       FROM
  #         (
  #           SELECT
  #             cage_code,
  #             cage_player_id,
  #             CASE WHEN game_type_code = 'SBOOK' THEN 'SB'
  #                 ELSE 'C'
  #                 END
  #                   AS game_type_pref,
  #             --when game_type_code = 'SBOOK' then 'SB' else 'C' end as game_type,
  #             CASE WHEN game_type_code NOT IN ('SBOOK', 'TABLE', 'BLACKJACK') THEN 'SLOTS'
  #                 WHEN game_type_code IN ('TABLE', 'BLACKJACK') AND (game_provider_code <> 'EVOLUTION' OR game_definition_code LIKE '%rng-%') THEN 'TABLE'
  #                 WHEN game_provider_code = 'EVOLUTION' AND game_definition_code NOT LIKE '%rng-%' THEN 'LIVEDEALER'
  #                 WHEN game_type_code = 'SBOOK' THEN 'SBOOK'
  #                 ELSE game_type_code
  #                 END
  #                   AS game_type,
  #             MIN(aggregate_hour) AS min_date,
  #             MAX(aggregate_hour) AS max_date,
  #             MIN(CASE WHEN game_type = 'SBOOK' THEN aggregate_hour END) AS min_sb_date,
  #             MIN(CASE WHEN game_type != 'SBOOK' THEN aggregate_hour END) AS min_casino_date
  #           FROM
  #             cage.agg_hourly_game_stats agg
  #           GROUP BY
  #             1, 2, 3, 4
  #         )
  #         gs
  #       GROUP BY
  #         1, 2
  #     ;;
  # }

  dimension: game_type_order {
    type: string
  }

  dimension: game_type_pref {
    type: string
  }
}

# view: registrations_cte {
#   ## Dependency on non_internal_player_cte, count = 3,580,988
#   derived_table: {
#     sql_trigger_value: SELECT count(*) FROM ${non_internal_players_cte.SQL_TABLE_NAME} nip ;;
#     cluster_keys: ["report_date","cage_code"]
#     sql:
#     SELECT
#           /*+ MATERIALIZE */
#           nip.cage_player_id,
#           nip.cage_code,
#           DATE(convert_timezone('UTC', rc.cage_timezone, signup_date)) AS report_date,
#           MAX(CAST(vip_level AS NUMERIC)) AS vip_level,
#           COUNT(DISTINCT(nip.cage_code || '-' || cage_player_id)) AS registrations,
#           COUNT(DISTINCT(CASE WHEN player_status = 'ACTIVE' THEN nip.cage_code || '-' || cage_player_id END)) AS passed_registrations,
#           COUNT(DISTINCT(CASE WHEN first_kyc_pass_date IS NOT NULL THEN nip.cage_code || '-' || cage_player_id END)) AS kyc_registrations
#         FROM
#           ${non_internal_players_cte.SQL_TABLE_NAME} nip
#           LEFT JOIN
#             reporting.registered_cages rc
#             ON (nip.cage_code = rc.cage_code)
#         WHERE
#           signup_date > CURRENT_DATE - INTERVAL '3670 days'
#         GROUP BY
#           1, 2, 3
#       ;;
#   }

#   dimension: registrations {
#     type: string
#   }

#   dimension: kyc_registrations {
#     type: string
#   }
# }

# view: ftds_cte {
#   ## Dependency on non_internal_player_cte, count = 1,601,518
#   derived_table: {
#     sql_trigger_value: SELECT count(*) FROM ${registrations_cte.SQL_TABLE_NAME} r ;;
#     cluster_keys: ["report_date","cage_code"]
#     sql:
#     SELECT
#           /*+ MATERIALIZE */
#           nip.cage_player_id,
#           nip.cage_code,
#           DATE(convert_timezone('UTC', rc.cage_timezone, first_deposit_date)) AS report_date,
#           COUNT(DISTINCT(CASE WHEN first_deposit_date IS NOT NULL THEN nip.cage_code || '-' || cage_player_id END)) AS ftds
#         FROM
#           ${non_internal_players_cte.SQL_TABLE_NAME} nip
#           LEFT JOIN
#             reporting.registered_cages rc
#             ON (nip.cage_code = rc.cage_code)
#         WHERE
#           first_deposit_date > CURRENT_DATE - INTERVAL '3670 days'
#         GROUP BY
#           1, 2, 3;;
#   }

#   dimension: ftds {
#     type: string
#   }

#   dimension: cage_code {
#     type: string
#   }
# }

# view: logins_cte {
#   ## No dependencies, count = 107,309,616
#   derived_table: {
#     sql_trigger_value: select date(convert_timezone('UTC','America/Los_Angeles',current_timestamp)) ;;
#     cluster_keys: ["report_date","cage_code"]
#     sql:
#     SELECT
#           /*+ MATERIALIZE */
#           cage_player_id,
#           cls.cage_code,
#           DATE(convert_timezone('UTC', rc.cage_timezone, start_time)) AS report_date,
#           COUNT(DISTINCT(cls.cage_code || '-' || cage_player_id)) AS logins,
#           COUNT(DISTINCT(cls.cage_code || '-' || cls.id)) AS sessions,
#           SUM(datediff('minutes', start_time, end_time)) AS session_length
#         FROM
#           cage.cage_login_sessions cls
#           LEFT JOIN
#             reporting.registered_cages rc
#             ON (cls.cage_code = rc.cage_code)
#         WHERE
#           start_time > CURRENT_DATE - INTERVAL '3670 days'
#         GROUP BY
#           1,
#           2,
#           3
#           ;;
#   }

#   dimension: logins {
#     type: string
#   }

#   dimension: sessions {
#     type: string
#   }
# }

# view: player_transactions_cte {
#   ## Dependency on non_internal_player_cte, count = 33,907,234
#   derived_table: {
#     sql_trigger_value: SELECT count(*) FROM ${ftds_cte.SQL_TABLE_NAME} f ;;
#     cluster_keys: ["report_date","cage_code"]
#     sql:
#     SELECT
#           /*+ MATERIALIZE */
#           pt.cage_player_id,
#           pt.cage_code,
#           CASE WHEN pdr.payment_method IN ('BBVA','KUSHKI_BANK_TRANSFER','STP_BANK_TRANSFER') AND pt.type = 'DEPOSIT' THEN DATE(convert_timezone('UTC', rc.cage_timezone, pdr.create_time))
#               WHEN pt.cage_code IN (57, 52) AND pdr.payment_method NOT IN ('BBVA', 'KUSHKI_BANK_TRANSFER','STP_BANK_TRANSFER') THEN DATE(convert_timezone('UTC', rc.cage_timezone, pt.insert_time))
#               ELSE DATE(convert_timezone('UTC', rc.cage_timezone, pt.insert_time))
#               END
#                 AS report_date,
#           COUNT(DISTINCT(CASE WHEN pt.type = 'DEPOSIT' THEN pt.cage_player_id END)) AS depositors,
#           COUNT(CASE WHEN pt.type = 'DEPOSIT' THEN 1 END) AS deposits,
#           SUM(CASE WHEN pt.type = 'DEPOSIT' THEN pdr.amount ELSE 0 END) AS deposit_amount,
#           SUM(CASE WHEN pt.type IN ('COMPS_CORR_INCR', 'COMPS_DEPOSIT') THEN pt.amount
#                   WHEN pt.type = 'COMPS_CORR_DECR' THEN - pt.amount
#                   ELSE 0
#                   END)
#                     AS bonus_store_pts_issued,
#           SUM(CASE WHEN pt.type = 'BONUSBANK_CORR_DECR' THEN - pt.amount
#                   ELSE 0
#                   END)
#                     AS bonus_money_issued
#         FROM
#           cage.player_transactions pt
#           LEFT JOIN
#             cage.player_deposit_requests pdr
#             ON pt.deposit_request_id = pdr.id
#             AND pt.cage_code = pdr.cage_code
#           LEFT JOIN
#             reporting.registered_cages rc
#             ON (pt.cage_code = rc.cage_code) , ${non_internal_players_cte.SQL_TABLE_NAME} p
#         WHERE
#           pt.cage_player_id = p.cage_player_id
#           AND pt.cage_code = p.cage_code
#           AND pt.type IN
#           (
#             'DEPOSIT', 'WITHDRAWAL', 'COMPS_CORR_INCR', 'COMPS_CORR_DECR', 'LOYALTY_STORE_PURCHASE', 'COMPS_DEPOSIT'
#           )
#           AND pt.insert_time > CURRENT_DATE - INTERVAL '3670 days'
#         GROUP BY
#           1, 2, 3
#     ;;
#   }

#   dimension: bonus_money_issued {
#     type: number
#   }

#   dimension: deposit_amount {
#     type: number
#   }
# }

# view: withdrawals_cte {
#   ## Dependency on non_internal_player_cte, count = 6,904,843
#   derived_table: {
#     sql_trigger_value: SELECT count(*) FROM ${player_transactions_cte.SQL_TABLE_NAME} pt ;;
#     cluster_keys: ["report_date","cage_code"]
#     sql:
#     SELECT
#           /*+ MATERIALIZE */
#           pwr.cage_player_id,
#           pwr.cage_code,
#           CASE WHEN pwr.payment_method IN ('BBVA','KUSHKI_BANK_TRANSFER','STP_BANK_TRANSFER') THEN DATE(convert_timezone('UTC', rc.cage_timezone, pwr.status_time))
#               WHEN pwr.cage_code IN (57, 52) AND pwr.payment_method NOT IN ('BBVA', 'KUSHKI_BANK_TRANSFER','STP_BANK_TRANSFER') THEN DATE(convert_timezone('UTC', rc.cage_timezone, pwr.status_time))
#               ELSE DATE(convert_timezone('UTC', rc.cage_timezone, pwr.status_time))
#               END
#                 AS report_date,
#           COUNT(DISTINCT(CASE WHEN pwr.status IN ('APPROVED') AND pwr.payment_method IN ('BBVA', 'KUSHKI_BANK_TRANSFER','STP_BANK_TRANSFER') THEN pwr.cage_code || '-' || pwr.cage_player_id
#                               WHEN pwr.status = 'APPROVED' AND pwr.payment_method NOT IN ('BBVA', 'KUSHKI_BANK_TRANSFER','STP_BANK_TRANSFER') THEN pwr.cage_code || '-' || pwr.cage_player_id
#                               ELSE NULL
#                               END))
#                                 AS withdrawers,
#           COUNT(CASE WHEN pwr.status IN ('APPROVED') AND pwr.payment_method IN ('BBVA', 'KUSHKI_BANK_TRANSFER','STP_BANK_TRANSFER') THEN 1
#                     WHEN pwr.status = 'APPROVED' AND pwr.payment_method NOT IN ('BBVA', 'KUSHKI_BANK_TRANSFER','STP_BANK_TRANSFER') THEN 1
#                     ELSE NULL
#                     END)
#                       AS withdrawals,
#           SUM(CASE WHEN pwr.status IN ('APPROVED') AND pwr.payment_method IN ('BBVA', 'KUSHKI_BANK_TRANSFER','STP_BANK_TRANSFER') THEN pwr.amount
#                   WHEN pwr.status = 'APPROVED' AND pwr.payment_method NOT IN ('BBVA', 'KUSHKI_BANK_TRANSFER','STP_BANK_TRANSFER') THEN pwr.amount
#                   ELSE NULL
#                   END)
#                     AS withdrawal_amount
#         FROM
#           cage.player_payments pwr
#           LEFT JOIN
#             reporting.registered_cages rc
#             ON (pwr.cage_code = rc.cage_code), ${non_internal_players_cte.SQL_TABLE_NAME} p
#         WHERE
#           pwr.cage_player_id = p.cage_player_id
#           AND pwr.cage_code = p.cage_code
#           AND pwr.status IN
#           (
#             'IN_PROGRESS', 'APPROVED'
#           )
#           AND type = 'WITHDRAWAL'
#           AND pwr.status_time > CURRENT_DATE - INTERVAL '3670 days'
#         GROUP BY
#           1, 2, 3
#     ;;
#   }

#   dimension: withdrawal_amount {
#     type: number
#   }

#   dimension: withdrawers {
#     type: string
#   }
# }

# view: store_pts_used_cte {
#   ## Dependency on non_internal_player_cte, count = 10,730,860
#   derived_table: {
#     sql_trigger_value: SELECT count(*) FROM ${withdrawals_cte.SQL_TABLE_NAME} w ;;
#     cluster_keys: ["report_date","cage_code"]
#     sql:
#     SELECT
#           /*+ MATERIALIZE */
#           lsp.cage_player_id,
#           lsp.cage_code,
#           DATE(convert_timezone('UTC', rc.cage_timezone, lsp.insert_timestamp)) AS report_date,
#           SUM(package_cost) AS bonus_store_pts_used
#         FROM
#           loyalty.store_purchases lsp
#           LEFT JOIN
#             reporting.registered_cages rc
#             ON (lsp.cage_code = rc.cage_code),
#             ${non_internal_players_cte.SQL_TABLE_NAME} p
#         WHERE
#           lsp.cage_player_id = p.cage_player_id
#           AND lsp.cage_code = p.cage_code
#           AND lsp.insert_timestamp > CURRENT_DATE - INTERVAL '3670 days'
#         GROUP BY
#           1,
#           2,
#           3
#     ;;
#   }

#   dimension: bonus_store_pts_used {
#     type: number
#   }
# }

# view: store_pts_issued_cte {
#   ## Dependency on non_internal_player_cte, count = 75,162,375
#   derived_table: {
#     sql_trigger_value: SELECT count(*) FROM ${store_pts_used_cte.SQL_TABLE_NAME} spu ;;
#     cluster_keys: ["report_date","cage_code"]
#     sql:
#     SELECT
#           /*+ MATERIALIZE */
#           agg.cage_player_id,
#           agg.cage_code,
#           DATE(convert_timezone('UTC', rc.cage_timezone, agg.aggregate_hour)) AS report_date,
#           SUM(loyalty_points_earned) AS bonus_store_pts_issued,
#           SUM(
#           CASE
#             WHEN
#               gd.game_type_code NOT IN
#               (
#                 'SBOOK',
#                 'TABLE'
#               )
#             THEN
#               loyalty_points_earned
#             ELSE
#               0
#           END
#       ) AS slots_llpts, SUM(
#           CASE
#             WHEN
#               gd.game_type_code = 'TABLE'
#               AND game_provider_code <> 'EVOLUTION'
#             THEN
#               loyalty_points_earned
#             ELSE
#               0
#           END
#       ) AS table_llpts, SUM(
#           CASE
#             WHEN
#               gd.game_type_code = 'TABLE'
#               AND game_provider_code = 'EVOLUTION'
#             THEN
#               loyalty_points_earned
#             ELSE
#               0
#           END
#       ) AS livedealer_llpts, SUM(
#           CASE
#             WHEN
#               gd.game_type_code = 'SBOOK'
#             THEN
#               loyalty_points_earned
#             ELSE
#               0
#           END
#       ) AS sbook_llpts
#         FROM
#           loyalty.agg_hourly_game_stats agg
#           LEFT JOIN
#             reporting.registered_cages rc
#             ON (agg.cage_code = rc.cage_code), ${non_internal_players_cte.SQL_TABLE_NAME} p, shared.game_definitions gd
#         WHERE
#           agg.cage_player_id = p.cage_player_id
#           AND agg.cage_code = p.cage_code
#           AND agg.aggregate_hour > CURRENT_DATE - INTERVAL '3670 days'
#           AND agg.game_bet_definition_code = gd.code
#           AND agg.site_code = gd.site_code
#         GROUP BY
#           1, 2, 3
#     ;;
#   }
# }

# view: game_stats_cte {
#   ## No dependencies, count = 80,574,366
#   derived_table: {
#     sql_trigger_value: select date(convert_timezone('UTC','America/Los_Angeles',current_timestamp)) ;;
#     cluster_keys: ["report_date","cage_code"]
#     sql:
#     SELECT
#           cage_player_id,
#           cage_code,
#           report_date,
#           COUNT(DISTINCT(cage_code || '-' || cage_player_id)) AS uniques_all,
#           SUM(bets) AS bets,
#           SUM(bet_amount) AS bet_amount,
#           SUM(bonus_bet_amount) AS bonus_bet_amount,
#           SUM(real_bet_amount) AS real_bet_amount,
#           SUM(win_amount) AS win_amount,
#           SUM(table_uniques) AS table_uniques,
#           SUM(table_bets) AS table_bets,
#           SUM(table_bet_amount) AS table_bet_amount,
#           SUM(table_bonus_bet_amount) AS table_bonus_bet_amount,
#           SUM(table_real_bet_amount) AS table_real_bet_amount,
#           SUM(table_win_amount) AS table_win_amount,
#           SUM(livedealer_uniques) AS livedealer_uniques,
#           SUM(livedealer_bets) AS livedealer_bets,
#           SUM(livedealer_bet_amount) AS livedealer_bet_amount,
#           SUM(livedealer_bonus_bet_amount) AS livedealer_bonus_bet_amount,
#           SUM(livedealer_real_bet_amount) AS livedealer_real_bet_amount,
#           SUM(livedealer_win_amount) AS livedealer_win_amount,
#           SUM(sbook_uniques) AS sbook_uniques,
#           SUM(sbook_bets) AS sbook_bets,
#           SUM(sbook_bet_amount) AS sbook_bet_amount,
#           SUM(sbook_bonus_bet_amount) AS sbook_bonus_bet_amount,
#           SUM(sbook_real_bet_amount) AS sbook_real_bet_amount,
#           SUM(sbook_win_amount) AS sbook_win_amount,
#           SUM(slots_uniques) AS slots_uniques,
#           SUM(slots_bets) AS slots_bets,
#           SUM(slots_bet_amount) AS slots_bet_amount,
#           SUM(slots_bonus_bet_amount) AS slots_bonus_bet_amount,
#           SUM(slots_real_bet_amount) AS slots_real_bet_amount,
#           SUM(slots_win_amount) AS slots_win_amount,
#           SUM(casino_uniques) AS casino_uniques,
#           SUM(casino_bets) AS casino_bets,
#           SUM(casino_bet_amount) AS casino_bet_amount,
#           SUM(casino_bonus_bet_amount) AS casino_bonus_bet_amount,
#           SUM(casino_real_bet_amount) AS casino_real_bet_amount,
#           SUM(casino_win_amount) AS casino_win_amount,
#           SUM(adjustments) AS adjustments,
#           SUM(casino_adjustments) AS casino_adjustments,
#           SUM(sbook_adjustments) AS sbook_adjustments,
#           SUM(slots_adjustments) AS slots_adjustments,
#           SUM(table_adjustments) AS table_adjustments,
#           SUM(livedealer_adjustments) AS livedealer_adjustments
#         FROM
#           (
#             SELECT
#               v.cage_player_id,
#               v.cage_code,
#               DATE(convert_timezone('UTC', rc.cage_timezone, v.aggregate_hour)) AS report_date,
#               COUNT(DISTINCT(v.cage_code || '-' || v.cage_player_id)) AS uniques_all,
#               0 AS bets,
#               SUM(total_bets) AS bet_amount,
#               SUM(bonuses) AS bonus_bet_amount,
#               SUM(total_bets - bonuses) AS real_bet_amount,
#               SUM(total_wins) AS win_amount,
#               COUNT(DISTINCT(CASE WHEN UPPER(tax_game_type) in ('TABLE','CARD') AND is_live_dealer = 'No' THEN v.cage_code || '-' || v.cage_player_id END)) AS table_uniques,
#               0 AS table_bets,
#               SUM(CASE WHEN UPPER(tax_game_type) in ('TABLE','CARD') AND is_live_dealer = 'No' THEN total_bets
#                       ELSE 0
#                       END)
#                         AS table_bet_amount,
#               SUM(CASE WHEN UPPER(tax_game_type) in ('TABLE','CARD') AND is_live_dealer = 'No' THEN bonuses
#                       ELSE 0
#                       END)
#                         AS table_bonus_bet_amount,
#               SUM(CASE WHEN UPPER(tax_game_type) in ('TABLE','CARD') AND is_live_dealer = 'No' THEN total_bets - bonuses
#                       ELSE 0
#                       END)
#                         AS table_real_bet_amount,
#               SUM(CASE WHEN UPPER(tax_game_type) in ('TABLE','CARD') AND is_live_dealer = 'No' THEN total_wins
#                       ELSE 0
#                       END)
#                         AS table_win_amount,
#               COUNT(DISTINCT(CASE WHEN is_live_dealer = 'Yes' THEN v.cage_code || '-' || v.cage_player_id END)) AS livedealer_uniques,
#               0 AS livedealer_bets,
#               SUM(CASE WHEN is_live_dealer = 'Yes' THEN total_bets
#                       ELSE 0
#                       END)
#                         AS livedealer_bet_amount,
#               SUM(CASE WHEN is_live_dealer = 'Yes' THEN bonuses
#                       ELSE 0
#                       END)
#                         AS livedealer_bonus_bet_amount,
#               SUM(CASE WHEN is_live_dealer = 'Yes' THEN total_bets - bonuses
#                       ELSE 0
#                       END)
#                         AS livedealer_real_bet_amount,
#               SUM(CASE WHEN is_live_dealer = 'Yes' THEN total_wins
#                       ELSE 0
#                       END)
#                         AS livedealer_win_amount,
#               COUNT(DISTINCT(CASE WHEN v.cage_code IN (57, 52) AND UPPER(tax_game_type) = 'SPORTS' THEN v.cage_code || '-' || v.cage_player_id END)) AS sbook_uniques,
#               0 AS sbook_bets,
#               SUM(CASE WHEN v.cage_code IN (57, 52) AND UPPER(tax_game_type) = 'SPORTS' THEN total_bets
#                       ELSE 0
#                       END)
#                         AS sbook_bet_amount,
#               SUM(CASE WHEN v.cage_code IN (57, 52) AND UPPER(tax_game_type) = 'SPORTS' THEN bonuses
#                       ELSE 0
#                       END)
#                         AS sbook_bonus_bet_amount,
#               SUM(CASE WHEN v.cage_code IN (57, 52) AND UPPER(tax_game_type) = 'SPORTS' THEN total_bets - bonuses
#                       ELSE 0
#                       END)
#                         AS sbook_real_bet_amount,
#               SUM(CASE WHEN v.cage_code IN (57, 52) AND UPPER(tax_game_type) = 'SPORTS' THEN total_wins
#                       ELSE 0
#                       END)
#                         AS sbook_win_amount,
#               COUNT(DISTINCT(CASE WHEN UPPER(tax_game_type) NOT IN ('SPORTS','CARD','TABLE') and is_live_dealer = 'No' THEN v.cage_code || '-' || v.cage_player_id END)) AS slots_uniques,
#               0 AS slots_bets,
#               SUM(CASE WHEN UPPER(tax_game_type) NOT IN ('SPORTS','CARD','TABLE') and is_live_dealer = 'No' THEN total_bets
#                       ELSE 0
#                       END)
#                         AS slots_bet_amount,
#               SUM(CASE WHEN UPPER(tax_game_type) NOT IN ('SPORTS','CARD','TABLE') and is_live_dealer = 'No' THEN bonuses
#                       ELSE 0
#                       END)
#                         AS slots_bonus_bet_amount,
#               SUM(CASE WHEN UPPER(tax_game_type) NOT IN ('SPORTS','CARD','TABLE') and is_live_dealer = 'No' THEN total_bets - bonuses
#                       ELSE 0
#                       END)
#                         AS slots_real_bet_amount,
#               SUM(CASE WHEN UPPER(tax_game_type) NOT IN ('SPORTS','CARD','TABLE') and is_live_dealer = 'No' THEN total_wins
#                       ELSE 0
#                       END)
#                         AS slots_win_amount,
#               COUNT(DISTINCT(CASE WHEN UPPER(tax_game_type) <> 'SPORTS' THEN v.cage_code || '-' || v.cage_player_id END)) AS casino_uniques,
#               0 AS casino_bets,
#               SUM(CASE WHEN UPPER(tax_game_type) <> 'SPORTS' THEN total_bets
#                       ELSE 0
#                       END)
#                         AS casino_bet_amount,
#               SUM(CASE WHEN UPPER(tax_game_type) <> 'SPORTS' THEN bonuses
#                       ELSE 0
#                       END)
#                         AS casino_bonus_bet_amount,
#               SUM(CASE WHEN UPPER(tax_game_type) <> 'SPORTS' THEN total_bets - bonuses
#                       ELSE 0
#                       END)
#                         AS casino_real_bet_amount,
#               SUM(CASE WHEN UPPER(tax_game_type) <> 'SPORTS' THEN total_wins
#                       ELSE 0
#                       END)
#                         AS casino_win_amount,
#               SUM(revenue_adjustments) AS adjustments,
#               SUM(CASE WHEN UPPER(tax_game_type) <> 'SPORTS' THEN revenue_adjustments
#                       ELSE 0
#                       END)
#                         AS casino_adjustments,
#               SUM(CASE WHEN v.cage_code IN (57, 52) AND UPPER(tax_game_type) = 'SPORTS' THEN revenue_adjustments
#                       ELSE 0
#                       END)
#                         AS sbook_adjustments,
#               SUM(CASE WHEN UPPER(tax_game_type) NOT IN ('SPORTS','CARD','TABLE') and is_live_dealer = 'No' THEN revenue_adjustments
#                       ELSE 0
#                       END)
#                         AS slots_adjustments,
#               SUM(CASE WHEN UPPER(tax_game_type) in ('TABLE','CARD') and is_live_dealer = 'No' THEN revenue_adjustments
#                       ELSE 0
#                       END)
#                         AS table_adjustments,
#               SUM(CASE WHEN is_live_dealer = 'Yes' THEN revenue_adjustments
#                       ELSE 0
#                       END)
#                         AS livedealer_adjustments
#             FROM
#               reporting.operator_revenue_v v
#               LEFT JOIN
#                 reporting.registered_cages rc
#                 ON (v.cage_code = rc.cage_code)
#               LEFT JOIN
#                 reporting.cage_game_definitions cgd
#                 ON (cgd.cage_code = v.cage_code
#                 AND cgd.game_definition_code = v.game_definition_code)
#               LEFT JOIN
#                 reporting.game_definition_segmentations gds
#                 ON (gds.game_definition_code = v.game_definition_code
#                 AND gds.site_code = v.site_code)
#             WHERE
#               v.is_internal = '0'
#               AND v.game_definition_code IS NOT NULL        --and v.cage_code in (57,52)
#             GROUP BY
#               1, 2, 3

#             UNION ALL

#             SELECT
#               /*+ MATERIALIZE */
#               agg.cage_player_id,
#               agg.cage_code,
#               DATE(convert_timezone('UTC', rc.cage_timezone, end_time)) AS report_date,
#               -- COUNT(DISTINCT(agg.CAGE_CODE||'-'||agg.CAGE_PLAYER_ID)) AS UNIQUES_ALL,
#               0 AS uniques_all,
#               SUM(bet_count) AS bets,
#               0 AS bet_amount,
#               0 AS bonus_bet_amount,
#               0 AS real_bet_amount,
#               0 AS win_amount,
#               -- COUNT(DISTINCT(CASE WHEN GAME_TYPE_CODE in ('TABLE','BLACKJACK') AND is_live_dealer = 'No' THEN agg.CAGE_CODE||'-'||agg.CAGE_PLAYER_ID END)) AS TABLE_UNIQUES,
#               -- SUM(CASE WHEN GAME_TYPE_CODE in ('TABLE','BLACKJACK') AND is_live_dealer = 'No' THEN bet_count ELSE 0 END) AS TABLE_BETS,
#               -- SUM(CASE WHEN GAME_TYPE_CODE in ('TABLE','BLACKJACK') AND is_live_dealer = 'No' THEN BETS ELSE 0 END) AS TABLE_BET_AMOUNT,
#               -- SUM(CASE WHEN GAME_TYPE_CODE in ('TABLE','BLACKJACK') AND is_live_dealer = 'No' THEN BONUS_BETS ELSE 0 END) AS TABLE_BONUS_BET_AMOUNT,
#               -- SUM(CASE WHEN GAME_TYPE_CODE in ('TABLE','BLACKJACK') AND is_live_dealer = 'No' THEN REAL_BETS ELSE 0 END) AS TABLE_REAL_BET_AMOUNT,
#               -- SUM(CASE WHEN GAME_TYPE_CODE in ('TABLE','BLACKJACK') AND is_live_dealer = 'No' THEN WINS ELSE 0 END) AS TABLE_WIN_AMOUNT,
#               0 AS table_uniques,
#               SUM(CASE WHEN game_type_code IN ('TABLE','BLACKJACK') AND is_live_dealer = 'No' THEN bet_count
#                       ELSE 0
#                       END)
#                         AS table_bets,
#               0 AS table_bet_amount,
#               0 AS table_bonus_bet_amount,
#               0 AS table_real_bet_amount,
#               0 AS table_win_amount,
#               -- COUNT(DISTINCT(CASE WHEN is_live_dealer = 'Yes' THEN agg.CAGE_CODE||'-'||agg.CAGE_PLAYER_ID END)) AS LIVEDEALER_UNIQUES,
#               -- SUM(CASE WHEN is_live_dealer = 'Yes' THEN bet_count ELSE 0 END) AS LIVEDEALER_BETS,
#               -- SUM(CASE WHEN is_live_dealer = 'Yes' THEN BETS ELSE 0 END) AS LIVEDEALER_BET_AMOUNT,
#               -- SUM(CASE WHEN is_live_dealer = 'Yes' THEN BONUS_BETS ELSE 0 END) AS LIVEDEALER_BONUS_BET_AMOUNT,
#               -- SUM(CASE WHEN is_live_dealer = 'Yes' THEN REAL_BETS ELSE 0 END) AS LIVEDEALER_REAL_BET_AMOUNT,
#               -- SUM(CASE WHEN is_live_dealer = 'Yes' THEN WINS ELSE 0 END) AS LIVEDEALER_WIN_AMOUNT,
#               0 AS livedealer_uniques,
#               SUM(CASE WHEN is_live_dealer = 'Yes' THEN bet_count
#                       ELSE 0
#                       END)
#                         AS livedealer_bets,
#               0 AS livedealer_bet_amount,
#               0 AS livedealer_bonus_bet_amount,
#               0 AS livedealer_real_bet_amount,
#               0 AS livedealer_win_amount,
#               0 AS sbook_uniques,
#               0 AS sbook_bets,
#               0 AS sbook_bet_amount,
#               0 AS sbook_bonus_bet_amount,
#               0 AS sbook_real_bet_amount,
#               0 AS sbook_win_amount,
#               -- COUNT(DISTINCT(CASE WHEN GAME_TYPE_CODE = 'SLOT' THEN agg.CAGE_CODE||'-'||agg.CAGE_PLAYER_ID END)) AS SLOTS_UNIQUES,
#               -- SUM(CASE WHEN GAME_TYPE_CODE = 'SLOT' THEN bet_count ELSE 0 END) AS SLOTS_BETS,
#               -- SUM(CASE WHEN GAME_TYPE_CODE = 'SLOT' THEN BETS ELSE 0 END) AS SLOTS_BET_AMOUNT,
#               -- SUM(CASE WHEN GAME_TYPE_CODE = 'SLOT' THEN BONUS_BETS ELSE 0 END) AS SLOTS_BONUS_BET_AMOUNT,
#               -- SUM(CASE WHEN GAME_TYPE_CODE = 'SLOT' THEN REAL_BETS ELSE 0 END) AS SLOTS_REAL_BET_AMOUNT,
#               -- SUM(CASE WHEN GAME_TYPE_CODE = 'SLOT' THEN WINS ELSE 0 END) AS SLOTS_WIN_AMOUNT,
#               0 AS slots_uniques,
#               SUM(CASE WHEN game_type_code = 'SLOT' THEN bet_count
#                       ELSE 0
#                       END)
#                         AS slots_bets,
#               0 AS slots_bet_amount,
#               0 AS slots_bonus_bet_amount,
#               0 AS slots_real_bet_amount,
#               0 AS slots_win_amount,
#               -- COUNT(DISTINCT(agg.CAGE_CODE||'-'||agg.CAGE_PLAYER_ID)) AS CASINO_UNIQUES,
#               -- SUM(bet_count) AS CASINO_BETS,
#               -- SUM(BETS) AS CASINO_BET_AMOUNT,
#               -- SUM(BONUS_BETS) AS CASINO_BONUS_BET_AMOUNT,
#               -- SUM(REAL_BETS) AS CASINO_REAL_BET_AMOUNT,
#               -- SUM(WINS) AS CASINO_WIN_AMOUNT,
#               0 AS casino_uniques,
#               SUM(bet_count) AS casino_bets,
#               0 AS casino_bet_amount,
#               0 AS casino_bonus_bet_amount,
#               0 AS casino_real_bet_amount,
#               0 AS casino_win_amount,
#               0 AS adjustments,
#               0 AS casino_adjustments,
#               0 AS sbook_adjustments,
#               0 AS slots_adjustments,
#               0 AS table_adjustments,
#               0 AS livedealer_adjustments
#             FROM
#               cage.cage_game_rounds agg         -- left join looker_scratch.bonus_money_override_2 bmo
#               --   on DATE(convert_timezone('UTC','America/New_York',end_time )) = bmo.report_date
#               JOIN
#                 cage.cage_players cp
#                 ON agg.cage_player_id = cp.cage_player_id
#                 AND agg.cage_code = cp.cage_code
#               JOIN
#                 shared.game_definitions gd
#                 ON agg.game_definition_code = gd.code
#                 AND agg.site_code = gd.site_code
#               JOIN
#                 reporting.game_definition_segmentations gds
#                 ON agg.game_definition_code = gds.game_definition_code
#                 AND agg.site_code = gds.site_code
#               LEFT JOIN
#                 reporting.registered_cages rc
#                 ON (agg.cage_code = rc.cage_code)
#             WHERE
#               cp.is_internal = '0'
#               AND end_time > CURRENT_DATE - INTERVAL '3670 days'        -- and GAME_TYPE_CODE <> 'SBOOK'
#               -- and cage_code <> 57
#               --and agg.cage_code not in (57,52)
#               --and agg.cage_code is null
#             GROUP BY
#               1, 2, 3         -- ,bmo.report_date
#             UNION ALL
#             SELECT
#               /*+ MATERIALIZE */
#               ccc.cage_player_id,
#               ccc.cage_code,
#               DATE(convert_timezone('UTC', rc.cage_timezone, ccc.first_end_time)) AS report_date,
#               COUNT(DISTINCT(ccc.cage_code || '-' || ccc.cage_player_id)) AS uniques_all,
#               COUNT(DISTINCT(ccc.id)) AS bets,
#               0 AS bet_amount,
#               0 AS bonus_bet_amount,
#               0 AS real_bet_amount,
#               0 AS win_amount,
#               0 AS table_uniques,
#               0 AS table_bets,
#               0 AS table_bet_amount,
#               0 AS table_bonus_bet_amount,
#               0 AS table_real_bet_amount,
#               0 AS table_win_amount,
#               0 AS livedealer_uniques,
#               0 AS livedealer_bets,
#               0 AS livedealer_bet_amount,
#               0 AS livedealer_bonus_bet_amount,
#               0 AS livedealer_real_bet_amount,
#               0 AS livedealer_win_amount,
#               --0 AS SBOOK_UNIQUES,
#               --count(distinct(ccc.id)) AS SBOOK_BETS,
#               --0 AS SBOOK_BET_AMOUNT,
#               --0 AS SBOOK_BONUS_BET_AMOUNT,
#               --0 AS SBOOK_REAL_BET_AMOUNT,
#               --0 AS SBOOK_WIN_AMOUNT,
#               COUNT(DISTINCT(ccc.cage_code || '-' || ccc.cage_player_id)) AS sbook_uniques,
#               COUNT(DISTINCT(ccc.id)) AS sbook_bets,
#               COALESCE(SUM(CAST(ccp.amount AS DOUBLE PRECISION)), 0) AS sbook_bet_amount,
#               COALESCE(SUM(CAST(ccp.amount_bonus AS DOUBLE PRECISION)), 0) AS sbook_bonus_bet_amount,
#               COALESCE(SUM(CAST(ccp.amount_real AS DOUBLE PRECISION)), 0)         -- -
#               -- case when bmo.report_date is NULL or ccc.cage_code <> 2 then
#               -- COALESCE(SUM(CAST(ccp.amount_bonus AS DOUBLE PRECISION)), 0)
#               --       else min(bmo.SBOOK_BONUS_BET_AMOUNT) end
#                 AS sbook_real_bet_amount,
#               SUM(CASE WHEN ccc.status = 'SETTLED' THEN ccc.win
#                       ELSE ccp.amount
#                       END)
#                         AS sbook_win_amount,
#               0 AS slots_uniques,
#               0 AS slots_bets,
#               0 AS slots_bet_amount,
#               0 AS slots_bonus_bet_amount,
#               0 AS slots_real_bet_amount,
#               0 AS slots_win_amount,
#               0 AS casino_uniques,
#               0 AS casino_bets,
#               0 AS casino_bet_amount,
#               0 AS casino_bonus_bet_amount,
#               0 AS casino_real_bet_amount,
#               0 AS casino_win_amount,
#               0 AS adjustments,
#               0 AS casino_adjustments,
#               0 AS sbook_adjustments,
#               0 AS slots_adjustments,
#               0 AS table_adjustments,
#               0 AS livedealer_adjustments
#             FROM
#               cage.cage_coupon_combinations ccc
#               JOIN
#                 cage.cage_coupon_payments ccp
#                 ON CAST(ccc.id AS BIGINT) = CAST(ccp.cage_combination_id AS BIGINT)
#                 AND ccc.cage_code = ccp.cage_code
#               JOIN
#                 cage.cage_players cp
#                 ON ccp.cage_player_id = cp.cage_player_id
#                 AND ccp.cage_code = cp.cage_code
#               LEFT JOIN
#                 reporting.registered_cages rc
#                 ON (ccc.cage_code = rc.cage_code)           -- left join looker_scratch.bonus_money_override_2 bmo
#                 --   on DATE(convert_timezone('UTC','America/New_York',ccc.first_end_time )) = bmo.report_date
#                 -- join ${non_internal_players_cte.SQL_TABLE_NAME} p
#                 --   on ccc.CAGE_PLAYER_ID = P.CAGE_PLAYER_ID
#                 --     and ccc.cage_code = p.cage_code
#             WHERE
#               ccp.type = 'BET'
#               AND ccp.status IN ('APPROVED')
#               AND ccc.status IN ('SETTLED','PUSHED')
#               AND cp.is_internal = '0'
#               AND ccc.cage_code NOT IN (57, 52)
#               --and ccc.cage_code is null
#             GROUP BY
#               1, 2, 3         -- , bmo.report_date
#           )
#         GROUP BY
#           1, 2, 3
#     ;;
#   }

#   dimension: bet_amount {
#     type: number
#   }

#   dimension: bonus_bet_amount {
#     type: number
#   }
# }


# view: bonuses_cte {
#   ## Dependency on non_internal_player_cte, count = 10,913,305
#   derived_table: {
#     sql_trigger_value: SELECT count(*) FROM ${store_pts_issued_cte.SQL_TABLE_NAME} spi ;;
#     cluster_keys: ["report_date","cage_code"]
#     sql:
#     SELECT
#           /*+ MATERIALIZE */
#           pb.cage_player_id,
#           pb.cage_code,
#           DATE(convert_timezone('UTC', rc.cage_timezone, create_time)) AS report_date,
#           SUM(bonus_amount)
#             - SUM(CASE WHEN voided_amount IS NULL THEN 0
#                       ELSE voided_amount
#                       END)
#             AS bonus_money_issued
#         FROM
#           cage.player_wagering_bonuses pb
#           LEFT JOIN
#             reporting.registered_cages rc
#             ON (pb.cage_code = rc.cage_code), ${non_internal_players_cte.SQL_TABLE_NAME} p
#         WHERE
#           pb.cage_player_id = p.cage_player_id
#           AND pb.cage_code = p.cage_code
#         GROUP BY
#           1, 2, 3
#     ;;
#   }

#   dimension: bonus_money_issued {
#     type: number
#   }
# }

view: level_by_day_cte {
  sql_table_name: edw.kpi_players_level_by_day ;;
  ## Dependency on non_internal_player_cte, count = 650,863,914
  # derived_table: {
  #   datagroup_trigger: daily
  #   # sql_trigger_value: SELECT count(*) FROM ${bonuses_cte.SQL_TABLE_NAME} b ;;
  #   cluster_keys: ["report_date","cage_code"]
  #   sql:
  #   SELECT
  #         /*+ MATERIALIZE */
  #         level.cage_code,
  #         change_date AS report_date,
  #         new_loyalty_level AS loyalty_level,
  #         level.cage_player_id
  #       FROM
  #         (
  #           SELECT
  #             cage_code,
  #             cage_player_id,
  #             change_date,
  #             new_loyalty_level,
  #             ROW_NUMBER() OVER (PARTITION BY cage_code, cage_player_id, change_date
  #           ORDER BY
  #             type DESC, true_date DESC) AS row_no
  #           FROM
  #             (
  #               SELECT
  #                 cage_code,
  #                 cage_player_id,
  #                 change_date,
  #                 change_date AS true_date,
  #                 new_loyalty_level,
  #                 'true' AS type
  #               FROM
  #                 (
  #                   SELECT
  #                     cage_code,
  #                     cage_player_id,
  #                     DATE(convert_timezone('UTC', 'America/New_York', change_time)) AS change_date,
  #                     change_time,
  #                     CAST(new_loyalty_level AS NUMERIC) AS new_loyalty_level,
  #                     ROW_NUMBER() OVER (PARTITION BY cage_code, cage_player_id, DATE(convert_timezone('UTC', 'America/New_York', change_time))
  #                   ORDER BY
  #                     change_time DESC) AS row_no
  #                   FROM
  #                     loyalty.player_level_changes
  #                   WHERE
  #                     product_code = 'COMBINED'
  #                 )
  #                 raw
  #               WHERE
  #                 row_no = 1
  #               UNION ALL
  #               SELECT
  #                 cage_code,
  #                 cage_player_id,
  #                 change_date + generate_series AS change_date,
  #                 change_date AS true_date,
  #                 new_loyalty_level,
  #                 'rolling' AS type
  #               FROM
  #                 (
  #                   SELECT
  #                     cage_code,
  #                     cage_player_id,
  #                     change_date,
  #                     new_loyalty_level
  #                   FROM
  #                     (
  #                       SELECT
  #                         cage_code,
  #                         cage_player_id,
  #                         DATE(convert_timezone('UTC', 'America/New_York', change_time)) AS change_date,
  #                         change_time,
  #                         CAST(new_loyalty_level AS NUMERIC) AS new_loyalty_level,
  #                         ROW_NUMBER() OVER (PARTITION BY cage_code, cage_player_id, DATE(convert_timezone('UTC', 'America/New_York', change_time))
  #                       ORDER BY
  #                         change_time DESC) AS row_no
  #                       FROM
  #                         loyalty.player_level_changes
  #                       WHERE
  #                         product_code = 'COMBINED'
  #                     )
  #                     raw
  #                   WHERE
  #                     row_no = 1
  #                 )
  #                 rolling,
  #                 (
  #                   SELECT
  #                     seq4() AS generate_series
  #                   FROM
  #                     TABLE (generator(rowcount => 2001))
  #                 )
  #                 gs
  #             )
  #             levels
  #         )
  #         level,
  #         ${non_internal_players_cte.SQL_TABLE_NAME} p
  #       WHERE
  #         level.cage_player_id = p.cage_player_id
  #         AND level.cage_code = p.cage_code
  #         AND row_no = 1
  #         AND change_date <= CURRENT_DATE
  #         ;;
  # }

  dimension: loyalty_level {
    type: string
  }
}

# view: sb_promos_cte {
#   ## Dependency on non_internal_player_cte
#   derived_table: {
#     sql_trigger_value: SELECT count(*) FROM ${level_by_day_cte.SQL_TABLE_NAME} lbd ;;
#     cluster_keys: ["report_date","cage_code"]
#     sql:
#     SELECT
#           /*+ MATERIALIZE */
#           sbp.*
#         FROM
#           (
#             SELECT
#               a.cage_player_id,
#               a.cage_code AS cage_code,
#               report_date,
#               outstanding_fb_amount,
#               in_use_fb_amount,
#               SUM(CASE WHEN reward_type IN ('FREE_BET','ODDS_BOOST','PROFIT_BOOST') THEN stake
#                       ELSE 0
#                       END) AS promo_handle_total ,
#               SUM(CASE WHEN reward_type = 'FREE_BET' THEN stake
#                       ELSE 0
#                       END)
#                       AS promo_handle_fb ,
#               SUM(CASE WHEN reward_type = 'ODDS_BOOST' THEN stake
#                       ELSE 0
#                       END)
#                         AS promo_handle_ob ,
#               SUM(CASE WHEN reward_type = 'PROFIT_BOOST' THEN stake
#                       ELSE 0
#                       END)
#                         AS promo_handle_pb ,
#               SUM(CASE WHEN reward_type IN ('FREE_BET', 'ODDS_BOOST', 'PROFIT_BOOST') THEN payout
#                       ELSE 0
#                       END)
#                         AS promo_win_amount_total ,
#               SUM(CASE WHEN reward_type = 'FREE_BET' THEN payout
#                       ELSE 0
#                       END)
#                         AS promo_win_amount_fb ,
#               SUM(CASE WHEN reward_type = 'ODDS_BOOST' THEN payout
#                       ELSE 0
#                       END)
#                         AS promo_win_amount_ob ,
#               SUM(CASE WHEN reward_type = 'PROFIT_BOOST' THEN payout
#                       ELSE 0
#                       END)
#                         AS promo_win_amount_pb ,
#               SUM(CASE WHEN reward_type IN ('PROFIT_BOOST', 'ODDS_BOOST') THEN profit_boost_amount_share
#                       WHEN reward_type = 'FREE_BET' THEN stake
#                       ELSE 0
#                       END)
#                         AS promo_bonus_total ,
#               SUM(CASE WHEN reward_type IN ('PROFIT_BOOST') THEN profit_boost_amount_share
#                       ELSE 0
#                       END)
#                         AS promo_bonus_pb ,
#               SUM(CASE WHEN reward_type IN ('ODDS_BOOST') THEN profit_boost_amount_share
#                       ELSE 0
#                       END)
#                         AS promo_bonus_ob ,
#               SUM(CASE WHEN reward_type IN ('FREE_BET') THEN stake
#                       ELSE 0
#                       END)
#                         AS promo_bonus_fb ,
#               SUM(CASE WHEN reward_type IN ('FREE_BET', 'PROFIT_BOOST', 'ODDS_BOOST') THEN 1
#                       ELSE 0
#                       END)
#                         AS total_sbp_unique ,
#               SUM(CASE WHEN reward_type = 'FREE_BET' THEN 1
#                       ELSE 0
#                       END)
#                         AS fb_unique ,
#               SUM(CASE WHEN reward_type = 'PROFIT_BOOST' THEN 1
#                       ELSE 0
#                       END)
#                         AS pb_unique ,
#               SUM(CASE WHEN reward_type = 'ODDS_BOOST' THEN 1
#                       ELSE 0
#                       END)
#                         AS ob_unique ,
#               SUM(CASE WHEN bet_status = 'WON' THEN 1
#                       ELSE 0
#                       END)
#                         AS promo_wins ,
#               SUM(CASE WHEN bet_status = 'WON' AND reward_type = 'FREE_BET' THEN 1
#                       ELSE 0
#                       END)
#                         AS promo_wins_fb ,
#               SUM(CASE WHEN bet_status = 'WON' AND reward_type = 'ODDS_BOOST' THEN 1
#                       ELSE 0
#                       END)
#                         AS promo_wins_ob ,
#               SUM(CASE WHEN bet_status = 'WON' AND reward_type = 'PROFIT_BOOST' THEN 1
#                       ELSE 0
#                       END)
#                         AS promo_wins_pb ,
#               SUM(CASE WHEN bet_status = 'LOST' THEN 1
#                       ELSE 0
#                       END)
#                         AS promo_lost ,
#               SUM(CASE WHEN bet_status = 'LOST' AND reward_type = 'FREE_BET' THEN 1
#                       ELSE 0
#                       END)
#                         AS promo_lost_fb ,
#               SUM(CASE WHEN bet_status = 'LOST' AND reward_type = 'ODDS_BOOST' THEN 1
#                       ELSE 0
#                       END)
#                         AS promo_lost_ob ,
#               SUM(CASE WHEN bet_status = 'LOST' AND reward_type = 'PROFIT_BOOST' THEN 1
#                       ELSE 0
#                       END)
#                         AS promo_lost_pb ,
#               SUM(CASE WHEN bet_status = 'VOID' THEN 1
#                       ELSE 0
#                       END)
#                         AS promo_voids ,
#               SUM(CASE WHEN bet_status = 'VOID' AND reward_type = 'FREE_BET' THEN 1
#                       ELSE 0
#                       END)
#                         AS promo_voids_fb ,
#               SUM(CASE WHEN bet_status = 'VOID' AND reward_type = 'ODDS_BOOST' THEN 1
#                       ELSE 0
#                       END)
#                         AS promo_voids_ob ,
#               SUM(CASE WHEN bet_status = 'VOID' AND reward_type = 'PROFIT_BOOST' THEN 1
#                       ELSE 0
#                       END)
#                         AS promo_voids_pb
#             FROM
#               (
#                 SELECT
#                   sc.*,
#                   DATE(convert_timezone('UTC', rc.cage_timezone, original_settled_date)) AS report_date,
#                   CASE WHEN combination_status_id = '7' THEN 'CASHED_OUT'
#                       WHEN combination_status_id = '1' THEN 'OPEN'
#                       WHEN stake < payout AND profit_boost_amount_share = 0 THEN 'NO_ODDS_BOOST'
#                       WHEN stake > payout AND payout != 0 THEN 'DISCREPANCY'                 -- NO discrpancies for odds boost
#                       WHEN stake = payout THEN 'VOID'
#                       WHEN stake > payout THEN 'LOST'
#                       WHEN stake < payout THEN 'WON'
#                       END
#                         AS bet_status
#                 FROM
#                   kambi.summary_combinations sc
#                   LEFT JOIN
#                     reporting.registered_cages rc
#                     ON (sc.cage_code = rc.cage_code)
#                 WHERE
#                   reward_type IN ('PROFIT_BOOST', 'ODDS_BOOST', 'FREE_BET')
#                   AND combination_status_id IN ('2', '3', '7')
#                   AND original_settled_date IS NOT NULL
#                   AND terminal_ref = '-1'
#               )
#               a
#               LEFT JOIN
#                 (
#                   SELECT
#                     cage_code,
#                     cage_player_id,
#                     COALESCE(SUM(CASE WHEN status_desc = 'Active' THEN amount END), 0) AS outstanding_fb_amount ,
#                     COALESCE(SUM(CASE WHEN status_desc = 'In Use' THEN amount END), 0) AS in_use_fb_amount
#                   FROM
#                     (
#                       SELECT
#                         *,
#                         CASE WHEN reward_type = 1 THEN 'FREE_BET'
#                             WHEN reward_type = 2 THEN 'PROFIT_BOOST'
#                             WHEN reward_type = 4 THEN 'ODDS_BOOST'
#                             ELSE 'OTHER'
#                             END
#                               AS type
#                       FROM
#                         kambi.bonus_rewards br
#                         JOIN
#                           (
#                             SELECT
#                               coupon_id,
#                               terminal_ref
#                             FROM
#                               kambi.summary_combinations
#                             WHERE
#                               terminal_ref = '-1'
#                           )
#                           sc
#                           ON br.coupon_id = sc.coupon_id                    -- WHERE left(customer_punter_id,position('-' in customer_punter_id)-1) IN ('720','847','812','268','267','2','57','705','777')
#                     )
#                     bb
#                   GROUP BY
#                     1,
#                     2
#                 )
#                 ost
#                 ON ost.cage_player_id = a.cage_player_id
#                 AND ost.cage_code = a.cage_code
#             GROUP BY
#               1,
#               2,
#               3,
#               4,
#               5
#           )
#           sbp,
#           ${non_internal_players_cte.SQL_TABLE_NAME} p
#         WHERE
#           sbp.cage_player_id = p.cage_player_id
#           AND sbp.cage_code = p.cage_code
#     ;;
#   }

#   dimension: outstanding_fb_amount {
#     type: number
#   }
# }

# view: fb_promos_cte {
#   ## Dependency on non_internal_player_cte, count = 8,838,018
#   derived_table: {
#     sql_trigger_value: SELECT count(*) FROM ${sb_promos_cte.SQL_TABLE_NAME} sbp ;;
#     cluster_keys: ["report_date","cage_code"]
#     sql:
#     SELECT
#           /*+ MATERIALIZE */
#           all_data.cage_player_id,
#           all_data.cage_code,
#           all_data.report_date,
#           SUM(free_bets_issued) AS free_bets_issued,
#           SUM(free_bets_placed) AS free_bets_placed,
#           SUM(free_bets_won) AS free_bets_won
#         FROM
#           (
#             -- bonuses free bets issued
#             SELECT
#               pp.cage_code,
#               cage_player_id,
#               DATE(convert_timezone('UTC', rc.cage_timezone, promotion_issued_date)) AS report_date,
#               SUM(CAST(NULLIF(json_extract_path_text(prize_parameters, 'AMOUNT'), '') AS NUMERIC)) AS free_bets_issued,
#               0 AS free_bets_placed,
#               0 AS free_bets_won
#             FROM
#               cage.player_promotions pp
#               LEFT JOIN
#                 reporting.registered_cages rc
#                 ON (pp.cage_code = rc.cage_code)
#             WHERE
#               promotion_provider_code = 'KAMBI'
#             GROUP BY
#               1,
#               2,
#               3

#             UNION ALL

#             -- bonuses free bets placed and won
#             SELECT
#               sc.cage_code,
#               cage_player_id,
#               DATE(convert_timezone('UTC', rc.cage_timezone, original_settled_date)) AS report_date,
#               0 AS free_bets_issued,
#               SUM(stake) AS free_bets_placed,
#               SUM(payout) AS free_bets_won
#             FROM
#               kambi.summary_combinations sc
#               LEFT JOIN
#                 reporting.registered_cages rc
#                 ON (sc.cage_code = rc.cage_code)
#             WHERE
#               reward_type = 'FREE_BET'
#               AND combination_status_id IN
#               (
#                 2,
#                 3,
#                 7
#               )
#               AND sc.cage_code IS NOT NULL
#             GROUP BY
#               1,
#               2,
#               3
#           )
#           all_data,
#           ${non_internal_players_cte.SQL_TABLE_NAME} p
#         WHERE
#           all_data.cage_player_id = p.cage_player_id
#           AND all_data.cage_code = p.cage_code
#         GROUP BY
#           1,
#           2,
#           3
#     ;;
#   }

#   dimension: free_bets_won {
#     type: string
#   }
# }

# view: vip_level_historical_cte {
#   derived_table: {
#     sql_trigger_value: select date(convert_timezone('UTC','America/Los_Angeles',current_timestamp)) ;;
#     cluster_keys: ["report_date","cage_code"]
#     sql: SELECT
#           /*+ MATERIALIZE */
#           level.cage_code,
#           change_date AS report_date,
#           new_value AS vip_level_code_historical,
#           level.cage_player_id
#         FROM
#           (
#             SELECT
#               cage_code,
#               cage_player_id,
#               change_date,
#               new_value,
#               ROW_NUMBER() OVER (PARTITION BY cage_code, cage_player_id, change_date
#             ORDER BY
#               type DESC, true_date DESC) AS row_no
#             FROM
#               (
#                 SELECT
#                   cage_code,
#                   cage_player_id,
#                   change_date,
#                   change_date AS true_date,
#                   new_value,
#                   'true' AS type
#                 FROM
#                   (
#                         SELECT
#                           t1.cage_code,
#                           cage_player_id,
#                           DATE(convert_timezone('UTC', cage_timezone, t1.change_timestamp)) AS change_date,
#                           change_timestamp,
#                           new_value AS new_value,
#                           ROW_NUMBER() OVER (PARTITION BY t1.cage_code, cage_player_id, DATE(convert_timezone('UTC', cage_timezone, t1.change_timestamp)) ORDER BY change_timestamp DESC) AS row_no
#                         FROM "CAGE"."PLAYER_PROFILE_CHANGES" t1
#                       LEFT JOIN reporting.registered_cages t2 ON (t1.cage_code = t2.cage_code)
#                         where upper(change_subject)= 'VIP_LEVEL'
#                   )
#                   raw
#                 WHERE
#                   row_no = 1
#                 UNION ALL
#                 SELECT
#                   cage_code,
#                   cage_player_id,
#                   change_date + generate_series AS change_date,
#                   change_date AS true_date,
#                   new_value,
#                   'rolling' AS type
#                 FROM
#                   (
#                     SELECT
#                       cage_code,
#                       cage_player_id,
#                       change_date,
#                       new_value
#                     FROM
#                       (
#                         SELECT
#                           t1.cage_code,
#                           cage_player_id,
#                           DATE(convert_timezone('UTC', cage_timezone, t1.change_timestamp)) AS change_date,
#                           change_timestamp,
#                           new_value AS new_value,
#                           ROW_NUMBER() OVER (PARTITION BY t1.cage_code, cage_player_id, DATE(convert_timezone('UTC', cage_timezone, t1.change_timestamp)) ORDER BY change_timestamp DESC) AS row_no
#                         FROM "CAGE"."PLAYER_PROFILE_CHANGES" t1
#                       LEFT JOIN reporting.registered_cages t2 ON (t1.cage_code = t2.cage_code)
#                         where upper(change_subject)= 'VIP_LEVEL'
#                       )
#                       raw
#                     WHERE
#                       row_no = 1
#                   )
#                   rolling,
#                   (
#                     SELECT
#                       seq4() AS generate_series
#                     FROM
#                       TABLE (generator(rowcount => 2001))
#                   )
#                   gs
#                 order by 3
#               )
#               levels
#           )
#           level,
#           edw.kpi_player_non_internal_players p --${non_internal_players_cte.SQL_TABLE_NAME} p
#         WHERE
#           level.cage_player_id = p.cage_player_id
#           AND level.cage_code = p.cage_code
#           AND row_no = 1
#           AND change_date <= CURRENT_DATE
#           order by 2 ;;
#   }
#   }

view: kpi_player {
  sql_table_name: edw.kpi_player;;
   set: player_payments_set {
     fields: [percent_fee_of_ngr, percent_fee_of_handle]
   }
  # derived_table: {
  #   publish_as_db_view: yes
  #   sql_trigger_value: SELECT count(*) FROM ${vip_level_historical_cte.SQL_TABLE_NAME} fbp ;;
  #   increment_key: "report_date_date"
  #   increment_offset: 1
  #   cluster_keys: ["report_date","cage_code"]
  ##   sql:
  ##    SELECT
  ##      kpi.*
  ##      , vip.vip_level_code_historical AS vip_level_code_historical_new
  ##    FROM edw.kpi_player kpi
  ##    LEFT JOIN ${vip_level_historical_cte.SQL_TABLE_NAME} vip
  ##      ON kpi.report_date = vip.report_date
  ##      AND kpi.cage_player_id = vip.cage_player_id
  ##      AND kpi.cage_code = vip.cage_code
  ##      ;;}
  #     SELECT
  #   c.cage_player_id,
  #   c.cage_code,
  #   c.report_date,
  #   c.site_code,
  #   gtp.last_game_date,
  #   gtp.first_game_date,
  #   gtp.first_sb_date,
  #   gtp.first_casino_date,
  #   gtp.game_types,
  #   gtp.game_type_order,
  #   gtp.game_type_pref,

  #   max(loyalty_level) as loyalty_level,
  #   max(vip_level) as vip_level,
  #   max(vip_level_code_historical) as vip_level_code_historical,
  #   SUM(ZEROIFNULL(REGISTRATIONS)) AS REGISTRATIONS,
  #   SUM(ZEROIFNULL(LOGINS)) AS LOGINS,
  #   SUM(ZEROIFNULL(SESSIONS)) AS SESSIONS,
  #   SUM(ZEROIFNULL(SESSION_LENGTH)) AS SESSION_LENGTH,
  #   SUM(ZEROIFNULL(PASSED_REGISTRATIONS)) AS PASSED_REGISTRATIONS,
  #   SUM(ZEROIFNULL(KYC_REGISTRATIONS)) AS KYC_REGISTRATIONS,
  #   SUM(ZEROIFNULL(FTDs)) AS FTDs,
  #   SUM(CASE WHEN c.cage_code = 212 THEN (FTDs * 150)
  #           WHEN c.cage_code IN (2,203,249,267,268,304,910) THEN (FTDs * 250)
  #           WHEN c.cage_code IN (847,812,602,720,705,777,504) THEN (FTDs * 200)
  #           ELSE 0 END) AS affiliate_commissions,

  #   SUM(ZEROIFNULL(DEPOSITORS)) AS DEPOSITORS,
  #   SUM(ZEROIFNULL(DEPOSITS)) AS DEPOSITS,
  #   SUM(ZEROIFNULL(DEPOSIT_AMOUNT)) AS DEPOSIT_AMOUNT,
  #   SUM(ZEROIFNULL(WITHDRAWERS)) AS WITHDRAWERS,
  #   SUM(ZEROIFNULL(WITHDRAWALS)) AS WITHDRAWALS,
  #   SUM(ZEROIFNULL(WITHDRAWAL_AMOUNT)) AS WITHDRAWAL_AMOUNT,
  #   SUM(ZEROIFNULL(DEPOSIT_AMOUNT)) - SUM(ZEROIFNULL(WITHDRAWAL_AMOUNT)) AS NET_DEPOSITS,
  #   SUM(ZEROIFNULL(BETS)) AS "NO_BETS",
  #   SUM(ZEROIFNULL(CASINO_BET_AMOUNT))+SUM(ZEROIFNULL(SBOOK_BET_AMOUNT)) AS BET_AMOUNT,
  #   SUM(ZEROIFNULL(CASINO_BONUS_BET_AMOUNT))+SUM(ZEROIFNULL(SBOOK_BONUS_BET_AMOUNT)) AS BONUS_BET_AMOUNT,
  #   SUM(ZEROIFNULL(CASINO_REAL_BET_AMOUNT))+SUM(ZEROIFNULL(SBOOK_REAL_BET_AMOUNT)) AS REAL_BET_AMOUNT,
  #   SUM(ZEROIFNULL(CASINO_WIN_AMOUNT))+SUM(ZEROIFNULL(SBOOK_WIN_AMOUNT)) AS WIN_AMOUNT,
  #   (SUM(ZEROIFNULL(SBOOK_BET_AMOUNT)) - SUM(ZEROIFNULL(SBOOK_WIN_AMOUNT)) + SUM(ZEROIFNULL(SBOOK_ADJUSTMENTS))) + (SUM(ZEROIFNULL(CASINO_BET_AMOUNT)) - SUM(ZEROIFNULL(CASINO_WIN_AMOUNT)) + SUM(ZEROIFNULL(CASINO_ADJUSTMENTS))) AS GGR,
  #   (SUM(ZEROIFNULL(SBOOK_REAL_BET_AMOUNT)) - SUM(ZEROIFNULL(SBOOK_WIN_AMOUNT)) + SUM(ZEROIFNULL(SBOOK_ADJUSTMENTS))) + (SUM(ZEROIFNULL(CASINO_REAL_BET_AMOUNT)) - SUM(ZEROIFNULL(CASINO_WIN_AMOUNT)) + SUM(ZEROIFNULL(CASINO_ADJUSTMENTS))) AS NGR,
  #   CASE WHEN
  #   (SUM(ZEROIFNULL(CASINO_BET_AMOUNT))+SUM(ZEROIFNULL(SBOOK_BET_AMOUNT)))>0 THEN (SUM(ZEROIFNULL(CASINO_WIN_AMOUNT))+SUM(ZEROIFNULL(SBOOK_WIN_AMOUNT)))/(SUM(ZEROIFNULL(CASINO_BET_AMOUNT))+SUM(ZEROIFNULL(SBOOK_BET_AMOUNT)))
  #   ELSE NULL END
  #   AS "RTP",
  #   CASE WHEN
  #   SUM(ZEROIFNULL(BETS))>0 THEN (SUM(ZEROIFNULL(CASINO_BET_AMOUNT))+SUM(ZEROIFNULL(SBOOK_BET_AMOUNT)))/SUM(ZEROIFNULL(BETS))
  #   ELSE NULL END
  #   AS AVG_BET_AMOUNT,
  #   CASE WHEN
  #   SUM(ZEROIFNULL(UNIQUES_ALL))>0 THEN ((SUM(ZEROIFNULL(CASINO_BET_AMOUNT))+SUM(ZEROIFNULL(SBOOK_BET_AMOUNT))) - (SUM(ZEROIFNULL(CASINO_WIN_AMOUNT))+SUM(ZEROIFNULL(SBOOK_WIN_AMOUNT))) + (SUM(ZEROIFNULL(CASINO_ADJUSTMENTS))+SUM(ZEROIFNULL(SBOOK_ADJUSTMENTS))) )/SUM(ZEROIFNULL(UNIQUES_ALL))
  #   ELSE NULL END
  #   AS AVG_GGR,
  #   CASE WHEN
  #   SUM(ZEROIFNULL(UNIQUES_ALL))>0 THEN (SUM(ZEROIFNULL(CASINO_BET_AMOUNT))+SUM(ZEROIFNULL(SBOOK_BET_AMOUNT)))/SUM(ZEROIFNULL(UNIQUES_ALL))
  #   ELSE NULL END
  #   AS AVG_HANDLE,
  #   SUM(ZEROIFNULL(CASINO_BETS)) AS "NO_CASINO_BETS",
  #   SUM(ZEROIFNULL(CASINO_UNIQUES)) AS CASINO_UNIQUES,
  #   SUM(ZEROIFNULL(CASINO_BET_AMOUNT)) AS CASINO_BET_AMOUNT,
  #   SUM(ZEROIFNULL(CASINO_BONUS_BET_AMOUNT)) AS CASINO_BONUS_BET_AMOUNT,
  #   SUM(ZEROIFNULL(CASINO_REAL_BET_AMOUNT)) AS CASINO_REAL_BET_AMOUNT,
  #   SUM(ZEROIFNULL(CASINO_WIN_AMOUNT)) AS CASINO_WIN_AMOUNT,
  #   SUM(ZEROIFNULL(CASINO_BET_AMOUNT)) - SUM(ZEROIFNULL(CASINO_WIN_AMOUNT)) + SUM(ZEROIFNULL(CASINO_ADJUSTMENTS))  AS CASINO_GGR,
  #   CASE WHEN
  #   SUM(ZEROIFNULL(CASINO_BET_AMOUNT))>0 THEN SUM(ZEROIFNULL(CASINO_WIN_AMOUNT))/SUM(ZEROIFNULL(CASINO_BET_AMOUNT))
  #   ELSE NULL END
  #   AS "CASINO_RTP",

  #   SUM(ZEROIFNULL(SBOOK_BETS)) AS "NO_SBOOK_BETS",
  #   SUM(ZEROIFNULL(SBOOK_UNIQUES)) AS SBOOK_UNIQUES,
  #   SUM(ZEROIFNULL(SBOOK_BET_AMOUNT)) AS SBOOK_BET_AMOUNT,
  #   SUM(ZEROIFNULL(SBOOK_BONUS_BET_AMOUNT)) AS SBOOK_BONUS_BET_AMOUNT,
  #   SUM(ZEROIFNULL(SBOOK_REAL_BET_AMOUNT)) AS SBOOK_REAL_BET_AMOUNT,
  #   SUM(ZEROIFNULL(SBOOK_WIN_AMOUNT)) AS SBOOK_WIN_AMOUNT,
  #   SUM(ZEROIFNULL(SBOOK_BET_AMOUNT)) - SUM(ZEROIFNULL(SBOOK_WIN_AMOUNT)) + SUM(ZEROIFNULL(SBOOK_ADJUSTMENTS))  AS SBOOK_GGR,
  #   CASE WHEN
  #   SUM(ZEROIFNULL(SBOOK_BET_AMOUNT))>0 THEN SUM(ZEROIFNULL(SBOOK_WIN_AMOUNT))/SUM(ZEROIFNULL(SBOOK_BET_AMOUNT))
  #   ELSE NULL END
  #   AS "SBOOK_RTP",

  #   SUM(ZEROIFNULL(SLOTS_BETS)) AS "NO_SLOTS_BETS",
  #   SUM(ZEROIFNULL(SLOTS_UNIQUES)) AS SLOTS_UNIQUES,
  #   SUM(ZEROIFNULL(SLOTS_BET_AMOUNT)) AS SLOTS_BET_AMOUNT,
  #   SUM(ZEROIFNULL(SLOTS_BONUS_BET_AMOUNT)) AS SLOTS_BONUS_BET_AMOUNT,
  #   SUM(ZEROIFNULL(SLOTS_REAL_BET_AMOUNT)) AS SLOTS_REAL_BET_AMOUNT,
  #   SUM(ZEROIFNULL(SLOTS_WIN_AMOUNT)) AS SLOTS_WIN_AMOUNT,
  #   SUM(ZEROIFNULL(SLOTS_BET_AMOUNT)) - SUM(ZEROIFNULL(SLOTS_WIN_AMOUNT))+ SUM(ZEROIFNULL(SLOTS_ADJUSTMENTS))   AS SLOTS_GGR,
  #   CASE WHEN
  #   SUM(ZEROIFNULL(SLOTS_BET_AMOUNT))>0 THEN SUM(ZEROIFNULL(SLOTS_WIN_AMOUNT))/SUM(ZEROIFNULL(SLOTS_BET_AMOUNT))
  #   ELSE NULL END
  #   AS "SLOTS_RTP",

  #   SUM(ZEROIFNULL(TABLE_BETS)) AS "NO_TABLE_BETS",
  #   SUM(ZEROIFNULL(TABLE_UNIQUES)) AS TABLE_UNIQUES,
  #   SUM(ZEROIFNULL(TABLE_BET_AMOUNT)) AS TABLE_BET_AMOUNT,
  #   SUM(ZEROIFNULL(TABLE_BONUS_BET_AMOUNT)) AS TABLE_BONUS_BET_AMOUNT,
  #   SUM(ZEROIFNULL(TABLE_REAL_BET_AMOUNT)) AS TABLE_REAL_BET_AMOUNT,
  #   SUM(ZEROIFNULL(TABLE_WIN_AMOUNT)) AS TABLE_WIN_AMOUNT,
  #   SUM(ZEROIFNULL(TABLE_BET_AMOUNT)) - SUM(ZEROIFNULL(TABLE_WIN_AMOUNT))+ SUM(ZEROIFNULL(TABLE_ADJUSTMENTS))   AS TABLE_GGR,
  #   CASE WHEN
  #   SUM(ZEROIFNULL(TABLE_BET_AMOUNT))>0 THEN SUM(ZEROIFNULL(TABLE_WIN_AMOUNT))/SUM(ZEROIFNULL(TABLE_BET_AMOUNT))
  #   ELSE NULL END
  #   AS "TABLE_RTP",
  #   SUM(ZEROIFNULL(LIVEDEALER_BETS)) AS "NO_LIVEDEALER_BETS",
  #   SUM(ZEROIFNULL(LIVEDEALER_UNIQUES)) AS LIVEDEALER_UNIQUES,
  #   SUM(ZEROIFNULL(LIVEDEALER_BET_AMOUNT)) AS LIVEDEALER_BET_AMOUNT,
  #   SUM(ZEROIFNULL(LIVEDEALER_BONUS_BET_AMOUNT)) AS LIVEDEALER_BONUS_BET_AMOUNT,
  #   SUM(ZEROIFNULL(LIVEDEALER_REAL_BET_AMOUNT)) AS LIVEDEALER_REAL_BET_AMOUNT,
  #   SUM(ZEROIFNULL(LIVEDEALER_WIN_AMOUNT)) AS LIVEDEALER_WIN_AMOUNT,
  #   SUM(ZEROIFNULL(LIVEDEALER_BET_AMOUNT)) - SUM(ZEROIFNULL(LIVEDEALER_WIN_AMOUNT)) + SUM(ZEROIFNULL(LIVEDEALER_ADJUSTMENTS)) AS LIVEDEALER_GGR,
  #   CASE WHEN SUM(ZEROIFNULL(LIVEDEALER_BET_AMOUNT))>0 THEN SUM(ZEROIFNULL(LIVEDEALER_WIN_AMOUNT))/SUM(ZEROIFNULL(LIVEDEALER_BET_AMOUNT))
  #   ELSE NULL END
  #   AS "LIVEDEALER_RTP",

  #   SUM(ZEROIFNULL(pt.BONUS_STORE_PTS_ISSUED + spi.BONUS_STORE_PTS_ISSUED)) AS BONUS_STORE_PTS_ISSUED,
  #   SUM(ZEROIFNULL(BONUS_STORE_PTS_USED)) AS BONUS_STORE_PTS_USED,
  #   SUM(ZEROIFNULL(ZEROIFNULL(pt.BONUS_MONEY_ISSUED) + ZEROIFNULL(b.BONUS_MONEY_ISSUED))) AS BONUS_MONEY_ISSUED,
  #   SUM(ZEROIFNULL(ADJUSTMENTS)) AS ADJUSTMENTS,
  #   SUM(ZEROIFNULL(CASINO_ADJUSTMENTS)) AS CASINO_ADJUSTMENTS,
  #   SUM(ZEROIFNULL(SBOOK_ADJUSTMENTS)) AS SBOOK_ADJUSTMENTS,
  #   SUM(ZEROIFNULL(SLOTS_ADJUSTMENTS)) AS SLOTS_ADJUSTMENTS,
  #   SUM(ZEROIFNULL(TABLE_ADJUSTMENTS)) AS TABLE_ADJUSTMENTS,
  #   SUM(ZEROIFNULL(LIVEDEALER_ADJUSTMENTS)) AS LIVEDEALER_ADJUSTMENTS,
  #   SUM(ZEROIFNULL(slots_llpts)) as slots_llpts,
  #   SUM(ZEROIFNULL(table_llpts)) as table_llpts,
  #   SUM(ZEROIFNULL(livedealer_llpts)) as livedealer_llpts,
  #   SUM(ZEROIFNULL(sbook_llpts)) as sbook_llpts,
  #   SUM(ZEROIFNULL(slots_llpts + table_llpts + livedealer_llpts)) as casino_llpts,


  #   SUM(ZEROIFNULL(free_bets_issued)) as fb_issued,
  #   SUM(ZEROIFNULL(free_bets_won)) as fb_won,
  #   SUM(ZEROIFNULL(free_bets_placed)) as fb_completed,
  #   -- ,

  #   -- sum(outstanding_fb_amount) as outstanding_fb_amount,
  #   -- sum(in_use_fb_amount) as in_use_fb_amount,

  #   -- sum(promo_handle_total) AS promo_handle_total,
  #   -- sum(promo_handle_fb) AS promo_handle_fb,
  #   -- sum(promo_handle_ob) AS promo_handle_ob,
  #   -- sum(promo_handle_pb) AS promo_handle_pb,

  #   -- sum(promo_win_amount_total) AS promo_win_amount_total,
  #   -- sum(promo_win_amount_fb) AS promo_win_amount_fb,
  #   -- sum(promo_win_amount_ob) AS promo_win_amount_ob,
  #   -- sum(promo_win_amount_pb) AS promo_win_amount_pb,

  #   -- sum(promo_bonus_total) AS promo_bonus_total,
  #   sum(promo_bonus_pb) AS promo_bonus_pb,
  #   sum(promo_bonus_ob) AS promo_bonus_ob
  #   -- sum(promo_bonus_fb) AS promo_bonus_fb,

  #   -- sum(total_sbp_unique) AS total_sbp_unique,
  #   -- sum(fb_unique) AS fb_unique,
  #   -- sum(pb_unique) AS pb_unique,
  #   -- sum(ob_unique) AS ob_unique,

  #   -- sum(promo_wins) AS promo_wins,
  #   -- sum(promo_wins_fb) AS promo_wins_fb,
  #   -- sum(promo_wins_ob) AS promo_wins_ob,
  #   -- sum(promo_wins_pb) AS promo_wins_pb,
  #   -- sum(promo_lost) AS promo_lost,
  #   -- sum(promo_lost_fb) AS promo_lost_fb,
  #   -- sum(promo_lost_ob) AS promo_lost_ob,
  #   -- sum(promo_lost_pb) AS promo_lost_pb,
  #   -- sum(promo_voids) AS promo_voids,
  #   -- sum(promo_voids_fb) AS promo_voids_fb,
  #   -- sum(promo_voids_ob) AS promo_voids_ob,
  #   -- sum(promo_voids_pb) AS promo_voids_pb
  #     FROM ${calendar_cte.SQL_TABLE_NAME} c
  #     LEFT JOIN
  #   ${registrations_cte.SQL_TABLE_NAME} r
  #     ON c.report_date = r.report_date
  #     AND c.cage_player_id = r.cage_player_id
  #     AND c.cage_code = r.cage_code
  #     LEFT JOIN
  #   ${ftds_cte.SQL_TABLE_NAME} f
  #     ON c.report_date = f.report_date
  #     AND c.cage_player_id = f.cage_player_id
  #     AND c.cage_code = f.cage_code
  #     LEFT JOIN
  #   ${logins_cte.SQL_TABLE_NAME} l
  #     ON c.report_date = l.report_date
  #     AND c.cage_player_id = l.cage_player_id
  #     AND c.cage_code = l.cage_code
  #     LEFT JOIN
  #     ${game_type_pref_cte.SQL_TABLE_NAME} gtp
  #     ON c.cage_player_id = gtp.cage_player_id
  #     AND c.cage_code = gtp.cage_code
  #     LEFT JOIN
  #   ${player_transactions_cte.SQL_TABLE_NAME} pt
  #     ON c.report_date = pt.report_date
  #     AND c.cage_player_id = pt.cage_player_id
  #     AND c.cage_code = pt.cage_code
  #     LEFT JOIN
  #   ${withdrawals_cte.SQL_TABLE_NAME} w
  #     ON c.report_date = w.report_date
  #     AND c.cage_player_id = w.cage_player_id
  #     AND c.cage_code = w.cage_code
  #     LEFT JOIN
  #   ${store_pts_used_cte.SQL_TABLE_NAME} spu
  #     ON c.report_date = spu.report_date
  #     AND c.cage_player_id = spu.cage_player_id
  #     AND c.cage_code = spu.cage_code
  #     LEFT JOIN
  #   ${store_pts_issued_cte.SQL_TABLE_NAME} spi
  #     ON c.report_date = spi.report_date
  #     AND c.cage_player_id = spi.cage_player_id
  #     AND c.cage_code = spi.cage_code
  #     LEFT JOIN
  #     ${game_stats_cte.SQL_TABLE_NAME} gs
  #     ON c.report_date = gs.report_date
  #     AND c.cage_player_id = gs.cage_player_id
  #     AND c.cage_code = gs.cage_code
  #     LEFT JOIN
  #     ${bonuses_cte.SQL_TABLE_NAME} b
  #     ON c.report_date = b.report_date
  #     AND c.cage_player_id = b.cage_player_id
  #     AND c.cage_code = b.cage_code
  #     LEFT JOIN
  #     ${level_by_day_cte.SQL_TABLE_NAME} lbd
  #     ON c.report_date = lbd.report_date
  #     AND c.cage_player_id = lbd.cage_player_id
  #     AND c.cage_code = lbd.cage_code
  #     LEFT JOIN
  #     ${sb_promos_cte.SQL_TABLE_NAME} sp
  #     ON c.report_date = sp.report_date
  #     AND c.cage_player_id = sp.cage_player_id
  #     AND c.cage_code = sp.cage_code
  #     LEFT JOIN
  #     ${fb_promos_cte.SQL_TABLE_NAME} fbp
  #     ON c.report_date = fbp.report_date
  #     AND c.cage_player_id = fbp.cage_player_id
  #     AND c.cage_code = fbp.cage_code
  #     LEFT JOIN
  #     ${vip_level_historical_cte.SQL_TABLE_NAME} vip
  #     ON c.report_date = vip.report_date
  #     AND c.cage_player_id = vip.cage_player_id
  #     AND c.cage_code = vip.cage_code
  #     WHERE {%incrementcondition%} c.report_date {%endincrementcondition%}
  #     GROUP BY
  #     1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11

      # ;;
#  }

  measure: count {
    type: count
    drill_fields: [detail*]
  }




  dimension: active_depositor {
    type: number
    sql: case when ${TABLE}."DEPOSIT_AMOUNT" > 0 then 1 else 0 end ;;
    group_label: "Activity Type (1/0)"
  }

  dimension: active_withdrawer {
    type: number
    sql: case when ${TABLE}."WITHDRAWAL_AMOUNT" > 0 then 1 else 0 end ;;
    group_label: "Activity Type (1/0)"
  }

  dimension: active_bettor {
    type: number
    sql: case when ${TABLE}."BET_AMOUNT" > 0 then 1 else 0 end ;;
    group_label: "Activity Type (1/0)"
  }

  dimension: active_sports_bettor {
    type: number
    sql: case when ${TABLE}."SBOOK_BET_AMOUNT" > 0 then 1 else 0 end ;;
    group_label: "Activity Type (1/0)"
  }

  dimension: active_casino_bettor {
    type: number
    sql: case when ${TABLE}."CASINO_BET_AMOUNT" > 0 then 1 else 0 end ;;
    group_label: "Activity Type (1/0)"
  }

  dimension: active_real_bettor {
    type: number
    sql: case when ${TABLE}."REAL_BET_AMOUNT" > 0 then 1 else 0 end ;;
    group_label: "Activity Type (1/0)"
  }

  dimension: active_login_user {
    type: number
    sql: case when ${TABLE}."LOGINS" > 0 then 1 else 0 end ;;
    group_label: "Activity Type (1/0)"
  }

  # measure: count_depositors {
  #   type: count_distinct
  #   sql: case when ${TABLE}."DEPOSIT_AMOUNT" > 0 then ${TABLE}."CAGE_CODE"  || '-' || ${TABLE}."CAGE_PLAYER_ID" end ;;
  #   description: "Unique Depositors"
  #   value_format_name: decimal_0
  # }

  # measure: count_withdrawers {
  #   type: count_distinct
  #   sql: case when ${TABLE}."WITHDRAWAL_AMOUNT" > 0 then ${TABLE}."CAGE_CODE"  || '-' || ${TABLE}."CAGE_PLAYER_ID" end ;;
  #   description: "Unique Withdrawers"
  #   value_format_name: decimal_0
  # }


  dimension: cage_player_id {
    type: number
    sql: ${TABLE}."CAGE_PLAYER_ID" ;;
    value_format_name: id
  }

  dimension: cage_code {
    type: number
    sql: ${TABLE}."CAGE_CODE" ;;
  }

  dimension: player_id {
    description: "Unique identifier across all cages, Cage Code and Cage Player ID"
    type: string
    # hidden: yes
    sql: ${TABLE}."CAGE_CODE"  || '-' || ${TABLE}."CAGE_PLAYER_ID" ;;
  }


  dimension: player_id_date {
    type: string
    hidden: yes
    primary_key: yes
    sql: ${TABLE}."CAGE_CODE"  || '-' || ${TABLE}."CAGE_PLAYER_ID" || '-' || ${TABLE}."REPORT_DATE" ;;
  }

  dimension: market_grouping {
    type: string
    sql:
     case when ${TABLE}."CAGE_CODE" = 57 then 'Colombia Online Markets'
              when ${TABLE}."CAGE_CODE" = 51 then 'Peru Online Markets'
              when ${TABLE}."CAGE_CODE" = 52 then 'Mexico Online Markets'
              when ${TABLE}."SITE_CODE" = 'C4F' then 'C4F Online Markets'
              when ${TABLE}."CAGE_CODE" = 249 then 'Canada Online Markets'
              when ${TABLE}."CAGE_CODE" > 0 and ${TABLE}."CAGE_CODE" <> 249 then 'US Online Markets'
              else ${TABLE}."CAGE_CODE"::varchar end;;
  }

  dimension: game_type_pref {
    label: "Game Type Preference"
    type: string
    sql: ${TABLE}."GAME_TYPE_PREF" ;;
    description: "List of Products played (a-z)"
  }

  dimension: game_type_order {
    label: "Game Type Order"
    type: string
    sql: ${TABLE}."GAME_TYPE_ORDER" ;;
    description: "List of Game Types played (by first played)"
  }

  dimension: game_type_order_agg {
    label: "Game Type Order - Simplified"
    type: string
    sql:
        case when kpi_player."GAME_TYPES" = 'C' then 'Casino Only'
        when kpi_player."GAME_TYPES" = 'SB' then 'SB Only'
        when left(kpi_player."GAME_TYPE_ORDER",9) = 'SBOOK | S' then 'SBOOK to SLOTS'
        when left(kpi_player."GAME_TYPE_ORDER",9) = 'SBOOK | T' then 'SBOOK to TABLE'
        when left(kpi_player."GAME_TYPE_ORDER",9) = 'SBOOK | L' then 'SBOOK to LIVEDEALER'
          else 'CASINO to SBOOK' end
    ;;
    description: "List of Game Types played (by first played)"
  }

  dimension: first_game_type {
    label: "First Game Played"
    type: string
    sql: CASE WHEN LEFT(${TABLE}."GAME_TYPE_ORDER" , 5) = 'SBOOK' THEN 'Sportsbook'
              WHEN POSITION('|', ${TABLE}."GAME_TYPE_ORDER") > 0 THEN LEFT(${TABLE}."GAME_TYPE_ORDER", POSITION(' |', ${TABLE}."GAME_TYPE_ORDER"))
              ELSE ${TABLE}."GAME_TYPE_ORDER" END ;;
    description: "First Game Type played"
  }

  dimension: game_types {
    label: "Game Types"
    type: string
    sql: ${TABLE}."GAME_TYPES" ;;
    description: "List of Game Types played (a-z)"
  }

  dimension_group: last_game_date {
    label: "Last Game Date - C and SB"
    description: "Last Game Date for both Casino and Sportsbook - override of Players table that only shows Casino Last Game Date"
    convert_tz: no
    type: time
    timeframes: [
      raw,
      time,
      minute15,
      date,
      week,
      month,
      quarter,
      year,
      hour,
      hour_of_day,
      day_of_week,
      day_of_month
    ]
    sql: ${TABLE}.last_game_date ;;
  }

  dimension_group: first_game_date {
    label: "First Game Date - C and SB"
    description: "First Game Date for both Casino and Sportsbook - override of Players table that only shows Casino Last Game Date"
    convert_tz: no
    type: time
    timeframes: [
      raw,
      time,
      minute15,
      date,
      week,
      month,
      quarter,
      year,
      hour,
      hour_of_day,
      day_of_week,
      day_of_month
    ]
    sql: ${TABLE}.first_game_date ;;
  }


  dimension_group: first_casino_date {
    label: "First Casino Game Date"
    description: "First Game Date for both Casino"
    convert_tz: no
    type: time
    timeframes: [
      raw,
      time,
      minute15,
      date,
      week,
      month,
      quarter,
      year,
      hour,
      hour_of_day,
      day_of_week,
      day_of_month
    ]
    sql: ${TABLE}.first_casino_date ;;
  }

  dimension_group: first_sb_date {
    label: "First Sportsbook Game Date"
    description: "First Game Date for both Sportsbook"
    convert_tz: no
    type: time
    timeframes: [
      raw,
      time,
      minute15,
      date,
      week,
      month,
      quarter,
      year,
      hour,
      hour_of_day,
      day_of_week,
      day_of_month
    ]
    sql: ${TABLE}.first_sb_date ;;
  }

  dimension_group: report_date {
    convert_tz: no
    type: time
    timeframes: [
      raw,
      time,
      time_of_day,
      date,
      week,
      month,
      month_name,
      month_num,
      quarter,
      year,
      week_of_year,
      day_of_month,
      day_of_week,
      day_of_year
    ]
    sql: ${TABLE}.report_date ;;
  }

  dimension: site_code {
    type: string
    sql: ${TABLE}."SITE_CODE" ;;
  }

  dimension: loyalty_level {
    description: "Player's loyalty level on the report date"
    type: number
    sql: case when ${TABLE}."LOYALTY_LEVEL" > 10 then 10
              when ${TABLE}."LOYALTY_LEVEL" is null then 0
              else ${TABLE}."LOYALTY_LEVEL" end ;;
  }


  dimension: player_type {
    description: "VIP vs. NON VIP adjusted for new loyalty program on 8/1/2024 based on VIP team goals"
    type: string
    sql: case when (${loyalty_level}>=5 and ${report_date_date}>='2024-08-01') or (${loyalty_level}>=8 and ${report_date_date}<'2024-08-01') then 'VIP'
    else 'NON-VIP' end;;
  }




  dimension: site_type {
    description: "Classification of Products available on the Site"
    type: string
    sql: case when ${TABLE}."SITE_CODE" = 'C4F' then 'Casino and Sports (C4F)'
              when ${TABLE}."SITE_CODE" in ('COL','ON','MI','PA','NJ', 'WV','MEX', 'DE','PER') then 'Casino and Sports'
              else 'Sports Only' end
    ;;
  }

  dimension: vip_level {
    type: string
    sql: ${TABLE}."VIP_LEVEL" ;;
  }

  dimension: vip_level_code_historical {
    type: string
    sql: ${TABLE}."vip_level_code_historical" ;;
  }

  dimension: vip_level_code_type {
    type: string
    sql: case when ${TABLE}."vip_level_code_historical" = 11 then 'Bonus Blocked'
    when ${TABLE}."vip_level_code_historical" = 1 or  ${TABLE}."vip_level_code_historical" is null then 'Uncoded'
    else 'Coded' end
    ;;
  }


  dimension: days_live {
    type: number
    sql:
    1+
    (case when ${cage_code} = 2 then date(${report_date_date}) - date('2016-09-06')
        when ${cage_code} = 5 then date(${report_date_date}) - date('2017-02-23')
        when ${cage_code} = 9 then date(${report_date_date}) - date('2020-08-31')
        when ${cage_code} = 17 then date(${report_date_date}) - date('2021-10-13')
        when ${cage_code} = 31 then date(${report_date_date}) - date('2017-10-09')
        when ${cage_code} = 37 then date(${report_date_date}) - date('2020-08-17')
        when ${cage_code} = 43 then date(${report_date_date}) - date('2015-06-09')
        when ${cage_code} = 44 then date(${report_date_date}) - date('2016-12-15')
        when ${cage_code} = 45 then date(${report_date_date}) - date('2018-01-29')
        when ${cage_code} = 46 then date(${report_date_date}) - date('2018-08-01')
        when ${cage_code} = 57 then date(${report_date_date}) - date('2018-06-13')
        when ${cage_code} = 52 then date(${report_date_date}) - date('2022-06-30')
        when ${cage_code} = 130 then date(${report_date_date}) - date('2019-07-22')
        when ${cage_code} = 203 then date(${report_date_date}) - date('2021-10-19')
        when ${cage_code} = 249 then date(${report_date_date}) - date('2022-04-01')
        when ${cage_code} = 212 then date(${report_date_date}) - date('2022-01-08')
        when ${cage_code} = 267 then date(${report_date_date}) - date('2019-05-28')
        when ${cage_code} = 268 then date(${report_date_date}) - date('2019-06-25')
        when ${cage_code} = 304 then date(${report_date_date}) - date('2021-04-12')
        when ${cage_code} = 602 then date(${report_date_date}) - date('2021-10-22')
        when ${cage_code} = 705 then date(${report_date_date}) - date('2021-01-27')
        when ${cage_code} = 720 then date(${report_date_date}) - date('2020-05-01')
        when ${cage_code} = 777 then date(${report_date_date}) - date('2020-10-08')
        when ${cage_code} = 812 then date(${report_date_date}) - date('2019-10-03')
        when ${cage_code} = 847 then date(${report_date_date}) - date('2020-06-18')
        when ${cage_code} = 910 then date(${report_date_date}) - date('2021-01-22')

      end
      )


      ;;
  }







# ========================
#   DIMENSIONS TO HIDE
# ========================






  dimension: registrations {
    hidden: yes
    type: number
    sql: ${TABLE}."REGISTRATIONS" ;;
  }

  dimension: logins {
    hidden: yes
    type: number
    sql: ${TABLE}."LOGINS" ;;
  }

  dimension: sessions {
    hidden: yes
    type: number
    sql: ${TABLE}."SESSIONS" ;;
  }

  dimension: session_length {
    hidden: yes
    type: number
    sql: ${TABLE}."SESSION_LENGTH" ;;
  }

  dimension: passed_registrations {
    hidden: yes
    type: number
    sql: ${TABLE}."PASSED_REGISTRATIONS" ;;
  }

  dimension: kyc_registrations {
    hidden: yes
    type: number
    sql: ${TABLE}."KYC_REGISTRATIONS" ;;
  }

  dimension: ftds {
    hidden: yes
    type: number
    sql: ${TABLE}."FTDS" ;;
  }

  dimension: depositors {
    hidden: yes
    type: number
    sql: ${TABLE}."DEPOSITORS" ;;
  }

  dimension: deposits {
    hidden: yes
    type: number
    sql: ${TABLE}."DEPOSITS" ;;
  }

  dimension: deposit_amount {
    hidden: yes
    type: number
    sql: ${TABLE}."DEPOSIT_AMOUNT" ;;
  }

  dimension: withdrawers {
    hidden: yes
    type: number
    sql: ${TABLE}."WITHDRAWERS" ;;
  }

  dimension: withdrawals {
    hidden: yes
    type: number
    sql: ${TABLE}."WITHDRAWALS" ;;
  }

  dimension: withdrawal_amount {
    hidden: yes
    type: number
    sql: ${TABLE}."WITHDRAWAL_AMOUNT" ;;
  }

  dimension: net_deposits {
    hidden: yes
    type: number
    sql: ${TABLE}."NET_DEPOSITS" ;;
  }

  dimension: _bets {
    hidden: yes
    type: number
    sql: ${TABLE}."NO_BETS" ;;
  }

  dimension: bet_amount {
    hidden: yes
    type: number
    sql: ${TABLE}."BET_AMOUNT" ;;
  }

  dimension: bonus_bet_amount {
    hidden: yes
    type: number
    sql: ${TABLE}."BONUS_BET_AMOUNT" ;;
  }

  dimension: real_bet_amount {
    hidden: yes
    type: number
    sql: ${TABLE}."REAL_BET_AMOUNT" ;;
  }

  dimension: win_amount {
    hidden: yes
    type: number
    sql: ${TABLE}."WIN_AMOUNT" ;;
  }

  dimension: ggr {
    hidden: yes
    type: number
    sql: ${TABLE}."GGR" ;;
  }

  dimension: ngr {
    hidden: yes
    type: number
    sql: ${TABLE}."NGR" ;;
  }

  dimension: rtp {
    hidden: yes
    type: number
    sql: ${TABLE}."RTP" ;;
  }

  dimension: avg_bet_amount {
    hidden: yes
    type: number
    sql: ${TABLE}."AVG_BET_AMOUNT" ;;
  }

  dimension: avg_ggr {
    hidden: yes
    type: number
    sql: ${TABLE}."AVG_GGR" ;;
  }

  dimension: avg_handle {
    hidden: yes
    type: number
    sql: ${TABLE}."AVG_HANDLE" ;;
  }

  dimension: _casino_bets {
    hidden: yes
    type: number
    sql: ${TABLE}."NO_CASINO_BETS" ;;
  }

  dimension: _table_bets {
    hidden: yes
    type: number
    sql: ${TABLE}."NO_TABLE_BETS" ;;
  }

  dimension: _livedealer_bets {
    hidden: yes
    type: number
    sql: ${TABLE}."NO_LIVEDEALER_BETS" ;;
  }

  dimension: _slots_bets {
    hidden: yes
    type: number
    sql: ${TABLE}."NO_SLOTS_BETS" ;;
  }

  dimension: unique_bettors {
    hidden: yes
    type: number
    sql: case when ${TABLE}."CASINO_UNIQUES" = 1 or ${TABLE}."SBOOK_UNIQUES" = 1 then 1 else 0 end ;;
  }

  dimension: casino_uniques {
    hidden: yes
    type: number
    sql: ${TABLE}."CASINO_UNIQUES" ;;
  }

  dimension: casino_bet_amount {
    hidden: yes
    type: number
    sql: ${TABLE}."CASINO_BET_AMOUNT" ;;
  }

  dimension: casino_bonus_bet_amount {
    hidden: yes
    type: number
    sql: ${TABLE}."CASINO_BONUS_BET_AMOUNT" ;;
  }

  dimension: casino_real_bet_amount {
    hidden: yes
    type: number
    sql: ${TABLE}."CASINO_REAL_BET_AMOUNT" ;;
  }

  dimension: casino_win_amount {
    hidden: yes
    type: number
    sql: ${TABLE}."CASINO_WIN_AMOUNT" ;;
  }

  dimension: casino_ggr {
    hidden: yes
    type: number
    sql: ${TABLE}."CASINO_GGR" ;;
  }

  dimension: casino_rtp {
    hidden: yes
    type: number
    sql: ${TABLE}."CASINO_RTP" ;;
  }

  dimension: _sbook_bets {
    hidden: yes
    type: number
    sql: ${TABLE}."NO_SBOOK_BETS" ;;
  }

  dimension: sbook_uniques {
    hidden: yes
    type: number
    sql: ${TABLE}."SBOOK_UNIQUES" ;;
  }

  dimension: sbook_bet_amount {
    hidden: yes
    type: number
    sql: ${TABLE}."SBOOK_BET_AMOUNT" ;;
  }

  dimension: sbook_bonus_bet_amount {
    hidden: yes
    type: number
    sql: ${TABLE}."SBOOK_BONUS_BET_AMOUNT" ;;
  }

  dimension: sbook_real_bet_amount {
    hidden: yes
    type: number
    sql: ${TABLE}."SBOOK_REAL_BET_AMOUNT" ;;
  }

  dimension: sbook_win_amount {
    hidden: yes
    type: number
    sql: ${TABLE}."SBOOK_WIN_AMOUNT" ;;
  }

  dimension: sbook_ggr {
    hidden: yes
    type: number
    sql: ${TABLE}."SBOOK_GGR" ;;
  }

  dimension: sbook_rtp {
    hidden: yes
    type: number
    sql: ${TABLE}."SBOOK_RTP" ;;
  }

  dimension: slots_uniques {
    hidden: yes
    type: number
    sql: ${TABLE}."SLOTS_UNIQUES" ;;
  }

  dimension: slots_bet_amount {
    hidden: yes
    type: number
    sql: ${TABLE}."SLOTS_BET_AMOUNT" ;;
  }

  dimension: slots_bonus_bet_amount {
    hidden: yes
    type: number
    sql: ${TABLE}."SLOTS_BONUS_BET_AMOUNT" ;;
  }

  dimension: slots_real_bet_amount {
    hidden: yes
    type: number
    sql: ${TABLE}."SLOTS_REAL_BET_AMOUNT" ;;
  }

  dimension: slots_win_amount {
    hidden: yes
    type: number
    sql: ${TABLE}."SLOTS_WIN_AMOUNT" ;;
  }

  dimension: slots_ggr {
    hidden: yes
    type: number
    sql: ${TABLE}."SLOTS_GGR" ;;
  }

  dimension: slots_rtp {
    hidden: yes
    type: number
    sql: ${TABLE}."SLOTS_RTP" ;;
  }

  dimension: table_uniques {
    hidden: yes
    type: number
    sql: ${TABLE}."TABLE_UNIQUES" ;;
  }

  dimension: table_bet_amount {
    hidden: yes
    type: number
    sql: ${TABLE}."TABLE_BET_AMOUNT" ;;
  }

  dimension: table_bonus_bet_amount {
    hidden: yes
    type: number
    sql: ${TABLE}."TABLE_BONUS_BET_AMOUNT" ;;
  }

  dimension: table_real_bet_amount {
    hidden: yes
    type: number
    sql: ${TABLE}."TABLE_REAL_BET_AMOUNT" ;;
  }

  dimension: table_win_amount {
    hidden: yes
    type: number
    sql: ${TABLE}."TABLE_WIN_AMOUNT" ;;
  }

  dimension: table_ggr {
    hidden: yes
    type: number
    sql: ${TABLE}."TABLE_GGR" ;;
  }

  dimension: table_rtp {
    hidden: yes
    type: number
    sql: ${TABLE}."TABLE_RTP" ;;
  }

  dimension: livedealer_uniques {
    hidden: yes
    type: number
    sql: ${TABLE}."LIVEDEALER_UNIQUES" ;;
  }

  dimension: livedealer_bet_amount {
    hidden: yes
    type: number
    sql: ${TABLE}."LIVEDEALER_BET_AMOUNT" ;;
  }

  dimension: livedealer_bonus_bet_amount {
    hidden: yes
    type: number
    sql: ${TABLE}."LIVEDEALER_BONUS_BET_AMOUNT" ;;
  }

  dimension: livedealer_real_bet_amount {
    hidden: yes
    type: number
    sql: ${TABLE}."LIVEDEALER_REAL_BET_AMOUNT" ;;
  }

  dimension: livedealer_win_amount {
    hidden: yes
    type: number
    sql: ${TABLE}."LIVEDEALER_WIN_AMOUNT" ;;
  }

  dimension: livedealer_ggr {
    hidden: yes
    type: number
    sql: ${TABLE}."LIVEDEALER_GGR" ;;
  }

  dimension: livedealer_rtp {
    hidden: yes
    type: number
    sql: ${TABLE}."LIVEDEALER_RTP" ;;
  }

  dimension: bonus_money_issued {
    hidden: yes
    type: number
    sql: ${TABLE}."BONUS_MONEY_ISSUED" ;;
  }

  dimension: adjustments {
    hidden: yes
    type: number
    sql: ${TABLE}."ADJUSTMENTS" ;;
  }

  dimension: casino_adjustments {
    hidden: yes
    type: number
    sql: ${TABLE}."CASINO_ADJUSTMENTS" ;;
  }

  dimension: sbook_adjustments {
    hidden: yes
    type: number
    sql: ${TABLE}."SBOOK_ADJUSTMENTS" ;;
  }

  dimension: slots_adjustments {
    hidden: yes
    type: number
    sql: ${TABLE}."SLOTS_ADJUSTMENTS" ;;
  }

  dimension: table_adjustments {
    hidden: yes
    type: number
    sql: ${TABLE}."TABLE_ADJUSTMENTS" ;;
  }

  dimension: livedealer_adjustments {
    hidden: yes
    type: number
    sql: ${TABLE}."LIVEDEALER_ADJUSTMENTS" ;;
  }

  dimension: outstanding_fb_amount {
    hidden: yes
    type: number
    sql: ${TABLE}."OUTSTANDING_FB_AMOUNT" ;;
  }

  dimension: in_use_fb_amount {
    hidden: yes
    type: number
    sql: ${TABLE}."IN_USE_FB_AMOUNT" ;;
  }

  dimension: promo_handle_total {
    hidden: yes
    type: number
    sql: ${TABLE}."PROMO_HANDLE_TOTAL" ;;
  }

  dimension: promo_handle_fb {
    hidden: yes
    type: number
    sql: ${TABLE}."PROMO_HANDLE_FB" ;;
  }

  dimension: promo_handle_ob {
    hidden: yes
    type: number
    sql: ${TABLE}."PROMO_HANDLE_OB" ;;
  }

  dimension: promo_handle_pb {
    hidden: yes
    type: number
    sql: ${TABLE}."PROMO_HANDLE_PB" ;;
  }

  dimension: promo_win_amount_total {
    hidden: yes
    type: number
    sql: ${TABLE}."PROMO_WIN_AMOUNT_TOTAL" ;;
  }

  dimension: promo_win_amount_fb {
    hidden: yes
    type: number
    sql: ${TABLE}."PROMO_WIN_AMOUNT_FB" ;;
  }

  dimension: promo_win_amount_ob {
    hidden: yes
    type: number
    sql: ${TABLE}."PROMO_WIN_AMOUNT_OB" ;;
  }

  dimension: promo_win_amount_pb {
    hidden: yes
    type: number
    sql: ${TABLE}."PROMO_WIN_AMOUNT_PB" ;;
  }

  dimension: promo_bonus_total {
    hidden: yes
    type: number
    sql: ${TABLE}."PROMO_BONUS_TOTAL" ;;
  }

  dimension: promo_bonus_pb {
    group_label: "Sports Promos"
    hidden: yes
    type: number
    sql: ${TABLE}."PROMO_BONUS_PB" ;;
  }

  dimension: promo_bonus_ob {
    group_label: "Sports Promos"
    hidden: yes
    type: number
    sql: ${TABLE}."PROMO_BONUS_OB" ;;
  }

  dimension: promo_bonus_fb {
    hidden: yes
    type: number
    sql: ${TABLE}."PROMO_BONUS_FB" ;;
  }

  dimension: total_sbp_unique {
    hidden: yes
    type: number
    sql: ${TABLE}."TOTAL_SBP_UNIQUE" ;;
  }

  dimension: fb_unique {
    hidden: yes
    type: number
    sql: ${TABLE}."FB_UNIQUE" ;;
  }

  dimension: pb_unique {
    hidden: yes
    type: number
    sql: ${TABLE}."PB_UNIQUE" ;;
  }

  dimension: ob_unique {
    hidden: yes
    type: number
    sql: ${TABLE}."OB_UNIQUE" ;;
  }

  dimension: promo_wins {
    hidden: yes
    type: number
    sql: ${TABLE}."PROMO_WINS" ;;
  }

  dimension: promo_wins_fb {
    hidden: yes
    type: number
    sql: ${TABLE}."PROMO_WINS_FB" ;;
  }

  dimension: promo_wins_ob {
    hidden: yes
    type: number
    sql: ${TABLE}."PROMO_WINS_OB" ;;
  }

  dimension: promo_wins_pb {
    hidden: yes
    type: number
    sql: ${TABLE}."PROMO_WINS_PB" ;;
  }

  dimension: promo_lost {
    hidden: yes
    type: number
    sql: ${TABLE}."PROMO_LOST" ;;
  }

  dimension: promo_lost_fb {
    hidden: yes
    type: number
    sql: ${TABLE}."PROMO_LOST_FB" ;;
  }

  dimension: promo_lost_ob {
    hidden: yes
    type: number
    sql: ${TABLE}."PROMO_LOST_OB" ;;
  }

  dimension: promo_lost_pb {
    hidden: yes
    type: number
    sql: ${TABLE}."PROMO_LOST_PB" ;;
  }

  dimension: promo_voids {
    hidden: yes
    type: number
    sql: ${TABLE}."PROMO_VOIDS" ;;
  }

  dimension: promo_voids_fb {
    hidden: yes
    type: number
    sql: ${TABLE}."PROMO_VOIDS_FB" ;;
  }

  dimension: promo_voids_ob {
    hidden: yes
    type: number
    sql: ${TABLE}."PROMO_VOIDS_OB" ;;
  }

  dimension: promo_voids_pb {
    hidden: yes
    type: number
    sql: ${TABLE}."PROMO_VOIDS_PB" ;;
  }

  dimension: fb_issued {
    hidden: yes
    type: number
    sql: ${TABLE}."FB_ISSUED" ;;
  }

  dimension: fb_completed {
    hidden: yes
    type: number
    sql: ${TABLE}."FB_COMPLETED" ;;
  }

  dimension: fb_won {
    hidden: yes
    type: number
    sql: ${TABLE}."FB_WON" ;;
  }

  dimension: BONUS_STORE_PTS_ISSUED {
    hidden: yes
    type: number
    sql: ${TABLE}."BONUS_STORE_PTS_ISSUED" ;;
  }

  dimension: LLPTS {
    hidden: yes
    type: number
    sql: ${TABLE}."BONUS_STORE_PTS_ISSUED" ;;
  }

  dimension: slots_llpts {
    hidden: yes
    type: number
    sql: ${TABLE}."SLOTS_LLPTS" ;;
  }

  dimension: TABLE_LLPTS {
    hidden: yes
    type: number
    sql: ${TABLE}."TABLE_LLPTS" ;;
  }

  dimension: LIVEDEALER_LLPTS {
    hidden: yes
    type: number
    sql: ${TABLE}."LIVEDEALER_LLPTS" ;;
  }

  dimension: SBOOK_LLPTS {
    hidden: yes
    type: number
    sql: ${TABLE}."SBOOK_LLPTS" ;;
  }

  dimension: CASINO_LLPTS {
    hidden: yes
    type: number
    sql: ${TABLE}."CASINO_LLPTS" ;;
  }

  dimension: cage_codes_explained {
    type: string
    sql: case when ${TABLE}."CAGE_CODE" = '2' then '2- New Jersey'
              when ${TABLE}."CAGE_CODE" = '267' then '267- Pennsylvania PSH'
              when ${TABLE}."CAGE_CODE" = '268' then '268- Pennsylvania BR'
              when ${TABLE}."CAGE_CODE" = '812' then '812- Indiana'
              when ${TABLE}."CAGE_CODE" = '847' then '847- Illinois'
              when ${TABLE}."CAGE_CODE" = '705' then '705- Virginia'
              when ${TABLE}."CAGE_CODE" = '720' then '720- Colorado'
              when ${TABLE}."CAGE_CODE" = '910' then '910- Michigan'
              when ${TABLE}."CAGE_CODE" = '777' then '777- Iowa'
              when ${TABLE}."CAGE_CODE" = '203' then '203- Connecticut'
              when ${TABLE}."CAGE_CODE" = '602' then '602- Arizona'
              when ${TABLE}."CAGE_CODE" = '212' then '212- New York'
              when ${TABLE}."CAGE_CODE" = '57' then '57- Colombia'
              when ${TABLE}."CAGE_CODE" = '51' then '51- Peru'
              when ${TABLE}."CAGE_CODE" = '504' then '504- Louisiana'
              when ${TABLE}."CAGE_CODE" = '249' then '249- Ontario'
              when ${TABLE}."CAGE_CODE" = '304' then '304- West Virginia'
              when ${TABLE}."CAGE_CODE" = '52' then '52- Mexico'
              when ${TABLE}."CAGE_CODE" = '410' then '410- Maryland'
              when ${TABLE}."CAGE_CODE" = '216' then '216- Ohio'
              when ${TABLE}."CAGE_CODE" = '301' then '301 - DE Delaware Park'
              when ${TABLE}."CAGE_CODE" = '302' then '302 - DE Bally Casino'
              when ${TABLE}."CAGE_CODE" = '303' then '303 - DE Harrington'
               end ;;
  }

  dimension: Time_Period {
    type:  string
    sql:  case when week(${TABLE}."REPORT_DATE") = week(current_date)-1
        and year(report_date) = year(current_date) then 'Current Week'
      when week(${TABLE}."REPORT_DATE") = week(current_date)-2
      and year(report_date) = year(current_date) then 'Previous Week' end ;;
  }

  dimension: First_Bet_Type{
    type: string
    description: "First Product Type a user wagers on"
    sql: case when left(${TABLE}."GAME_TYPE_ORDER",5) = 'SBOOK' then 'Sportsbook'
    when left("GAME_TYPE_ORDER",5) = 'POKER' then 'Poker'
    when ${TABLE}."GAME_TYPE_ORDER" is not null then 'Casino'
    end ;;
  }

  dimension: First_Game_Type_Bet {
    description: "First Game Type a user wagers on"
    type: string
    sql: CASE WHEN POSITION('|',${TABLE}."GAME_TYPE_ORDER")>0 then LEFT(${TABLE}."GAME_TYPE_ORDER", POSITION(' |', ${TABLE}."GAME_TYPE_ORDER"))
      else ${TABLE}."GAME_TYPE_ORDER" end ;;
  }

  dimension: user_type {
    type: string
    sql: case when ${TABLE}."GAME_TYPES" = 'C' then 'Casino'
              when ${TABLE}."GAME_TYPES" = 'SB' then 'Sportsbook'
              when ${TABLE}."GAME_TYPES" = 'C | SB'then 'Cross-Over'
              else 'Other'
               end ;;
    drill_fields: [game_type_pref]
  }





# ========================
#        PARAMETERS
# ========================

  parameter: colombia_conversion {
    group_label: "Conversions"
    type: number
    description: "Conversion for Colombian Pesos to US Dollars. Insert $X COP per $1 USD."
  }

  parameter: mexico_conversion {
    group_label: "Conversions"
    type: number
    description: "Conversion for Mexican Pesos to US Dollars. Insert $X MXP per $1 USD."
  }

  parameter: canada_conversion {
    group_label: "Conversions"
    type: number
    description: "Conversion for Canadian Dollars to US Dollars. Insert $X CAD per $1 USD."
  }

  parameter: peru_conversion {
    group_label: "Conversions"
    type: number
    description: "Conversion for Peru Sol to US Dollars. Insert $X Sol per $1 USD."
  }

  parameter: reinvestment_level {
    type: number
    description: "Used to dynamically adjust BBB Calculation"
  }

  parameter: date_comparison {
    type: date
    description: "Used to mark vertical line for comparision analysis"
  }

  parameter: kpi {
    type: unquoted
    description: "Use this to dynamically choose the KPI to calcuate"

    allowed_value: {label: "Registrations"  value: "REGISTRATIONS"}
    allowed_value: {label: "KYC Registrations"  value: "KYC_REGISTRATIONS"}
    allowed_value: {label: "FTDs"  value: "FTDS"}
    allowed_value: {label: "KYC Pass Rate"  value: "PASSED_REGISTRATIONS"}
    allowed_value: {label: "FTD Conversion of KYC Regs"  value: "LIVEDEALER_LLPTS"}
      # used field as a filler

    allowed_value: {label: "Logins"  value: "LOGINS"}
    allowed_value: {label: "Session Length"  value: "SESSION_LENGTH"}
    allowed_value: {label: "Sessions"  value: "SESSIONS"}


    allowed_value: {label: "Loyalty Points Earned - Casino"  value: "CASINO_LLPTS"}
    allowed_value: {label: "Loyalty Points Earned - Sports"  value: "SBOOK_LLPTS"}

  # DOES NOT WORK
    # allowed_value: {label: "Bonus Store Points Issued"  value: "LLPTS"} #have to put a table field to work
  # DOES NOT WORK
    # allowed_value: {label: "Loyalty Points Earned"  value: "LLPTS"} #have to put a table field to work

    allowed_value: {label: "Number of Bets"  value: "NO_BETS"}
    allowed_value: {label: "Number of Bets - Casino"  value: "NO_CASINO_BETS"}
    allowed_value: {label: "Number of Bets - Sports"  value: "NO_SBOOK_BETS"}
    allowed_value: {label: "Number of Bets - Live Dealer"  value: "NO_LIVEDEALER_BETS"}
    allowed_value: {label: "Number of Bets - Slots"  value: "NO_SLOTS_BETS"}
    allowed_value: {label: "Number of Bets - Table"  value: "NO_TABLE_BETS"}

    allowed_value: {label: "Depositors"  value: "DEPOSITORS"}
    allowed_value: {label: "Number of Deposits"  value: "DEPOSITS"}
    allowed_value: {label: "Deposit Amount"  value: "DEPOSIT_AMOUNT"}
    allowed_value: {label: "Withdrawers"  value: "WITHDRAWERS"}
    allowed_value: {label: "Number of Withdrawals"  value: "WITHDRAWALS"}
    allowed_value: {label: "Withdrawal Amount"  value: "WITHDRAWAL_AMOUNT"}
    allowed_value: {label: "Net Deposits"  value: "NET_DEPOSITS"}



    allowed_value: {label: "Bonus Money Issued"  value: "BONUS_MONEY_ISSUED"}
    allowed_value: {label: "Free Bets Issued"  value: "FB_ISSUED"}
    allowed_value: {label: "Reinvestment"  value: "PROMO_BONUS_OB"} #used field as filler


    allowed_value: {label: "Handle"  value: "BET_AMOUNT"}
    allowed_value: {label: "Handle - Real"  value: "REAL_BET_AMOUNT"}
    allowed_value: {label: "Handle - Bonus"  value: "BONUS_BET_AMOUNT"}
    allowed_value: {label: "Handle - Casino"  value: "CASINO_BET_AMOUNT"}
    allowed_value: {label: "Handle - Real Casino"  value: "CASINO_REAL_BET_AMOUNT"}
    allowed_value: {label: "Handle - Bonus Casino"  value: "CASINO_BONUS_BET_AMOUNT"}
    allowed_value: {label: "Handle - Sports"  value: "SBOOK_BET_AMOUNT"}
    allowed_value: {label: "Handle - Real Sports"  value: "SBOOK_REAL_BET_AMOUNT"}
    allowed_value: {label: "Handle - Bonus Sports"  value: "SBOOK_BONUS_BET_AMOUNT"}
    allowed_value: {label: "Handle - Free Bets"  value: "FB_COMPLETED"}
    allowed_value: {label: "Handle - Slots"  value: "SLOTS_BET_AMOUNT"}
    allowed_value: {label: "Handle - Real Slots"  value: "SLOTS_REAL_BET_AMOUNT"}
    allowed_value: {label: "Handle - Bonus Slots"  value: "SLOTS_BONUS_BET_AMOUNT"}
    allowed_value: {label: "Handle - Table"  value: "TABLE_BET_AMOUNT"}
    allowed_value: {label: "Handle - Real Table"  value: "TABLE_REAL_BET_AMOUNT"}
    allowed_value: {label: "Handle - Bonus Table"  value: "TABLE_BONUS_BET_AMOUNT"}
    allowed_value: {label: "Handle - Live Dealer"  value: "LIVEDEALER_BET_AMOUNT"}
    allowed_value: {label: "Handle - Real Live Dealer"  value: "LIVEDEALER_REAL_BET_AMOUNT"}
    allowed_value: {label: "Handle - Bonus Live Dealer"  value: "LIVEDEALER_BONUS_BET_AMOUNT"}


    allowed_value: {label: "Payout"  value: "WIN_AMOUNT"}
    allowed_value: {label: "Payout - Casino"  value: "CASINO_WIN_AMOUNT"}
    allowed_value: {label: "Payout - Sports"  value: "SBOOK_WIN_AMOUNT"}
    allowed_value: {label: "Payout - Free Bets"  value: "FB_WON"}
    allowed_value: {label: "Payout - Slots"  value: "SLOTS_WIN_AMOUNT"}
    allowed_value: {label: "Payout - Table"  value: "TABLE_WIN_AMOUNT"}
    allowed_value: {label: "Payout - Live Dealer"  value: "LIVEDEALER_WIN_AMOUNT"}


    allowed_value: {label: "GGR"  value: "GGR"}
    allowed_value: {label: "GGR - Casino"  value: "CASINO_GGR"}
    allowed_value: {label: "GGR - Sports"  value: "SBOOK_GGR"}
    allowed_value: {label: "GGR - Slots"  value: "SLOTS_GGR"}
    allowed_value: {label: "GGR - Table"  value: "TABLE_GGR"}
    allowed_value: {label: "GGR - Live Dealer"  value: "LIVEDEALER_GGR"}


    allowed_value: {label: "NGR"  value: "NGR"}
    allowed_value: {label: "NGR - Casino"  value: "CASINO_ADJUSTMENTS"}
    allowed_value: {label: "NGR - Sports"  value: "SBOOK_ADJUSTMENTS"}
    allowed_value: {label: "NGR - Slots"  value: "SLOTS_ADJUSTMENTS"}
    allowed_value: {label: "NGR - Table"  value: "TABLE_ADJUSTMENTS"}
    allowed_value: {label: "NGR - Live Dealer"  value: "LIVEDEALER_ADJUSTMENTS"}


    allowed_value: {label: "RTP"  value: "RTP"}
    allowed_value: {label: "RTP - Casino"  value: "CASINO_RTP"}
    allowed_value: {label: "RTP - Sports"  value: "SBOOK_RTP"}
    allowed_value: {label: "RTP - Slots"  value: "SLOTS_RTP"}
    allowed_value: {label: "RTP - Table"  value: "TABLE_RTP"}
    allowed_value: {label: "RTP - Live Dealer"  value: "LIVEDEALER_RTP"}


  # ALL BELOW: DOES NOT WORK
    allowed_value: {label: "Unique Bettors"  value: "CAGE_PLAYER_ID"}
    # used cage_player_id as substitute
    allowed_value: {label: "Unique Bettors - Casino"  value: "CASINO_UNIQUES"}
    allowed_value: {label: "Unique Bettors - Sports"  value: "SBOOK_UNIQUES"}
    allowed_value: {label: "Unique Bettors - Slots"  value: "SLOTS_UNIQUES"}
    allowed_value: {label: "Unique Bettors - Table"  value: "TABLE_UNIQUES"}
    allowed_value: {label: "Unique Bettors - Live Dealer"  value: "LIVEDEALER_UNIQUES"}



  # ALL BELOW: DOES NOT WORK
    # allowed_value: {label: "AHPU"  value: "AVG_HANDLE"}
    # allowed_value: {label: "ARPU"  value: "AVG_GGR"}
    # allowed_value: {label: "Avg. Bet Size"  value: "AVG_BET_AMOUNT"}
    # allowed_value: {label: "Avg. Bet Size - Casino"  value: "CASINO_ADJUSTMENTS"} #have to put a table field to work
    # allowed_value: {label: "Avg. Bet Size - Live Dealer"  value: "LIVEDEALER_ADJUSTMENTS"} #have to put a table field to work
    # allowed_value: {label: "Avg. Bet Size - Slots"  value: "SLOTS_ADJUSTMENTS"} #have to put a table field to work
    # allowed_value: {label: "Avg. Bet Size - Sports"  value: "SBOOK_ADJUSTMENTS"} #have to put a table field to work
    # allowed_value: {label: "Avg. Bet Size - Table"  value: "TABLE_ADJUSTMENTS"} #have to put a table field to work
    # allowed_value: {label: "Avg. Session Length"  value: "ADJUSTMENTS"} #have to put a table field to work




  }

  measure: kpi_total {
    type: number
    sql:
    sum(case when '{% parameter kpi %}' in ('FTDS','KYC_REGISTRATIONS','LOGINS','CASINO_LLPTS',
                      'SBOOK_LLPTS','NO_BETS','NO_LIVEDEALER_BETS','NO_SLOTS_BETS','NO_SBOOK_BETS','NO_TABLE_BETS',
                      'NO_CASINO_BETS','DEPOSITS','REGISTRATIONS','SESSION_LENGTH','SESSIONS','WITHDRAWALS')
              then ${TABLE}.{% parameter kpi %}

      when '{% parameter kpi %}' in ('BONUS_MONEY_ISSUED','DEPOSIT_AMOUNT','FB_ISSUED','CASINO_GGR','LIVEDEALER_GGR',
      'SLOTS_GGR','TABLE_GGR','BET_AMOUNT','BONUS_BET_AMOUNT','CASINO_BET_AMOUNT','CASINO_BONUS_BET_AMOUNT',
      'CASINO_REAL_BET_AMOUNT','FB_COMPLETED','LIVEDEALER_BET_AMOUNT','LIVEDEALER_BONUS_BET_AMOUNT',
      'LIVEDEALER_REAL_BET_AMOUNT','REAL_BET_AMOUNT','SLOTS_BET_AMOUNT','SLOTS_BONUS_BET_AMOUNT','SLOTS_REAL_BET_AMOUNT',
      'SBOOK_BET_AMOUNT','SBOOK_BONUS_BET_AMOUNT','SBOOK_REAL_BET_AMOUNT','TABLE_BET_AMOUNT','TABLE_BONUS_BET_AMOUNT',
      'TABLE_REAL_BET_AMOUNT','NET_DEPOSITS','WIN_AMOUNT','CASINO_WIN_AMOUNT','FB_WON','LIVEDEALER_WIN_AMOUNT',
      'SLOTS_WIN_AMOUNT','SBOOK_WIN_AMOUNT','TABLE_WIN_AMOUNT','WITHDRAWAL_AMOUNT')
      then case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}.{% parameter kpi %}
      when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}.{% parameter kpi %}
      when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}.{% parameter kpi %}
      else ${TABLE}.{% parameter kpi %} end

      when '{% parameter kpi %}' in ('GGR','SBOOK_GGR')
      then case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}.{% parameter kpi %}
      when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}.{% parameter kpi %}
      when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}
      *(${TABLE}.{% parameter kpi %} + ${TABLE}."FB_COMPLETED" - ${TABLE}."FB_WON")
      when ${cage_code} = 57 and {% parameter colombia_conversion %} is null then ${TABLE}.{% parameter kpi %}
      when ${cage_code} = 52 and {% parameter mexico_conversion %} is null then ${TABLE}.{% parameter kpi %}
      else ${TABLE}.{% parameter kpi %} + ${TABLE}."FB_COMPLETED" - ${TABLE}."FB_WON" end

      when '{% parameter kpi %}' = 'NGR'
      then case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}.{% parameter kpi %}
      when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}.{% parameter kpi %}
      when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}
      *(${TABLE}."GGR" - ${TABLE}."BONUS_BET_AMOUNT" - ${TABLE}."FB_WON")
      when ${cage_code} = 57 and {% parameter colombia_conversion %} is null then ${TABLE}.{% parameter kpi %}
      when ${cage_code} = 52 and {% parameter mexico_conversion %} is null then ${TABLE}.{% parameter kpi %}
      else ${TABLE}."GGR" - ${TABLE}."BONUS_BET_AMOUNT" - ${TABLE}."FB_WON" end

      when '{% parameter kpi %}' = 'SBOOK_ADJUSTMENTS'
      -- for sb NGR
      then case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}
      *(${TABLE}."SBOOK_GGR"-${TABLE}."SBOOK_BONUS_BET_AMOUNT")
      when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}
      *(${TABLE}."SBOOK_GGR"-${TABLE}."SBOOK_BONUS_BET_AMOUNT")
      when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}
      *(${TABLE}."SBOOK_GGR"-${TABLE}."SBOOK_BONUS_BET_AMOUNT"-${TABLE}."FB_WON")
      else (${TABLE}."SBOOK_GGR"-${TABLE}."SBOOK_BONUS_BET_AMOUNT"-${TABLE}."FB_WON") end

      when '{% parameter kpi %}' = 'SLOTS_ADJUSTMENTS'
      -- for slots NGR
      then case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."SLOTS_GGR"
      when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."SLOTS_GGR"
      when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."SLOTS_GGR"
      else ${TABLE}."SLOTS_GGR" end
      - case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."SLOTS_BONUS_BET_AMOUNT"
      when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."SLOTS_BONUS_BET_AMOUNT"
      when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."SLOTS_BONUS_BET_AMOUNT"
      else ${TABLE}."SLOTS_BONUS_BET_AMOUNT" end

      when '{% parameter kpi %}' = 'TABLE_ADJUSTMENTS'
      -- for table NGR
      then case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."TABLE_GGR"
      when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."TABLE_GGR"
      when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."TABLE_GGR"
      else ${TABLE}."TABLE_GGR" end
      - case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."TABLE_BONUS_BET_AMOUNT"
      when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."TABLE_BONUS_BET_AMOUNT"
      when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."TABLE_BONUS_BET_AMOUNT"
      else ${TABLE}."TABLE_BONUS_BET_AMOUNT" end


      when '{% parameter kpi %}' = 'CASINO_ADJUSTMENTS'
      -- for casino NGR
      then case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."CASINO_GGR"
      when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."CASINO_GGR"
      when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."CASINO_GGR"
      else ${TABLE}."CASINO_GGR" end
      - case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."CASINO_BONUS_BET_AMOUNT"
      when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."CASINO_BONUS_BET_AMOUNT"
      when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."CASINO_BONUS_BET_AMOUNT"
      else ${TABLE}."CASINO_BONUS_BET_AMOUNT" end

      when '{% parameter kpi %}' = 'LIVEDEALER_ADJUSTMENTS'
      -- for livedealer NGR
      then case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."LIVEDEALER_GGR"
      when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."LIVEDEALER_GGR"
      when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."LIVEDEALER_GGR"
      else ${TABLE}."LIVEDEALER_GGR" end
      - case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."LIVEDEALER_BONUS_BET_AMOUNT"
      when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."LIVEDEALER_BONUS_BET_AMOUNT"
      when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."LIVEDEALER_BONUS_BET_AMOUNT"
      else ${TABLE}."LIVEDEALER_BONUS_BET_AMOUNT" end

      when '{% parameter kpi %}' = 'LLPTS'
      then ${TABLE}."CASINO_LLPTS" + ${TABLE}."SBOOK_LLPTS"

      else 0 end)

      +

      count(distinct(

      case when '{% parameter kpi %}' = 'CAGE_PLAYER_ID'
           and (${TABLE}."CASINO_UNIQUES" = 1 or ${TABLE}."SBOOK_UNIQUES" = 1) then ${TABLE}."CAGE_CODE"  || '-' || ${TABLE}."CAGE_PLAYER_ID"

           when '{% parameter kpi %}' in ('CASINO_UNIQUES','LIVEDEALER_UNIQUES','SLOTS_UNIQUES','SBOOK_UNIQUES','TABLE_UNIQUES','DEPOSITORS','WITHDRAWERS')
           and ${TABLE}.{% parameter kpi %} = 1 then ${TABLE}."CAGE_CODE"  || '-' || ${TABLE}."CAGE_PLAYER_ID"

      else null end
      )
      )


      +

      (
      sum(
      case

      when '{% parameter kpi %}' in ('RTP')
      then case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."WIN_AMOUNT"
      when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."WIN_AMOUNT"
      when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."WIN_AMOUNT"
      else ${TABLE}."WIN_AMOUNT" end

      when '{% parameter kpi %}' in ('CASINO_RTP')
      then case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."CASINO_WIN_AMOUNT"
      when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."CASINO_WIN_AMOUNT"
      when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."CASINO_WIN_AMOUNT"
      else ${TABLE}."CASINO_WIN_AMOUNT" end

      when '{% parameter kpi %}' in ('SLOTS_RTP')
      then case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."SLOTS_WIN_AMOUNT"
      when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."SLOTS_WIN_AMOUNT"
      when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."SLOTS_WIN_AMOUNT"
      else ${TABLE}."SLOTS_WIN_AMOUNT" end

      when '{% parameter kpi %}' in ('TABLE_RTP')
      then case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."TABLE_WIN_AMOUNT"
      when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."TABLE_WIN_AMOUNT"
      when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."TABLE_WIN_AMOUNT"
      else ${TABLE}."TABLE_WIN_AMOUNT" end

      when '{% parameter kpi %}' in ('LIVEDEALER_RTP')
      then case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."LIVEDEALER_WIN_AMOUNT"
      when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."LIVEDEALER_WIN_AMOUNT"
      when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."LIVEDEALER_WIN_AMOUNT"
      else ${TABLE}."LIVEDEALER_WIN_AMOUNT" end

      when '{% parameter kpi %}' in ('SBOOK_RTP')
      then case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."SBOOK_WIN_AMOUNT"
      when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."SBOOK_WIN_AMOUNT"
      when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."SBOOK_WIN_AMOUNT"
      else ${TABLE}."SBOOK_WIN_AMOUNT" end

      when '{% parameter kpi %}' in ('PROMO_BONUS_OB') --hold over for reinvestment
      then case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*(${TABLE}."BONUS_MONEY_ISSUED"+${TABLE}."FB_ISSUED")
      when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*(${TABLE}."BONUS_MONEY_ISSUED"+${TABLE}."FB_ISSUED")
      when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*(${TABLE}."BONUS_MONEY_ISSUED"+${TABLE}."FB_ISSUED")
      else (${TABLE}."BONUS_MONEY_ISSUED"+${TABLE}."FB_ISSUED") end

      when '{% parameter kpi %}' in ('PASSED_REGISTRATIONS') --hold over for kyc pass
      then ${TABLE}."KYC_REGISTRATIONS"

      when '{% parameter kpi %}' in ('LIVEDEALER_LLPTS') --hold over for ftd conv
      then ${TABLE}."FTDS"

      when '{% parameter kpi %}' in ('ADJUSTMENTS') --hold over for avg session length
      then ${TABLE}."SESSION_LENGTH"


      else 0 end


      )

      /

      sum(case

      when '{% parameter kpi %}' in ('RTP')
      then case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."BET_AMOUNT"
      when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."BET_AMOUNT"
      when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."BET_AMOUNT"
      else ${TABLE}."BET_AMOUNT" end

      when '{% parameter kpi %}' in ('CASINO_RTP')
      then case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."CASINO_BET_AMOUNT"
      when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."CASINO_BET_AMOUNT"
      when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."CASINO_BET_AMOUNT"
      else ${TABLE}."CASINO_BET_AMOUNT" end

      when '{% parameter kpi %}' in ('SLOTS_RTP')
      then case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."SLOTS_BET_AMOUNT"
      when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."SLOTS_BET_AMOUNT"
      when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."SLOTS_BET_AMOUNT"
      else ${TABLE}."SLOTS_BET_AMOUNT" end

      when '{% parameter kpi %}' in ('TABLE_RTP')
      then case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."TABLE_BET_AMOUNT"
      when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."TABLE_BET_AMOUNT"
      when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."TABLE_BET_AMOUNT"
      else ${TABLE}."TABLE_BET_AMOUNT" end

      when '{% parameter kpi %}' in ('LIVEDEALER_RTP')
      then case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."LIVEDEALER_BET_AMOUNT"
      when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."LIVEDEALER_BET_AMOUNT"
      when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."LIVEDEALER_BET_AMOUNT"
      else ${TABLE}."LIVEDEALER_BET_AMOUNT" end

      when '{% parameter kpi %}' in ('SBOOK_RTP')
      then case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."SBOOK_BET_AMOUNT"
      when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."SBOOK_BET_AMOUNT"
      when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."SBOOK_BET_AMOUNT"
      else ${TABLE}."SBOOK_BET_AMOUNT" end

      when '{% parameter kpi %}' in ('PROMO_BONUS_OB') --hold over for reinvestment
      then case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."GGR"
      when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."GGR"
      when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}
      *(${TABLE}."GGR" + ${TABLE}."FB_COMPLETED" - ${TABLE}."FB_WON")
      when ${cage_code} = 57 and {% parameter colombia_conversion %} is null then ${TABLE}."GGR"
      when ${cage_code} = 52 and {% parameter mexico_conversion %} is null then ${TABLE}."GGR"
      else ${TABLE}."GGR" + ${TABLE}."FB_COMPLETED" - ${TABLE}."FB_WON" end

      when '{% parameter kpi %}' in ('PASSED_REGISTRATIONS') --hold over for kyc_passed
      then ${TABLE}."REGISTRATIONS"

      when '{% parameter kpi %}' in ('LIVEDEALER_LLPTS') --hold over for FTD conv
      then ${TABLE}."KYC_REGISTRATIONS"

      when '{% parameter kpi %}' in ('ADJUSTMENTS') --hold over for avg session length
      then ${TABLE}."SESSIONS"

      else 1 end
      )
      )


      ;;
  }


  measure: date_comparison_m {
    label: "Date Comparison"
    type: sum
    sql: case when date(${report_date_date}) = date({% parameter date_comparison %}) then 1 else 0 end ;;
  }

## ------------------ USER FILTERS  ------------------ ##


  filter: Pre_Promotion_Dates {
    view_label: "Parameter_Testing"
    group_label: "Arbitrary Period Comparisons"
    description: "Choose the first date range to compare against. This must be before the second period"
    type: date
    convert_tz: no
  }

  filter: Promotion_Dates {
    view_label: "Parameter_Testing"
    group_label: "Arbitrary Period Comparisons"
    description: "Choose the second date range to compare to. This must be after the first period"
    type: date
    convert_tz: no
  }

## ------------------ HIDDEN HELPER DIMENSIONS  ------------------ ##


  dimension: days_from_start_first {
    view_label: "Parameter_Testing"
    hidden: yes
    type: number
    sql: DATEDIFF(day,  {% date_start Pre_Promotion_Dates %}, ${report_date_date}) ;;
  }

  dimension: days_from_start_second {
    view_label: "Parameter_Testing"
    hidden: yes
    type: number
    sql: DATEDIFF(day,  {% date_start Promotion_Dates %}, ${report_date_date}) ;;
  }

## ------------------ DIMENSIONS TO PLOT ------------------ ##


  dimension: days_from_first_period {
    view_label: "Parameter_Testing"
    description: "Select for Grouping (Rows)"
    group_label: "Arbitrary Period Comparisons"
    type: date
    sql:
        CASE
        WHEN ${days_from_start_second} >= 0
        THEN ${report_date_date}
        WHEN ${days_from_start_first} >= 0
        THEN ${report_date_date}
        END;;
  }


  dimension: Promotion_Periods {
    view_label: "Parameter_Testing"
    group_label: "Arbitrary Period Comparisons"
    ## label: "First or second period"
    description: "Select for Comparison (Pivot)"
    type: string
    sql:
        CASE
            WHEN {% condition Pre_Promotion_Dates %}${report_date_date} {% endcondition %}
            THEN 'Pre Promotion Period'
            WHEN {% condition Promotion_Dates %}${report_date_date} {% endcondition %}
            THEN 'Promotion Period'
            END ;;
  }


  # dimension: first_deposit_attempt_method {
  #   label: "First Attempted Deposit Method"
  #   type: string
  #   sql: ${TABLE}."FIRST_DEPOSIT_ATTEMPT_METHOD" ;;
  #   description: "First Attempted Deposit Method regardless of status"
  # }

  # dimension: first_deposit_method {
  #   label: "First Approved Deposit Method"
  #   type: string
  #   sql: ${TABLE}."FIRST_DEPOSIT_METHOD" ;;
  #   description: "First Approved Deposit Method"
  # }

# ========================
#        MEASURES
# ========================

  measure: registrations_m {
    group_label: "Registration Flow"
    label: "Registrations"
    type: sum
    sql: ${TABLE}."REGISTRATIONS";;
  }

  measure: logins_m {
    group_label: "Login Info"
    label: "Logins"
    description: "Number of unique players logging in in a day"
    type: sum
    sql: ${TABLE}."LOGINS" ;;
  }

  measure: sessions_m {
    group_label: "Login Info"
    label: "Sessions"
    description: "Number of Sessions. Note a player may have multiple sessions in one day"
    type: sum
    sql: ${TABLE}."SESSIONS" ;;
  }

  measure: session_length_m {
    group_label: "Login Info"
    label: "Session Length"
    description: "Session Length in Minutes"
    type: sum
    sql: ${TABLE}."SESSION_LENGTH" ;;
  }

  measure: avg_session_length_m {
    group_label: "Averages"
    label: "Avg. Session Length"
    description: "Average Length in Minutes per Session"
    type: number
    sql: case when ${sessions_m} > 0 then ${session_length_m}/${sessions_m} else null end ;;
  }

  measure: passed_registrations_m {
    group_label: "Registration Flow"
    label: "Passed Registrations"
    type: sum
    sql: ${TABLE}."PASSED_REGISTRATIONS" ;;
  }

  measure: kyc_registrations_m {
    group_label: "Registration Flow"
    label: "KYC Registrations"
    type: sum
    sql: ${TABLE}."KYC_REGISTRATIONS" ;;
  }


  measure: kyc_pass_pct {
    group_label: "Registration Flow"
    label: "KYC Pass %"
    type: number
    sql:  sum(${TABLE}."KYC_REGISTRATIONS")/sum(${TABLE}."REGISTRATIONS") ;;
    value_format_name: percent_2
  }
  measure: ftd_pass_pct_of_reg {
    group_label: "Registration Flow"
    label: "FTD Pass % of Regs"
    type: number
    sql:  sum(${TABLE}."FTDS")/sum(${TABLE}."REGISTRATIONS") ;;
    value_format_name: percent_2
  }
  measure: ftd_pass_pct_of_kyc {
    group_label: "Registration Flow"
    label: "FTD Pass % of KYC Regs"
    type: number
    sql:  sum(${TABLE}."FTDS")/sum(${TABLE}."KYC_REGISTRATIONS") ;;
    value_format_name: percent_2
  }

  measure: Days_To_Crossover {
    label: "Days to Crossover"
    type: number
    sql:  case when  (case when left(${TABLE}."GAME_TYPE_ORDER",5) = 'SBOOK' then 'Sportsbook'
      when position('|',${TABLE}."GAME_TYPE_ORDER")>0 then left(${TABLE}."GAME_TYPE_ORDER",position(' |',${TABLE}."GAME_TYPE_ORDER"))
      end) = 'Sportsbook' then datediff(day,${TABLE}."first_sb_date",${TABLE}."first_casino_date")
        else datediff(day,${TABLE}."first_casino_date",${TABLE}."first_sb_date") end ;;
  }

  measure: ftds_m {
    group_label: "Registration Flow"
    label: "FTDs"
    type: sum
    sql: ${TABLE}."FTDS" ;;
  }

  measure: attempted_ftds_m {
    group_label: "Registration Flow"
    label: "Attempted FTDs"
    type: sum
    sql: case when ${TABLE}."FIRST_DEPOSIT_ATTEMPT_METHOD" is not null then 1 else 0 end ;;
  }

  measure: affiliate_commissions {
    type: sum
    sql: ${TABLE}."affiliate_commissions" ;;
    value_format: "$#,##0.00"
    description: "FTD NY = $150, FTD Casino = $250, FTD Sbook = $200"

  }



  measure: depositors_m {
    group_label: "Payment Info"
    label: "Depositors"
     type: count_distinct
    sql: case when ${TABLE}."DEPOSIT_AMOUNT" > 0 then ${TABLE}."CAGE_CODE"  || '-' || ${TABLE}."CAGE_PLAYER_ID" end ;;
    description: "Unique Depositors"
    value_format_name: decimal_0
  }

  measure: deposit_days {
    group_label: "Payment Info"
    type: sum
    sql: ${TABLE}."DEPOSITORS" ;;
  }



  measure: deposits_m {
    group_label: "Payment Info"
    label: "Deposits"
    type: sum
    sql: ${TABLE}."DEPOSITS" ;;
  }

  measure: BBB {
    group_label: "Bonuses and Promotions"
    label: "BBB"
    type: number
    sql:

    case when floor(({% parameter reinvestment_level %}-${reinvestment})*${ggr_m})>100 then 100
      when floor(({% parameter reinvestment_level %}-${reinvestment})*${ggr_m})<5 then 5
      else floor(({% parameter reinvestment_level %}-${reinvestment})*${ggr_m}) end ;;
  }



  measure: Casino_Activity_Days {
    group_label: "Activity Days"
    label: "Casino Activity Days"
    type: number
    sql:
    count(distinct
    case when ${TABLE}."CASINO_BET_AMOUNT" >0 then ${TABLE}."REPORT_DATE" end) ;;
  }


  measure: Sportsbook_Activity_Days {
    group_label: "Activity Days"
    label: "Sportsbook Activity Days"
    type: number
    sql:
    count(distinct
    case when ${TABLE}."SBOOK_BET_AMOUNT" >0 then ${TABLE}."REPORT_DATE" end) ;;
  }

  measure: Activity_Days{
    group_label: "Activity Days"
    label: "Activity Days"
    type: number
    sql:
    count(distinct
    case when ${TABLE}."BET_AMOUNT" >0 then ${TABLE}."REPORT_DATE" end) ;;
  }



  measure: deposit_amount_m {
    group_label: "Payment Info"
    label: "Deposit Amount"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."DEPOSIT_AMOUNT"
              when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."DEPOSIT_AMOUNT"
              when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."DEPOSIT_AMOUNT"
              when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."DEPOSIT_AMOUNT"
              else ${TABLE}."DEPOSIT_AMOUNT" end ;;
    # sql: ${TABLE}."DEPOSIT_AMOUNT" ;;
      value_format_name: usd
  }


  measure: gross_deposit {
    group_label: "Payment Info"
    label: "Gross Deposit Amount"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."gross_deposit"
              when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."gross_deposit"
              when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."gross_deposit"
              when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."gross_deposit"
              else ${TABLE}."gross_deposit" end ;;
      value_format_name: usd
    }


  measure: deposit_tax {
    group_label: "Payment Info"
    label: "Deposit Tax"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."deposit_tax"
              when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."deposit_tax"
              when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."deposit_tax"
              when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."deposit_tax"
              else ${TABLE}."deposit_tax" end ;;
      value_format_name: usd
    }

  measure: wagering_percent {
    label: "Wagering %"
    type: number
    value_format: "0.00%"
    sql: ${bet_amount_m}/${deposit_amount_m} ;;
  }

  measure: withdrawers_m {
    group_label: "Payment Info"
    label: "Withdrawers"
    type: count_distinct
    sql: case when ${TABLE}."WITHDRAWAL_AMOUNT" > 0 then ${TABLE}."CAGE_CODE"  || '-' || ${TABLE}."CAGE_PLAYER_ID" end ;;
    description: "Unique Withdrawers"
    value_format_name: decimal_0
  }

  measure: withdrawal_days {
    group_label: "Payment Info"
    type: sum
    sql: ${TABLE}."WITHDRAWERS" ;;
  }

  measure: withdrawals_m {
    group_label: "Payment Info"
    label: "Withdrawals"
    type: sum
    sql: ${TABLE}."WITHDRAWALS" ;;
  }

  measure: withdrawal_amount_m {
    group_label: "Payment Info"
    label: "Withdrawal Amount"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."WITHDRAWAL_AMOUNT"
            when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."WITHDRAWAL_AMOUNT"
            when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."WITHDRAWAL_AMOUNT"
            when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."WITHDRAWAL_AMOUNT"
            else ${TABLE}."WITHDRAWAL_AMOUNT" end ;;
  # sql: ${TABLE}."WITHDRAWAL_AMOUNT" ;;
      value_format_name: usd
  }

  measure: net_deposits_m {
    group_label: "Payment Info"
    label: "Net Deposits"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."NET_DEPOSITS"
          when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."NET_DEPOSITS"
          when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."NET_DEPOSITS"
          when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."NET_DEPOSITS"
          else ${TABLE}."NET_DEPOSITS" end ;;
  # sql: ${TABLE}."NET_DEPOSITS";;
          value_format_name: usd
  }


  # ---------- NUMBER OF BETS

  measure: _bets_m {
    label: "Number of Bets"
    group_label: "Number of Bets"
    type: sum
    sql: ${TABLE}."NO_BETS" ;;
  }

  measure: _casino_bets_m {
    label: "Number of Casino Bets"
    group_label: "Number of Bets"
    type: sum
    sql: ${TABLE}."NO_CASINO_BETS" ;;
  }

  measure: sbook_bets_m {
    label: "Number of SBook Bets"
    group_label: "Number of Bets"
    type: sum
    sql: ${TABLE}."NO_SBOOK_BETS" ;;
  }

  measure: livedealer_bets_m {
    label: "Number of Live Dealer Bets"
    group_label: "Number of Bets"
    type: sum
    sql: ${TABLE}."NO_LIVEDEALER_BETS";;
  }

  measure: table_bets_m {
    label: "Number of Table Bets"
    group_label: "Number of Bets"
    type: sum
    sql: ${TABLE}."NO_TABLE_BETS";;
  }

  measure: slots_bets_m {
    label: "Number of Slots Bets"
    group_label: "Number of Bets"
    type: sum
    sql: ${TABLE}."NO_SLOTS_BETS";;
  }





  measure: bet_amount_m {
    group_label: "Game Play: Totals"
    label: "Handle"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."BET_AMOUNT"
        when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."BET_AMOUNT"
        when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."BET_AMOUNT"
        when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."BET_AMOUNT"
        else ${TABLE}."BET_AMOUNT" end ;;
   # sql: ${TABLE}."BET_AMOUNT";;
    value_format_name: usd
  }

  measure: bonus_bet_amount_m {
    group_label: "Game Play: Totals"
    label: "Bonus Handle"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."BONUS_BET_AMOUNT"
      when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."BONUS_BET_AMOUNT"
      when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."BONUS_BET_AMOUNT"
      when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."BONUS_BET_AMOUNT"
      else ${TABLE}."BONUS_BET_AMOUNT" end ;;
  # sql: ${TABLE}."BONUS_BET_AMOUNT";;
    value_format_name: usd
    }

  measure: real_bet_amount_m {
    group_label: "Game Play: Totals"
    label: "Real Handle"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."REAL_BET_AMOUNT"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."REAL_BET_AMOUNT"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."REAL_BET_AMOUNT"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."REAL_BET_AMOUNT"
                    else ${TABLE}."REAL_BET_AMOUNT" end ;;
          # sql: ${TABLE}."REAL_BET_AMOUNT";;
    value_format_name: usd
  }

  measure: win_amount_m {
    group_label: "Game Play: Totals"
    label: "Win Amount"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."WIN_AMOUNT"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."WIN_AMOUNT"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."WIN_AMOUNT"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."WIN_AMOUNT"
                    else ${TABLE}."WIN_AMOUNT" end ;;
          # sql: ${TABLE}."WIN_AMOUNT";;
    value_format_name: usd
  }






  measure: ggr_m {
    group_label: "Game Play: Totals"
    label: "GGR"
##    type: sum
##    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."GGR"
##                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."GGR"
##                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."GGR"
##                    else ${TABLE}."GGR" end ;;
##          # sql: ${TABLE}."GGR";;
##      value_format_name: usd
##  }
##
##  measure: agr_m {
##    label: "Adjusted GGR"
    type: sum

    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."GGR"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."GGR"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."GGR"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."GGR"
                    else ${TABLE}."GGR" end ;;

    # sql: case when ${cage_code} in (52,57) then ${TABLE}."GGR"
    #       else ${TABLE}."GGR" + ${TABLE}."FB_COMPLETED" - ${TABLE}."FB_WON" end;;

    value_format_name: usd
    drill_fields: [cage_player_id]
  }

  measure: ngr_m {
    group_label: "Game Play: Totals"
    label: "NGR"
##    type: sum
##    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."NGR"
##                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."NGR"
##                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."NGR"
##                    else ${TABLE}."NGR" end ;;
##          # sql:  ${TABLE}."NGR" ;;
##      value_format_name: usd
##  }
##
##  measure: angr_m {
##    label: "Adjusted NGR"
    type: sum

    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."NGR"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."NGR"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."NGR"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."NGR"
                    else ${TABLE}."NGR" end;;
    # sql: case when ${cage_code} in (57,52) then ${TABLE}."NGR"
    #       else ${TABLE}."GGR" - ${TABLE}."BONUS_BET_AMOUNT" - ${TABLE}."FB_WON" end;;



    value_format_name: usd
    drill_fields: [cage_player_id]
  }

  measure: rtp_m {
    group_label: "Game Play: Totals"
    label: "RTP%"
    type: number
    sql: ${win_amount_m}/nullif(${bet_amount_m},0) ;;
    value_format_name: percent_2
  }


  measure: reinvestment {
    group_label: "Bonuses and Promotions"
    label: "Total Reinvestment"
    description: "Free Bets Issued+Bonus Money Issued divided by GGR"
    type: number
    sql: (${bonus_money_issued_m}+${fb_issued_m})/nullif(${ggr_m},0) ;;
    value_format_name: percent_2
  }


  measure: bonus_money_issued_reinvestment {
    group_label: "Bonuses and Promotions"
    label: "Bonus Money Reinvestment"
    description: "Bonus Money Issued divided by GGR"
    type: number
    sql: ${bonus_money_issued_m}/nullif(${ggr_m},0) ;;
    value_format_name: percent_2
  }



  measure: free_bet_reinvestment {
    group_label: "Bonuses and Promotions"
    label: "Free Bet Reinvestment"
    description: "Free Bet Issued divided by GGR"
    type: number
    sql: ${fb_issued_m}/nullif(${ggr_m},0) ;;
    value_format_name: percent_2
  }

  measure: arpu {
    group_label: "Averages"
    label: "ARPU"
    type: number

    sql: CASE WHEN COUNT( DISTINCT (CASE WHEN ${TABLE}."BET_AMOUNT" > 0 THEN ${TABLE}."cage_player_id" END)) = 0 THEN 0
      ELSE ${ggr_m}/COUNT( DISTINCT (CASE WHEN ${TABLE}."BET_AMOUNT" > 0 THEN ${TABLE}."cage_player_id" END)) END;;
    value_format_name:  usd
  }


# ------Loyalty Points


  measure: BONUS_STORE_PTS_ISSUED_m {
    label: "Bonus Store Points"
    group_label: "Loyalty Points Earned"
    type: sum
    sql: ${TABLE}."CASINO_LLPTS" + ${TABLE}."SBOOK_LLPTS" ;;
  }

  measure: LLPTS_m {
    label: "Loyalty Points"
    group_label: "Loyalty Points Earned"
    type: sum
    sql: ${TABLE}."LOYALTY_POINTS_EARNED" ;;
  }

  measure: slots_llpts_m {
    label: "Slots Loyalty Points"
    group_label: "Loyalty Points Earned"
    type: sum
    sql: ${TABLE}."SLOTS_LLPTS" ;;
  }

  measure: TABLE_LLPTS_m {
    label: "Table Loyalty Points"
    group_label: "Loyalty Points Earned"
    type: sum
    sql: ${TABLE}."TABLE_LLPTS" ;;
  }

  measure: LIVEDEALER_LLPTS_m {
    label: "Livedealer Loyalty Points"
    group_label: "Loyalty Points Earned"
    type: sum
    sql: ${TABLE}."LIVEDEALER_LLPTS" ;;
  }

  measure: SBOOK_LLPTS_m {
    label: "Sportsbook Loyalty Points"
    group_label: "Loyalty Points Earned"
    type: sum
    sql: ${TABLE}."SBOOK_LLPTS" ;;
  }

  measure: CASINO_LLPTS_m {
    label: "Casino Loyalty Points"
    group_label: "Loyalty Points Earned"
    type: sum
    sql: ${TABLE}."CASINO_LLPTS" ;;
    value_format_name: decimal_2
  }


# ------Avgerages



  measure: avg_bet_amount_m {
    label: "AVG Bet"
    group_label: "Averages"
    type: number

    sql: case when ${_bets_m} > 0 then ${bet_amount_m}/${_bets_m} else null end;;
    value_format_name:  usd
  }

  measure: avg_casino_bet_amount_m {
    label: "AVG Casino Bet"
    group_label: "Averages"
    type: number
    sql: case when ${_casino_bets_m} > 0 then ${casino_bet_amount_m}/${_casino_bets_m} else null end;;
    value_format_name: usd
  }

  measure: avg_sbook_bet_amount_m {
    label: "AVG Sportsbook Bet"
    group_label: "Averages"
    type: number
    sql: case when ${sbook_bets_m} > 0 then ${sbook_bet_amount_m}/${sbook_bets_m} else null end;;
    value_format_name: usd
  }

  measure: avg_slots_bet_amount_m {
    label: "AVG Slots Bet"
    group_label: "Averages"
    type: number
    sql: case when ${slots_bets_m} > 0 then ${slots_bet_amount_m}/${slots_bets_m} else null end;;
    value_format_name: usd
  }

  measure: avg_table_bet_amount_m {
    label: "AVG Table Bet"
    group_label: "Averages"
    type: number
    sql: case when ${table_bets_m}} > 0 then ${table_bet_amount_m}/${table_bets_m} else null end;;
    value_format_name: usd
  }

  measure: avg_livedealer_bet_amount_m {
    label: "AVG Livedealer Bet"
    group_label: "Averages"
    type: number
    sql: case when ${livedealer_bets_m} > 0 then ${livedealer_bet_amount_m}/${livedealer_bets_m} else null end;;
    value_format_name: usd
  }

  measure: avg_ggr_m {
    label: "AVG GGR"
    group_label: "Averages"
    type: number
    sql: case when ${unique_bettors_m} > 0 then ${ggr_m}/${unique_bettors_m} else null end;;
    value_format_name: usd
  }

  measure: avg_handle_m {
    label: "AVG Handle"
    group_label: "Averages"
    type: number
    sql: case when ${unique_bettors_m} > 0 then ${bet_amount_m}/${unique_bettors_m} else null end;;
    value_format_name: usd
  }



  measure: real_money_uniques {
    group_label: "Game Play: Totals"
    label: "Real Money Unique Bettors"
    type: count_distinct
    sql: ${TABLE}."REAL_MONEY_UNIQUES";;
  }

  measure: unique_bettors_m {
    group_label: "Game Play: Totals"
    label: "Unique Bettors"
    type: count_distinct
    sql: ${TABLE}."UNIQUE_BETTORS";;
  }

  measure: casino_uniques_m {
    group_label: "Game Play: Casino"
    label: "Casino Uniques"
    type: count_distinct
    sql:${TABLE}."CASINO_UNIQUES";;
  }

  measure: casino_bet_amount_m {
    group_label: "Game Play: Casino"
    label: "Casino Handle"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."CASINO_BET_AMOUNT"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."CASINO_BET_AMOUNT"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."CASINO_BET_AMOUNT"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."CASINO_BET_AMOUNT"
                    else ${TABLE}."CASINO_BET_AMOUNT" end ;;
          # sql: ${TABLE}."CASINO_BET_AMOUNT" ;;
      value_format_name: usd
  }

  measure: casino_bonus_bet_amount_m {
    group_label: "Game Play: Casino"
    label: "Casino Bonus Handle"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."CASINO_BONUS_BET_AMOUNT"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."CASINO_BONUS_BET_AMOUNT"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."CASINO_BONUS_BET_AMOUNT"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."CASINO_BONUS_BET_AMOUNT"
                    else ${TABLE}."CASINO_BONUS_BET_AMOUNT" end ;;
          # sql: ${TABLE}."CASINO_BONUS_BET_AMOUNT";;
      value_format_name: usd
  }

  measure: casino_real_bet_amount_m {
    group_label: "Game Play: Casino"
    label: "Casino Real Handle"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."CASINO_REAL_BET_AMOUNT"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."CASINO_REAL_BET_AMOUNT"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."CASINO_REAL_BET_AMOUNT"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."CASINO_REAL_BET_AMOUNT"
                    else ${TABLE}."CASINO_REAL_BET_AMOUNT" end ;;
          # sql: ${TABLE}."CASINO_REAL_BET_AMOUNT" ;;
      value_format_name: usd
  }

  measure: casino_win_amount_m {
    group_label: "Game Play: Casino"
    label: "Casino Win Amount"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."CASINO_WIN_AMOUNT"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."CASINO_WIN_AMOUNT"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."CASINO_WIN_AMOUNT"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."CASINO_WIN_AMOUNT"
                    else ${TABLE}."CASINO_WIN_AMOUNT" end ;;
          # sql: ${TABLE}."CASINO_WIN_AMOUNT" ;;
      value_format_name: usd
  }

  measure: casino_ggr_m {
    group_label: "Game Play: Casino"
    label: "Casino GGR"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."CASINO_GGR"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."CASINO_GGR"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."CASINO_GGR"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."CASINO_GGR"
                    else ${TABLE}."CASINO_GGR" end ;;
          # sql: ${TABLE}."CASINO_GGR" ;;
      value_format_name: usd
  }

  measure: casino_ngr_m {
    group_label: "Game Play: Casino"
    label: "Casino NGR"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."CASINO_NGR"
    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."CASINO_NGR"
    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."CASINO_NGR"
    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."CASINO_NGR"
    else ${TABLE}."CASINO_NGR" end ;;
    value_format_name: usd
  }

  measure: casino_rtp_m {
    group_label: "Game Play: Casino"
    label: "Casino RTP%"
    type: number
    sql: ${casino_win_amount_m}/nullif(${casino_bet_amount_m},0) ;;
    value_format_name: percent_2
  }

  measure: sbook_uniques_m {
    group_label: "Game Play: Sportsbook"
    label: "SBook Uniques"
    type: count_distinct
    sql: ${TABLE}."SBOOK_UNIQUES";;
  }

  measure: sbook_bet_amount_m {
    group_label: "Game Play: Sportsbook"
    label: "SBook Handle"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."SBOOK_BET_AMOUNT"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."SBOOK_BET_AMOUNT"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."SBOOK_BET_AMOUNT"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."SBOOK_BET_AMOUNT"
                    else ${TABLE}."SBOOK_BET_AMOUNT" end ;;
          # sql: ${TABLE}."SBOOK_BET_AMOUNT" ;;
      value_format_name: usd
  }

  measure: sbook_bonus_bet_amount_m {
    group_label: "Game Play: Sportsbook"
    label: "SBook Bonus Handle"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."SBOOK_BONUS_BET_AMOUNT"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."SBOOK_BONUS_BET_AMOUNT"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."SBOOK_BONUS_BET_AMOUNT"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."SBOOK_BONUS_BET_AMOUNT"
                    else ${TABLE}."SBOOK_BONUS_BET_AMOUNT" end ;;
          # sql: ${TABLE}."SBOOK_BONUS_BET_AMOUNT";;
    value_format_name: usd
  }

  measure: sbook_real_bet_amount_m {
    group_label: "Game Play: Sportsbook"
    label: "SBook Real Handle"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."SBOOK_REAL_BET_AMOUNT"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."SBOOK_REAL_BET_AMOUNT"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."SBOOK_REAL_BET_AMOUNT"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."SBOOK_REAL_BET_AMOUNT"
                    else ${TABLE}."SBOOK_REAL_BET_AMOUNT" end ;;
          # sql: ${TABLE}."SBOOK_REAL_BET_AMOUNT";;
    value_format_name: usd
  }

  measure: sbook_win_amount_m {
    group_label: "Game Play: Sportsbook"
    label: "SBook Win Amount"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."SBOOK_WIN_AMOUNT"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."SBOOK_WIN_AMOUNT"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."SBOOK_WIN_AMOUNT"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."SBOOK_WIN_AMOUNT"
                    else ${TABLE}."SBOOK_WIN_AMOUNT" end ;;
          # sql: ${TABLE}."SBOOK_WIN_AMOUNT" ;;
    value_format_name: usd
  }

  measure: sbook_ggr_m {
    group_label: "Game Play: Sportsbook"
    label: "SBook GGR"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."SBOOK_GGR"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."SBOOK_GGR"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."SBOOK_GGR"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."SBOOK_GGR"
                    when ${cage_code} = 57 and {% parameter colombia_conversion %} is null then ${TABLE}."SBOOK_GGR"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is null then ${TABLE}."SBOOK_GGR"
                     when ${cage_code} = 51 and {% parameter colombia_conversion %} is null then ${TABLE}."SBOOK_GGR"
                    when ${cage_code} = 249 and {% parameter mexico_conversion %} is null then ${TABLE}."SBOOK_GGR"
                    else ${TABLE}."SBOOK_GGR"  end ;;
          # sql: ${TABLE}."SBOOK_GGR";;
    value_format_name: usd
  }

  measure: sbook_ngr_m {
    group_label: "Game Play: Sportsbook"
    label: "SBook NGR"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}
                        *(${TABLE}."SBOOK_NGR")
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}
                        *(${TABLE}."SBOOK_NGR")
                         when ${cage_code} = 51 and {% parameter peru_conversion  %} is not null then 1/{% parameter peru_conversion  %}
                        *(${TABLE}."SBOOK_NGR")
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}
                        *(${TABLE}."SBOOK_NGR")
                    else (${TABLE}."SBOOK_NGR") end ;;
    value_format_name: usd
  }

  measure: sbook_rtp_m {
    group_label: "Game Play: Sportsbook"
    label: "SBook RTP%"
    type: number
    sql: ${sbook_win_amount_m}/nullif(${sbook_bet_amount_m},0) ;;
    value_format_name: percent_2
  }

  ####DELAWARE KPI METRICS NEEDED FOR REGULATORS##########
  measure: sbook_hold {
    group_label: "Delaware Test Metrics"
    label: "SBook Hold%"
    type: number
    sql: ${sbook_ggr_m}/nullif(${sbook_bet_amount_m},0) ;;
    value_format_name: percent_2
  }

  measure: sbook_handle_test {
    group_label: "Delaware Test Metrics"
    label: "SBook Handle Test"
    type: number
    sql: ${sbook_bet_amount_m}+${fb_completed_m} ;;
    value_format_name: usd
  }

  measure: handle_test {
    group_label: "Delaware Test Metrics"
    label: "Handle Test"
    type: number
    sql: ${bet_amount_m}+${fb_completed_m} ;;
    value_format_name: usd
  }

  measure: sbook_free_bet_handle_test {
    group_label: "Delaware Test Metrics"
    label: "Free Bet Handle Test"
    type: number
    sql: ${fb_completed_m} ;;
    value_format_name: usd
  }
   ####END##############

  measure: slots_uniques_m {
    group_label: "Game Play: Slots"
    label: "Slots Uniques"
    type: count_distinct
    sql: ${TABLE}."SLOTS_UNIQUES" ;;
  }

  measure: slots_bet_amount_m {
    group_label: "Game Play: Slots"
    label: "Slots Handle"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."SLOTS_BET_AMOUNT"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."SLOTS_BET_AMOUNT"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."SLOTS_BET_AMOUNT"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."SLOTS_BET_AMOUNT"
                    else ${TABLE}."SLOTS_BET_AMOUNT" end ;;
          # sql: ${TABLE}."SLOTS_BET_AMOUNT"  ;;
      value_format_name: usd
  }

  measure: slots_bonus_bet_amount_m {
    group_label: "Game Play: Slots"
    label: "Slots Bonus Handle"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."SLOTS_BONUS_BET_AMOUNT"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."SLOTS_BONUS_BET_AMOUNT"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."SLOTS_BONUS_BET_AMOUNT"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."SLOTS_BONUS_BET_AMOUNT"
                    else ${TABLE}."SLOTS_BONUS_BET_AMOUNT" end ;;
          # sql: ${TABLE}."SLOTS_BONUS_BET_AMOUNT"  ;;
    value_format_name: usd
  }

  measure: slots_real_bet_amount_m {
    group_label: "Game Play: Slots"
    label: "Slots Real Handle"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."SLOTS_REAL_BET_AMOUNT"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."SLOTS_REAL_BET_AMOUNT"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."SLOTS_REAL_BET_AMOUNT"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."SLOTS_REAL_BET_AMOUNT"
                    else ${TABLE}."SLOTS_REAL_BET_AMOUNT" end ;;
          # sql: ${TABLE}."SLOTS_REAL_BET_AMOUNT"  ;;
    value_format_name: usd
  }

  measure: slots_win_amount_m {
    group_label: "Game Play: Slots"
    label: "Slots Win Amount"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."SLOTS_WIN_AMOUNT"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."SLOTS_WIN_AMOUNT"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."SLOTS_WIN_AMOUNT"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."SLOTS_WIN_AMOUNT"
                    else ${TABLE}."SLOTS_WIN_AMOUNT" end ;;
          # sql: ${TABLE}."SLOTS_WIN_AMOUNT"  ;;
    value_format_name: usd
  }

  measure: slots_ggr_m {
    group_label: "Game Play: Slots"
    label: "Slots GGR"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."SLOTS_GGR"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."SLOTS_GGR"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."SLOTS_GGR"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."SLOTS_GGR"
                    else ${TABLE}."SLOTS_GGR" end ;;
          # sql: ${TABLE}."SLOTS_GGR" ;;
    value_format_name: usd
  }

  measure: slots_ngr_m {
    group_label: "Game Play: Slots"
    label: "Slots NGR"
    type: sum
   sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."SLOTS_NGR"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."SLOTS_NGR"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."SLOTS_NGR"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."SLOTS_NGR"
                    else ${TABLE}."SLOTS_NGR" end ;;
    value_format_name: usd
  }

  measure: slots_rtp_m {
    group_label: "Game Play: Slots"
    label: "Slots RTP%"
    type: number
    sql: ${slots_win_amount_m}/nullif(${slots_bet_amount_m},0) ;;
    value_format_name: percent_2
  }

  measure: table_uniques_m {
    group_label: "Game Play: Table"
    label: "Table Uniques"
    type: count_distinct
    sql: ${TABLE}."TABLE_UNIQUES";;
  }

  measure: table_bet_amount_m {
    group_label: "Game Play: Table"
    label: "Table Handle"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."TABLE_BET_AMOUNT"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."TABLE_BET_AMOUNT"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."TABLE_BET_AMOUNT"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."TABLE_BET_AMOUNT"
                    else ${TABLE}."TABLE_BET_AMOUNT" end ;;
          # sql: ${TABLE}."TABLE_BET_AMOUNT" ;;
    value_format_name: usd
  }

  measure: table_bonus_bet_amount_m {
    group_label: "Game Play: Table"
    label: "Table Bonus Handle"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."TABLE_BONUS_BET_AMOUNT"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."TABLE_BONUS_BET_AMOUNT"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."TABLE_BONUS_BET_AMOUNT"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."TABLE_BONUS_BET_AMOUNT"
                    else ${TABLE}."TABLE_BONUS_BET_AMOUNT" end ;;
          # sql: ${TABLE}."TABLE_BONUS_BET_AMOUNT"  ;;
    value_format_name: usd
  }

  measure: table_real_bet_amount_m {
    group_label: "Game Play: Table"
    label: "Table Real Handle"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."TABLE_REAL_BET_AMOUNT"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."TABLE_REAL_BET_AMOUNT"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."TABLE_REAL_BET_AMOUNT"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."TABLE_REAL_BET_AMOUNT"
                    else ${TABLE}."TABLE_REAL_BET_AMOUNT" end ;;
          # sql: ${TABLE}."TABLE_REAL_BET_AMOUNT" ;;
    value_format_name: usd
  }

  measure: table_win_amount_m {
    group_label: "Game Play: Table"
    label: "Table Win Amount"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."TABLE_WIN_AMOUNT"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."TABLE_WIN_AMOUNT"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."TABLE_WIN_AMOUNT"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."TABLE_WIN_AMOUNT"
                    else ${TABLE}."TABLE_WIN_AMOUNT" end ;;
          # sql: ${TABLE}."TABLE_WIN_AMOUNT" ;;
    value_format_name: usd
  }

  measure: table_ggr_m {
    group_label: "Game Play: Table"
    label: "Table GGR"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."TABLE_GGR"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."TABLE_GGR"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."TABLE_GGR"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."TABLE_GGR"
                    else ${TABLE}."TABLE_GGR" end ;;
          # sql: ${TABLE}."TABLE_GGR"  ;;
    value_format_name: usd
  }

  measure: table_ngr_m {
    group_label: "Game Play: Table"
    label: "Table NGR"
    type: sum
    sql:  case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."TABLE_NGR"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."TABLE_NGR"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."TABLE_NGR"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."TABLE_NGR"
                    else ${TABLE}."TABLE_NGR" end ;;
    value_format_name: usd
  }

  measure: table_rtp_m {
    group_label: "Game Play: Table"
    label: "Table RTP%"
    type: number
    sql: ${table_win_amount_m}/nullif(${table_bet_amount_m},0) ;;
    value_format_name: percent_2
  }

  measure: livedealer_uniques_m {
    group_label: "Game Play: Livedealer"
    label: "Livedealer Uniques"
    type: count_distinct
    sql: ${TABLE}."LIVEDEALER_UNIQUES";;
  }

  measure: livedealer_bet_amount_m {
    group_label: "Game Play: Livedealer"
    label: "Livedealer Handle"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."LIVEDEALER_BET_AMOUNT"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."LIVEDEALER_BET_AMOUNT"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."LIVEDEALER_BET_AMOUNT"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."LIVEDEALER_BET_AMOUNT"
                    else ${TABLE}."LIVEDEALER_BET_AMOUNT" end ;;
          # sql: ${TABLE}."LIVEDEALER_BET_AMOUNT" ;;
    value_format_name: usd
  }

  measure: livedealer_bonus_bet_amount_m {
    group_label: "Game Play: Livedealer"
    label: "Livedealer Bonus Handle"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."LIVEDEALER_BONUS_BET_AMOUNT"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."LIVEDEALER_BONUS_BET_AMOUNT"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."LIVEDEALER_BONUS_BET_AMOUNT"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."LIVEDEALER_BONUS_BET_AMOUNT"
                    else ${TABLE}."LIVEDEALER_BONUS_BET_AMOUNT" end ;;
          # sql: ${TABLE}."LIVEDEALER_BONUS_BET_AMOUNT" ;;
    value_format_name: usd
  }

  measure: livedealer_real_bet_amount_m {
    group_label: "Game Play: Livedealer"
    label: "Livedealer Real Handle"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."LIVEDEALER_REAL_BET_AMOUNT"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."LIVEDEALER_REAL_BET_AMOUNT"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."LIVEDEALER_REAL_BET_AMOUNT"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."LIVEDEALER_REAL_BET_AMOUNT"
                    else ${TABLE}."LIVEDEALER_REAL_BET_AMOUNT" end ;;
          # sql: ${TABLE}."LIVEDEALER_REAL_BET_AMOUNT" ;;
    value_format_name: usd
  }

  measure: livedealer_win_amount_m {
    group_label: "Game Play: Livedealer"
    label: "Livedealer Win Amount"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."LIVEDEALER_WIN_AMOUNT"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."LIVEDEALER_WIN_AMOUNT"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."LIVEDEALER_WIN_AMOUNT"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."LIVEDEALER_WIN_AMOUNT"
                    else ${TABLE}."LIVEDEALER_WIN_AMOUNT" end ;;
          # sql: ${TABLE}."LIVEDEALER_WIN_AMOUNT" ;;
    value_format_name: usd
  }

  measure: livedealer_ggr_m {
    group_label: "Game Play: Livedealer"
    label: "Livedealer GGR"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."LIVEDEALER_GGR"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."LIVEDEALER_GGR"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."LIVEDEALER_GGR"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."LIVEDEALER_GGR"
                    else ${TABLE}."LIVEDEALER_GGR" end ;;
    # sql: ${TABLE}."LIVEDEALER_GGR"  ;;
    value_format_name: usd
  }

  measure: livedealer_ngr_m {
    group_label: "Game Play: Livedealer"
    label: "Livedealer NGR"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."LIVEDEALER_NGR"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."LIVEDEALER_NGR"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."LIVEDEALER_NGR"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."LIVEDEALER_NGR"
                    else ${TABLE}."LIVEDEALER_NGR" end ;;
    value_format_name: usd
  }

  measure: livedealer_rtp_m {
    group_label: "Game Play: Livedealer"
    label: "Livedealer RTP%"
    type: number
    sql: ${livedealer_win_amount_m}/nullif(${livedealer_bet_amount_m},0) ;;
    value_format_name: percent_2
  }

  measure: bonus_money_issued_m {
    group_label: "Bonuses and Promotions"
    label: "Bonus Money Issued"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."BONUS_MONEY_ISSUED"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."BONUS_MONEY_ISSUED"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."BONUS_MONEY_ISSUED"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."BONUS_MONEY_ISSUED"
                    else ${TABLE}."BONUS_MONEY_ISSUED" end ;;
    # sql: ${TABLE}."BONUS_MONEY_ISSUED" ;;
    value_format_name: usd
  }

  measure: adjustments_m {
    group_label: "Game Play: Totals"
    label: "Adjustments"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."ADJUSTMENTS"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."ADJUSTMENTS"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."ADJUSTMENTS"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."ADJUSTMENTS"
                    else ${TABLE}."ADJUSTMENTS" end ;;
    # sql: ${TABLE}."ADJUSTMENTS" ;;
    value_format_name: usd
  }

  measure: casino_adjustments_m {
    group_label: "Game Play: Casino"
    label: "Casino Adjustments"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."CASINO_ADJUSTMENTS"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."CASINO_ADJUSTMENTS"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."CASINO_ADJUSTMENTS"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."CASINO_ADJUSTMENTS"
                    else ${TABLE}."CASINO_ADJUSTMENTS" end ;;
    # sql: ${TABLE}."CASINO_ADJUSTMENTS" ;;
    value_format_name: usd
  }

  measure: sbook_adjustments_m {
    group_label: "Game Play: Sportsbook"
    label: "SBook Adjustments"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."SBOOK_ADJUSTMENTS"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."SBOOK_ADJUSTMENTS"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."SBOOK_ADJUSTMENTS"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."SBOOK_ADJUSTMENTS"
                    else ${TABLE}."SBOOK_ADJUSTMENTS" end ;;
    # sql: ${TABLE}."SBOOK_ADJUSTMENTS" ;;
    value_format_name: usd
  }

  measure: slots_adjustments_m {
    group_label: "Game Play: Slots"
    label: "Slots Adjustments"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."SLOTS_ADJUSTMENTS"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."SLOTS_ADJUSTMENTS"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."SLOTS_ADJUSTMENTS"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."SLOTS_ADJUSTMENTS"
                    else ${TABLE}."SLOTS_ADJUSTMENTS" end ;;
    # sql: ${TABLE}."SLOTS_ADJUSTMENTS" ;;
    value_format_name: usd
  }

  measure: table_adjustments_m {
    group_label: "Game Play: Table"
    label: "Table Adjustments"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."TABLE_ADJUSTMENTS"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."TABLE_ADJUSTMENTS"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."TABLE_ADJUSTMENTS"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."TABLE_ADJUSTMENTS"
                    else ${TABLE}."TABLE_ADJUSTMENTS" end ;;
    # sql: ${TABLE}."TABLE_ADJUSTMENTS" ;;
    value_format_name: usd
  }

  measure: livedealer_adjustments_m {
    group_label: "Game Play: Livedealer"
    label: "Livedealer Adjustments"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."LIVEDEALER_ADJUSTMENTS"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."LIVEDEALER_ADJUSTMENTS"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."LIVEDEALER_ADJUSTMENTS"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."LIVEDEALER_ADJUSTMENTS"
                    else ${TABLE}."LIVEDEALER_ADJUSTMENTS" end ;;
    # sql: ${TABLE}."LIVEDEALER_ADJUSTMENTS" ;;
    value_format_name: usd
  }

  measure: outstanding_fb_amount_m {
    hidden: yes
    label: "Outstanding Free Bet Amount"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."OUTSTANDING_FB_AMOUNT"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."OUTSTANDING_FB_AMOUNT"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."OUTSTANDING_FB_AMOUNT"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."OUTSTANDING_FB_AMOUNT"
                    else ${TABLE}."OUTSTANDING_FB_AMOUNT" end ;;
    # sql: ${TABLE}."OUTSTANDING_FB_AMOUNT" ;;
    value_format_name: usd
    group_label: "Bonuses and Promotions"
  }

  measure: in_use_fb_amount_m {
    hidden: yes
    label: "In-Use Free Bet Amount"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."IN_USE_FB_AMOUNT"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."IN_USE_FB_AMOUNT"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."IN_USE_FB_AMOUNT"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."IN_USE_FB_AMOUNT"
                    else ${TABLE}."IN_USE_FB_AMOUNT" end ;;
    # sql: ${TABLE}."IN_USE_FB_AMOUNT" ;;
    value_format_name: usd
    group_label: "Bonuses and Promotions"
  }

  measure: promo_handle_total_m {
    hidden: yes
    label: "Promo Handle Total"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."PROMO_HANDLE_TOTAL"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."PROMO_HANDLE_TOTAL"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."PROMO_HANDLE_TOTAL"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."PROMO_HANDLE_TOTAL"
                    else ${TABLE}."PROMO_HANDLE_TOTAL" end ;;
    # sql: ${TABLE}."PROMO_HANDLE_TOTAL" ;;
    value_format_name: usd
    group_label: "Bonuses and Promotions"
  }

  measure: promo_handle_fb_m {
    hidden: yes
    label: "Promo Handle Free Bet"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."PROMO_HANDLE_FB"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."PROMO_HANDLE_FB"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."PROMO_HANDLE_FB"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."PROMO_HANDLE_FB"
                    else ${TABLE}."PROMO_HANDLE_FB" end ;;
    # sql: ${TABLE}."PROMO_HANDLE_FB"  ;;
    value_format_name: usd
    group_label: "Bonuses and Promotions"
  }

  measure: promo_handle_ob_m {
    hidden: yes
    label: "Promo Handle Odds Boost"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."PROMO_HANDLE_OB"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."PROMO_HANDLE_OB"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."PROMO_HANDLE_OB"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."PROMO_HANDLE_OB"
                    else ${TABLE}."PROMO_HANDLE_OB" end ;;
    # sql: ${TABLE}."PROMO_HANDLE_OB"  ;;
    value_format_name: usd
    group_label: "Bonuses and Promotions"
  }

  measure: promo_handle_pb_m {
    hidden: yes
    label: "Promo Handle Profit Boost"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."PROMO_HANDLE_PB"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."PROMO_HANDLE_PB"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."PROMO_HANDLE_PB"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."PROMO_HANDLE_PB"
                    else ${TABLE}."PROMO_HANDLE_PB" end ;;
    # sql: ${TABLE}."PROMO_HANDLE_PB"  ;;
    value_format_name: usd
    group_label: "Bonuses and Promotions"
  }

  measure: promo_win_amount_total_m {
    hidden: yes
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."PROMO_WIN_AMOUNT_TOTAL"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."PROMO_WIN_AMOUNT_TOTAL"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."PROMO_WIN_AMOUNT_TOTAL"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."PROMO_WIN_AMOUNT_TOTAL"
                    else ${TABLE}."PROMO_WIN_AMOUNT_TOTAL" end ;;
    # sql:  ${TABLE}."PROMO_WIN_AMOUNT_TOTAL"  ;;
    value_format_name: usd
    group_label: "Bonuses and Promotions"
  }

  measure: promo_win_amount_fb_m {
    hidden: yes
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."PROMO_WIN_AMOUNT_FB"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."PROMO_WIN_AMOUNT_FB"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."PROMO_WIN_AMOUNT_FB"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."PROMO_WIN_AMOUNT_FB"
                    else ${TABLE}."PROMO_WIN_AMOUNT_FB" end ;;
    # sql:  ${TABLE}."PROMO_WIN_AMOUNT_FB"  ;;
    value_format_name: usd
    group_label: "Bonuses and Promotions"
  }

  measure: promo_win_amount_ob_m {
    hidden: yes
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."PROMO_WIN_AMOUNT_OB"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."PROMO_WIN_AMOUNT_OB"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."PROMO_WIN_AMOUNT_OB"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."PROMO_WIN_AMOUNT_OB"
                    else ${TABLE}."PROMO_WIN_AMOUNT_OB" end ;;
    # sql: ${TABLE}."PROMO_WIN_AMOUNT_OB"  ;;
    value_format_name: usd
    group_label: "Bonuses and Promotions"
  }

  measure: promo_win_amount_pb_m {
    hidden: yes
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."PROMO_WIN_AMOUNT_PB"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."PROMO_WIN_AMOUNT_PB"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."PROMO_WIN_AMOUNT_PB"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."PROMO_WIN_AMOUNT_PB"
                    else ${TABLE}."PROMO_WIN_AMOUNT_PB" end ;;
    # sql:  ${TABLE}."PROMO_WIN_AMOUNT_PB"  ;;
    value_format_name: usd
    group_label: "Bonuses and Promotions"
  }

  measure: promo_bonus_total_m {
    hidden: yes
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."PROMO_BONUS_TOTAL"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."PROMO_BONUS_TOTAL"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."PROMO_BONUS_TOTAL"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."PROMO_BONUS_TOTAL"
                    else ${TABLE}."PROMO_BONUS_TOTAL" end ;;
    # sql:  ${TABLE}."PROMO_BONUS_TOTAL"  ;;
    value_format_name: usd
    group_label: "Bonuses and Promotions"
  }

  measure: promo_bonus_pb_m {
    label: "Profit Boost Bonus Amount"
    # hidden: yes
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."PROMO_BONUS_PB"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."PROMO_BONUS_PB"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."PROMO_BONUS_PB"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."PROMO_BONUS_PB"
                    else ${TABLE}."PROMO_BONUS_PB" end ;;
    # sql: ${TABLE}."PROMO_BONUS_PB"  ;;
    value_format_name: usd
    group_label: "Bonuses and Promotions"
  }

  measure: promo_bonus_ob_m {
    label: "Odds Boost Bonus Amount"
    # hidden: yes
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."PROMO_BONUS_OB"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."PROMO_BONUS_OB"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."PROMO_BONUS_OB"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."PROMO_BONUS_OB"
                    else ${TABLE}."PROMO_BONUS_OB" end ;;
    # sql: ${TABLE}."PROMO_BONUS_OB"  ;;
    value_format_name: usd
    group_label: "Bonuses and Promotions"
  }

  measure: promo_bonus_fb_m {
    hidden: yes
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."PROMO_BONUS_FB"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."PROMO_BONUS_FB"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."PROMO_BONUS_FB"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."PROMO_BONUS_FB"
                    else ${TABLE}."PROMO_BONUS_FB" end ;;
    # sql: ${TABLE}."PROMO_BONUS_FB"  ;;
    value_format_name: usd
    group_label: "Bonuses and Promotions"
  }

  measure: total_sbp_unique_m {
    hidden: yes
    type: sum
    sql: ${TABLE}."TOTAL_SBP_UNIQUE" ;;
    group_label: "Bonuses and Promotions"
  }

  measure: fb_unique_m {
    hidden: yes
    type: sum
    sql: ${TABLE}."FB_UNIQUE" ;;
    group_label: "Bonuses and Promotions"
  }

  measure: pb_unique_m {
    hidden: yes
    type: sum
    sql: ${TABLE}."PB_UNIQUE" ;;
    group_label: "Bonuses and Promotions"
  }

  measure: ob_unique_m {
    hidden: yes
    type: sum
    sql: ${TABLE}."OB_UNIQUE" ;;
    group_label: "Bonuses and Promotions"
  }

  measure: promo_wins_m {
    hidden: yes
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."PROMO_WINS"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."PROMO_WINS"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."PROMO_WINS"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."PROMO_WINS"
                    else ${TABLE}."PROMO_WINS" end ;;
    # sql:  ${TABLE}."PROMO_WINS"  ;;
    value_format_name: usd
    group_label: "Bonuses and Promotions"
  }

  measure: promo_wins_fb_m {
    hidden: yes
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."PROMO_WINS_FB"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."PROMO_WINS_FB"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."PROMO_WINS_FB"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."PROMO_WINS_FB"
                    else ${TABLE}."PROMO_WINS_FB" end ;;
    # sql: ${TABLE}."PROMO_WINS_FB"  ;;
    value_format_name: usd
    group_label: "Bonuses and Promotions"
  }

  measure: promo_wins_ob_m {
    hidden: yes
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."PROMO_WINS_OB"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."PROMO_WINS_OB"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."PROMO_WINS_OB"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."PROMO_WINS_OB"
                    else ${TABLE}."PROMO_WINS_OB" end ;;
    # sql:  ${TABLE}."PROMO_WINS_OB"  ;;
    value_format_name: usd
    group_label: "Bonuses and Promotions"
  }

  measure: promo_wins_pb_m {
    hidden: yes
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."PROMO_WINS_PB"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."PROMO_WINS_PB"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."PROMO_WINS_PB"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."PROMO_WINS_PB"
                    else ${TABLE}."PROMO_WINS_PB" end ;;
          # sql: ${TABLE}."PROMO_WINS_PB"  ;;
    value_format_name: usd
    group_label: "Bonuses and Promotions"
  }

  measure: promo_lost_m {
    hidden: yes
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."PROMO_LOST"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."PROMO_LOST"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."PROMO_LOST"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."PROMO_LOST"
                    else ${TABLE}."PROMO_LOST" end ;;
    # sql: ${TABLE}."PROMO_LOST"  ;;
    value_format_name: usd
    group_label: "Bonuses and Promotions"
  }

  measure: promo_lost_fb_m {
    hidden: yes
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."PROMO_LOST_FB"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."PROMO_LOST_FB"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."PROMO_LOST_FB"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."PROMO_LOST_FB"
                    else ${TABLE}."PROMO_LOST_FB" end ;;
    # sql: ${TABLE}."PROMO_LOST_FB"  ;;
    value_format_name: usd
     group_label: "Bonuses and Promotions"
  }

  measure: promo_lost_ob_m {
    hidden: yes
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."PROMO_LOST_OB"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."PROMO_LOST_OB"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."PROMO_LOST_OB"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."PROMO_LOST_OB"
                    else ${TABLE}."PROMO_LOST_OB" end ;;
    # sql:  ${TABLE}."PROMO_LOST_OB"  ;;
    value_format_name: usd
    group_label: "Bonuses and Promotions"
  }

  measure: promo_lost_pb_m {
    hidden: yes
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."PROMO_LOST_PB"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."PROMO_LOST_PB"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."PROMO_LOST_PB"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."PROMO_LOST_PB"
                    else ${TABLE}."PROMO_LOST_PB" end ;;
    # sql: ${TABLE}."PROMO_LOST_PB"  ;;
    value_format_name: usd
    group_label: "Bonuses and Promotions"
  }

  measure: promo_voids_m {
    hidden: yes
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."PROMO_VOIDS"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."PROMO_VOIDS"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."PROMO_VOIDS"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."PROMO_VOIDS"
                    else ${TABLE}."PROMO_VOIDS" end ;;
    # sql:  ${TABLE}."PROMO_VOIDS"  ;;
    value_format_name: usd
    group_label: "Bonuses and Promotions"
  }

  measure: promo_voids_fb_m {
    hidden: yes
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."PROMO_VOIDS_FB"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."PROMO_VOIDS_FB"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."PROMO_VOIDS_FB"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."PROMO_VOIDS_FB"
                    else ${TABLE}."PROMO_VOIDS_FB" end ;;
    # sql: ${TABLE}."PROMO_VOIDS_FB"  ;;
    value_format_name: usd
    group_label: "Bonuses and Promotions"
  }

  measure: promo_voids_ob_m {
    hidden: yes
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."PROMO_VOIDS_OB"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."PROMO_VOIDS_OB"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."PROMO_VOIDS_OB"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."PROMO_VOIDS_OB"
                    else ${TABLE}."PROMO_VOIDS_OB" end ;;
    # sql: ${TABLE}."PROMO_VOIDS_OB"  ;;
    value_format_name: usd
    group_label: "Bonuses and Promotions"
  }

  measure: promo_voids_pb_m {
    hidden: yes
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."PROMO_VOIDS_PB"
    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."PROMO_VOIDS_PB"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."PROMO_VOIDS_PB"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."PROMO_VOIDS_PB"
                    else ${TABLE}."PROMO_VOIDS_PB" end ;;
    # sql: ${TABLE}."PROMO_VOIDS_PB"  ;;
    value_format_name: usd
    group_label: "Bonuses and Promotions"
  }

  measure: fb_issued_m {
    label: "Free Bets Issued"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."FB_ISSUED"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."FB_ISSUED"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."FB_ISSUED"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."FB_ISSUED"
                    else ${TABLE}."FB_ISSUED" end ;;
    # sql: ${TABLE}."FB_ISSUED"  ;;
    value_format_name: usd
    group_label: "Bonuses and Promotions"
  }

  measure: fb_completed_m {
    label: "Free Bets Completed"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."FB_COMPLETED"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."FB_COMPLETED"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."FB_COMPLETED"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."FB_COMPLETED"
                    else ${TABLE}."FB_COMPLETED" end ;;
    # sql: ${TABLE}."FB_COMPLETED"  ;;
    value_format_name: usd
    group_label: "Bonuses and Promotions"
  }

  measure: FB_WON_m {
    label: "Free Bets Won"
    type: sum
    sql: case when ${cage_code} = 57 and {% parameter colombia_conversion %} is not null then 1/{% parameter colombia_conversion %}*${TABLE}."FB_WON"
                    when ${cage_code} = 52 and {% parameter mexico_conversion %} is not null then 1/{% parameter mexico_conversion %}*${TABLE}."FB_WON"
                    when ${cage_code} = 249 and {% parameter canada_conversion %} is not null then 1/{% parameter canada_conversion %}*${TABLE}."FB_WON"
                    when ${cage_code} = 51 and {% parameter peru_conversion %} is not null then 1/{% parameter peru_conversion %}*${TABLE}."FB_WON"
                    else ${TABLE}."FB_WON" end ;;
    # sql:  ${TABLE}."FB_WON"  ;;
    value_format_name: usd
    group_label: "Bonuses and Promotions"
  }

  measure: distinct_players {
    type: count_distinct
    sql: ${player_id};;
  }

    measure: percent_fee_of_ngr {
    type: number
    value_format_name: percent_2
    sql: ${player_payments.total_payment_cost}/${ngr_m} ;;
  }

  measure: percent_fee_of_handle {
    type: number
    value_format_name: percent_4
    sql: ${player_payments.total_payment_cost}/${bet_amount_m} ;;
  }

  parameter: choose_breakdown {
    label: "Choose Grouping (Rows)"
    hidden: yes
    view_label: "Period over Period Comparison"
    type: unquoted
    default_value: "Month"
    allowed_value: {label: "Month Name" value:"Month"}
    allowed_value: {label: "Day of Month" value: "DOM"}
    allowed_value: {label: "Day of Week" value: "DOW"}
    allowed_value: {label: "Week" value: "Week"}
    allowed_value: {value: "Date"}
  }

  parameter: choose_comparison {
    label: "Choose Comparison (Pivot)"
    view_label: "Period over Period Comparison"
    type: unquoted
    default_value: "Month"
    allowed_value: {value: "Year" }
    allowed_value: {value: "Month"}
    allowed_value: {value: "Quarter"}
    allowed_value: {value: "Week"}
    allowed_value: {value: "Date"}
    allowed_value: {value: "DOY"}
  }

  dimension: PoP_Grouping  {
    view_label: "Period over Period Comparison"
    hidden: yes
    label_from_parameter: choose_breakdown
    type: string
    order_by_field: sort_by1
    sql:
        {% if choose_breakdown._parameter_value == 'Month' %} ${report_date_month}
        {% elsif choose_breakdown._parameter_value == 'DOM' %} ${report_date_day_of_month}
        {% elsif choose_breakdown._parameter_value == 'DOW' %} ${report_date_day_of_week}
        {% elsif choose_breakdown._parameter_value == 'Week' %} ${report_date_week}
        {% elsif choose_breakdown._parameter_value == 'Date' %} ${report_date_date}
        {% else %}NULL{% endif %} ;;
  }

  dimension: Date_Dimension {
    view_label: "Period over Period Comparison"
    label_from_parameter: choose_comparison
    type: string
    order_by_field: sort_by2
    sql:
        {% if choose_comparison._parameter_value == 'Year' %} ${report_date_year}
        {% elsif choose_comparison._parameter_value == 'Month' %} ${report_date_month}
        {% elsif choose_comparison._parameter_value == 'Quarter' %} ${report_date_quarter}
        {% elsif choose_comparison._parameter_value == 'Week' %} ${report_date_week}
        {% elsif choose_comparison._parameter_value == 'Date' %} ${report_date_date}
        {% elsif choose_comparison._parameter_value == 'DOY' %} ${report_date_day_of_year}
        {% else %}NULL{% endif %} ;;
  }

  dimension: sort_by1 {
    hidden: yes
    type: number
    sql:
        {% if choose_breakdown._parameter_value == 'Month' %} ${report_date_month}
        {% elsif choose_breakdown._parameter_value == 'DOM' %} ${report_date_day_of_month}
        {% elsif choose_breakdown._parameter_value == 'DOW' %} ${report_date_day_of_week}
        {% elsif choose_breakdown._parameter_value == 'Week' %} ${report_date_week}
        {% elsif choose_breakdown._parameter_value == 'Date' %} ${report_date_date}
        {% else %}NULL{% endif %} ;;
  }

  dimension: sort_by2 {
    hidden: yes
    type: string
    sql:
        {% if choose_comparison._parameter_value == 'Year' %} ${report_date_year}
        {% elsif choose_comparison._parameter_value == 'Month' %} ${report_date_month}
        {% elsif choose_comparison._parameter_value == 'Quarter' %} ${report_date_quarter}
        {% elsif choose_comparison._parameter_value == 'Week' %} ${report_date_week}
        {% elsif choose_comparison._parameter_value == 'Date' %} ${report_date_date}
        {% elsif choose_comparison._parameter_value == 'DOY' %} ${report_date_day_of_year}
        {% else %}NULL{% endif %} ;;
  }

  ################################### POKER #########################################################

  measure: poker_uniques {
    type: count_distinct
    group_label: "Game Play: Poker"
    sql: case when ${TABLE}."PK_CASH_GAME_TABLES"+ ${TABLE}."PK_TOURNAMENTS_PLAYED">0 THEN ${player_id} end ;;
  }

  measure: cash_game_uniques {
    type: count_distinct
    group_label:"Game Play: Poker"
    sql: case when ${TABLE}."PK_CASH_GAME_TABLES">0 THEN ${player_id} end  ;;
  }

  measure: tournament_uniques {
    type: count_distinct
    group_label: "Game Play: Poker"
    sql: case when ${TABLE}."PK_TOURNAMENT_BUYINS">0 THEN ${player_id} end  ;;
  }

  measure: sng_uniques {
    type: count_distinct
    group_label: "Game Play: Poker"
    sql: case when ${TABLE}."PK_TOTAL_SNG_BUYINS">0 THEN ${player_id} end  ;;
  }

  measure: mtt_uniques {
    type: count_distinct
    group_label: "Game Play: Poker"
    sql: case when ${TABLE}."PK_TOTAL_MTT_BUYINS">0 THEN ${player_id} end ;;
  }


  measure: cash_game_tables {
    label: "Table Seats"
    type: sum
    group_label:"Game Play: Poker"
    sql: ${TABLE}."PK_CASH_GAME_TABLES" ;;
  }

  measure: cash_game_hands {
    type: sum
    group_label: "Game Play: Poker"
    sql: ${TABLE}."PK_CASH_GAME_HANDS" ;;
  }

  measure: cash_game_bet_amount {
    type: sum
    group_label: "Game Play: Poker"
    sql: ${TABLE}."PK_CASH_GAME_BET_AMOUNT" ;;
    value_format_name: usd
  }

  measure: cash_game_win_amount {
    type: sum
    group_label: "Game Play: Poker"
    sql: ${TABLE}."PK_CASH_GAME_WIN_AMOUNT" ;;
    value_format_name: usd
  }

  measure: cash_game_rake {
    type: sum
    group_label :"Game Play: Poker"
    sql: ${TABLE}."PK_CASH_GAME_RAKE" ;;
    value_format_name: usd
  }


  measure: cash_game_rake_adj {
    type: sum
    group_label :"Game Play: Poker"
    sql: ${TABLE}."PK_CASH_GAME_RAKE_ADJ" ;;
    value_format_name: usd
  }

  measure: tournament_buyins {
    type: sum
    group_label: "Game Play: Poker"
    sql: ${TABLE}."PK_TOURNAMENT_BUYINS" ;;
  }

  measure: tournament_win_amount {
    type: sum
    group_label: "Game Play: Poker"
    sql: ${TABLE}."PK_TOURNAMENT_WIN_AMOUNT" ;;
    value_format_name: usd
  }

  measure: tournament_buyin_amount {
    type: sum
    group_label: "Game Play: Poker"
    sql: ${TABLE}."PK_TOURNAMENT_BUYIN_AMOUNT" ;;
    value_format_name: usd
  }

  measure: tournament_cash_buyin_amount {
    type: sum
    group_label: "Game Play: Poker"
    sql: ${TABLE}."PK_TOURNAMENT_cash_BUYIN_AMOUNT" ;;
    value_format_name: usd
  }

  measure: tournament_ticket_buyin_amount {
    type: sum
    group_label: "Game Play: Poker"
    sql: ${TABLE}."PK_TOURNAMENT_TICKET_BUYIN_AMOUNT"  ;;
    value_format_name: usd
  }

  measure: PK_TICKET_PROMOTIONAL_CREDITS {
    label: "Poker Promotional Credits"
    type: sum
    group_label: "Game Play: Poker"
    sql: ${TABLE}."PK_TICKET_PROMOTIONAL_CREDITS"  ;;
    value_format_name: usd
  }


  measure: tournament_rake {
    type: sum
    group_label: "Game Play: Poker"
    sql: ${TABLE}."PK_TOURNAMENT_RAKE" ;;
    value_format_name: usd
  }

  measure: total_sng_buyins {
    label: "SNG Buyins"
    type: sum
    group_label: "Game Play: Poker"
    sql: ${TABLE}."PK_TOTAL_SNG_BUYINS" ;;
  }

  measure: total_sng_win_amount {
    label: "SNG Win Amount"
    type: sum
    group_label:"Game Play: Poker"
    sql: ${TABLE}."PK_TOTAL_SNG_WIN_AMOUNT" ;;
    value_format_name: usd
  }

  measure: total_sng_buyin_amount {
    label: "SNG Buyin Amount"
    type: sum
    group_label:"Game Play: Poker"
    sql: ${TABLE}."PK_TOTAL_SNG_BUYIN_AMOUNT";;
    value_format_name: usd
  }

  measure: total_sng_cash_buyin_amount {
    label: "SNG Cash Buyin Amount"
    type: sum
    group_label:"Game Play: Poker"
    sql: ${TABLE}."PK_TOTAL_SNG_cash_BUYIN_AMOUNT" ;;
    value_format_name: usd
  }

  measure: total_sng_ticket_buyin_amount {
    label: "SNG Ticket Buyin Amount"
    type: sum
    group_label:"Game Play: Poker"
    sql: ${TABLE}."PK_sng_TOURNAMENT_TICKET_BUYIN_AMOUNT" ;;
    value_format_name: usd
  }

  measure: PK_SNG_TICKET_PROMOTIONAL_CREDITS {
    label: "SNG Ticket Promotional Credits"
    type: sum
    group_label:"Game Play: Poker"
    sql: ${TABLE}."PK_SNG_TICKET_PROMOTIONAL_CREDITS";;
    value_format_name: usd
  }

  measure: total_sng_rake {
    label: "SNG Rake"
    type: sum
    group_label:"Game Play: Poker"
    sql: ${TABLE}."PK_TOTAL_SNG_RAKE" ;;
    value_format_name: usd
  }

  measure: total_mtt_buyins {
    label: "MTT Buyins"
    type: sum
    group_label:"Game Play: Poker"
    sql: ${TABLE}."PK_TOTAL_MTT_BUYINS" ;;
  }

  measure: total_mtt_win_amount {
    label: "MTT Win Amount"
    type: sum
    group_label:"Game Play: Poker"
    sql: ${TABLE}."PK_TOTAL_MTT_WIN_AMOUNT" ;;
    value_format_name: usd
  }

  measure: total_mtt_buyin_amount {
    label: "MTT Buyin Amount"
    type: sum
    group_label:"Game Play: Poker"
    sql: ${TABLE}."PK_TOTAL_MTT_BUYIN_AMOUNT" ;;
    value_format_name: usd
  }

  measure: total_mtt_cash_buyin_amount {
    label: "MTT Cash Buyin Amount"
    type: sum
    group_label:"Game Play: Poker"
    sql: ${TABLE}."PK_TOTAL_MTT_cash_BUYIN_AMOUNT" ;;
    value_format_name: usd
  }

  measure: total_MTT_ticket_buyin_amount {
    label: "MTT Ticket Buyin Amount"
    type: sum
    group_label:"Game Play: Poker"
    sql: ${TABLE}."PK_MTT_TOURNAMENT_TICKET_BUYIN_AMOUNT";;
    value_format_name: usd
  }

  measure: PK_mtt_TICKET_PROMOTIONAL_CREDITS {
    label: "MTT Ticket Promotional Credits"
    type: sum
    group_label:"Game Play: Poker"
    sql: ${TABLE}."PK_mtt_TICKET_PROMOTIONAL_CREDITS";;
    value_format_name: usd
  }

  measure: total_mtt_rake {
    label: "MTT Rake"
    type: sum
    group_label:"Game Play: Poker"
    sql: ${TABLE}."PK_TOTAL_MTT_RAKE" ;;
    value_format_name: usd
  }

  measure: total_rake {
    type: sum
    group_label:"Game Play: Poker"
    sql: ${TABLE}."PK_TOTAL_RAKE" ;;
    value_format_name: usd
  }

  measure: overlay {
    type: sum
    group_label:"Game Play: Poker"
    sql: ${TABLE}."PK_OVERLAY" ;;
    value_format_name: usd
  }


  measure: poker_cash_release {
    type: sum
    group_label:"Game Play: Poker"
    sql: ${TABLE}."PK_CASH_RELEASE" ;;
    value_format_name: usd
  }


  measure: poker_revenue {
    type: sum
    group_label:"Game Play: Poker"
    sql: ${TABLE}."POKER_REVENUE";;
    value_format_name: usd
    }


# dimension_group: first_poker_date {
# type: time
# sql: ${TABLE}."first_poker_date" ;;
# }




  set: detail {
    fields: [
      cage_player_id,
      cage_code,
      site_code,
      vip_level,
      registrations,
      passed_registrations,
      kyc_registrations,
      ftds,
      depositors,
      deposits,
      deposit_amount,
      withdrawers,
      withdrawals,
      withdrawal_amount,
      net_deposits,
      _bets,
      bet_amount,
      bonus_bet_amount,
      real_bet_amount,
      win_amount,
      ggr,
      ngr,
      rtp,
      _casino_bets,
      casino_uniques,
      casino_bet_amount,
      casino_bonus_bet_amount,
      casino_real_bet_amount,
      casino_win_amount,
      casino_ggr,
      casino_rtp,
      _sbook_bets,
      sbook_uniques,
      sbook_bet_amount,
      sbook_bonus_bet_amount,
      sbook_real_bet_amount,
      sbook_win_amount,
      sbook_ggr,
      sbook_rtp,
      slots_uniques,
      slots_bet_amount,
      slots_bonus_bet_amount,
      slots_real_bet_amount,
      slots_win_amount,
      slots_ggr,
      slots_rtp,
      table_uniques,
      table_bet_amount,
      table_bonus_bet_amount,
      table_real_bet_amount,
      table_win_amount,
      table_ggr,
      table_rtp,
      livedealer_uniques,
      livedealer_bet_amount,
      livedealer_bonus_bet_amount,
      livedealer_real_bet_amount,
      livedealer_win_amount,
      livedealer_ggr,
      livedealer_rtp,
      bonus_money_issued,
      adjustments,
      casino_adjustments,
      sbook_adjustments,
      slots_adjustments,
      table_adjustments,
      livedealer_adjustments,
      outstanding_fb_amount,
      in_use_fb_amount,
      promo_handle_total,
      promo_handle_fb,
      promo_handle_ob,
      promo_handle_pb,
      promo_win_amount_total,
      promo_win_amount_fb,
      promo_win_amount_ob,
      promo_win_amount_pb,
      promo_bonus_total,
      promo_bonus_pb,
      promo_bonus_ob,
      promo_bonus_fb,
      total_sbp_unique,
      fb_unique,
      pb_unique,
      ob_unique,
      promo_wins,
      promo_wins_fb,
      promo_wins_ob,
      promo_wins_pb,
      promo_lost,
      promo_lost_fb,
      promo_lost_ob,
      promo_lost_pb,
      promo_voids,
      promo_voids_fb,
      promo_voids_ob,
      promo_voids_pb
    ]
  }
}
