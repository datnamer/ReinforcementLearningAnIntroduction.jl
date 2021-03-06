module BlackJack

using Random
using Ju

import Ju:AbstractSyncEnvironment,
          reset!, render, observe, observationspace, actionspace

export BlackJackEnv

function get_card()
    card = rand(1:13)
    card = min(card, 10)
    card == 1 ? 11 : card
end

function cards2state(c1, c2)
    if c1 == c2 == 11
        [1, 12]
    elseif c1 == 11 || c2 == 11
        [1, c1+c2]
    else
        [0, c1+c2]
    end
end

function update_state!(state, card)
    if card == 11
        state[1] += 1
    end
    state[2] += card
    while state[2] > 21 && state[1] > 0
        state[2] -= 10
        state[1] -= 1
    end
end

"""
map each element to a range start from 1

usable_ace: 0:1 -> 1:2
player_sum: 11:21 => 1:11
dealer_card: 2:11 => 1:10
"""
encode(usable_ace, player_sum, dealer_card) = (usable_ace+1, player_sum-10, dealer_card-1)

mutable struct BlackJackEnv <: AbstractSyncEnvironment{MultiDiscreteSpace, DiscreteSpace, 1}
    is_random_start::Bool
    init::Union{Nothing, Vector{Int}}
    player_state::Vector{Int}
    dealer_card::Int
    dealer_state::Vector{Int}
    isend::Bool
    function BlackJackEnv(;is_random_start=false, init=nothing)
        if is_random_start
            player_state = [rand(0:1), rand(11:21)]
            dealer_card = rand(2:11)
            dealer_state = [dealer_card == 11 ? 1 : 0, dealer_card]
            new(is_random_start, init, player_state, dealer_card, dealer_state, false)
        elseif init == nothing
            player_state = cards2state(get_card(), get_card())
            while player_state[2] < 11
                update_state!(player_state, get_card())
            end
            dealer_card = get_card()
            new(is_random_start, init, player_state, dealer_card, cards2state(dealer_card, get_card()), false)
        else
            new(is_random_start, init, init[1:2], init[3], cards2state(init[3], get_card()), false)
        end
    end
end

function (env::BlackJackEnv)(a::Int)
    if a == 1
        update_state!(env.player_state, get_card())
        env.isend = env.player_state[2] > 21
        (observation = encode(env.player_state[1],
                              min(env.player_state[2], 22),  # 22 is used to represent all invalid sum
                              env.dealer_card),
         reward = env.player_state[2] > 21 ? -1. : 0.,
         isdone =  env.isend)
    else
        while env.dealer_state[2] < 17
            update_state!(env.dealer_state, get_card())
        end
        env.isend = true
        (observation = encode(env.player_state[1],
                              min(env.player_state[2], 22),  # 22 is used to represent all invalid sum
                              env.dealer_card),
         reward = (env.dealer_state[2] > 21 || env.dealer_state[2] < env.player_state[2]) ? 1. : (env.dealer_state[2] == env.player_state[2] ? 0. : -1.),
         isdone = true)
    end
end

function reset!(env::BlackJackEnv) 
    if env.is_random_start
        env.player_state = [rand(0:1), rand(11:21)]
        env.dealer_card = rand(2:11)
        env.dealer_state = [env.dealer_card == 11 ? 1 : 0, env.dealer_card]
    elseif env.init == nothing
        player_state = cards2state(get_card(), get_card())
        while player_state[2] < 11
            update_state!(player_state, get_card())
        end
        env.player_state = player_state
        env.dealer_card = get_card()
        env.dealer_state = cards2state(env.dealer_card, get_card())
    else
        env.player_state = env.init[1:2]
        env.dealer_card = env.init[3]
        env.dealer_state = cards2state(env.dealer_card, get_card())
    end
    env.isend = false
    (observation = encode(env.player_state[1], env.player_state[2], env.dealer_card),
     isdone = false)
end

function observe(env::BlackJackEnv)
    (observation = encode(env.player_state[1],
                          min(env.player_state[2], 22),  # 22 is used to represent all invalid sum
                          env.dealer_card),
     isdone=env.isend)
end

observationspace(::Type{BlackJackEnv}) = MultiDiscreteSpace([2, 12, 10])
actionspace(::Type{BlackJackEnv}) = DiscreteSpace(2)

end