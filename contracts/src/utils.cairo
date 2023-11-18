use dojo_arena::models::io::{CharacterState, BattleAction, Direction};
use dojo_arena::actions::{
    AGI_INITIATIVE_MODIFIER, QUICK_ATC_INI, PRECISE_ATC_INI, HEAVY_ATC_INI, MOVE_INI, REST_INI,
    RANGE_POS, QUICK_HIT_CHANCE, PRECISE_HIT_CHANCE, HEAVY_HIT_CHANCE, REST_RECOVERY,
    QUICK_ATC_DAMAGE, PRECISE_ATC_DAMAGE, HEAVY_ATC_DAMAGE, QUICK_ATC_ENERGY, PRECISE_ATC_ENERGY,
    HEAVY_ATC_ENERGY
};
use traits::{Into};
use dojo_arena::models::{ArenaCharacter};


fn determin_action(my_state: CharacterState, opponent_state: CharacterState) -> BattleAction {
    //TODO: action logic
    BattleAction::QuickAttack
}

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
        BattleAction::MoveRight => {
            if MOVE_INI > modifier {
                result = MOVE_INI - modifier;
            } else {
                result = 0;
            }
        },
        BattleAction::MoveLeft => {
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

fn get_movement(agility: u8) -> u8 {
    if agility >= 1 && agility <= 2 {
        1
    } else if agility >= 3 && agility <= 4 {
        2
    } else if agility >= 5 && agility <= 6 {
        3
    } else if agility >= 7 && agility <= 8 {
        4
    } else if agility == 9 {
        5
    } else {
        0
    }
}

fn new_pos_and_hit(
    attacker_pos: u8, defender_pos: u8, attacker_agility: u8, chance: u128
) -> (u8, bool) {
    let attacker_avaiable_move = get_movement(attacker_agility);

    let mut new_attacker_pos: u8 = attacker_pos;
    let mut is_near: bool = false;
    if attacker_pos < defender_pos {
        if attacker_pos + attacker_avaiable_move >= defender_pos - 1 {
            new_attacker_pos = defender_pos - 1;
            is_near = true;
        } else {
            new_attacker_pos = attacker_pos + attacker_avaiable_move;
        }
    } else {
        if attacker_pos > attacker_avaiable_move {
            if attacker_pos - attacker_avaiable_move <= defender_pos + 1 {
                new_attacker_pos = defender_pos + 1;
                is_near = true;
            } else {
                new_attacker_pos = attacker_pos - attacker_avaiable_move;
            }
        } else {
            new_attacker_pos = defender_pos + 1;
            is_near = true;
        }
    }
    if !is_near {
        (new_attacker_pos, false)
    } else {
        let is_hit = ratio(chance + 2 * (attacker_agility).into(), 100);
        (new_attacker_pos, is_hit)
    }
}

fn ratio(num: u128, deno: u128) -> bool {
    let tx = starknet::get_tx_info().unbox().transaction_hash;
    let seed: u256 = tx.into();

    let result = seed.low % deno + 1;
    if result <= num {
        true
    } else {
        false
    }
}

fn new_pos_and_steps(
    direction: Direction, attacker_pos: u8, defender_pos: u8, attacker_agility: u8
) -> (u8, u8) {
    let attacker_avaiable_move = get_movement(attacker_agility);

    let mut new_pos: u8 = attacker_pos;
    let mut steps: u8 = 0;

    match direction {
        Direction::Right => {
            if attacker_pos < defender_pos {
                if attacker_pos + attacker_avaiable_move >= defender_pos - 1 {
                    new_pos = defender_pos - 1;
                    steps = defender_pos - attacker_pos - 1
                } else {
                    new_pos = attacker_pos + attacker_avaiable_move;
                    steps = attacker_avaiable_move;
                }
            } else {
                if attacker_pos + attacker_avaiable_move >= RANGE_POS {
                    new_pos = RANGE_POS;
                    steps = RANGE_POS - attacker_pos;
                } else {
                    new_pos = attacker_pos + attacker_avaiable_move;
                    steps = attacker_avaiable_move;
                }
            }
        },
        Direction::Left => {
            if attacker_pos > defender_pos {
                if attacker_pos - attacker_avaiable_move <= defender_pos + 1 {
                    new_pos = defender_pos + 1;
                    steps = attacker_pos - defender_pos - 1;
                } else {
                    new_pos = attacker_pos - attacker_avaiable_move;
                    steps = attacker_avaiable_move;
                }
            } else {
                if attacker_pos <= attacker_avaiable_move {
                    new_pos = 1;
                    steps = attacker_pos - 1;
                } else {
                    new_pos = attacker_pos - attacker_avaiable_move;
                    steps = attacker_avaiable_move;
                }
            }
        },
    };

    (new_pos, steps)
}

fn execute_action(
    action: BattleAction,
    ref c1_state: CharacterState,
    ref c2_state: CharacterState,
    c1: @ArenaCharacter,
    c2: @ArenaCharacter,
) {
    match action {
        BattleAction::QuickAttack => {
            if c1_state.energy >= QUICK_ATC_ENERGY {
                c1_state.energy -= QUICK_ATC_ENERGY;
                let (new_pos, is_hit) = new_pos_and_hit(
                    c1_state.position, c2_state.position, *c1.attributes.agility, QUICK_HIT_CHANCE
                );
                c1_state.position = new_pos;
                if is_hit {
                    let damage = *c1.attributes.strength * 2_u8 + QUICK_ATC_DAMAGE;
                    if c2_state.hp > damage {
                        c2_state.hp -= damage;
                    } else {
                        c2_state.hp = 0;
                    }
                }
            }
        },
        BattleAction::PreciseAttack => {
            if c1_state.energy >= PRECISE_ATC_ENERGY {
                c1_state.energy -= PRECISE_ATC_ENERGY;
                let (new_pos, is_hit) = new_pos_and_hit(
                    c1_state.position, c2_state.position, *c1.attributes.agility, PRECISE_HIT_CHANCE
                );
                c1_state.position = new_pos;
                if is_hit {
                    let damage = *c1.attributes.strength * 3 + PRECISE_ATC_DAMAGE;
                    if c2_state.hp > damage {
                        c2_state.hp -= damage;
                    } else {
                        c2_state.hp = 0;
                    }
                }
            }
        },
        BattleAction::HeavyAttack => {
            if c1_state.energy >= HEAVY_ATC_ENERGY {
                c1_state.energy -= HEAVY_ATC_ENERGY;
                let (new_pos, is_hit) = new_pos_and_hit(
                    c1_state.position, c2_state.position, *c1.attributes.agility, HEAVY_HIT_CHANCE
                );
                c1_state.position = new_pos;
                if is_hit {
                    let damage = *c1.attributes.strength * 4_u8 + HEAVY_ATC_DAMAGE;
                    if c2_state.hp > damage {
                        c2_state.hp -= damage;
                    } else {
                        c2_state.hp = 0;
                    }
                }
            }
        },
        BattleAction::MoveRight => {
            let (new_pos, steps) = new_pos_and_steps(
                Direction::Right, c1_state.position, c2_state.position, *c1.attributes.agility
            );
            if c1_state.energy >= steps {
                c1_state.energy -= steps;
                c1_state.position = new_pos;
            }
        },
        BattleAction::MoveLeft => {
            let (new_pos, steps) = new_pos_and_steps(
                Direction::Left, c1_state.position, c2_state.position, *c1.attributes.agility
            );
            if c1_state.energy >= steps {
                c1_state.energy -= steps;
                c1_state.position = new_pos;
            }
        },
        BattleAction::Rest => {
            let rest_penalty = c1_state.consecutive_rest_count
                * (c1_state.consecutive_rest_count - 1);
            if rest_penalty < REST_RECOVERY {
                c1_state.energy += REST_RECOVERY - rest_penalty;
            }
        },
    };
}
