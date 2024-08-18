#[test_only]
module MultisigAddr::MultisigFactoryTests {
    use std::signer;
    use std::vector;
    use aptos_framework::account;
    use MultisigAddr::account_addr;

    #[test(aptos_framework = @0x1, factory_admin = @0xABC, user1 = @0x123, user2 = @0x456, user3 = @0x789)]
    public entry fun test_multisig_factory_deployment(
        aptos_framework: &signer,
        factory_admin: &signer,
        user1: &signer,
        user2: &signer,
        user3: &signer
    ) {
        // Setup: Initialize the Aptos framework
        account::create_account_for_test(@aptos_framework);

        // Step 1: Create accounts
        let factory_admin_addr = signer::address_of(factory_admin);
        account::create_account_for_test(factory_admin_addr);

        let user1_addr = signer::address_of(user1);
        account::create_account_for_test(user1_addr);

        let user2_addr = signer::address_of(user2);
        account::create_account_for_test(user2_addr);

        let user3_addr = signer::address_of(user3);
        account::create_account_for_test(user3_addr);

        // Step 2: Initialize the MultisigFactory
        MultisigFactory::initialize(factory_admin);

        // Step 3: Deploy a new Multisig contract
        let owners = vector::empty<address>();
        vector::push_back(&mut owners, user1_addr);
        vector::push_back(&mut owners, user2_addr);
        vector::push_back(&mut owners, user3_addr);
        let required_signatures = 2;

        MultisigFactory::deploy_contract(user1, owners, required_signatures);

        // Step 4: Verify the deployment
        let deployed_contracts = MultisigFactory::get_deployed(user1_addr);
        assert!(vector::length(&deployed_contracts) == 1, 0);

        let count = MultisigFactory::count_deployed(user1_addr);
        assert!(count == 1, 1);

        // Step 5: Deploy another contract and verify
        MultisigFactory::deploy_contract(user1, owners, required_signatures);

        let deployed_contracts = MultisigFactory::get_deployed(user1_addr);
        assert!(vector::length(&deployed_contracts) == 2, 2);

        let count = MultisigFactory::count_deployed(user1_addr);
        assert!(count == 2, 3);

        // Step 6: Verify no deployments for other users
        let user2_deployments = MultisigFactory::get_deployed(user2_addr);
        assert!(vector::is_empty(&user2_deployments), 4);

        let user2_count = MultisigFactory::count_deployed(user2_addr);
        assert!(user2_count == 0, 5);
    }
}