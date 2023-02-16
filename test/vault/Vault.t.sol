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
contract VaultTokenHandlerTest is Test {
    WFIL public t1;
    WFIL public t2;
    WFIL public t3;
    WFIL public wfil;
    address public admin;
    Vault public vault;
    address public sender = vm.addr(1);
    uint256 public constant defaultBalance = 100000000000000;

    function setUp() public {
        wfil = new WFIL();
        t1 = new WFIL();
        t2 = new WFIL();
        t3 = new WFIL();

        admin = vm.addr(1);
        vault = new Vault(admin, address(wfil));
        vm.startPrank(sender);
        t1.deposit(sender, defaultBalance);
    }

    function test_ExternalToInternalTransferInsufficientAllowance() public  {  
        uint256 amount = 50000;

        ITokenHandler.FundTransferParam memory param = ITokenHandler.FundTransferParam(
            sender,
            ITokenHandler.ReserveType.External,
            sender,
            true
        );
        vm.expectRevert("ERC20: insufficient allowance");
        vault.sendToken(address(t1), amount, param);
    }

    function test_ExternalToInternalTransfer() public  {
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


    function test_ExternalToExternalLoopRevert() public {
        uint256 amount = 50000;

        ITokenHandler.FundTransferParam memory param = ITokenHandler.FundTransferParam(
            sender,
            ITokenHandler.ReserveType.External,
            sender,
            false
        );
        /// approve vault
        t1.approve(address(vault), amount);
        vm.expectRevert("CIRCULAR_TRANSFER");
        vault.sendToken(address(t1), amount, param);
    }

    function test_ExternalToExternal() public  {
        uint256 amount = 50000;
        address recp = vm.addr(3);

        ITokenHandler.FundTransferParam memory param = ITokenHandler.FundTransferParam(
            sender,
            ITokenHandler.ReserveType.External,
            recp,
            false
        );
        /// approve vault
        t1.approve(address(vault), amount);
        vault.sendToken(address(t1), amount, param);
        assertEq(t1.balanceOf(recp), amount);

    }


    function _deposit(address token, address sender_, uint256 amount) internal {
        ITokenHandler.FundTransferParam memory param = ITokenHandler.FundTransferParam(
            sender_,
            ITokenHandler.ReserveType.External,
            sender_,
            true
        );
        t1.approve(address(vault), amount);
        vault.sendToken(address(token), amount, param);
    }

    function test_InternalToInternalSameOriginTransfer() public {
        address recp = vm.addr(3);
        uint256 amount = 50000;
        _deposit(address(t1), sender, amount);
        ITokenHandler.FundTransferParam memory param = ITokenHandler.FundTransferParam(
            sender,
            ITokenHandler.ReserveType.Internal,
            recp,
            true
        );
        vault.sendToken(address(t1), amount, param);
        assertEq(vault.getBalance(sender, address(t1)), 0);
        assertEq(vault.getBalance(recp, address(t1)), amount);

    }

    function test_InternalDiffOriginTransferINSFAllowance() public {
        address recp = vm.addr(3);
        uint256 amount = 50000;
        _deposit(address(t1), sender, amount);
        address worker = vm.addr(4);
        vault.approve(address(t1), worker, 20);
        vm.stopPrank();
        vm.startPrank(worker);
        ITokenHandler.FundTransferParam memory param = ITokenHandler.FundTransferParam(
            sender,
            ITokenHandler.ReserveType.Internal,
            recp,
            true
        );
        bytes memory err = "SPNA";
        vm.expectRevert(err);
        vault.sendToken(address(t1), amount, param);

    }


    function test_internalDiffOriginTransferINSFBalance() public {
        address recp = vm.addr(3);
        uint256 amount = 50000;
        _deposit(address(t1), sender, amount);
        address worker = vm.addr(4);
        vault.approve(address(t1), worker, amount + 10000);
        vm.stopPrank();
        vm.startPrank(worker);
        ITokenHandler.FundTransferParam memory param = ITokenHandler.FundTransferParam(
            sender,
            ITokenHandler.ReserveType.Internal,
            recp,
            true
        );
        bytes memory err = "INSA";
        vm.expectRevert(err);
        vault.sendToken(address(t1), amount + 10000, param);
    }

    function test_internalDiffOriginTransfer() public {
        address recp = vm.addr(3);
        address worker = vm.addr(4);
        uint256 amount = 50000;
        _deposit(address(t1), sender, amount);
        vault.approve(address(t1), worker, amount);
        vm.stopPrank();
        vm.startPrank(worker);
        ITokenHandler.FundTransferParam memory param = ITokenHandler.FundTransferParam(
            sender,
            ITokenHandler.ReserveType.Internal,
            recp,
            true
        );
        vault.sendToken(address(t1), amount, param);
        assertEq(vault.getBalance(sender, address(t1)), 0);
        assertEq(vault.getBalance(recp, address(t1)), amount);
        assertFalse(vault.allowance(worker, sender, address(t1), amount));
    }

    function test_internalToExternalSameOriginTransfer() public {
        uint256 amount = 50000;
        uint256 _t1Balance = t1.balanceOf(sender);
        _deposit(address(t1), sender, amount);
        assertTrue(t1.balanceOf(sender) != _t1Balance);
        ITokenHandler.FundTransferParam memory param = ITokenHandler.FundTransferParam(
            sender,
            ITokenHandler.ReserveType.Internal,
            sender,
            false
        );

        vault.sendToken(address(t1), amount, param);
        assertEq(vault.getBalance(sender, address(t1)), 0);
        assertEq(t1.balanceOf(sender), _t1Balance);
    }

    function test_intenalToExternalDiffOriginTransfer() public {
        address worker = vm.addr(4);
        uint256 amount = 50000;
        uint256 _t1Balance = t1.balanceOf(sender);
        _deposit(address(t1), sender, amount);
        assertTrue(t1.balanceOf(sender) != _t1Balance);
        vault.approve(address(t1), worker, amount);
        vm.stopPrank();
        vm.startPrank(worker);
        ITokenHandler.FundTransferParam memory param = ITokenHandler.FundTransferParam(
            sender,
            ITokenHandler.ReserveType.Internal,
            sender,
            false
        );
        vault.sendToken(address(t1), amount, param);
        assertEq(vault.getBalance(sender, address(t1)), 0);
        assertEq(t1.balanceOf(sender), _t1Balance);
    }

    function test_bothToInternalSameOriginTransferLOOPERROR() public {
        uint256 amount = defaultBalance;
        _deposit(address(t1), sender, amount);
        ITokenHandler.FundTransferParam memory param = ITokenHandler.FundTransferParam(
            sender,
            ITokenHandler.ReserveType.Both,
            sender,
            true
        );
        vm.expectRevert("CIRCULAR_TRANSFER");
        vault.sendToken(address(t1), amount, param);
    }

    function test_bothToInternalSameOriginTransfer() public {
        address recp = vm.addr(3);
        uint256 amount = defaultBalance;
        _deposit(address(t1), sender, amount / 2);
        ITokenHandler.FundTransferParam memory param = ITokenHandler.FundTransferParam(
            sender,
            ITokenHandler.ReserveType.Both,
            recp,
            true
        );
        t1.approve(address(vault), amount);
        vault.sendToken(address(t1), amount, param);
        assertEq(vault.getBalance(sender, address(t1)), 0);
        assertEq(t1.balanceOf(sender), 0);
        assertEq(vault.getBalance(recp, address(t1)), amount);
    }


    function test_bothToExternalSameOriginTransfer() public  {
        address recp = vm.addr(3);
        uint256 amount = defaultBalance;
        _deposit(address(t1), sender, amount / 2);
        ITokenHandler.FundTransferParam memory param = ITokenHandler.FundTransferParam(
            sender,
            ITokenHandler.ReserveType.Both,
            recp,
            false
        );
        t1.approve(address(vault), amount);
        vault.sendToken(address(t1), amount, param);
        assertEq(vault.getBalance(sender, address(t1)), 0);
        assertEq(t1.balanceOf(sender), 0);
        assertEq(t1.balanceOf(recp), amount);
    }

    function test_bothToExternalDiffOriginTransferAllowanceFailure() public  {
        address recp = vm.addr(3);
        address worker = vm.addr(4);
        uint256 amount = defaultBalance;
        _deposit(address(t1), sender, amount / 2);
        vault.approve(address(t1), worker, amount / 4);
        ITokenHandler.FundTransferParam memory param = ITokenHandler.FundTransferParam(
            sender,
            ITokenHandler.ReserveType.Both,
            recp,
            false
        );
        t1.approve(address(vault), amount);
        vm.stopPrank();
        vm.startPrank(worker);
        bytes memory err = "SPNA";
        vm.expectRevert(err);
        vault.sendToken(address(t1), amount, param);
    }

    function test_bothToExternalDiffOriginTransferAllowanceSuccess() public  {
        address recp = vm.addr(3);
        address worker = vm.addr(4);
        uint256 amount = defaultBalance;
        _deposit(address(t1), sender, amount / 2);
        vault.approve(address(t1), worker, amount / 2);
        ITokenHandler.FundTransferParam memory param = ITokenHandler.FundTransferParam(
            sender,
            ITokenHandler.ReserveType.Both,
            recp,
            false
        );
        t1.approve(address(vault), amount);

        vm.stopPrank();
        vm.startPrank(worker);
        vault.sendToken(address(t1), amount, param);
        assertEq(vault.getBalance(sender, address(t1)), 0);
        assertEq(t1.balanceOf(sender), 0);
        assertEq(t1.balanceOf(recp), amount);
    }

    function test_bothToInternalDiffOriginTransferAllowanceSuccess() public  {
        address recp = vm.addr(3);
        address worker = vm.addr(4);
        uint256 amount = defaultBalance;
        _deposit(address(t1), sender, amount / 2);
        vault.approve(address(t1), worker, amount / 2);
        ITokenHandler.FundTransferParam memory param = ITokenHandler.FundTransferParam(
            sender,
            ITokenHandler.ReserveType.Both,
            recp,
            true
        );
        t1.approve(address(vault), amount);

        vm.stopPrank();
        vm.startPrank(worker);
        vault.sendToken(address(t1), amount, param);
        assertEq(vault.getBalance(sender, address(t1)), 0);
        assertEq(t1.balanceOf(sender), 0);
        assertEq(vault.getBalance(recp, address(t1)), amount);
    }
}