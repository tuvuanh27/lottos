module lottos::config {
    use std::signer;
    use aptos_framework::fungible_asset::Metadata;
    use aptos_framework::object;
    use aptos_framework::object::Object;

    const CONFIG_MODULE_NAME: vector<u8> = b"lottos::config";

    const USDt: address = @0x357b0b74bc833e95a115ad22604854d6b0fca151cecd94111770e5d6ffc9dc2b;
    const USDC: address = @0xbae207659db88bea0cbead6da0ed00aac12edcdda169e591cd41c94180b46f3b;

    /// Not authorized to perform the operation.
    const EUNAUTHORIZED: u64 = 1;
    /// Fungible asset is not accepted.
    const ENOT_ACCEPTED_FA: u64 = 2;

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct GlobalConfig has key {
        stable_fa_accepted: vector<Object<Metadata>>,
        admin: address,
        pending_admin: address
    }

    fun init_module(lottos_signer: &signer) {
        move_to(
            lottos_signer,
            GlobalConfig {
                stable_fa_accepted: vector[object::address_to_object(USDt), object::address_to_object(USDC)],
                admin: @admin,
                pending_admin: @0x0
            }
        )
    }

    public entry fun set_pending_admin(
        admin: &signer, pending_admin: address
    ) acquires GlobalConfig {
        assert_admin(admin);
        let config = &mut GlobalConfig[@lottos];
        config.pending_admin = pending_admin;
    }

    public entry fun accept_admin(pending_admin: &signer) acquires GlobalConfig {
        let config = &mut GlobalConfig[@lottos];
        assert!(
            config.pending_admin == signer::address_of(pending_admin),
            EUNAUTHORIZED
        );
        config.admin = config.pending_admin;
        config.pending_admin = @0x0;
    }

    package fun assert_admin(user: &signer) acquires GlobalConfig {
        let config = &GlobalConfig[@lottos];
        assert!(config.admin == signer::address_of(user), EUNAUTHORIZED);
    }

    package fun assert_stable_fa(fa: Object<Metadata>) acquires GlobalConfig {
        let config = &GlobalConfig[@lottos];
        assert!(config.stable_fa_accepted.contains(&fa), ENOT_ACCEPTED_FA);
    }

    #[test_only]
    public fun init_module_for_test(lottos_signer: &signer) {
        move_to(
            lottos_signer,
            GlobalConfig {
                stable_fa_accepted: vector[object::address_to_object(USDt), object::address_to_object(USDC)],
                admin: @admin,
                pending_admin: @0x0
            }
        )
    }
}
