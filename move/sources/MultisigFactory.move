module MultisigAddr::MultisigFactory {
    use std::signer;
    use std::vector;
    use aptos_std::table::{Self, Table};
    use aptos_framework::account;
    use aptos_framework::event;
    use MultisigAddr::Multisig;

    // Struct to hold the factory data
    struct MultisigFactory has key {
        owner: address,
        deployments: Table<address, vector<address>>,
        contract_deployed_events: event::EventHandle<ContractDeployedEvent>,
    }

    // Event definitions
    struct ContractDeployedEvent has drop, store {
        deployer: address,
        deployed_contract: address,
    }

    // Error codes
    const ERROR_NOT_OWNER: u64 = 1;
    const ERROR_FACTORY_NOT_INITIALIZED: u64 = 2;

    // Initialize the MultisigFactory
    public fun initialize(account: &signer) {
        let account_addr = signer::address_of(account);
        assert!(!exists<MultisigFactory>(account_addr), ERROR_FACTORY_NOT_INITIALIZED);

        let factory = MultisigFactory {
            owner: account_addr,
            deployments: table::new(),
            contract_deployed_events: account::new_event_handle<ContractDeployedEvent>(account),
        };
        move_to(account, factory);
    }

    // Deploy a new contract
    public entry fun deploy_contract(account: &signer, owners: vector<address>, required_signatures: u64) acquires MultisigFactory {
        let sender = signer::address_of(account);
        let factory = borrow_global_mut<MultisigFactory>(@MultisigAddr);
        
        let deployed_contract = Multisig::create_multisig(account, owners, required_signatures);
        
        if (!table::contains(&factory.deployments, sender)) {
            table::add(&mut factory.deployments, sender, vector::empty<address>());
        };
        let deployments = table::borrow_mut(&mut factory.deployments, sender);
        vector::push_back(deployments, deployed_contract);

        event::emit_event(&mut factory.contract_deployed_events, ContractDeployedEvent {
            deployer: sender,
            deployed_contract,
        });
    }

    // Get deployed contracts
    #[view]
    public fun get_deployed(deployer: address): vector<address> acquires MultisigFactory {
        let factory = borrow_global<MultisigFactory>(@MultisigAddr);
        if (table::contains(&factory.deployments, deployer)) {
            *table::borrow(&factory.deployments, deployer)
        } else {
            vector::empty<address>()
        }
    }

    // Count deployed contracts
    #[view]
    public fun count_deployed(deployer: address): u64 acquires MultisigFactory {
        let factory = borrow_global<MultisigFactory>(@MultisigAddr);
        if (table::contains(&factory.deployments, deployer)) {
            vector::length(table::borrow(&factory.deployments, deployer))
        } else {
            0
        }
    }
}