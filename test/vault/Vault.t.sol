//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@almight/modules/forge-std/src/Test.sol";
import "../../protocols/vault/contracts/Vault.sol";


import "@almight/contract-interfaces/contracts/vault/ITokenHandler.sol";
import "@almight/modules/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

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
contract VaultTokenHandlerTest is Test {
    WFIL public t1;
    WFIL public t2;
    WFIL public t3;
    WFIL public wfil;
    address public admin;
    Vault public vault;

    function setUp() public {
        wfil = new WFIL();
        t1 = new WFIL();
        t2 = new WFIL();
        t3 = new WFIL();

        admin = vm.addr(1);
        vault = new Vault(admin, address(wfil));

    }

    function test_ExternalToInternalTransferInsufficientAllowance() public  {
        address sender = vm.addr(2);
        vm.startPrank(sender);
        t1.deposit(sender, 100000000000000);
        uint256 amount = 50000;

        ITokenHandler.FundTransferParam memory param = ITokenHandler.FundTransferParam(
            sender,
            ITokenHandler.ReserveType.External,
            sender,
            true
        );
        vm.expectRevert();
        vault.sendToken(address(t1), amount, param);
    }

    function test_ExternalToInternalTransfer() public  {
        address sender = vm.addr(2);
        vm.startPrank(sender);
        t1.deposit(sender, 100000000000000);
        uint256 amount = 50000;

        ITokenHandler.FundTransferParam memory param = ITokenHandler.FundTransferParam(
            sender,
            ITokenHandler.ReserveType.External,
            sender,
            true
        );
        /// aprove vault
        t1.approve(address(vault), amount);
        vault.sendToken(address(t1), amount, param);
        assertEq(vault.getBalance(sender, address(t1)), amount);

    }



}