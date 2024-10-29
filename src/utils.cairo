use cairo_arena::models::Arena::{BattleAction, Direction, ArenaCharacter, Position};
use cairo_arena::constants::{
    AGI_INITIATIVE_MODIFIER, QUICK_ATC_INI, PRECISE_ATC_INI, HEAVY_ATC_INI, MOVE_INI, REST_INI,
    QUICK_HIT_CHANCE, PRECISE_HIT_CHANCE, HEAVY_HIT_CHANCE, REST_RECOVERY,
    QUICK_ATC_DAMAGE, PRECISE_ATC_DAMAGE, HEAVY_ATC_DAMAGE, QUICK_ATC_ENERGY, PRECISE_ATC_ENERGY,
    HEAVY_ATC_ENERGY, GRID_WIDTH, GRID_HEIGHT
};
use traits::{Into};


fn calculate_initiative(action: BattleAction, agility: u8) -> u8 {
    let modifier = agility + agility * AGI_INITIATIVE_MODIFIER / 100;
    let mut result = 0;
    match action {
        BattleAction::QuickAttack => {
            if QUICK_ATC_INI > modifier {
                result = QUICK_ATC_INI - modifier;
            } else {
                result = 0;
            }
        },
        BattleAction::PreciseAttack => {
            if PRECISE_ATC_INI > modifier {
                result = PRECISE_ATC_INI - modifier;
            } else {
                result = 0;
            }
        },
        BattleAction::HeavyAttack => {
            if HEAVY_ATC_INI > modifier {
                result = HEAVY_ATC_INI - modifier;
            } else {
                result = 0;
            }
        },
        BattleAction::Move => {
            if MOVE_INI > modifier {
                result = MOVE_INI - modifier;
            } else {
                result = 0;
            }
        },
        BattleAction::Rest => {
            if REST_INI > modifier {
                result = REST_INI - modifier;
            } else {
                result = 0;
            }
        },
    };

    result
}



fn get_gain_xp(level: u8) -> u32 {
    if level == 0 {
        300
    } else if level == 1 {
        600
    } else if level == 2 {
        600
    } else if level == 3 {
        1350
    } else if level == 4 {
        3240
    } else if level == 5 {
        8100
    } else if level == 6 {
        18225
    } else if level == 7 {
        48600
    } else if level == 8 {
        131220
    } else if level == 9 {
        328050
    } else {
        0
    }
}

fn get_level_xp(level: u8) -> u32 {
    if level == 0 {
        300
    } else if level == 1 {
        600
    } else if level == 2 {
        1800
    } else if level == 3 {
        5400
    } else if level == 4 {
        16200
    } else if level == 5 {
        48600
    } else if level == 6 {
        145800
    } else if level == 7 {
        437400
    } else if level == 8 {
        1312200
    } else if level == 9 {
        3936600
    } else {
        2147483647
    }
}

fn ratio(num: u8, deno: u8) -> bool {
    let tx = starknet::get_tx_info().unbox().transaction_hash;
    let seed: u256 = tx.into();

    let result = seed.low % deno.into() + 1;
    if result <= num.into() {
        true
    } else {
        false
    }
}

fn attack(ref c: ArenaCharacter, ref c1: ArenaCharacter, hit_chance: u8, damage_base: u32, ref arenaGrid: Felt252Dict<u8>) -> u8 {
    let mut fail_reason = 0;
    let is_hit = ratio(hit_chance + 2 * (c.attributes.agility).into(), 100);
    if is_hit {
        let damage = c.attributes.strength.into() * 2 + damage_base;
        if c1.hp > damage {
            c1.hp -= damage;
        } else {
            c1.hp = 0;
            arenaGrid.insert((c1.position.x + c1.position.y * GRID_HEIGHT).into(), 0);
        }
    } else {
        fail_reason = 2;
    }

    fail_reason
}

