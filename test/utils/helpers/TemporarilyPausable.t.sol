//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@almight/modules/forge-std/src/Test.sol";
import "../../../protocols/utils/contracts/helpers/TemporarilyPausable.sol";

contract DummyPausableContract is TemporarilyPausable {


    function pause() public {
        _pause();
    }

    constructor(uint256 pauseDuration) TemporarilyPausable(pauseDuration) {}


    function add(uint256 a, uint256 b) public view whenNotPaused returns(uint256) {
        return a + b;
    }


    function unpause() public {
        _unpause();
    }
}


contract TemporarilyPausableTest is Test {

    function test_ranomPauseDurations(uint256 duration) public {
        DummyPausableContract pauser = new DummyPausableContract(duration);
        assertEq(pauser.add(4, 5), 9);
        pauser.pause();
        vm.expectRevert();
        pauser.add(4,5);
    }

    function test_randomPauseDurationTimeWarp(uint32 duration) public  {
        DummyPausableContract pauser = new DummyPausableContract(duration);
        assertEq(pauser.add(4, 5), 9);
        pauser.pause();
        if (duration == 0) {
            assertTrue(pauser.paused());
            return;
        }
        assertTrue(pauser.paused());
        if(duration > pauser.MAX_PAUSE_DURATION()) {
            vm.warp(block.timestamp + pauser.MAX_PAUSE_DURATION());
            assertFalse(pauser.paused());
            return;
        }
        vm.warp(block.timestamp + duration);
        assertFalse(pauser.paused());

    }
}