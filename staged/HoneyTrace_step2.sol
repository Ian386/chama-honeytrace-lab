// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title HoneyTrace: farm-to-shelf traceability for honey batches
/// @notice Approved handlers create batches and move them through fixed stages.
contract HoneyTrace {
    // ---- Types ----
    enum Stage { Harvested, Processed, Packaged, Shipped, Delivered } // 0..4

    struct Batch {
        uint256 id;
        string origin;          // e.g. "Kitui, beekeeper group A"
        address currentHolder;  // last handler to touch the batch
        Stage stage;
        uint256 updatedAt;      // block timestamp of last update
        bool exists;
    }

    // ---- State ----
    address public admin;
    mapping(address => bool) public isHandler;
    mapping(uint256 => Batch) public batches;
    uint256 public nextBatchId = 1;

    // ---- Events: together they form the batch's audit trail ----
    event HandlerAdded(address indexed handler);

    // ---- Custom errors ----
    error NotAdmin();
    error NotHandler(address caller);
    error BatchNotFound(uint256 id);
    error AlreadyDelivered(uint256 id);

    // ---- Modifiers: reusable access checks ----
    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    modifier onlyHandler() {
        if (!isHandler[msg.sender]) revert NotHandler(msg.sender);
        _;
    }

    constructor() {
        admin = msg.sender;
        isHandler[msg.sender] = true;
    }

    function addHandler(address handler) external onlyAdmin {
        isHandler[handler] = true;
        emit HandlerAdded(handler);
    }
}