fn execute_action(
    ref c: ArenaCharacter,
    ref c1: ArenaCharacter,
    ref c2: ArenaCharacter,
    ref c3: ArenaCharacter,
    ref c4: ArenaCharacter,
    ref c5: ArenaCharacter,
    ref arenaGrid: Felt252Dict<u8>
) -> (u8, u8) {
    let target_pos = match c.direction {
        Direction::Up => {
            if c.position.y < GRID_HEIGHT - 1 {
                Position { x: c.position.x, y: c.position.y + 1 }
            } else {
                Position { x: c.position.x, y: c.position.y }
            }
        },
        Direction::Down => {
            if c.position.y > 0 {
                Position { x: c.position.x, y: c.position.y - 1 }
            } else {
                Position { x: c.position.x, y: c.position.y }
            }
        },
        Direction::Right => {
            if c.position.x < GRID_WIDTH - 1 {
                Position { x: c.position.x + 1, y: c.position.y }
            } else {
                Position { x: c.position.x, y: c.position.y }
            }
        },
        Direction::Left => {
            if c.position.x > 0 {
                Position { x: c.position.x - 1, y: c.position.y }
            } else {
                Position { x: c.position.x, y: c.position.y }
            }
        },
    };

    // 1: lack of energy, 2: reflect
    let mut fail_reason: u8 = 0;
    let mut target_cid: u8 = 0;

    // println!("action: {:?}", c.action);

    let mut energy_cost = 0;
    let mut hit_chance = 0;
    let mut damage_base = 0;
    match c.action {
        BattleAction::QuickAttack => {
            energy_cost = QUICK_ATC_ENERGY;
            hit_chance = QUICK_HIT_CHANCE;
            damage_base = QUICK_ATC_DAMAGE;
        },
        BattleAction::PreciseAttack => {
            energy_cost = PRECISE_ATC_ENERGY;
            hit_chance = PRECISE_HIT_CHANCE;
            damage_base = PRECISE_ATC_DAMAGE;
        },
        BattleAction::HeavyAttack => {
            energy_cost = HEAVY_ATC_ENERGY;
            hit_chance = HEAVY_HIT_CHANCE;
            damage_base = HEAVY_ATC_DAMAGE;
        },
        BattleAction::Move => {
            if c.energy >= 1 {
                c.energy -= 1;

                if c.position.x != target_pos.x || c.position.y != target_pos.y { 
                    let grid = target_pos.x + target_pos.y * GRID_HEIGHT;
                    target_cid = arenaGrid.get(grid.into());
                    if target_cid == 0 {
                        arenaGrid.insert((c.position.x + c.position.y * GRID_HEIGHT).into(), 0);
                        arenaGrid.insert(grid.into(), c.cid);
                        c.position = target_pos;
                    }
                }
            } else {
                fail_reason = 1;
            }
        },
        BattleAction::Rest => {
            if c.consecutive_rest_count > 1 {
                let rest_penalty = (c.consecutive_rest_count * (c.consecutive_rest_count - 1)).into();
                if rest_penalty < REST_RECOVERY {
                    c.energy += REST_RECOVERY - rest_penalty;
                }
            } else {
                c.energy += REST_RECOVERY;
            }
            c.consecutive_rest_count += 1;
        },
    };

    if c.action != BattleAction::Rest {
        c.consecutive_rest_count = 0;
    }

    if c.action == BattleAction::QuickAttack || c.action == BattleAction::PreciseAttack || c.action == BattleAction::HeavyAttack {
        if c.energy >= energy_cost {
            c.energy -= energy_cost;

            if c.position.x != target_pos.x || c.position.y != target_pos.y {
                let grid = target_pos.x + target_pos.y * GRID_HEIGHT;
                target_cid = arenaGrid.get(grid.into());
                if target_cid != 0 {
                    if target_cid == c1.cid {
                        fail_reason = attack(ref c, ref c1, hit_chance, damage_base, ref arenaGrid);
                    } else if target_cid == c2.cid {
                        fail_reason = attack(ref c, ref c2, hit_chance, damage_base, ref arenaGrid);
                    } else if target_cid == c3.cid {
                        fail_reason = attack(ref c, ref c3, hit_chance, damage_base, ref arenaGrid);
                    } else if target_cid == c4.cid {
                        fail_reason = attack(ref c, ref c4, hit_chance, damage_base, ref arenaGrid);
                    } else if target_cid == c5.cid {
                        fail_reason = attack(ref c, ref c5, hit_chance, damage_base, ref arenaGrid);
                    }
                }
            }
        } else {
            fail_reason = 1;
        }
    }

    (fail_reason, target_cid)
}

