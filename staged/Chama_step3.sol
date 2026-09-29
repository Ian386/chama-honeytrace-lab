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
    event Transferred(address indexed from, address indexed to, uint256 amount);
    event Withdrawn(address indexed member, uint256 amount);

    // ---- Custom error (cheaper and more informative than a string) ----
    error InsufficientBalance(uint256 requested, uint256 available);

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

    /// Move savings to another member. No ETH leaves the contract.
    function transferTo(address to, uint256 amount) external {
        require(to != address(0), "Invalid recipient");
        uint256 available = balances[msg.sender];
        if (amount > available) revert InsufficientBalance(amount, available);

        balances[msg.sender] = available - amount;
        balances[to] += amount;
        emit Transferred(msg.sender, to, amount);
    }

    /// Take ETH out of the chama back to your wallet.
    function withdraw(uint256 amount) external {
        uint256 available = balances[msg.sender];
        if (amount > available) revert InsufficientBalance(amount, available);

        // Update state BEFORE sending ETH (checks-effects-interactions).
        balances[msg.sender] = available - amount;
        totalSavings -= amount;

        (bool sent, ) = payable(msg.sender).call{value: amount}("");
        require(sent, "ETH transfer failed");
        emit Withdrawn(msg.sender, amount);
    }

    /// ETH physically held by the contract. Should always equal totalSavings.
    function contractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
