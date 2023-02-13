//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@almight/modules/forge-std/src/Test.sol";
import "../../../protocols/utils/contracts/helpers/NoDelegateCall.sol";


contract DummyContract is NoDelegateCall {

    function addSum(uint256 a, uint256 b) external view returns(address, uint256) {
        return (address(this), a + b);
    }

}


contract NoDelegateCallTest is Test {

    address public ctr;

    function setUp() public {
        ctr = address(new DummyContract());
    }

    function test_withoutDelegateCall() public {
        (address addr, ) = DummyContract(ctr).addSum(4, 3);
        assertEq(addr, ctr);
    }

    function test_withDelegateCall() public  {
        vm.expectRevert();
        (bool success, ) = ctr.delegatecall(
            abi.encodeWithSignature("addSum(uint256,uint256)", 4, 3)
        );
        assertFalse(success);

    }



}
