//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@almight/modules/forge-std/src/Test.sol";
import "../../protocols/vault/contracts/Vault.sol";


import "@almight/contract-interfaces/contracts/vault/ITokenHandler.sol";
import "@almight/modules/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

//solhint-disable func-name-mixedcase

contract WFIL is ERC20 {

    constructor() ERC20("Wrapped Filecoin", "WFIL") {}


    function deposit(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function withdraw(uint256 amount) external {
        _burn(msg.sender, amount);
        (bool success, ) = address(msg.sender).call{value: amount}(new bytes(0));
        require(success, "Failed");
    }
}

/// Good works
contract VaultAuthorizerTest is Test {
    WFIL public t1;
    WFIL public t2;
    WFIL public t3;
    WFIL public wfil;
    address public admin;
    Vault public vault;
    address public sender = vm.addr(2);
    uint256 public constant defaultBalance = 100000000000000;

    function setUp() public {
        wfil = new WFIL();
        t1 = new WFIL();
        t2 = new WFIL();
        t3 = new WFIL();

        admin = vm.addr(1);
        vault = new Vault(admin, address(wfil));
        vm.prank(sender);
        t1.deposit(sender, defaultBalance);
    }
    function test_canAdminPerform() public  {
        assertTrue(vault.canPerform(vault.REGISTER_CONTROLLER_ACTION_ID(), admin, address(vault)));
    }

    function test_canPerform(address random) public  {
        if (random == address(0) || random == admin) {
            return;
        }
        assertFalse(vault.canPerform(vault.REGISTER_CONTROLLER_ACTION_ID(), random, address(vault)));
    }

    function test_pauseFailure(address random) public {
        if (random == address(0) || random == admin) {
            return;
        }
        bytes memory err = "UNAUTHORIZED";
        vm.prank(random);
        vm.expectRevert(err);
        vault.pause();
    }

    function test_pauseSuccess() public {
        vm.prank(admin);
        vault.pause();
        assertTrue(vault.paused());
        ITokenHandler.FundTransferParam memory param = ITokenHandler.FundTransferParam(
            sender,
            ITokenHandler.ReserveType.External,
            sender,
            true
        );
        vm.expectRevert();
        vault.sendToken(address(t1), 1000, param);
    }


    function test_registerControllerFailure() public {
        bytes memory err = "UNAUTHORIZED";
        vm.expectRevert(err);
        vault.registerController(vm.addr(6));
    }

    function test_registerController() public {
        address controller = vm.addr(6);
        vm.prank(admin);
        vault.registerController(controller);
        assertTrue(vault.isControllerRegisterd(controller));
    }
}