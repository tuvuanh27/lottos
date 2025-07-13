#[test_only]
module lottos::test_lottos {
    use std::string::Self;
    use aptos_framework::primary_fungible_store;
    use aptos_framework::timestamp;

    use lottos::config::Self;
    use lottos::lottos::Self;
    use lottos::test_helpers::{Self, admin_signer, get_usdt, setup};

    // ==================== HELPER CONSTANTS ====================

    const LOTTO_535: vector<u8> = b"Lotto 5/35";
    const MEGA_645: vector<u8> = b"Mega 6/45";
    const POWER_655: vector<u8> = b"Power 6/55";

    const TICKET_PRICE: u64 = 500000;
    // $0.50 in microunits
    const ONE_HOUR: u64 = 3600;
    const ONE_DAY: u64 = 86400;

    // Test addresses
    const USER1: address = @0x100;
    const USER2: address = @0x200;
    const USER3: address = @0x300;
    const TREASURY: address = @treasury;

    // ==================== MODULE INITIALIZATION TESTS ====================

    #[test]
    fun test_module_initialization() {
        setup();

        // Test that next_draw_id starts at 1
        let next_id = lottos::get_next_draw_id();
        assert!(next_id == 1, 0);
    }

    #[test]
    fun test_game_configurations_lotto_535() {
        setup();

        // Create a Lotto 5/35 draw to test configuration
        lottos::create_draw(
            admin_signer(),
            string::utf8(LOTTO_535),
            timestamp::now_seconds() + ONE_DAY
        );

        let (draw_id, game_type, status, _close_time, jackpot_pool, jackpot2_pool, winning_numbers, extra_number, tickets_sold) =
            lottos::get_draw(1);

        assert!(draw_id == 1, 1);
        assert!(game_type == string::utf8(LOTTO_535), 2);
        assert!(lottos::is_draw_status_open(status), 3);
        assert!(jackpot_pool == 0, 4);
        assert!(jackpot2_pool == 0, 5);
        assert!(winning_numbers.is_empty(), 6);
        assert!(extra_number == 0, 7);
        assert!(tickets_sold == 0, 8);
    }

    #[test]
    fun test_game_configurations_mega_645() {
        setup();

        lottos::create_draw(
            admin_signer(),
            string::utf8(MEGA_645),
            timestamp::now_seconds() + ONE_DAY
        );

        let (_, game_type, _, _, _, _, _, _, _) = lottos::get_draw(1);
        assert!(game_type == string::utf8(MEGA_645), 0);
    }

    #[test]
    fun test_game_configurations_power_655() {
        setup();

        lottos::create_draw(
            admin_signer(),
            string::utf8(POWER_655),
            timestamp::now_seconds() + ONE_DAY
        );

        let (_, game_type, _, _, _, _, _, _, _) = lottos::get_draw(1);
        assert!(game_type == string::utf8(POWER_655), 0);
    }

    // ==================== DRAW CREATION TESTS ====================

    #[test]
    fun test_create_draw_success() {
        setup();

        let close_time = timestamp::now_seconds() + ONE_DAY;
        lottos::create_draw(admin_signer(), string::utf8(LOTTO_535), close_time);

        let (draw_id, game_type, status, actual_close_time, _, _, _, _, _) = lottos::get_draw(1);
        assert!(draw_id == 1, 0);
        assert!(game_type == string::utf8(LOTTO_535), 1);
        assert!(lottos::is_draw_status_open(status), 2);
        assert!(actual_close_time == close_time, 3);

        // Test next_draw_id incremented
        assert!(lottos::get_next_draw_id() == 2, 4);
    }

    #[test]
    fun test_create_multiple_draws() {
        setup();

        let close_time = timestamp::now_seconds() + ONE_DAY;

        // Create draws of different types
        lottos::create_draw(admin_signer(), string::utf8(LOTTO_535), close_time);
        lottos::create_draw(admin_signer(), string::utf8(MEGA_645), close_time + ONE_HOUR);
        lottos::create_draw(admin_signer(), string::utf8(POWER_655), close_time + 2 * ONE_HOUR);

        assert!(lottos::get_next_draw_id() == 4, 0);

        // Verify each draw
        let (_, type1, _, _, _, _, _, _, _) = lottos::get_draw(1);
        let (_, type2, _, _, _, _, _, _, _) = lottos::get_draw(2);
        let (_, type3, _, _, _, _, _, _, _) = lottos::get_draw(3);

        assert!(type1 == string::utf8(LOTTO_535), 1);
        assert!(type2 == string::utf8(MEGA_645), 2);
        assert!(type3 == string::utf8(POWER_655), 3);
    }

    #[test]
    #[expected_failure(abort_code = 1, location = lottos::config)] // EUNAUTHORIZED
    fun test_create_draw_unauthorized() {
        setup();

        let user_signer = &aptos_framework::account::create_signer_for_test(USER1);
        lottos::create_draw(user_signer, string::utf8(LOTTO_535), timestamp::now_seconds() + ONE_DAY);
    }

    // ==================== TICKET VALIDATION TESTS ====================

    #[test]
    fun test_valid_lotto_535_tickets() {
        setup();

        let close_time = timestamp::now_seconds() + ONE_DAY;
        lottos::create_draw(admin_signer(), string::utf8(LOTTO_535), close_time);

        let user_signer = &aptos_framework::account::create_signer_for_test(USER1);
        let mint_amount = 10 * TICKET_PRICE;
        test_helpers::mint_tokens(user_signer, get_usdt(), mint_amount);

        // Valid tickets: 5 unique numbers from 1-35
        let valid_tickets = vector[
            vector[1, 2, 3, 4, 5, 11],
            vector[10, 15, 20, 25, 30, 11],
            vector[35, 34, 33, 32, 31, 11],
            vector[7, 14, 21, 28, 35, 11]
        ];

        lottos::buy_tickets(user_signer, 1, valid_tickets, get_usdt());
        assert!(
            primary_fungible_store::balance(USER1, get_usdt()) == (mint_amount - valid_tickets.length() * TICKET_PRICE),
            0
        );
        assert!(
            primary_fungible_store::balance(TREASURY, get_usdt()) == (valid_tickets.length() * TICKET_PRICE),
            1
        );
    }

    #[test]
    fun test_valid_mega_645_tickets() {
        setup();

        let close_time = timestamp::now_seconds() + ONE_DAY;
        lottos::create_draw(admin_signer(), string::utf8(MEGA_645), close_time);

        let user_signer = &aptos_framework::account::create_signer_for_test(USER1);
        test_helpers::mint_tokens(user_signer, get_usdt(), 5 * TICKET_PRICE);

        // Valid tickets: 6 unique numbers from 1-45
        let valid_tickets = vector[
            vector[1, 2, 3, 4, 5, 6],
            vector[40, 41, 42, 43, 44, 45],
            vector[10, 15, 20, 25, 30, 35]
        ];

        lottos::buy_tickets(user_signer, 1, valid_tickets, get_usdt());
    }

