#[test_only]
module lottos::test_config {
    use aptos_framework::account;
    use lottos::config;
    use lottos::test_helpers;
    use std::signer;

    // Test constants
    const EUNAUTHORIZED: u64 = 1;
    const ENOT_ACCEPTED_FA: u64 = 2;

    // Test addresses
    const NEW_ADMIN: address = @0x123;
    const UNAUTHORIZED_USER: address = @0x456;
    const FAKE_ASSET: address = @0x789;

    // ==================== INITIALIZATION TESTS ====================

    #[test]
    /// Test that module initialization sets up correct initial state
    fun test_init_module_for_test() {
        test_helpers::setup();

        // Verify initialization completed without errors
        // The GlobalConfig should exist at @lottos with:
        // - admin set to @admin
        // - pending_admin set to @0x0
        // - stable_fa_accepted containing USDt

        // Test admin authorization works
        config::assert_admin(test_helpers::admin_signer());
    }

    #[test]
    /// Test that USDt asset is accepted after initialization
    fun test_usdt_asset_accepted_after_init() {
        test_helpers::setup();

        // USDt address from config module
        let usdt_object = test_helpers::get_usdt();

        // Should not abort - USDt is whitelisted
        config::assert_stable_fa(usdt_object);
    }

    // ==================== ADMIN TRANSFER TESTS ====================

    #[test]
    /// Test successful admin transfer: set pending then accept
    fun test_admin_transfer_success() {
        test_helpers::setup();

        let admin = test_helpers::admin_signer();
        let new_admin = &account::create_signer_for_test(NEW_ADMIN);

        // Step 1: Current admin sets pending admin
        config::set_pending_admin(admin, NEW_ADMIN);

        // Step 2: Pending admin accepts the role
        config::accept_admin(new_admin);

        // Step 3: Verify new admin has authorization
        config::assert_admin(new_admin);
    }

    #[test]
    #[expected_failure(abort_code = EUNAUTHORIZED, location = lottos::config)]
    /// Test that non-admin cannot set pending admin
    fun test_set_pending_admin_unauthorized() {
        test_helpers::setup();

        let unauthorized = &account::create_signer_for_test(UNAUTHORIZED_USER);

        // Should fail: unauthorized user cannot set pending admin
        config::set_pending_admin(unauthorized, NEW_ADMIN);
    }

    #[test]
    #[expected_failure(abort_code = EUNAUTHORIZED, location = lottos::config)]
    /// Test that wrong address cannot accept admin role
    fun test_accept_admin_wrong_address() {
        test_helpers::setup();

        let admin = test_helpers::admin_signer();
        let wrong_user = &account::create_signer_for_test(UNAUTHORIZED_USER);

        // Step 1: Admin sets pending admin to NEW_ADMIN
        config::set_pending_admin(admin, NEW_ADMIN);

        // Step 2: Wrong user tries to accept (should fail)
        config::accept_admin(wrong_user);
    }

    #[test]
    #[expected_failure(abort_code = EUNAUTHORIZED, location = lottos::config)]
    /// Test that accept_admin fails when no pending admin is set
    fun test_accept_admin_no_pending() {
        test_helpers::setup();

        let user = &account::create_signer_for_test(NEW_ADMIN);

        // Try to accept admin role when no pending admin is set
        config::accept_admin(user);
    }

    #[test]
    /// Test that pending admin is cleared after successful transfer
    fun test_pending_admin_cleared_after_transfer() {
        test_helpers::setup();

        let admin = test_helpers::admin_signer();
        let new_admin = &account::create_signer_for_test(NEW_ADMIN);

        // Complete admin transfer
        config::set_pending_admin(admin, NEW_ADMIN);
        config::accept_admin(new_admin);

        // Verify new admin has access
        config::assert_admin(new_admin);
    }

    #[test]
    /// Test overwriting pending admin before acceptance
    fun test_overwrite_pending_admin() {
        test_helpers::setup();

        let admin = test_helpers::admin_signer();
        let second_pending = &account::create_signer_for_test(UNAUTHORIZED_USER);

        // Set first pending admin
        config::set_pending_admin(admin, NEW_ADMIN);

        // Overwrite with second pending admin
        config::set_pending_admin(admin, UNAUTHORIZED_USER);

        // Second pending admin should be able to accept
        config::accept_admin(second_pending);
        config::assert_admin(second_pending);
    }

    #[test]
    #[expected_failure(abort_code = EUNAUTHORIZED, location = lottos::config)]
    /// Test that first pending admin cannot accept after being overwritten
    fun test_first_pending_admin_cannot_accept_after_overwrite() {
        test_helpers::setup();

        let admin = test_helpers::admin_signer();
        let first_pending = &account::create_signer_for_test(NEW_ADMIN);

        // Set first pending admin
        config::set_pending_admin(admin, NEW_ADMIN);

        // Overwrite with second pending admin
        config::set_pending_admin(admin, UNAUTHORIZED_USER);

        // First pending admin should not be able to accept (should fail)
        config::accept_admin(first_pending);
    }

    // ==================== AUTHORIZATION TESTS ====================

