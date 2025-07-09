#[test_only]
module lottos::test_helpers {

    use std::option;
    use std::signer;
    use std::string;
    use aptos_std::smart_table;
    use aptos_std::smart_table::SmartTable;
    use aptos_framework::account;
    use aptos_framework::fungible_asset;
    use aptos_framework::fungible_asset::{Metadata, MintRef};
    use aptos_framework::object;
    use aptos_framework::object::Object;
    use aptos_framework::primary_fungible_store;
    use aptos_framework::randomness;
    use lottos::config;

    struct FungibleCap has key {
        mint_cap: SmartTable<Object<Metadata>, MintRef>,
        metadata_map: SmartTable<vector<u8>, Object<Metadata>>
    }

    const USDt: vector<u8> = b"USDt";
    const USDC: vector<u8> = b"USDC";

    #[lint::allow_unsafe_randomness]
    public fun setup() acquires FungibleCap {
        let usdt = create_fungible_asset(USDt, 6);
        let usdc = create_fungible_asset(USDC, 6);

        randomness::initialize_for_testing(aptos_fx());
        config::init_module_for_test(lottos_signer(), vector[usdt, usdc]);
    }

    public inline fun lottos_signer(): &signer {
        &account::create_signer_for_test(@lottos)
    }

    public inline fun admin_signer(): &signer {
        &account::create_signer_for_test(@admin)
    }

    public inline fun aptos_fx(): &signer {
        &account::create_signer_for_test(@0x1)
    }

    public fun create_fungible_asset(
        name: vector<u8>, decimals: u8
    ): Object<Metadata> acquires FungibleCap {
        if (!exists<FungibleCap>(@lottos)) {
            move_to(
                lottos_signer(),
                FungibleCap { mint_cap: smart_table::new(), metadata_map: smart_table::new() }
            );
        };
        let token_metadata = &object::create_named_object(lottos_signer(), name);
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            token_metadata,
            option::none(),
            string::utf8(name),
            string::utf8(name),
            decimals,
            string::utf8(b""),
            string::utf8(b"")
        );
        let fungible_cap = &mut FungibleCap[@lottos];
        let metadata = object::object_from_constructor_ref(token_metadata);
        fungible_cap.mint_cap.add(
            metadata, fungible_asset::generate_mint_ref(token_metadata)
        );
        fungible_cap.metadata_map.add(
            name, metadata
        );

        metadata
    }

    public fun get_usdt(): Object<Metadata> acquires FungibleCap {
        let fungible_cap = &FungibleCap[@lottos];
        *fungible_cap.metadata_map.borrow(USDt)
    }

    public fun get_usdc(): Object<Metadata> acquires FungibleCap {
        let fungible_cap = &FungibleCap[@lottos];
        *fungible_cap.metadata_map.borrow(USDC)
    }
}
