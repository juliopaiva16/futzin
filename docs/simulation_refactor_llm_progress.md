## REFRACTOR_STATE_V1
version: 1
generated_utc: 2025-08-10T00:00:00Z

# NOTE: Machine-oriented hierarchical snapshot for LLM consumption.
# Each node carries: id, status(TODO|DOING|TUNE|DONE|HOLD), deps[], metrics_if_applicable, notes.

root:
  id: graph_engine_refactor
  status: DOING
  phases:
    - id: phase1_roles_coords
      status: DONE
      delivered: [role_enum, player.role, coord_assignment]
    - id: phase2_basic_micro_engine
      status: DONE
      delivered: [short_pass_selection, simple_shot, flag_switch]
    - id: phase3_weighted_edges_intercepts
      status: DONE
      delivered: [congestion_penalty, multi_def_intercept_v2]
    - id: phase4_extended_actions
      status: TUNE
      delivered: [dribble,long_pass,back_pass,hold,launch,adaptive_boost]
    - id: phase5_abilities_core
      status: TUNE
      delivered: [VIS,PAS,DRB,FIN,WALL,CAT,CAP,ENG]
      pending: [MRK,AER,REF,COM,HDR,CLT,SPR]
    - id: phase6_stamina_model
      status: TUNE
      delivered: [variable_decay_split,ENG_variable_reduction]
      pending: [position_decay_modulators, sprint_cost_hook]
    - id: phase7_momentum_xg_alignment
      status: TODO
    - id: phase8_ui_flag_toggle
      status: DONE
    - id: phase9_legacy_deprecation
      status: TODO

macro_topics:
  - id: MT1_event_instrumentation
    status: DOING
    goal: structured JSONL for every action/possession
    fields: [matchId,minute,possId,actionIndex,actionType,fromId,toId,fromX,fromY,toX,toY,preXg,xgDelta,isShot,isGoal,pressureScore,passDist]
    metrics_enabled: [seq_length,progressive_pass_rate,ppda,shot_distance_hist]
    implemented: [logger_file,engine_hooks,poss_counter,pressure_score_calc,distance_bins_metric_extractor,summary_batch_script]
    next: []
  - id: MT2_player_generation_enhancement
  status: DOING
  additions: [height_cm,preferred_foot,tier,correlated_attributes]
  delivered: [height_cm,preferred_foot,tier,correlated_attributes]
  pending: []
  - id: MT3_shot_volume_controls
  status: DOING
  levers: [fallback_shot,post_dribble_shot_chance,forced_shot_stagnation]
  implemented: [post_dribble_dynamic_prob,fallback_forced_shot,stagnation_trigger]
  - id: MT4_pass_success_tuning
    status: TODO
    target_range: [0.75,0.82]
    params: [graphInterceptBase,graphInterceptDefenseFactor,graphMultiInterceptMaxV2,graphAbilityVisInterceptRel,graphAbilityPasShortRel]
  - id: MT5_xg_model_multifeature
    status: TODO
    features: [distance,angle,assist_type,pressure,body_part]
    outputs: [xg_raw,shot_quality_adjusted]
  - id: MT6_set_pieces_basic
    status: TODO
    events: [corner,fk_direct,fk_cross,throw_in_high]
    abilities_hooks: [HDR,AER,MRK]
  - id: MT7_transitions_counterattack
    status: TODO
    trigger: intercept_in_final_third
    effect: early_shot_boost_temporal
  - id: MT8_dynamic_tactics_gamestate
    status: TODO
    inputs: [score_diff,minute,card_state]
    adjustments: [attackBias_delta,pressing_delta,tempo_delta]
  - id: MT9_advanced_abilities_remaining
    status: TODO
    mapping:
      MRK: intercept_rel_boost_vs_dribble
      HDR: shot_xg_add_if_header_context
      AER: gk_save_cross_modifier
      REF: gk_reaction_pGoal_reduction
      COM: gk_error_rate_reduction
      CLT: late_game_pGoal_rel_boost
      SPR: dribble_pace_component_rel
  - id: MT10_stamina_micro_events
    status: TODO
    micro_costs: [sprint,dribble_attempt,press_action,long_pass,launch]
  - id: MT11_value_models_xt_xtThreat
    status: TODO
    grid: 12x8
    metric: xT_delta_per_action
  - id: MT12_calibration_pipeline
    status: TODO
    steps: [batch_run,metric_extract,divergence_score,report_md]
  - id: MT13_testing_suite_expansion
    status: TODO
    tests: [dribble_vs_mrk,fin_calibration,intercept_monotonicity,prob_calibration_ece,stamina_eng_gap]
  - id: MT14_logging_modes
    status: TODO
    modes: [summary,detailed,off]
  - id: MT15_performance_optimizations
    status: TODO
    strategies: [edge_cache_dirty_flags,batched_logging_flush,alloc_reuse]

metrics_targets:
  shot_volume_avg: 22
  pass_success_range: [0.75,0.82]
  dribble_attempts_range: [10,20]
  dribble_success_range: [0.45,0.60]
  xg_total_range: [2.4,3.2]
  goals_total_range: [2.4,3.2]
  stamina_eng_reduction_rel: 0.15
  header_shot_share_target: 0.07

open_questions:
  - intercept_scaling_vs_pressing_overlap
  - mapping_event_to_real_pass_count
  - penalty_for_repeated_dribbles_same_lane

next_batch_priority_order: [MT1_event_instrumentation,MT2_player_generation_enhancement,MT3_shot_volume_controls,MT4_pass_success_tuning,MT5_xg_model_multifeature]
