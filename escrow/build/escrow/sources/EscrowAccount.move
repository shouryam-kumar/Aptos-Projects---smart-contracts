module Escrow::EscrowAccount {

    use std::signer;
    use aptos_framework::account;
    use aptos_framework::coin;
    use aptos_framework::managed_coin;

    // Errors
    const EINVALID_BALANCE: u64 = 0;
    const ERESOURCE_DOESNT_EXIST: u64 = 1;
    const EINVALID_SIGNER: u64 = 2;
    const ECOIN_STORE_NOT_PUBLISHED: u64 = 3;

    // Resources
    struct ResourceInfo has key {
        source: address,
        resource_cap: account::SignerCapability
    }

    public entry fun initialize<CoinType>(initializer: &signer, amount: u64, seeds: vector<u8>) {
        // creating a resource account controlled by the program to store the amount which acts as an escrow account
        let (vault, vault_signer_cap) = account::create_resource_account(initializer, seeds);
        let resource_account_from_cap = account::create_signer_with_capability(&vault_signer_cap);
        move_to<ResourceInfo>(&resource_account_from_cap, ResourceInfo{resource_cap: vault_signer_cap, source: signer::address_of(initializer)});
        managed_coin::register<CoinType>(&vault);

        let vault_addr = signer::address_of(&vault); 
        coin::transfer<CoinType>(initializer, vault_addr, amount);
    } 

    public entry fun cancel<CoinType>(initializer: &signer, vault_account: address) acquires ResourceInfo{
        assert!(exists<ResourceInfo>(vault_account), ERESOURCE_DOESNT_EXIST);

        let initializer_addr = signer::address_of(initializer);
        let vault_info = borrow_global<ResourceInfo>(vault_account); 
        assert!(vault_info.source == initializer_addr, EINVALID_SIGNER);

        // getting the signer from the program
        let resource_account_from_cap = account::create_signer_with_capability(&vault_info.resource_cap);
        let balance = coin::balance<CoinType>(vault_account);
        coin::transfer<CoinType>(&resource_account_from_cap, initializer_addr,balance);
    }

    public entry fun exchange<FirstCoin, SecondCoin>(taker: &signer, initializer: address, vault_account: address) acquires ResourceInfo {
        assert!(exists<ResourceInfo>(vault_account), ERESOURCE_DOESNT_EXIST);

        let vault_info = borrow_global<ResourceInfo>(vault_account); 
        let taker_addr = signer::address_of(taker);
        assert!(vault_info.source == initializer, EINVALID_SIGNER); 

        assert!(coin::is_account_registered<SecondCoin>(taker_addr), ECOIN_STORE_NOT_PUBLISHED);
        assert!(coin::is_account_registered<SecondCoin>(initializer), ECOIN_STORE_NOT_PUBLISHED);
        assert!(coin::is_account_registered<FirstCoin>(taker_addr), ECOIN_STORE_NOT_PUBLISHED);
        

        let balance = coin::balance<FirstCoin>(vault_account);
        coin::transfer<SecondCoin>(taker, initializer, balance);
        let resource_account_from_cap = account::create_signer_with_capability(&vault_info.resource_cap);
        coin::transfer<FirstCoin>(&resource_account_from_cap, taker_addr, balance);
    }


}