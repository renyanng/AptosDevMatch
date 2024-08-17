#[test_only]
module MultisigAddr::MultisigTests {
    use std::signer;
    use std::vector;
    use aptos_framework::account;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use MultisigAddr::Multisig;

    #[test(admin = @MultisigAddr, owner1 = @0x456, owner2 = @0x789)]
    public entry fun test_multisig_flow(admin: &signer, owner1: &signer, owner2: &signer) {
        // Setup
        let admin_addr = signer::address_of(admin);
        account::create_account_for_test(admin_addr);
        let owner1_addr = signer::address_of(owner1);
        account::create_account_for_test(owner1_addr);
        let owner2_addr = signer::address_of(owner2);
        account::create_account_for_test(owner2_addr);

        // Initialize coin
        let (burn_cap, mint_cap) = coin::initialize<AptosCoin>(
            admin,
            b"AptosCoin",
            b"APT",
            8,
            false,
        );

        // Mint and fund the multisig wallet
        coin::register(admin);
        let coins = coin::mint(1000, &mint_cap);
        coin::deposit(admin_addr, coins);

        // Initialize multisig
        let owners = vector::empty<address>();
        vector::push_back(&mut owners, owner1_addr);
        vector::push_back(&mut owners, owner2_addr);
        Multisig::initialize(admin, owners, 2);

        // Submit transaction
        let recipient = @0xABC;
        account::create_account_for_test(recipient);
        coin::register(recipient);
        Multisig::submit_transaction(owner1, recipient, 100, b"test");

        // Sign transaction
        Multisig::sign_transaction(owner1, 0);
        Multisig::sign_transaction(owner2, 0);

        // Verify execution
        assert!(coin::balance<AptosCoin>(recipient) == 100, 0);

        // Cleanup
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }
}