
module MultisigAddr::Multisig {
    // 
    use std::vector;
    use std::signer;
    use aptos_framework::account;
    use aptos_framework::event;
    use aptos_framework::coin;
    use aptos_std::table::{Self, Table};
    use aptos_framework::aptos_coin::AptosCoin;

    // Struct definitions
    struct Multisig has key {
        required_signatures: u64,
        owners: vector<address>,
        transactions: vector<Transaction>,
        transaction_created_events: event::EventHandle<TransactionCreatedEvent>,
        transaction_signed_events: event::EventHandle<TransactionSignedEvent>,
        transaction_executed_events: event::EventHandle<TransactionExecutedEvent>,
    }

    struct Transaction has store {
        to: address,
        value: u64,
        data: vector<u8>,
        executed: bool,
        signatures: Table<address, bool>,
    }

    // Event definitions
    struct TransactionCreatedEvent has drop, store {
        transaction_id: u64,
        to: address,
        value: u64,
        data: vector<u8>,
    }

    struct TransactionSignedEvent has drop, store {
        transaction_id: u64,
        signer: address,
    }

    struct TransactionExecutedEvent has drop, store {
        transaction_id: u64,
        executer: address,
    }

    // Error codes
    const ERROR_NOT_INITIALIZED: u64 = 1;
    const ERROR_ALREADY_INITIALIZED: u64 = 2;
    const ERROR_INVALID_OWNER_COUNT: u64 = 3;
    const ERROR_INVALID_REQUIRED_SIGNATURES: u64 = 4;
    const ERROR_NOT_OWNER: u64 = 5;
    const ERROR_INVALID_DESTINATION: u64 = 6;
    const ERROR_INVALID_TRANSACTION_ID: u64 = 7;
    const ERROR_TRANSACTION_ALREADY_EXECUTED: u64 = 8;
    const ERROR_ALREADY_SIGNED: u64 = 9;
    const ERROR_INSUFFICIENT_SIGNATURES: u64 = 10;
    const ERROR_INSUFFICIENT_FUNDS: u64 = 11;

    // Initialize the Multisig contract
    fun initialize(account: &signer, owners: vector<address>, required_signatures: u64) {
        let account_addr = signer::address_of(account);
        assert!(!exists<Multisig>(account_addr), ERROR_ALREADY_INITIALIZED);
        assert!(vector::length(&owners) > 0, ERROR_INVALID_OWNER_COUNT);
        assert!(required_signatures > 0 && required_signatures <= vector::length(&owners), ERROR_INVALID_REQUIRED_SIGNATURES);

        let multisig = Multisig {
            required_signatures,
            owners,
            transactions: vector::empty(),
            transaction_created_events: account::new_event_handle<TransactionCreatedEvent>(account),
            transaction_signed_events: account::new_event_handle<TransactionSignedEvent>(account),
            transaction_executed_events: account::new_event_handle<TransactionExecutedEvent>(account),
        };
        move_to(account, multisig);
    }

    // Create a new multisig instance
    public fun create_multisig(account: &signer, owners: vector<address>, required_signatures: u64): address {
        let salt = bcs::to_bytes(&owners);
        vector::append(&mut salt, bcs::to_bytes(&required_signatures));
        let (resource_signer, _) = account::create_resource_account(account, salt);
        let resource_addr = signer::address_of(&resource_signer);
        
        initialize(&resource_signer, owners, required_signatures);
        resource_addr
    }

    // Submit a transaction
    public entry fun submit_transaction(account: &signer, to: address, value: u64, data: vector<u8>) acquires Multisig {
        let sender = signer::address_of(account);
        let multisig = borrow_global_mut<Multisig>(sender);
        
        assert!(is_owner(sender, &multisig.owners), ERROR_NOT_OWNER);
        assert!(to != @0x0, ERROR_INVALID_DESTINATION);

        let transaction_id = vector::length(&multisig.transactions);
        let transaction = Transaction {
            to,
            value,
            data,
            executed: false,
            signatures: table::new(),
        };
        vector::push_back(&mut multisig.transactions, transaction);

        event::emit_event(&mut multisig.transaction_created_events, TransactionCreatedEvent {
            transaction_id,
            to,
            value,
            data,
        });
    }

    // Sign a transaction
    public entry fun sign_transaction(account: &signer, transaction_id: u64) acquires Multisig {
        let sender = signer::address_of(account);
        let multisig = borrow_global_mut<Multisig>(sender);
        
        assert!(transaction_id < vector::length(&multisig.transactions), ERROR_INVALID_TRANSACTION_ID);
        let transaction = vector::borrow_mut(&mut multisig.transactions, transaction_id);
        assert!(!transaction.executed, ERROR_TRANSACTION_ALREADY_EXECUTED);
        assert!(is_owner(sender, &multisig.owners), ERROR_NOT_OWNER);
        assert!(!table::contains(&transaction.signatures, sender), ERROR_ALREADY_SIGNED);

        table::add(&mut transaction.signatures, sender, true);

        event::emit_event(&mut multisig.transaction_signed_events, TransactionSignedEvent {
            transaction_id,
            signer: sender,
        });

        if (count_signatures(transaction) == multisig.required_signatures) {
            execute_transaction(multisig, transaction_id);
        };
    }

    // Execute a transaction (private function)
    fun execute_transaction(multisig: &mut Multisig, transaction_id: u64) {
        let multisig_addr = signer::address_of(multisig);
        let transaction = vector::borrow_mut(&mut multisig.transactions, transaction_id);
        assert!(!transaction.executed, ERROR_TRANSACTION_ALREADY_EXECUTED);
        assert!(count_signatures(transaction) >= multisig.required_signatures, ERROR_INSUFFICIENT_SIGNATURES);

        transaction.executed = true;

        // Transfer funds
        assert!(coin::balance<AptosCoin>(multisig_addr) >= transaction.value, ERROR_INSUFFICIENT_FUNDS);
        coin::transfer<AptosCoin>(multisig_addr, transaction.to, transaction.value);

        event::emit_event(&mut multisig.transaction_executed_events, TransactionExecutedEvent {
            transaction_id,
            executer: multisig_addr,
        });
    }

    // Helper functions
    fun is_owner(account: address, owners: &vector<address>): bool {
        vector::contains(owners, &account)
    }

    fun count_signatures(transaction: &Transaction): u64 {
        table::length(&transaction.signatures)
    }

    // Public view functions
    #[view]
    public fun get_transaction(multisig_address: address, transaction_id: u64): (address, u64, vector<u8>, bool, u64) acquires Multisig {
        let multisig = borrow_global<Multisig>(multisig_address);
        assert!(transaction_id < vector::length(&multisig.transactions), ERROR_INVALID_TRANSACTION_ID);

        let transaction = vector::borrow(&multisig.transactions, transaction_id);
        (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            count_signatures(transaction)
        )
    }

    #[view]
    public fun get_owners(multisig_address: address): vector<address> acquires Multisig {
        let multisig = borrow_global<Multisig>(multisig_address);
        multisig.owners
    }

    #[view]
    public fun get_required_signatures(multisig_address: address): u64 acquires Multisig {
        let multisig = borrow_global<Multisig>(multisig_address);
        multisig.required_signatures
    }
}