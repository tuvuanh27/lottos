#[test_only]
module lottos::test_config {
    use std::signer;
    use aptos_framework::account;
    use aptos_framework::object;
    use aptos_framework::fungible_asset::{Self, Metadata};
    use aptos_framework::primary_fungible_store;

    use lottos::config;

    #[test(admin = @admin, user = @0x123)]
    fun test_admin_functions(admin: &signer, user: &signer) {
        // Setup accounts
        account::create_account_for_test(signer::address_of(admin));
        account::create_account_for_test(signer::address_of(user));

        // Initialize config
        config::init_module_for_test(admin);

        // Test admin assertion - should pass for admin
        config::assert_admin(admin);
    }

    #[test(admin = @admin, user = @0x123)]
    #[expected_failure(abort_code = 1)] // EUNAUTHORIZED
    fun test_non_admin_fails(admin: &signer, user: &signer) {
        // Setup accounts
        account::create_account_for_test(signer::address_of(admin));
        account::create_account_for_test(signer::address_of(user));

        // Initialize config
        config::init_module_for_test(admin);

        // Test admin assertion - should fail for non-admin
        config::assert_admin(user);
    }

    #[test(admin = @admin)]
    fun test_stable_fa_validation(admin: &signer) {
        // Setup
        account::create_account_for_test(signer::address_of(admin));
        config::init_module_for_test(admin);

        // This test would need actual fungible asset objects to test properly
        // For now, we'll test the structure
    }

    #[test(admin = @admin, new_admin = @0x456)]
    fun test_admin_transfer(admin: &signer, new_admin: &signer) {
        // Setup accounts
        account::create_account_for_test(signer::address_of(admin));
        account::create_account_for_test(signer::address_of(new_admin));

        // Initialize config
        config::init_module_for_test(admin);

        // Test that admin can perform admin functions
        config::assert_admin(admin);

        // Test admin transfer functionality would go here
        // This would require implementing admin transfer functions in config.move
    }
}
