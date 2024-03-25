module my_addrx::share_coin {
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::timestamp;
    use aptos_framework::account;
    use aptos_framework::account::SignerCapability;
    use aptos_std::event::{Self, EventHandle};
    use std::option;
    use std::signer;
    use std::string;
    use std::error;

    //Error codes
    ///Permission denied
    const EPERMISSION_DENIED: u64 = 1001;
    ///Token capabilities already exist
    const ETOKEN_CAPABILITIES_EXIST: u64 = 1003;
    ///Invalid token owner
    const EINVALID_TOKEN_OWNER: u64 = 1004;

    
    //Constants
    const SHARE_TOKEN_SEED: vector<u8> = b"MARKETPLACE:RESOURCE_ACCOUNT";
    
    //Structs
    struct ShareToken {}

    struct ShareTokenCapabilities has key {
        burn_capability: coin::BurnCapability<ShareToken>,
        freeze_capability: coin::FreezeCapability<ShareToken>,
        mint_capability: coin::MintCapability<ShareToken>,
    }

    struct TokenCapability has key {
        token_capability: SignerCapability,
    }

    struct InitializeShareTokenEvent has drop, store {
        account: address,
        name: string::String,
        symbol: string::String,
        decimals: u8,
        monitor_supply: bool,
        timestamp: u64,
    }

    struct MintShareTokenEvent has drop, store {
        owner_addr: address,
        user_addr: address,
        amount: u64,
        timestamp: u64,
    }

    struct TransferShareTokenEvent has drop, store {
        from_addr: address,
        to_addr: address,
        amount: u64,
        timestamp: u64,
    }

    struct FreezeOrUnfreezeAccountEvent has drop, store {
        account: address,
        freeze_account: address,
        freeze: bool,
        timestamp: u64,
    }

    struct BurnAccountEvent has drop, store {
        account: address,
        burn_account: address,
        amount: u64,
        timestamp: u64,
    }

    struct RegisterShareTokenEvent has drop, store {
        account: address,
        timestamp: u64,
    }

    struct ShareTokenEvents has key {
        initialize_share_token_event: EventHandle<InitializeShareTokenEvent>,
        mint_share_token_event: EventHandle<MintShareTokenEvent>,
        transfer_share_token_event: EventHandle<TransferShareTokenEvent>,
        freeze_or_unfreeze_account_event: EventHandle<FreezeOrUnfreezeAccountEvent>,
        burn_account_event: EventHandle<BurnAccountEvent>,
        register_share_token_event: EventHandle<RegisterShareTokenEvent>,
    }

    /**
     * @notice Get the balance of the share token for a given owner address.
     * @param owner The address of the token owner.
     * @return The balance of the share token.
     */

    #[view]
    public fun balance(owner: address): u64 {
        coin::balance<ShareToken>(owner)
    }

    /**
     * @notice Get the name of the share token.
     * @return The name of the share token.
     */
    #[view]
    public fun name(): string::String {
        coin::name<ShareToken>()
    }
    /**
     * @notice Get the symbol of the share token.
     * @return The symbol of the share token.
     */
    #[view]
    public fun symbol(): string::String {
        coin::symbol<ShareToken>()
    }

    /**
     * @notice Get the number of decimal places used for the share token.
     * @return The number of decimal places.
     */

    #[view]
    public fun decimals(): u8 {
        coin::decimals<ShareToken>()
    }
    /**
     * @notice Get the total supply of the share token.
     * @return The total supply of the share token.
     */

    #[view]
    public fun totalSupply(): u128 {
        let x = coin::supply<ShareToken>();
        option::extract(&mut x)
    }

     /**
     * @notice Initialize the share token with the provided parameters.
     * @param account The signer account initializing the token.
     * @param name The name of the share token.
     * @param symbol The symbol of the share token.
     * @param decimals The number of decimal places for the share token.
     * @param monitor_supply Whether to monitor the token supply.
     */

    public entry fun initialize_share_token(
        account: &signer,
        name: string::String,
        symbol: string::String,
        decimals: u8,
        monitor_supply: bool,
    ) acquires ShareTokenEvents {
        let account_addr: address = signer::address_of(account);

        assert!(account_addr == @my_addrx, error::permission_denied(EPERMISSION_DENIED));

        let (token_signer, token_capability): (signer, SignerCapability) =
            account::create_resource_account(account, SHARE_TOKEN_SEED);

        let token_addr: address = signer::address_of(&token_signer);
        let (burn_cap, freeze_cap, mint_cap): (
            coin::BurnCapability<ShareToken>,
            coin::FreezeCapability<ShareToken>,
            coin::MintCapability<ShareToken>,
        ) = coin::initialize<ShareToken>(account, name, symbol, decimals, monitor_supply);

        assert!(
            !exists<TokenCapability>(token_addr),
            error::already_exists(ETOKEN_CAPABILITIES_EXIST)
        );
        move_to(
            &token_signer,
            TokenCapability {
                token_capability: token_capability,
            },
        );

        assert!(
            !exists<ShareTokenCapabilities>(token_addr),
            error::already_exists(ETOKEN_CAPABILITIES_EXIST)
        );
        move_to(
            &token_signer,
            ShareTokenCapabilities {
                burn_capability: burn_cap,
                freeze_capability: freeze_cap,
                mint_capability: mint_cap,
            },
        );

        if (!exists<ShareTokenEvents>(token_addr)) {
            move_to(
                &token_signer,
                ShareTokenEvents {
                    initialize_share_token_event: account::new_event_handle(&token_signer),
                    mint_share_token_event: account::new_event_handle(&token_signer),
                    transfer_share_token_event: account::new_event_handle(&token_signer),
                    freeze_or_unfreeze_account_event: account::new_event_handle(&token_signer),
                    burn_account_event: account::new_event_handle(&token_signer),
                    register_share_token_event: account::new_event_handle(&token_signer),
                },
            );
        };

        coin::register<ShareToken>(account);

        let event_data: &mut ShareTokenEvents = borrow_global_mut<ShareTokenEvents>(token_addr);

        event::emit_event<RegisterShareTokenEvent>(
            &mut event_data.register_share_token_event,
            RegisterShareTokenEvent {
                account: account_addr,
                timestamp: timestamp::now_seconds(),
            },
        );

        event::emit_event<InitializeShareTokenEvent>(
            &mut event_data.initialize_share_token_event,
            InitializeShareTokenEvent {
                account: account_addr,
                name,
                symbol,
                decimals,
                monitor_supply,
                timestamp: timestamp::now_seconds(),
            },
        )
    }
     /**
     * @notice Register the share token for the specified account.
     * @param account The signer account registering the token.
     */
    public entry fun register_share_token(account: &signer) acquires ShareTokenEvents {
        let account_addr = signer::address_of(account);
        coin::register<ShareToken>(account);
        let token_addr: address = account::create_resource_address(&@my_addrx, SHARE_TOKEN_SEED);

        let event_data: &mut ShareTokenEvents = borrow_global_mut<ShareTokenEvents>(token_addr);

        event::emit_event<RegisterShareTokenEvent>(
            &mut event_data.register_share_token_event,
            RegisterShareTokenEvent {
                account: account_addr,
                timestamp: timestamp::now_seconds(),
            },
        )
    }

     /**
     * @notice Mint share tokens and assign them to a user.
     * @param account The signer account minting the tokens.
     * @param user_addr The address of the user receiving the tokens.
     * @param amount The amount of tokens to mint.
     */

    public entry fun mint_share_token(account: &signer, user_addr: address, amount: u64) acquires ShareTokenCapabilities, ShareTokenEvents {
        let token_owner: address = signer::address_of(account);

        assert!(
            token_owner == @my_addrx,
            error::invalid_state(EINVALID_TOKEN_OWNER)
        );

        let token_addr: address = account::create_resource_address(&@my_addrx, SHARE_TOKEN_SEED);
        let mint_cap = &borrow_global<ShareTokenCapabilities>(token_addr).mint_capability;
        let coin: Coin<ShareToken> = coin::mint<ShareToken>(amount, mint_cap);

        coin::deposit<ShareToken>(user_addr, coin);

        let event_data: &mut ShareTokenEvents = borrow_global_mut<ShareTokenEvents>(token_addr);

        event::emit_event<MintShareTokenEvent>(
            &mut event_data.mint_share_token_event,
            MintShareTokenEvent {
                owner_addr: token_owner,
                user_addr,
                amount,
                timestamp: timestamp::now_seconds(),
            },
        )
    }

     /**
     * @notice Transfer share tokens from one address to another.
     * @param from The signer account transferring the tokens.
     * @param to_addr The address of the recipient.
     * @param amount The amount of tokens to transfer.
     */
    public entry fun transfer_share_token(from: &signer, to_addr: address, amount: u64) acquires ShareTokenEvents {
        let from_addr = signer::address_of(from);
        coin::transfer<ShareToken>(from, to_addr, amount);

        let token_addr: address = account::create_resource_address(&@my_addrx, SHARE_TOKEN_SEED);
        let event_data: &mut ShareTokenEvents = borrow_global_mut<ShareTokenEvents>(token_addr);

        event::emit_event<TransferShareTokenEvent>(
            &mut event_data.transfer_share_token_event,
            TransferShareTokenEvent {
                from_addr,
                to_addr,
                amount,
                timestamp: timestamp::now_seconds(),
            },
        )
    }

      /**
     * @notice Freeze or unfreeze the specified account.
     * @param account The signer account freezing or unfreezing the account.
     * @param freeze_account The address of the account to be frozen or unfrozen.
     * @param freeze A boolean indicating whether to freeze or unfreeze the account.
     */

    public entry fun freeze_account(account: &signer, freeze_account: address, freeze: bool) acquires ShareTokenCapabilities, ShareTokenEvents {
        let account_addr: address = signer::address_of(account);

        assert!(
            account_addr == @my_addrx,
            error::invalid_state(EINVALID_TOKEN_OWNER)
        );

        let token_addr: address = account::create_resource_address(&@my_addrx, SHARE_TOKEN_SEED);
        let freeze_cap: &coin::FreezeCapability<ShareToken> = &borrow_global<ShareTokenCapabilities>(token_addr).freeze_capability;
        let event_data: &mut ShareTokenEvents = borrow_global_mut<ShareTokenEvents>(token_addr);
        if (freeze) {
            coin::freeze_coin_store<ShareToken>(freeze_account, freeze_cap);

            event::emit_event<FreezeOrUnfreezeAccountEvent>(
                &mut event_data.freeze_or_unfreeze_account_event,
                FreezeOrUnfreezeAccountEvent {
                    account: account_addr,
                    freeze_account,
                    freeze,
                    timestamp: timestamp::now_seconds(),
                },
            )
        } else {
            coin::unfreeze_coin_store<ShareToken>(freeze_account, freeze_cap);

            event::emit_event<FreezeOrUnfreezeAccountEvent>(
                &mut event_data.freeze_or_unfreeze_account_event,
                FreezeOrUnfreezeAccountEvent {
                    account: account_addr,
                    freeze_account,
                    freeze,
                    timestamp: timestamp::now_seconds(),
                },
            )
        }
    }

     /**
     * @notice Burn share tokens owned by the specified account.
     * @param account The signer account burning the tokens.
     * @param amount The amount of tokens to burn.
     */

    public entry fun pt_burn(account: &signer, amount: u64) acquires ShareTokenEvents, ShareTokenCapabilities {
        let account_addr: address = signer::address_of(account);

        assert!(
            account_addr == @my_addrx,
            error::invalid_state(EINVALID_TOKEN_OWNER)
        );

        let token_addr = account::create_resource_address(&@my_addrx, SHARE_TOKEN_SEED);

        let burn_cap = &borrow_global<ShareTokenCapabilities>(token_addr).burn_capability;

        let coin: Coin<ShareToken> = coin::withdraw(account, amount);
        coin::burn(coin, burn_cap);

        let event_data: &mut ShareTokenEvents = borrow_global_mut<ShareTokenEvents>(token_addr);

        event::emit_event<BurnAccountEvent>(
            &mut event_data.burn_account_event,
            BurnAccountEvent {
                account: account_addr,
                burn_account: account_addr,
                amount,
                timestamp: timestamp::now_seconds(),
            },
        )
    }

     /**
     * @notice Burn share tokens from the specified user's account.
     * @param account The signer account burning the tokens.
     * @param user_addr The address of the user whose tokens are being burned.
     * @param amount The amount of tokens to burn.
     */

    public entry fun pt_burn_from(account: &signer, user_addr: address, amount: u64) acquires ShareTokenEvents, ShareTokenCapabilities {
        let account_addr: address = signer::address_of(account);

        assert!(
            account_addr == @my_addrx,
            error::invalid_state(EINVALID_TOKEN_OWNER)
        );

        let token_addr = account::create_resource_address(&@my_addrx, SHARE_TOKEN_SEED);

        let burn_cap = &borrow_global<ShareTokenCapabilities>(token_addr).burn_capability;

        coin::burn_from(user_addr, amount, burn_cap);

        let event_data: &mut ShareTokenEvents = borrow_global_mut<ShareTokenEvents>(token_addr);

        event::emit_event<BurnAccountEvent>(
            &mut event_data.burn_account_event,
            BurnAccountEvent {
                account: account_addr,
                burn_account: user_addr,
                amount,
                timestamp: timestamp::now_seconds(),
            },
        )
    }
}