// fn mirror_ation_to_int(action: BattleAction) -> u32 {
//     let i = match action {
//         BattleAction::QuickAttack => { 1 },
//         BattleAction::PreciseAttack => { 2 },
//         BattleAction::HeavyAttack => { 3 },
//         BattleAction::MoveRight => { 4 },
//         BattleAction::MoveLeft => { 5 },
//         BattleAction::MoveUp => { 6 },
//         BattleAction::MoveDown => { 7 },
//         BattleAction::Rest => { 8 },
//     };

//     i
// }


// fn new_pos_and_hit(
//     attacker_pos: u32, defender_pos: u32, attacker_agility: u32, chance: u128
// ) -> (u32, bool) {
//     let attacker_avaiable_move = get_movement(attacker_agility);

//     let mut new_attacker_pos: u32 = attacker_pos;
//     let mut is_near: bool = false;
//     if attacker_pos < defender_pos {
//         if attacker_pos + attacker_avaiable_move >= defender_pos - 1 {
//             new_attacker_pos = defender_pos - 1;
//             is_near = true;
//         } else {
//             new_attacker_pos = attacker_pos + attacker_avaiable_move;
//         }
//     } else {
//         if attacker_pos > attacker_avaiable_move {
//             if attacker_pos - attacker_avaiable_move <= defender_pos + 1 {
//                 new_attacker_pos = defender_pos + 1;
//                 is_near = true;
//             } else {
//                 new_attacker_pos = attacker_pos - attacker_avaiable_move;
//             }
//         } else {
//             new_attacker_pos = defender_pos + 1;
//             is_near = true;
//         }
//     }
//     if !is_near {
//         (new_attacker_pos, false)
//     } else {
//         let is_hit = ratio(chance + 2 * (attacker_agility).into(), 100);
//         (new_attacker_pos, is_hit)
//     }
// }

// fn new_pos_and_steps(
//     direction: Direction, attacker_pos: u32, defender_pos: u32, attacker_agility: u32
// ) -> (u32, u32) {
//     let attacker_avaiable_move = get_movement(attacker_agility);

//     let mut new_pos: u32 = attacker_pos;
//     let mut steps: u32 = 0;

//     match direction {
//         Direction::Right => {
//             if attacker_pos < defender_pos {
//                 if attacker_pos + attacker_avaiable_move >= defender_pos - 1 {
//                     new_pos = defender_pos - 1;
//                     steps = defender_pos - attacker_pos - 1
//                 } else {
//                     new_pos = attacker_pos + attacker_avaiable_move;
//                     steps = attacker_avaiable_move;
//                 }
//             } else {
//                 if attacker_pos + attacker_avaiable_move >= RANGE_POS {
//                     new_pos = RANGE_POS;
//                     steps = RANGE_POS - attacker_pos;
//                 } else {
//                     new_pos = attacker_pos + attacker_avaiable_move;
//                     steps = attacker_avaiable_move;
//                 }
//             }
//         },
//         Direction::Left => {
//             if attacker_pos > defender_pos {
//                 if attacker_pos - attacker_avaiable_move <= defender_pos + 1 {
//                     new_pos = defender_pos + 1;
//                     steps = attacker_pos - defender_pos - 1;
//                 } else {
//                     new_pos = attacker_pos - attacker_avaiable_move;
//                     steps = attacker_avaiable_move;
//                 }
//             } else {
//                 if attacker_pos <= attacker_avaiable_move {
//                     new_pos = 1;
//                     steps = attacker_pos - 1;
//                 } else {
//                     new_pos = attacker_pos - attacker_avaiable_move;
//                     steps = attacker_avaiable_move;
//                 }
//             }
//         },
//     };

//     (new_pos, steps)
// }


// fn get_movement(agility: u32) -> u32 {
//     if agility >= 1 && agility <= 2 {
//         1
//     } else if agility >= 3 && agility <= 4 {
//         2
//     } else if agility >= 5 && agility <= 6 {
//         3
//     } else if agility >= 7 && agility <= 8 {
//         4
//     } else if agility == 9 {
//         5
//     } else {
//         0
//     }
// }