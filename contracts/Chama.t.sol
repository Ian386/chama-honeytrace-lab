// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Chama} from "./Chama.sol";
import {Test} from "forge-std/Test.sol";

contract ChamaTest is Test {
    Chama chama;
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    event Deposited(address indexed member, uint256 amount);

    function setUp() public {
        chama = new Chama();
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    function test_TreasurerIsDeployer() public view {
        require(chama.treasurer() == address(this), "Treasurer should be deployer");
    }

    function test_DepositUpdatesBalancesAndEmits() public {
        vm.expectEmit(true, false, false, true);
        emit Deposited(alice, 1 ether);
        vm.prank(alice);
        chama.deposit{value: 1 ether}();

        require(chama.balances(alice) == 1 ether, "Alice balance");
        require(chama.totalSavings() == 1 ether, "Total savings");
        require(chama.contractBalance() == 1 ether, "Contract holds the ETH");
    }

    function test_ZeroDepositReverts() public {
        vm.prank(alice);
        vm.expectRevert(bytes("Deposit must be more than zero"));
        chama.deposit{value: 0}();
    }

    function test_TransferMovesSavingsNotEth() public {
        vm.prank(alice);
        chama.deposit{value: 2 ether}();
        vm.prank(alice);
        chama.transferTo(bob, 0.5 ether);

        require(chama.balances(alice) == 1.5 ether, "Alice after transfer");
        require(chama.balances(bob) == 0.5 ether, "Bob after transfer");
        require(chama.contractBalance() == 2 ether, "ETH stays in contract");
    }

    function test_WithdrawSendsEthBack() public {
        vm.prank(alice);
        chama.deposit{value: 2 ether}();
        uint256 before = alice.balance;

        vm.prank(alice);
        chama.withdraw(1 ether);

        require(alice.balance == before + 1 ether, "Alice received ETH");
        require(chama.totalSavings() == 1 ether, "Total reduced");
        require(chama.contractBalance() == chama.totalSavings(), "Books balance");
    }

    function test_OverdrawRevertsWithCustomError() public {
        vm.prank(alice);
        chama.deposit{value: 1 ether}();
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Chama.InsufficientBalance.selector, 2 ether, 1 ether));
        chama.withdraw(2 ether);
    }
}
