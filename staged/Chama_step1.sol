// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title Chama: a group savings wallet
/// @notice Members deposit ETH, move savings to each other, and withdraw.
contract Chama {
    // ---- State ----
    address public treasurer;                    // who deployed the chama
    mapping(address => uint256) public balances; // member => savings in wei
    uint256 public totalSavings;                 // sum of all balances

    // ---- Events (the contract's public receipts) ----
    event Deposited(address indexed member, uint256 amount);

    constructor() {
        treasurer = msg.sender;
    }

    /// Send ETH with this call (use the VALUE field in Remix).
    function deposit() external payable {
        require(msg.value > 0, "Deposit must be more than zero");
        balances[msg.sender] += msg.value;
        totalSavings += msg.value;
        emit Deposited(msg.sender, msg.value);
    }
}
