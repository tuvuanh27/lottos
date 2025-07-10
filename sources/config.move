/// # Lottery Configuration Module
/// 
/// Manages global configuration for the lottery system including:
/// - Admin access control with pending transfer mechanism
/// - Whitelisted fungible assets for payments
/// - Security validations for lottery operations
/// 
/// ## Admin Model
/// - Single admin with ability to create draws and execute them
/// - Two-step admin transfer process for security
/// - Pending admin must explicitly accept the role
/// 
/// ## Payment Assets
/// - Only whitelisted fungible assets accepted for ticket purchases
/// - Currently supports USDt (Tether) on testnet
/// - Can be extended to support multiple stablecoins
module lottos::config {
    use aptos_framework::fungible_asset::Metadata;
    use aptos_framework::object::{Self, Object};
    use std::signer;

    /// Module identifier for domain separation
    const CONFIG_MODULE_NAME: vector<u8> = b"lottos::config";

    // ==================== ASSET ADDRESSES ====================
    
    // Mainnet addresses (commented out)
    // const USDt: address = @0x357b0b74bc833e95a115ad22604854d6b0fca151cecd94111770e5d6ffc9dc2b;
    // const USDC: address = @0xbae207659db88bea0cbead6da0ed00aac12edcdda169e591cd41c94180b46f3b;

    /// Testnet USDt (Tether) fungible asset address
    const USDt: address = @0x91b360075b46ce449831980931efbd8ae8993096e005c77d41ad63f57e87e022;

    // ==================== ERROR CODES ====================
    
    /// Access denied: Signer is not authorized to perform this operation
    const EUNAUTHORIZED: u64 = 1;
    /// Invalid payment: Fungible asset is not in the whitelist
    const ENOT_ACCEPTED_FA: u64 = 2;

    // ==================== STRUCTS ====================
    
    // Global configuration stored at module address
    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct GlobalConfig has key {
        /// List of fungible assets accepted for ticket payments
        stable_fa_accepted: vector<Object<Metadata>>,
        /// Current admin address authorized to manage lottery
        admin: address,
        /// Pending admin address (0x0 if no transfer in progress)
        pending_admin: address
    }

    /// Initialize module with default configuration
    /// Sets up initial admin and whitelisted payment assets
    /// 
    /// # Parameters
    /// * `lottos_signer` - Module publisher's signer
    fun init_module(lottos_signer: &signer) {
        move_to(
            lottos_signer,
            GlobalConfig {
                stable_fa_accepted: vector[object::address_to_object(USDt)],
                admin: @admin,
                pending_admin: @0x0
            }
        )
    }

    /// Initiate admin transfer by setting pending admin
    /// 
    /// First step of two-phase admin transfer process.
    /// The pending admin must call accept_admin() to complete transfer.
    /// 
    /// # Parameters
    /// * `admin` - Current admin initiating the transfer
    /// * `pending_admin` - Address that will become new admin after acceptance
    /// 
    /// # Aborts
    /// * `EUNAUTHORIZED` - If signer is not current admin
    public entry fun set_pending_admin(
        admin: &signer, pending_admin: address
    ) acquires GlobalConfig {
        assert_admin(admin);
        let config = &mut GlobalConfig[@lottos];
        config.pending_admin = pending_admin;
    }

    /// Complete admin transfer by accepting pending role
    /// 
    /// Second step of two-phase admin transfer process.
    /// Only the pending admin can call this function.
    /// 
    /// # Parameters
    /// * `pending_admin` - Address accepting the admin role
    /// 
    /// # Aborts
    /// * `EUNAUTHORIZED` - If signer is not the pending admin
    public entry fun accept_admin(pending_admin: &signer) acquires GlobalConfig {
        let config = &mut GlobalConfig[@lottos];
        assert!(
            config.pending_admin == signer::address_of(pending_admin),
            EUNAUTHORIZED
        );
        config.admin = config.pending_admin;
        config.pending_admin = @0x0;
    }

    /// Validate that signer is authorized admin
    /// 
    /// Used by lottery functions to ensure only admin can create/execute draws.
    /// 
    /// # Parameters
    /// * `user` - Signer to validate
    /// 
    /// # Aborts
    /// * `EUNAUTHORIZED` - If signer is not current admin
    package fun assert_admin(user: &signer) acquires GlobalConfig {
        let config = &GlobalConfig[@lottos];
        assert!(config.admin == signer::address_of(user), EUNAUTHORIZED);
    }

    /// Validate that fungible asset is whitelisted for payments
    /// 
    /// Ensures only approved stablecoins can be used for ticket purchases.
    /// 
    /// # Parameters
    /// * `fa` - Fungible asset object to validate
    /// 
    /// # Aborts
    /// * `ENOT_ACCEPTED_FA` - If asset is not in whitelist
    package fun assert_stable_fa(fa: Object<Metadata>) acquires GlobalConfig {
        let config = &GlobalConfig[@lottos];
        assert!(config.stable_fa_accepted.contains(&fa), ENOT_ACCEPTED_FA);
    }

    #[test_only]
    /// Initialize module for testing with same configuration as production
    /// 
    /// # Parameters
    /// * `lottos_signer` - Test environment signer
    public fun init_module_for_test(lottos_signer: &signer, stable_fa_accepted: vector<Object<Metadata>>) {
        move_to(
            lottos_signer,
            GlobalConfig {
                stable_fa_accepted,
                admin: @admin,
                pending_admin: @0x0
            }
        )
    }
}
