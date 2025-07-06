#[test_only]
module lottos::test_lottos {
    // use std::string;
    // use std::signer;
    // use aptos_framework::timestamp;
    // use aptos_framework::account;
    // use aptos_framework::coin;
    // use aptos_framework::aptos_coin::AptosCoin;
    // use aptos_framework::object;
    // use aptos_framework::primary_fungible_store;
    // use aptos_framework::fungible_asset::{Self, Metadata};
    // use aptos_framework::dispatchable_fungible_asset;
    //
    // use lottos::lottos;
    // use lottos::config;
    //
    // const LOTTO_535: vector<u8> = b"Lotto 5/35";
    // const MEGA_645: vector<u8> = b"Mega 6/45";
    // const POWER_655: vector<u8> = b"Power 6/55";
    //
    // #[test(aptos_framework = @0x1, lottos = @lottos, treasury = @treasury, admin = @admin, user = @0x123)]
    // fun test_init_and_create_draw(
    //     aptos_framework: &signer,
    //     lottos: &signer,
    //     treasury: &signer,
    //     admin: &signer,
    //     user: &signer
    // ) {
    //     // Setup
    //     timestamp::set_time_has_started_for_testing(aptos_framework);
    //     timestamp::update_global_time_for_test_secs(1000);
    //
    //     account::create_account_for_test(signer::address_of(lottos));
    //     account::create_account_for_test(signer::address_of(treasury));
    //     account::create_account_for_test(signer::address_of(admin));
    //     account::create_account_for_test(signer::address_of(user));
    //
    //     // Initialize config first
    //     config::init_module_for_test(admin);
    //
    //     // Initialize lottos
    //     lottos::init_module_for_test(lottos);
    //
    //     // Test creating a draw
    //     let close_time = timestamp::now_seconds() + 3600; // 1 hour from now
    //     lottos::create_draw(admin, string::utf8(LOTTO_535), close_time);
    //
    //     // Verify draw was created
    //     let next_id = lottos::get_next_draw_id();
    //     assert!(next_id == 2, 1); // Should be 2 since we created draw with id 1
    //
    //     // Get draw details
    //     let (draw_id, draw_type, status, close_timestamp, prize_pool, winning_numbers, extra_number, tickets_sold) =
    //         lottos::get_draw(1);
    //
    //     assert!(draw_id == 1, 2);
    //     assert!(draw_type == string::utf8(LOTTO_535), 3);
    //     assert!(status == 0, 4); // Open status
    //     assert!(close_timestamp == close_time, 5);
    //     assert!(prize_pool == 0, 6);
    //     assert!(winning_numbers.length() == 0, 7); // No winning numbers yet
    //     assert!(extra_number == 0, 8);
    //     assert!(tickets_sold == 0, 9);
    // }
    //
    // #[test(aptos_framework = @0x1, lottos = @lottos, treasury = @treasury, admin = @admin)]
    // fun test_close_draw(
    //     aptos_framework: &signer,
    //     lottos: &signer,
    //     treasury: &signer,
    //     admin: &signer
    // ) {
    //     // Setup
    //     timestamp::set_time_has_started_for_testing(aptos_framework);
    //     timestamp::update_global_time_for_test_secs(1000);
    //
    //     account::create_account_for_test(signer::address_of(lottos));
    //     account::create_account_for_test(signer::address_of(treasury));
    //     account::create_account_for_test(signer::address_of(admin));
    //
    //     config::init_module_for_test(admin);
    //     lottos::init_module_for_test(lottos);
    //
    //     // Create and close a draw
    //     let close_time = timestamp::now_seconds() + 3600;
    //     lottos::create_draw(admin, string::utf8(MEGA_645), close_time);
    //
    //     // Close the draw
    //     lottos::close_draw(admin, 1);
    //
    //     // Verify draw status changed to closed
    //     let (_, _, status, _, _, _, _, _) = lottos::get_draw(1);
    //     assert!(status == 1, 1); // Closed status
    // }
    //
    // #[test(aptos_framework = @0x1, lottos = @lottos, treasury = @treasury, admin = @admin)]
    // #[expected_failure(abort_code = 4)] // ECLOSED_DRAW
    // fun test_close_already_closed_draw(
    //     aptos_framework: &signer,
    //     lottos: &signer,
    //     treasury: &signer,
    //     admin: &signer
    // ) {
    //     // Setup
    //     timestamp::set_time_has_started_for_testing(aptos_framework);
    //     timestamp::update_global_time_for_test_secs(1000);
    //
    //     account::create_account_for_test(signer::address_of(lottos));
    //     account::create_account_for_test(signer::address_of(treasury));
    //     account::create_account_for_test(signer::address_of(admin));
    //
    //     config::init_module_for_test(admin);
    //     lottos::init_module_for_test(lottos);
    //
    //     // Create and close a draw
    //     let close_time = timestamp::now_seconds() + 3600;
    //     lottos::create_draw(admin, string::utf8(MEGA_645), close_time);
    //     lottos::close_draw(admin, 1);
    //
    //     // Try to close again - should fail
    //     lottos::close_draw(admin, 1);
    // }
    //
    // #[test]
    // fun test_ticket_validation() {
    //     // Test valid Lotto 5/35 ticket
    //     let valid_ticket = vector[1, 5, 10, 20, 35];
    //     // This would be tested through buy_tickets function
    //
    //     // Test invalid tickets would be tested through expected_failure tests
    // }
    //
    // #[test]
    // fun test_prize_tier_calculation() {
    //     // This would test the compare_draw_result function
    //     // Testing different match scenarios for each game type
    // }
}