    #[test]
    fun test_valid_power_655_tickets() {
        setup();

        let close_time = timestamp::now_seconds() + ONE_DAY;
        lottos::create_draw(admin_signer(), string::utf8(POWER_655), close_time);

        let user_signer = &aptos_framework::account::create_signer_for_test(USER1);
        test_helpers::mint_tokens(user_signer, get_usdt(), 5 * TICKET_PRICE);

        // Valid tickets: 6 unique numbers from 1-55
        let valid_tickets = vector[
            vector[1, 2, 3, 4, 5, 6],
            vector[50, 51, 52, 53, 54, 55],
            vector[10, 20, 30, 40, 50, 55]
        ];

        lottos::buy_tickets(user_signer, 1, valid_tickets, get_usdt());
    }

    #[test]
    #[expected_failure(
        abort_code = lottos::EINVALID_TICKET_NUMBER,
        location = lottos::lottos
    )]
    fun test_invalid_ticket_wrong_count_lotto() {
        setup();

        let close_time = timestamp::now_seconds() + ONE_DAY;
        lottos::create_draw(admin_signer(), string::utf8(LOTTO_535), close_time);

        let user_signer = &aptos_framework::account::create_signer_for_test(USER1);
        test_helpers::mint_tokens(user_signer, get_usdt(), TICKET_PRICE);

        // Invalid: Wrong number count (7 numbers instead of 6)
        let invalid_tickets = vector[vector[1, 2, 3, 4, 5, 6, 7]];
        lottos::buy_tickets(user_signer, 1, invalid_tickets, get_usdt());
    }

    #[test]
    #[expected_failure(
        abort_code = lottos::EINVALID_TICKET_NUMBER,
        location = lottos::lottos
    )]
    fun test_invalid_ticket_out_of_range() {
        setup();

        let close_time = timestamp::now_seconds() + ONE_DAY;
        lottos::create_draw(admin_signer(), string::utf8(LOTTO_535), close_time);

        let user_signer = &aptos_framework::account::create_signer_for_test(USER1);
        test_helpers::mint_tokens(user_signer, get_usdt(), TICKET_PRICE);

        // Invalid: Number out of range (36 > 35 for Lotto 5/35)
        let invalid_tickets = vector[vector[1, 2, 3, 4, 36, 1]];
        lottos::buy_tickets(user_signer, 1, invalid_tickets, get_usdt());
    }

    #[test]
    #[expected_failure(
        abort_code = lottos::EINVALID_TICKET_NUMBER,
        location = lottos::lottos
    )]
    fun test_invalid_ticket_zero_number() {
        setup();

        let close_time = timestamp::now_seconds() + ONE_DAY;
        lottos::create_draw(admin_signer(), string::utf8(LOTTO_535), close_time);

        let user_signer = &aptos_framework::account::create_signer_for_test(USER1);
        test_helpers::mint_tokens(user_signer, get_usdt(), TICKET_PRICE);

        // Invalid: Zero is not allowed
        let invalid_tickets = vector[vector[0, 1, 2, 3, 4]];
        lottos::buy_tickets(user_signer, 1, invalid_tickets, get_usdt());
    }

    #[test]
    #[expected_failure(
        abort_code = lottos::EINVALID_TICKET_NUMBER,
        location = lottos::lottos
    )]
    fun test_invalid_ticket_duplicate_numbers() {
        setup();

        let close_time = timestamp::now_seconds() + ONE_DAY;
        lottos::create_draw(admin_signer(), string::utf8(LOTTO_535), close_time);

        let user_signer = &aptos_framework::account::create_signer_for_test(USER1);
        test_helpers::mint_tokens(user_signer, get_usdt(), TICKET_PRICE);

        // Invalid: Duplicate numbers
        let invalid_tickets = vector[vector[1, 1, 3, 4, 5]];
        lottos::buy_tickets(user_signer, 1, invalid_tickets, get_usdt());
    }

    // ==================== TICKET BUYING TESTS ====================

    #[test]
    fun test_buy_tickets_success() {
        setup();

        let close_time = timestamp::now_seconds() + ONE_DAY;
        lottos::create_draw(admin_signer(), string::utf8(LOTTO_535), close_time);

        let user_signer = &aptos_framework::account::create_signer_for_test(USER1);
        test_helpers::mint_tokens(user_signer, get_usdt(), 3 * TICKET_PRICE);

        let tickets = vector[
            vector[1, 2, 3, 4, 5, 11],
            vector[10, 15, 20, 25, 30, 11],
            vector[35, 34, 33, 32, 31, 11]
        ];

        lottos::buy_tickets(user_signer, 1, tickets, get_usdt());

        // Verify tickets were recorded
        let (_, _, _, _, _, _, _, _, tickets_sold) = lottos::get_draw(1);
        assert!(tickets_sold == 3, 0);

        // Verify ticket ownership
        let (draw_id, chosen_numbers, owner, claim_status) =
            lottos::get_ticket(USER1, 1, vector[1, 2, 3, 4, 5, 11]);

        assert!(draw_id == 1, 1);
        assert!(chosen_numbers == vector[1, 2, 3, 4, 5, 11], 2);

        assert!(owner == USER1, 3);
        assert!(lottos::is_claim_status_unclaimed(claim_status), 4);
    }

    #[test]
    fun test_buy_tickets_multiple_users_same_numbers() {
        setup();

        let close_time = timestamp::now_seconds() + ONE_DAY;
        lottos::create_draw(admin_signer(), string::utf8(LOTTO_535), close_time);

        let user1_signer = &aptos_framework::account::create_signer_for_test(USER1);
        let user2_signer = &aptos_framework::account::create_signer_for_test(USER2);

        test_helpers::mint_tokens(user1_signer, get_usdt(), TICKET_PRICE);
        test_helpers::mint_tokens(user2_signer, get_usdt(), TICKET_PRICE);

        let tickets = vector[vector[1, 2, 3, 4, 5, 5]];

        // Both users can buy the same numbers
        lottos::buy_tickets(user1_signer, 1, tickets, get_usdt());
        lottos::buy_tickets(user2_signer, 1, tickets, get_usdt());

        // Verify both tickets exist
        let (_, _, owner1, _) = lottos::get_ticket(USER1, 1, vector[1, 2, 3, 4, 5, 5]);
        let (_, _, owner2, _) = lottos::get_ticket(USER2, 1, vector[1, 2, 3, 4, 5, 5]);

        assert!(owner1 == USER1, 0);
        assert!(owner2 == USER2, 1);
    }

    #[test]
    #[expected_failure(
        abort_code = lottos::ETICKET_ALREADY_BOUGHT,
        location = lottos::lottos
    )]
    fun test_buy_tickets_duplicate_by_same_user() {
        setup();

        let close_time = timestamp::now_seconds() + ONE_DAY;
        lottos::create_draw(admin_signer(), string::utf8(LOTTO_535), close_time);

        let user_signer = &aptos_framework::account::create_signer_for_test(USER1);
        test_helpers::mint_tokens(user_signer, get_usdt(), 2 * TICKET_PRICE);

        let tickets = vector[vector[1, 2, 3, 4, 5, 5]];

        // First purchase should succeed
        lottos::buy_tickets(user_signer, 1, tickets, get_usdt());

        // Second purchase of same numbers should fail
        lottos::buy_tickets(user_signer, 1, tickets, get_usdt());
    }

    #[test]
    #[expected_failure(abort_code = lottos::ECLOSED_DRAW, location = lottos::lottos)]
    fun test_buy_tickets_after_close_time() {
        setup();

        let close_time = timestamp::now_seconds() + 100;
        lottos::create_draw(admin_signer(), string::utf8(LOTTO_535), close_time);

        // Fast forward past close time
        timestamp::fast_forward_seconds(200);

        let user_signer = &aptos_framework::account::create_signer_for_test(USER1);
        test_helpers::mint_tokens(user_signer, get_usdt(), TICKET_PRICE);

        let tickets = vector[vector[1, 2, 3, 4, 5]];
        lottos::buy_tickets(user_signer, 1, tickets, get_usdt());
    }

    #[test]
    #[expected_failure(abort_code = config::ENOT_ACCEPTED_FA, location = lottos::config)]
    fun test_buy_tickets_invalid_payment_asset() {
        setup();

        let close_time = timestamp::now_seconds() + ONE_DAY;
        lottos::create_draw(admin_signer(), string::utf8(LOTTO_535), close_time);

        let user_signer = &aptos_framework::account::create_signer_for_test(USER1);

        // Create an unaccepted token
        let invalid_token = test_helpers::create_fungible_asset(b"INVALID", 6);
        test_helpers::mint_tokens(user_signer, invalid_token, TICKET_PRICE);

        let tickets = vector[vector[1, 2, 3, 4, 5]];
        lottos::buy_tickets(user_signer, 1, tickets, invalid_token);
    }

    // ==================== DRAW EXECUTION TESTS ====================

    #[test]
    fun test_execute_draw_success() {
        setup();

        let close_time = timestamp::now_seconds() + 100;
        lottos::create_draw(admin_signer(), string::utf8(LOTTO_535), close_time);

        // Fast forward past close time
        timestamp::fast_forward_seconds(200);

        lottos::test_execute_draw(admin_signer(), 1, 0);

        // Verify draw is completed
        let (_, _, status, _, _, _, winning_numbers, extra_number, _) = lottos::get_draw(1);
        assert!(lottos::is_draw_status_completed(status), 0);
        assert!(winning_numbers.length() == 5, 1); // Lotto 5/35
        assert!(extra_number > 0, 2); // Should have extra number

        // Verify all numbers are in valid range
        winning_numbers.for_each(|num| {
            assert!(num >= 1 && num <= 35, 3);
        });
        assert!(extra_number >= 1 && extra_number <= 35, 4);
    }

    #[test]
    fun test_execute_draw_mega_645() {
        setup();

        let close_time = timestamp::now_seconds() + 100;
        lottos::create_draw(admin_signer(), string::utf8(MEGA_645), close_time);

        timestamp::fast_forward_seconds(200);

        lottos::test_execute_draw(admin_signer(), 1, 0);

        let (_, _, status, _, _, _, winning_numbers, extra_number, _) = lottos::get_draw(1);
        assert!(lottos::is_draw_status_completed(status), 0);
        assert!(winning_numbers.length() == 6, 1); // Mega 6/45
        assert!(extra_number == 0, 2); // No extra number for Mega

        winning_numbers.for_each(|num| {
            assert!(num >= 1 && num <= 45, 3);
        });
    }

    #[test]
    fun test_execute_draw_power_655() {
        setup();

        let close_time = timestamp::now_seconds() + 100;
        lottos::create_draw(admin_signer(), string::utf8(POWER_655), close_time);

        timestamp::fast_forward_seconds(200);

        lottos::test_execute_draw(admin_signer(), 1, 0);

        let (_, _, status, _, _, _, winning_numbers, extra_number, _) = lottos::get_draw(1);
        assert!(lottos::is_draw_status_completed(status), 0);
        assert!(winning_numbers.length() == 6, 1); // Power 6/55
        assert!(extra_number > 0, 2); // Should have extra number

        winning_numbers.for_each(|num| {
            assert!(num >= 1 && num <= 55, 3);
        });
        assert!(extra_number >= 1 && extra_number <= 55, 4);
    }

    #[test]
    fun test_execute_draw_unique_numbers() {
        setup();

        let close_time = timestamp::now_seconds() + 100;
        lottos::create_draw(admin_signer(), string::utf8(LOTTO_535), close_time);

        timestamp::fast_forward_seconds(200);

        lottos::test_execute_draw(admin_signer(), 1, 0);

        let (_, _, _, _, _, _, winning_numbers, extra_number, _) = lottos::get_draw(1);

        // Verify all main numbers are unique
        let i = 0;
        while (i < winning_numbers.length()) {
            let j = i + 1;
            while (j < winning_numbers.length()) {
                assert!(winning_numbers[i] != winning_numbers[j], 0);
                j += 1;
            };
            i += 1;
        };

        // Verify extra number is different from main numbers
        assert!(!winning_numbers.contains(&extra_number), 1);
    }

    #[test]
    #[expected_failure(abort_code = config::EUNAUTHORIZED, location = lottos::config)]
    fun test_execute_draw_unauthorized() {
        setup();

        let close_time = timestamp::now_seconds() + 100;
        lottos::create_draw(admin_signer(), string::utf8(LOTTO_535), close_time);

        timestamp::fast_forward_seconds(200);

        let user_signer = &aptos_framework::account::create_signer_for_test(USER1);
        lottos::test_execute_draw(user_signer, 1, 0);
    }

    #[test]
    #[expected_failure(abort_code = lottos::ENOT_OPEN_DRAW, location = lottos::lottos)] // ENOT_OPEN_DRAW
    fun test_execute_draw_already_completed() {
        setup();

        let close_time = timestamp::now_seconds() + 100;
        lottos::create_draw(admin_signer(), string::utf8(LOTTO_535), close_time);

        timestamp::fast_forward_seconds(200);

        // Execute once - should succeed
        lottos::test_execute_draw(admin_signer(), 1, 0);

        // Execute again - should fail
        lottos::test_execute_draw(admin_signer(), 1, 0);
    }

    #[test]
    #[expected_failure(abort_code = lottos::ENOT_CLOSE_DRAW_TIME, location = lottos::lottos)] // ENOT_CLOSE_DRAW_TIME
    fun test_execute_draw_before_close_time() {
        setup();

        let close_time = timestamp::now_seconds() + ONE_DAY;
        lottos::create_draw(admin_signer(), string::utf8(LOTTO_535), close_time);

        // Don't fast forward - should fail
        lottos::test_execute_draw(admin_signer(), 1, 0);
    }

    // ==================== PRIZE CALCULATION TESTS ====================

    #[test]
    fun test_prize_calculation_mega_645_tiers() {
        setup();

        let close_time = timestamp::now_seconds() + 100;
        lottos::create_draw(admin_signer(), string::utf8(MEGA_645), close_time);

        let user_signer = &aptos_framework::account::create_signer_for_test(USER1);
        test_helpers::mint_tokens(user_signer, get_usdt(), TICKET_PRICE);

        let tickets = vector[vector[1, 2, 3, 4, 5, 6]];
        lottos::buy_tickets(user_signer, 1, tickets, get_usdt());

        timestamp::fast_forward_seconds(200);
        lottos::test_execute_draw(admin_signer(), 1, 0);
    }

    #[test]
    fun test_prize_calculation_power_655_jackpot2() {
        setup();

        let close_time = timestamp::now_seconds() + 100;
        lottos::create_draw(admin_signer(), string::utf8(POWER_655), close_time);

        let user_signer = &aptos_framework::account::create_signer_for_test(USER1);
        test_helpers::mint_tokens(user_signer, get_usdt(), TICKET_PRICE);

        let tickets = vector[vector[1, 2, 3, 4, 5, 6]];
        lottos::buy_tickets(user_signer, 1, tickets, get_usdt());

        timestamp::fast_forward_seconds(200);
        lottos::test_execute_draw(admin_signer(), 1, 0);
    }

    // ==================== PRIZE CLAIMING TESTS ====================

    #[test]
    fun test_claim_prize_success() {
        setup();

        let close_time = timestamp::now_seconds() + 100;
        lottos::create_draw(admin_signer(), string::utf8(LOTTO_535), close_time);

        let user_signer = &aptos_framework::account::create_signer_for_test(USER1);
        let treasury_signer = &aptos_framework::account::create_signer_for_test(TREASURY);

        test_helpers::mint_tokens(treasury_signer, get_usdt(), 1_000_000 * TICKET_PRICE); // Treasury funds

        timestamp::fast_forward_seconds(200);
        lottos::test_execute_draw(admin_signer(), 1, 0);

        // Get the actual winning numbers to test a known scenario
        let (_, _, _, _, _, _, winning_numbers, extra_number, _) = lottos::get_draw(1);

        // Create a ticket that ưin jackpot
        winning_numbers.push_back(extra_number);

        lottos::add_ticket_for_user_unchecked(user_signer, 1, winning_numbers);
        // get ticket
        let (draw_id, chosen_numbers, owner, claim_status) = lottos::get_ticket(USER1, 1, winning_numbers);
        assert!(draw_id == 1, 0);
        assert!(chosen_numbers == winning_numbers, 1);
        assert!(owner == USER1, 2);
        assert!(lottos::is_claim_status_unclaimed(claim_status), 3);

        lottos::claim_prize(user_signer, treasury_signer, 1, winning_numbers, get_usdt());

        assert!(primary_fungible_store::balance(USER1, get_usdt()) == 600_000 * TICKET_PRICE, 0);
        assert!(primary_fungible_store::balance(TREASURY, get_usdt()) == 400_000 * TICKET_PRICE, 1);
    }

    #[test]
    #[expected_failure(abort_code = lottos::ENOT_COMPLETED_DRAW, location = lottos::lottos)] // ENOT_COMPLETED_DRAW
    fun test_claim_prize_before_draw_completion() {
        setup();

        let close_time = timestamp::now_seconds() + 100;
        lottos::create_draw(admin_signer(), string::utf8(LOTTO_535), close_time);

        let user_signer = &aptos_framework::account::create_signer_for_test(USER1);
        let treasury_signer = &aptos_framework::account::create_signer_for_test(TREASURY);

        test_helpers::mint_tokens(user_signer, get_usdt(), TICKET_PRICE);
        test_helpers::mint_tokens(treasury_signer, get_usdt(), 1000 * TICKET_PRICE);

        let tickets = vector[vector[1, 2, 3, 4, 5, 11]];
        lottos::buy_tickets(user_signer, 1, tickets, get_usdt());

        // Try to claim before draw execution - should fail
        lottos::claim_prize(user_signer, treasury_signer, 1, vector[1, 2, 3, 4, 5, 11], get_usdt());
    }

    #[test]
    #[expected_failure(abort_code = lottos::ENOT_WINNER, location = lottos::lottos)]
    fun test_claim_prize_nonexistent_ticket() {
        setup();

        let close_time = timestamp::now_seconds() + 100;
        lottos::create_draw(admin_signer(), string::utf8(LOTTO_535), close_time);

        let user_signer = &aptos_framework::account::create_signer_for_test(USER1);
        let treasury_signer = &aptos_framework::account::create_signer_for_test(TREASURY);

        test_helpers::mint_tokens(treasury_signer, get_usdt(), 1000 * TICKET_PRICE);

        timestamp::fast_forward_seconds(200);
        lottos::test_execute_draw(admin_signer(), 1, 0);

        // Try to claim without owning a ticket
        lottos::claim_prize(user_signer, treasury_signer, 1, vector[1, 2, 3, 4, 5], get_usdt());
    }

    // ==================== ROLLOVER LOGIC TESTS ====================

    #[test]
    fun test_rollover_logic_same_game_type() {
        setup();

        // Create and execute first draw
        let close_time1 = timestamp::now_seconds() + 100;
        lottos::create_draw(admin_signer(), string::utf8(LOTTO_535), close_time1);

        let user_signer = &aptos_framework::account::create_signer_for_test(USER1);
        test_helpers::mint_tokens(user_signer, get_usdt(), TICKET_PRICE);

        // Buy ticket that likely won't win jackpot
        let tickets = vector[vector[1, 2, 3, 4, 5, 1]];
        lottos::buy_tickets(user_signer, 1, tickets, get_usdt());

        timestamp::fast_forward_seconds(200);
        lottos::test_execute_draw(admin_signer(), 1, 0);

        // Create second draw of same type
        let close_time2 = timestamp::now_seconds() + 100;
        lottos::create_draw(admin_signer(), string::utf8(LOTTO_535), close_time2);

        timestamp::fast_forward_seconds(200);
        lottos::test_execute_draw(admin_signer(), 2, TICKET_PRICE);

        // Check that second draw has rollover (might be 0 if first draw had winner)
        let (_, _, _, _, jackpot_pool, _, _, _, _) = lottos::get_draw(2);
        assert!(jackpot_pool >= TICKET_PRICE / 2, 0);
    }

    #[test]
    fun test_rollover_logic_different_game_types() {
        setup();

        // Create and execute Lotto 5/35 draw
        let close_time1 = timestamp::now_seconds() + 100;
        lottos::create_draw(admin_signer(), string::utf8(LOTTO_535), close_time1);

        timestamp::fast_forward_seconds(200);
        lottos::test_execute_draw(admin_signer(), 1, 0);

        // Create Mega 6/45 draw - should not inherit rollover from different game type
        let close_time2 = timestamp::now_seconds() + 100;
        lottos::create_draw(admin_signer(), string::utf8(MEGA_645), close_time2);

        timestamp::fast_forward_seconds(200);
        lottos::test_execute_draw(admin_signer(), 2, 0);

        // Mega draw should not have rollover from Lotto draw
        let (_, _, _, _, jackpot_pool, _, _, _, _) = lottos::get_draw(2);
        assert!(jackpot_pool == 0, 0); // No rollover from different game type
    }

    // ==================== VIEW FUNCTIONS TESTS ====================

    #[test]
    fun test_get_draw_view_function() {
        setup();

        let close_time = timestamp::now_seconds() + ONE_DAY;
        lottos::create_draw(admin_signer(), string::utf8(LOTTO_535), close_time);

        let (draw_id, game_type, status, actual_close_time, jackpot_pool, jackpot2_pool, winning_numbers, extra_number, tickets_sold) =
            lottos::get_draw(1);

        assert!(draw_id == 1, 0);
        assert!(game_type == string::utf8(LOTTO_535), 1);
        assert!(lottos::is_draw_status_open(status), 2);
        assert!(actual_close_time == close_time, 3);
        assert!(jackpot_pool == 0, 4);
        assert!(jackpot2_pool == 0, 5);
        assert!(winning_numbers.is_empty(), 6);
        assert!(extra_number == 0, 7);
        assert!(tickets_sold == 0, 8);
    }

    #[test]
    fun test_get_ticket_view_function() {
        setup();

        let close_time = timestamp::now_seconds() + ONE_DAY;
        lottos::create_draw(admin_signer(), string::utf8(LOTTO_535), close_time);

        let user_signer = &aptos_framework::account::create_signer_for_test(USER1);
        test_helpers::mint_tokens(user_signer, get_usdt(), TICKET_PRICE);

        let tickets = vector[vector[1, 2, 3, 4, 5, 1]];
        lottos::buy_tickets(user_signer, 1, tickets, get_usdt());

        let (draw_id, chosen_numbers, owner, claim_status) =
            lottos::get_ticket(USER1, 1, vector[1, 2, 3, 4, 5, 1]);

        assert!(draw_id == 1, 0);
        assert!(chosen_numbers == vector[1, 2, 3, 4, 5, 1], 1);
        assert!(owner == USER1, 2);
        assert!(lottos::is_claim_status_unclaimed(claim_status), 3);
    }

    #[test]
    fun test_get_next_draw_id_view_function() {
        setup();

        assert!(lottos::get_next_draw_id() == 1, 0);

        lottos::create_draw(admin_signer(), string::utf8(LOTTO_535), timestamp::now_seconds() + ONE_DAY);
        assert!(lottos::get_next_draw_id() == 2, 1);

        lottos::create_draw(admin_signer(), string::utf8(MEGA_645), timestamp::now_seconds() + ONE_DAY);
        assert!(lottos::get_next_draw_id() == 3, 2);
    }

    // ==================== ERROR CONDITIONS AND EDGE CASES ====================

    #[test]
    #[expected_failure] // Draw ID doesn't exist
    fun test_get_nonexistent_draw() {
        setup();

        let (_, _, _, _, _, _, _, _, _) = lottos::get_draw(999);
    }

    #[test]
    #[expected_failure] // Ticket doesn't exist
    fun test_get_nonexistent_ticket() {
        setup();

        let (_, _, _, _) = lottos::get_ticket(USER1, 1, vector[1, 2, 3, 4, 5]);
    }

    #[test]
    #[expected_failure(
        abort_code = lottos::EINVALID_TICKET_NUMBER,
        location = lottos::lottos
    )]
    fun test_boundary_numbers_lotto_535() {
        setup();

        let close_time = timestamp::now_seconds() + ONE_DAY;
        lottos::create_draw(admin_signer(), string::utf8(LOTTO_535), close_time);

        let user_signer = &aptos_framework::account::create_signer_for_test(USER1);
        test_helpers::mint_tokens(user_signer, get_usdt(), 2 * TICKET_PRICE);

        // Test boundary numbers: minimum and maximum
        let boundary_tickets = vector[
            vector[1, 2, 3, 4, 35, 11], // Min and max
            vector[1, 1, 2, 3, 4, 4]      // Should fail due to duplicates
        ];

        // First ticket should succeed
        lottos::buy_tickets(user_signer, 1, vector[boundary_tickets[0]], get_usdt());

        // Second ticket should fail
        lottos::buy_tickets(user_signer, 1, vector[boundary_tickets[1]], get_usdt());
    }

    #[test]
    #[expected_failure(
        abort_code = lottos::EINVALID_TICKET_NUMBER,
        location = lottos::lottos
    )]
    fun test_boundary_numbers_mega_645_invalid() {
        setup();

        let close_time = timestamp::now_seconds() + ONE_DAY;
        lottos::create_draw(admin_signer(), string::utf8(MEGA_645), close_time);

        let user_signer = &aptos_framework::account::create_signer_for_test(USER1);
        test_helpers::mint_tokens(user_signer, get_usdt(), TICKET_PRICE);

        // Invalid: Number 46 is out of range for Mega 6/45
        let invalid_tickets = vector[vector[1, 2, 3, 4, 5, 46]];
        lottos::buy_tickets(user_signer, 1, invalid_tickets, get_usdt());
    }

    #[test]
    #[expected_failure(
        abort_code = lottos::EINVALID_TICKET_NUMBER,
        location = lottos::lottos
    )]
    fun test_boundary_numbers_power_655_invalid() {
        setup();

        let close_time = timestamp::now_seconds() + ONE_DAY;
        lottos::create_draw(admin_signer(), string::utf8(POWER_655), close_time);

        let user_signer = &aptos_framework::account::create_signer_for_test(USER1);
        test_helpers::mint_tokens(user_signer, get_usdt(), TICKET_PRICE);

        // Invalid: Number 56 is out of range for Power 6/55
        let invalid_tickets = vector[vector[1, 2, 3, 4, 5, 56]];
        lottos::buy_tickets(user_signer, 1, invalid_tickets, get_usdt());
    }

    // ==================== ENHANCED PRIZE TIER TESTS ====================

    #[test]
    fun test_lotto_535_all_prize_tiers() {
        setup();

        let close_time = timestamp::now_seconds() + 100;
        lottos::create_draw(admin_signer(), string::utf8(LOTTO_535), close_time);

        // Execute draw first to get winning numbers
        timestamp::fast_forward_seconds(200);
        lottos::test_execute_draw(admin_signer(), 1, 0);

        let (_, _, _, _, _, _, winning_numbers, extra_number, _) = lottos::get_draw(1);

        // Create test users
        let user1 = &aptos_framework::account::create_signer_for_test(USER1);
        let user2 = &aptos_framework::account::create_signer_for_test(USER2);
        let treasury_signer = &aptos_framework::account::create_signer_for_test(TREASURY);

        // Fund treasury for prize payouts
        test_helpers::mint_tokens(treasury_signer, get_usdt(), 1_000_000 * TICKET_PRICE);

        // Test Jackpot: 5 matches + extra (if extra is in winning numbers, it's jackpot)
        let jackpot_numbers = winning_numbers;
        jackpot_numbers.push_back(extra_number);
        lottos::add_ticket_for_user_unchecked(user1, 1, jackpot_numbers);

        // Test First: 5 matches, no extra
        let first_ticket = winning_numbers;
        first_ticket.push_back(if (extra_number == 12) 11 else (extra_number + 1));
        lottos::add_ticket_for_user_unchecked(user2, 1, first_ticket);

        // Claim jackpot prize (if extra number was in the winning combination)
        lottos::claim_prize(user1, treasury_signer, 1, jackpot_numbers, get_usdt());

        // Claim first prize

        lottos::claim_prize(user2, treasury_signer, 1, first_ticket, get_usdt());

        // Verify claims were successful
        let (_, _, _, claim_status1) = lottos::get_ticket(USER1, 1, jackpot_numbers);
        let (_, _, _, claim_status2) = lottos::get_ticket(USER2, 1, first_ticket);

        assert!(lottos::is_claim_status_claimed(claim_status1), 0);
        assert!(lottos::is_claim_status_claimed(claim_status2), 1);

        // verify balances
        assert!(primary_fungible_store::balance(USER1, get_usdt()) == 600_000 * TICKET_PRICE, 3);
        assert!(primary_fungible_store::balance(USER2, get_usdt()) == 1_000 * TICKET_PRICE, 4);

        // verify treasury balance
        assert!(
            primary_fungible_store::balance(TREASURY, get_usdt()) == (1_000_000 - 600_000 - 1000) * TICKET_PRICE,
            5
        );
    }

    #[test]
    fun test_mega_645_all_prize_tiers() {
        setup();

        let close_time = timestamp::now_seconds() + 100;
        lottos::create_draw(admin_signer(), string::utf8(MEGA_645), close_time);

        timestamp::fast_forward_seconds(200);
        lottos::test_execute_draw(admin_signer(), 1, 0);

        let (_, _, _, _, _, _, winning_numbers, _, _) = lottos::get_draw(1);

        let user1 = &aptos_framework::account::create_signer_for_test(USER1);
        let user2 = &aptos_framework::account::create_signer_for_test(USER2);
        let user3 = &aptos_framework::account::create_signer_for_test(USER3);
        let treasury_signer = &aptos_framework::account::create_signer_for_test(TREASURY);

        test_helpers::mint_tokens(treasury_signer, get_usdt(), 4000000 * TICKET_PRICE);

        // Test Jackpot: 6 matches
        lottos::add_ticket_for_user_unchecked(user1, 1, winning_numbers);

        // Test First: 5 matches
        let mut_winning = winning_numbers; // Get a mutable copy
        let last_element = mut_winning.pop_back(); // Remove last element
        mut_winning.push_back(44); // Replace with different number
        let first_ticket = mut_winning;
        lottos::add_ticket_for_user_unchecked(user2, 1, first_ticket);

        // Test Second: 4 matches
        let mut_winning2 = winning_numbers; // Get another copy
        mut_winning2.pop_back(); // Remove last element
        mut_winning2.pop_back(); // Remove second to last
        mut_winning2.push_back(43); // Add different numbers
        mut_winning2.push_back(44);
        let second_ticket = mut_winning2;
        lottos::add_ticket_for_user_unchecked(user3, 1, second_ticket);

        // Claim prizes
        lottos::claim_prize(user1, treasury_signer, 1, winning_numbers, get_usdt());
        lottos::claim_prize(user2, treasury_signer, 1, first_ticket, get_usdt());
        lottos::claim_prize(user3, treasury_signer, 1, second_ticket, get_usdt());

        // Verify claims were successful
        let (_, _, _, claim_status1) = lottos::get_ticket(USER1, 1, winning_numbers);
        let (_, _, _, claim_status2) = lottos::get_ticket(USER2, 1, first_ticket);
        let (_, _, _, claim_status3) = lottos::get_ticket(USER3, 1, second_ticket);

        assert!(lottos::is_claim_status_claimed(claim_status1), 0);
        assert!(lottos::is_claim_status_claimed(claim_status2), 1);
        assert!(lottos::is_claim_status_claimed(claim_status3), 2);
    }

    #[test]
    fun test_power_655_jackpot2_scenarios() {
        setup();

        let close_time = timestamp::now_seconds() + 100;
        lottos::create_draw(admin_signer(), string::utf8(POWER_655), close_time);

        timestamp::fast_forward_seconds(200);
        lottos::test_execute_draw(admin_signer(), 1, 0);

        let (_, _, _, _, _, _, winning_numbers, extra_number, _) = lottos::get_draw(1);

        let user1 = &aptos_framework::account::create_signer_for_test(USER1);
        let user2 = &aptos_framework::account::create_signer_for_test(USER2);
        let treasury_signer = &aptos_framework::account::create_signer_for_test(TREASURY);

        test_helpers::mint_tokens(treasury_signer, get_usdt(), 4000000 * TICKET_PRICE);

        // Test Jackpot: 6 matches (no extra needed)
        lottos::add_ticket_for_user_unchecked(user1, 1, winning_numbers);

        // Test Jackpot2: 5 matches + extra  
        let jackpot2_ticket = vector[winning_numbers[0], winning_numbers[1], winning_numbers[2], winning_numbers[3], winning_numbers[4], extra_number];
        lottos::add_ticket_for_user_unchecked(user2, 1, jackpot2_ticket);

        // Claim prizes
        lottos::claim_prize(user1, treasury_signer, 1, winning_numbers, get_usdt());
        lottos::claim_prize(user2, treasury_signer, 1, jackpot2_ticket, get_usdt());
    }

    #[test]
    fun test_multiple_winners_same_ticket() {
        setup();

        let close_time = timestamp::now_seconds() + 100;
        lottos::create_draw(admin_signer(), string::utf8(MEGA_645), close_time);

        timestamp::fast_forward_seconds(200);
        lottos::test_execute_draw(admin_signer(), 1, 0);

        let (_, _, _, _, _, _, winning_numbers, _, _) = lottos::get_draw(1);

        let user1 = &aptos_framework::account::create_signer_for_test(USER1);
        let user2 = &aptos_framework::account::create_signer_for_test(USER2);
        let user3 = &aptos_framework::account::create_signer_for_test(USER3);
        let treasury_signer = &aptos_framework::account::create_signer_for_test(TREASURY);

        test_helpers::mint_tokens(treasury_signer, get_usdt(), 4000000 * TICKET_PRICE);

        // All users buy the same winning combination
        lottos::add_ticket_for_user_unchecked(user1, 1, winning_numbers);
        lottos::add_ticket_for_user_unchecked(user2, 1, winning_numbers);
        lottos::add_ticket_for_user_unchecked(user3, 1, winning_numbers);

        // All should be able to claim (prize will be split)
        lottos::claim_prize(user1, treasury_signer, 1, winning_numbers, get_usdt());
        lottos::claim_prize(user2, treasury_signer, 1, winning_numbers, get_usdt());
        lottos::claim_prize(user3, treasury_signer, 1, winning_numbers, get_usdt());

        // Verify all claims successful
        let (_, _, _, claim_status1) = lottos::get_ticket(USER1, 1, winning_numbers);
        let (_, _, _, claim_status2) = lottos::get_ticket(USER2, 1, winning_numbers);
        let (_, _, _, claim_status3) = lottos::get_ticket(USER3, 1, winning_numbers);

        assert!(lottos::is_claim_status_claimed(claim_status1), 0);
        assert!(lottos::is_claim_status_claimed(claim_status2), 1);
        assert!(lottos::is_claim_status_claimed(claim_status3), 2);
    }

    #[test]
    #[expected_failure(abort_code = lottos::EALREADY_CLAIMED, location = lottos::lottos)]
    fun test_double_claim_prevention() {
        setup();

        let close_time = timestamp::now_seconds() + 100;
        lottos::create_draw(admin_signer(), string::utf8(MEGA_645), close_time);

        timestamp::fast_forward_seconds(200);
        lottos::test_execute_draw(admin_signer(), 1, 0);

        let (_, _, _, _, _, _, winning_numbers, _, _) = lottos::get_draw(1);

        let user1 = &aptos_framework::account::create_signer_for_test(USER1);
        let treasury_signer = &aptos_framework::account::create_signer_for_test(TREASURY);

        test_helpers::mint_tokens(treasury_signer, get_usdt(), 4000000 * TICKET_PRICE);

        // Add winning ticket
        lottos::add_ticket_for_user_unchecked(user1, 1, winning_numbers);

        // First claim should succeed
        lottos::claim_prize(user1, treasury_signer, 1, winning_numbers, get_usdt());

        // Second claim should fail
        lottos::claim_prize(user1, treasury_signer, 1, winning_numbers, get_usdt());
    }

    #[test]
    #[expected_failure(abort_code = lottos::ENOT_WINNER, location = lottos::lottos)]
    fun test_claim_non_winning_ticket() {
        setup();

        let close_time = timestamp::now_seconds() + 100;
        lottos::create_draw(admin_signer(), string::utf8(LOTTO_535), close_time);

        timestamp::fast_forward_seconds(200);
        lottos::test_execute_draw(admin_signer(), 1, 0);

        let user1 = &aptos_framework::account::create_signer_for_test(USER1);
        let treasury_signer = &aptos_framework::account::create_signer_for_test(TREASURY);

        test_helpers::mint_tokens(treasury_signer, get_usdt(), 1000000 * TICKET_PRICE);

        // Add non-winning ticket (completely different numbers)
        lottos::add_ticket_for_user_unchecked(user1, 1, vector[30, 31, 32, 33, 34, 11]);

        // Try to claim - should fail
        lottos::claim_prize(user1, treasury_signer, 1, vector[30, 31, 32, 33, 34, 11], get_usdt());
    }

    #[test]
    fun test_edge_case_all_numbers_sequential() {
        setup();

        let close_time = timestamp::now_seconds() + ONE_DAY;
        lottos::create_draw(admin_signer(), string::utf8(LOTTO_535), close_time);

        let user_signer = &aptos_framework::account::create_signer_for_test(USER1);
        test_helpers::mint_tokens(user_signer, get_usdt(), 3 * TICKET_PRICE);

        // Test sequential numbers (valid but unusual patterns)
        let sequential_tickets = vector[
            vector[1, 2, 3, 4, 5, 1], // Low sequential
            vector[31, 32, 33, 34, 35, 1], // High sequential
            vector[5, 10, 15, 20, 25, 1]   // Pattern with gaps
        ];

        lottos::buy_tickets(user_signer, 1, sequential_tickets, get_usdt());

        let (_, _, _, _, _, _, _, _, tickets_sold) = lottos::get_draw(1);
        assert!(tickets_sold == 3, 0);
    }

    #[test]
    fun test_stress_many_prize_claims() {
        setup();

        let close_time = timestamp::now_seconds() + 100;
        lottos::create_draw(admin_signer(), string::utf8(MEGA_645), close_time);

        timestamp::fast_forward_seconds(200);
        lottos::test_execute_draw(admin_signer(), 1, 0);

        let (_, _, _, _, _, _, winning_numbers, _, _) = lottos::get_draw(1);

        let treasury_signer = &aptos_framework::account::create_signer_for_test(TREASURY);
        test_helpers::mint_tokens(treasury_signer, get_usdt(), 1000000 * TICKET_PRICE);

        // Create 5 users with third place tickets (4 matches)
        let test_addresses = vector[@0x1000, @0x1001, @0x1002, @0x1003, @0x1004];
        let i = 0;
        while (i < test_addresses.length()) {
            let user_addr = *test_addresses.borrow(i);
            let user_signer = &aptos_framework::account::create_signer_for_test(user_addr);

            // Create ticket with 4 matches
            let mut_winning_copy = winning_numbers;
            mut_winning_copy.pop_back(); // Remove last 2 elements
            mut_winning_copy.pop_back();
            mut_winning_copy.push_back(43); // Add different numbers
            mut_winning_copy.push_back(44);
            let third_ticket = mut_winning_copy;

            lottos::add_ticket_for_user_unchecked(user_signer, 1, third_ticket);
            lottos::claim_prize(user_signer, treasury_signer, 1, third_ticket, get_usdt());

            i += 1;
        };

        // All 5 users should have successfully claimed
        // Create the same ticket format we used above
        let verify_winning = winning_numbers;
        verify_winning.pop_back();
        verify_winning.pop_back();
        verify_winning.push_back(43);
        verify_winning.push_back(44);
        let (_, _, _, claim_status) = lottos::get_ticket(@0x1002, 1, verify_winning);
        assert!(lottos::is_claim_status_claimed(claim_status), 0);
    }

    // ==================== INTEGRATION TEST WITH HELPER FUNCTION ====================

    #[test]
    fun test_complete_lottery_cycle_with_known_winners() {
        setup();

        // Phase 1: Create draw and gather participants
        let close_time = timestamp::now_seconds() + 100;
        lottos::create_draw(admin_signer(), string::utf8(POWER_655), close_time);

        let user1 = &aptos_framework::account::create_signer_for_test(USER1);
        let user2 = &aptos_framework::account::create_signer_for_test(USER2);
        let user3 = &aptos_framework::account::create_signer_for_test(USER3);

        test_helpers::mint_tokens(user1, get_usdt(), 3 * TICKET_PRICE);
        test_helpers::mint_tokens(user2, get_usdt(), 2 * TICKET_PRICE);
        test_helpers::mint_tokens(user3, get_usdt(), 1 * TICKET_PRICE);

        // Users buy various tickets
        lottos::buy_tickets(user1, 1, vector[
            vector[1, 2, 3, 4, 5, 6],
            vector[10, 11, 12, 13, 14, 15],
            vector[20, 21, 22, 23, 24, 25]
        ], get_usdt());

        lottos::buy_tickets(user2, 1, vector[
            vector[7, 8, 9, 10, 11, 12],
            vector[30, 31, 32, 33, 34, 35]
        ], get_usdt());

        lottos::buy_tickets(user3, 1, vector[
            vector[40, 41, 42, 43, 44, 45]
        ], get_usdt());

        // Phase 2: Execute draw
        timestamp::fast_forward_seconds(200);
        lottos::test_execute_draw(admin_signer(), 1, 0);

        let (_, _, status, _, cumulative_jackpot, cumulative_jackpot2, winning_numbers, extra_number, tickets_sold) = lottos::get_draw(
            1
        );

        assert!(lottos::is_draw_status_completed(status), 0);
        assert!(winning_numbers.length() == 6, 1);
        assert!(extra_number > 0, 2);
        assert!(tickets_sold == 6, 3);

        // Phase 3: Add strategic winning tickets using helper
        let treasury_signer = &aptos_framework::account::create_signer_for_test(TREASURY);
        test_helpers::mint_tokens(treasury_signer, get_usdt(), 4000000 * TICKET_PRICE);

        // Add jackpot winner
        let winner1 = &aptos_framework::account::create_signer_for_test(@0x2001);
        lottos::add_ticket_for_user_unchecked(winner1, 1, winning_numbers);

        // Add jackpot2 winner (5 matches + extra)
        let winner2 = &aptos_framework::account::create_signer_for_test(@0x2002);
        let jackpot2_ticket = vector[winning_numbers[0], winning_numbers[1], winning_numbers[2], winning_numbers[3], winning_numbers[4], extra_number];
        lottos::add_ticket_for_user_unchecked(winner2, 1, jackpot2_ticket);

        // Add first place winner (5 matches, no extra)
        let winner3 = &aptos_framework::account::create_signer_for_test(@0x2003);
        let first_ticket = vector[winning_numbers[0], winning_numbers[1], winning_numbers[2], winning_numbers[3], winning_numbers[4], 55];
        if (!winning_numbers.contains(&55) && extra_number != 55) {
            lottos::add_ticket_for_user_unchecked(winner3, 1, first_ticket);
        };

        // Phase 4: Claims
        lottos::claim_prize(winner1, treasury_signer, 1, winning_numbers, get_usdt());
        lottos::claim_prize(winner2, treasury_signer, 1, jackpot2_ticket, get_usdt());

        if (!winning_numbers.contains(&55) && extra_number != 55) {
            lottos::claim_prize(winner3, treasury_signer, 1, first_ticket, get_usdt());
        };

        // Phase 5: Verify final state
        let (_, _, _, claim1) = lottos::get_ticket(@0x2001, 1, winning_numbers);
        let (_, _, _, claim2) = lottos::get_ticket(@0x2002, 1, jackpot2_ticket);

        assert!(lottos::is_claim_status_claimed(claim1), 4);
        assert!(lottos::is_claim_status_claimed(claim2), 5);

        // Phase 6: Test rollover for next draw
        let close_time2 = timestamp::now_seconds() + 100;
        lottos::create_draw(admin_signer(), string::utf8(POWER_655), close_time2);

        timestamp::fast_forward_seconds(200);
        lottos::test_execute_draw(admin_signer(), 2, 0);

        // Since we had winners, rollover should be minimal
        let (_, _, _, _, _jackpot_pool2, _jackpot2_pool2, _, _, _) = lottos::get_draw(2);

        // Test completed - demonstrates full lottery lifecycle with controlled outcomes
    }

    #[test]
    fun test_helper_function_add_ticket() {
        setup();

        let close_time = timestamp::now_seconds() + 100;
        lottos::create_draw(admin_signer(), string::utf8(LOTTO_535), close_time);

        timestamp::fast_forward_seconds(200);
        lottos::test_execute_draw(admin_signer(), 1, 0);

        let user1 = &aptos_framework::account::create_signer_for_test(USER1);

        // Add ticket using helper function
        let test_ticket = vector[1, 2, 3, 4, 5, 1];
        lottos::add_ticket_for_user_unchecked(user1, 1, test_ticket);

        // Verify ticket was added
        let (draw_id, chosen_numbers, owner, claim_status) = lottos::get_ticket(USER1, 1, test_ticket);
        assert!(draw_id == 1, 0);
        assert!(chosen_numbers == test_ticket, 1);
        assert!(owner == USER1, 2);
        assert!(lottos::is_claim_status_unclaimed(claim_status), 3);
    }
}