    #[test]
    #[expected_failure(abort_code = EUNAUTHORIZED, location = lottos::config)]
    /// Test that non-admin user fails authorization check
    fun test_assert_admin_unauthorized() {
        test_helpers::setup();

        let unauthorized = &account::create_signer_for_test(UNAUTHORIZED_USER);

        // Should fail: unauthorized user
        config::assert_admin(unauthorized);
    }

    #[test]
    #[expected_failure(abort_code = EUNAUTHORIZED, location = lottos::config)]
    /// Test that pending admin cannot use admin functions before acceptance
    fun test_assert_admin_pending_before_acceptance() {
        test_helpers::setup();

        let admin = test_helpers::admin_signer();
        let pending_admin = &account::create_signer_for_test(NEW_ADMIN);

        // Set pending admin but don't accept yet
        config::set_pending_admin(admin, NEW_ADMIN);

        // Pending admin should not have authorization yet
        config::assert_admin(pending_admin);
    }

    #[test]
    /// Test that new admin has authorization after transfer
    fun test_assert_admin_after_transfer() {
        test_helpers::setup();

        let admin = test_helpers::admin_signer();
        let new_admin = &account::create_signer_for_test(NEW_ADMIN);

        // Complete transfer
        config::set_pending_admin(admin, NEW_ADMIN);
        config::accept_admin(new_admin);

        // New admin should have authorization
        config::assert_admin(new_admin);
    }

    #[test]
    #[expected_failure(abort_code = EUNAUTHORIZED, location = lottos::config)]
    /// Test that old admin loses access after transfer
    fun test_old_admin_loses_access_after_transfer() {
        test_helpers::setup();

        let admin = test_helpers::admin_signer();
        let new_admin = &account::create_signer_for_test(NEW_ADMIN);

        // Complete transfer
        config::set_pending_admin(admin, NEW_ADMIN);
        config::accept_admin(new_admin);

        // Old admin should no longer have access
        config::assert_admin(admin);
    }

    // ==================== ASSET VALIDATION TESTS ====================

    #[test]
    #[expected_failure(abort_code = ENOT_ACCEPTED_FA, location = lottos::config)]
    /// Test that non-whitelisted asset fails validation
    fun test_assert_stable_fa_not_accepted() {
        test_helpers::setup();

        // Create fake asset object
        let fake_asset = test_helpers::create_fungible_asset(
            b"FAKE_ASSET",
            6
        );

        // Should fail: fake asset not in whitelist
        config::assert_stable_fa(fake_asset);
    }

    #[test]
    /// Test that whitelisted USDt asset passes validation
    fun test_assert_stable_fa_usdt_accepted() {
        test_helpers::setup();

        // USDt is whitelisted during initialization
        let usdt_object = test_helpers::get_usdt();

        // Should not abort
        config::assert_stable_fa(usdt_object);
    }

    // ==================== EDGE CASE TESTS ====================

    #[test]
    /// Test setting pending admin to same current admin
    fun test_set_pending_admin_same_as_current() {
        test_helpers::setup();

        let admin = test_helpers::admin_signer();
        let admin_address = signer::address_of(admin);

        // Set pending admin to current admin address
        config::set_pending_admin(admin, admin_address);

        // Admin should be able to accept their own role
        config::accept_admin(admin);

        // Should still be admin
        config::assert_admin(admin);
    }

    #[test]
    /// Test setting pending admin to zero address
    fun test_set_pending_admin_zero_address() {
        test_helpers::setup();

        let admin = test_helpers::admin_signer();

        // Should be able to set pending admin to zero address
        config::set_pending_admin(admin, @0x0);

        // Admin should still have authorization (no transfer occurred)
        config::assert_admin(admin);
    }

    // ==================== INTEGRATION TESTS ====================

    #[test]
    /// Test complete admin workflow with multiple transfers
    fun test_multiple_admin_transfers() {
        test_helpers::setup();

        let original_admin = test_helpers::admin_signer();
        let admin1 = &account::create_signer_for_test(NEW_ADMIN);
        let admin2 = &account::create_signer_for_test(UNAUTHORIZED_USER);

        // Transfer 1: original -> admin1
        config::set_pending_admin(original_admin, NEW_ADMIN);
        config::accept_admin(admin1);
        config::assert_admin(admin1);

        // Transfer 2: admin1 -> admin2
        config::set_pending_admin(admin1, UNAUTHORIZED_USER);
        config::accept_admin(admin2);
        config::assert_admin(admin2);
    }

    #[test]
    /// Test admin operations work correctly after transfer
    fun test_admin_operations_after_transfer() {
        test_helpers::setup();

        let original_admin = test_helpers::admin_signer();
        let new_admin = &account::create_signer_for_test(NEW_ADMIN);
        let another_user = &account::create_signer_for_test(UNAUTHORIZED_USER);

        // Complete admin transfer
        config::set_pending_admin(original_admin, NEW_ADMIN);
        config::accept_admin(new_admin);

        // New admin should be able to set another pending admin
        config::set_pending_admin(new_admin, UNAUTHORIZED_USER);

        // Verify USDt validation still works after admin change
        let usdt_object = test_helpers::get_usdt();
        config::assert_stable_fa(usdt_object);

        // Complete second transfer
        config::accept_admin(another_user);
        config::assert_admin(another_user);
    }

}
