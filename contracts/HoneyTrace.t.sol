// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {HoneyTrace} from "./HoneyTrace.sol";
import {Test} from "forge-std/Test.sol";

contract HoneyTraceTest is Test {
    HoneyTrace trace;
    address processor = makeAddr("processor");
    address outsider = makeAddr("outsider");

    function setUp() public {
        trace = new HoneyTrace();
    }

    function _stage(uint256 id) internal view returns (HoneyTrace.Stage s) {
        (, , , s, , ) = trace.batches(id);
    }

    function test_DeployerIsAdminAndHandler() public view {
        require(trace.admin() == address(this), "Admin");
        require(trace.isHandler(address(this)), "Admin is a handler");
    }

    function test_CreateBatchStartsHarvested() public {
        uint256 id = trace.createBatch("Kitui, group A");
        require(id == 1, "First id is 1");
        require(_stage(id) == HoneyTrace.Stage.Harvested, "Starts Harvested");
    }

    function test_OutsiderCannotCreateBatch() public {
        vm.prank(outsider);
        vm.expectRevert(abi.encodeWithSelector(HoneyTrace.NotHandler.selector, outsider));
        trace.createBatch("Fake honey");
    }

    function test_OnlyAdminAddsHandlers() public {
        vm.prank(outsider);
        vm.expectRevert(HoneyTrace.NotAdmin.selector);
        trace.addHandler(outsider);
    }

    function test_HandlerAdvancesAndBecomesHolder() public {
        uint256 id = trace.createBatch("Kitui, group A");
        trace.addHandler(processor);
        vm.prank(processor);
        trace.advanceStage(id);

        (, , address holder, HoneyTrace.Stage s, , ) = trace.batches(id);
        require(s == HoneyTrace.Stage.Processed, "Now Processed");
        require(holder == processor, "Processor holds it");
    }

    function test_FullJourneyThenStops() public {
        uint256 id = trace.createBatch("Kitui, group A");
        for (uint256 i = 0; i < 4; i++) trace.advanceStage(id);
        require(_stage(id) == HoneyTrace.Stage.Delivered, "Delivered");

        vm.expectRevert(abi.encodeWithSelector(HoneyTrace.AlreadyDelivered.selector, id));
        trace.advanceStage(id);
    }

    function test_UnknownBatchReverts() public {
        vm.expectRevert(abi.encodeWithSelector(HoneyTrace.BatchNotFound.selector, 99));
        trace.advanceStage(99);
    }
}
