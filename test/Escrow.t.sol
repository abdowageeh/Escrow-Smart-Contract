// SPDX-License-Identifier:MIT
pragma solidity ^0.8.31;

import {Test} from "forge-std/Test.sol";
import {Escrow} from "../src/Escrow.sol";

// @dev helper contract empty without receive() or fallback()
//      to reject ether transfer using call method
//      so that we can trigger custom error Escrow__TransferFailed.
contract RejectEther {
    // Empty contract intentionally no receive() or fallback() function to reject ether
}

contract EscrowTest is Test {
    Escrow public escrow;

    address public buyer = makeAddr("buyer");
    address public seller = makeAddr("seller");
    address public arbiter = makeAddr("arbiter");

    uint256 public constant AMOUNT = 1 ether;

    function setUp() public {
        escrow = new Escrow{value: AMOUNT}(buyer, seller, arbiter);
    }

    /*/////////////////////////////////
                CONSTRUCTOR
    /////////////////////////////////*/

    function test_Constructor() public view {
        assertEq(escrow.buyer(), buyer);
        assertEq(escrow.seller(), seller);
        assertEq(escrow.arbiter(), arbiter);
        assertEq(escrow.amount(), AMOUNT);
        assertEq(address(escrow).balance, AMOUNT);
        assertFalse(escrow.isBuyerApproved());
        assertFalse(escrow.isSellerApproved());
        assertFalse(escrow.isDisputeRaised());
    }

    /*/////////////////////////////////
                APPROVE BY BUYER
    /////////////////////////////////*/
    function test_ApproveByBuyer_RevertIfNotBuyer() public {
        vm.prank(seller);
        vm.expectRevert(Escrow.Escrow__OnlyBuyer.selector);
        escrow.approveByBuyer();
    }

    function test_ApproveByBuyer_NoReleaseWhenSellerHasNotApproved() public {
        vm.prank(buyer);
        escrow.approveByBuyer();

        assertTrue(escrow.isBuyerApproved());
        assertFalse(escrow.isSellerApproved());
        assertEq(address(escrow).balance, AMOUNT);
        assertEq(seller.balance, 0);
    }

    /*/////////////////////////////////
                APPROVE BY SELLER
    /////////////////////////////////*/
    function test_ApproveBySeller_RevertIfNotSeller() public {
        vm.prank(buyer);
        vm.expectRevert(Escrow.Escrow__OnlySeller.selector);
        escrow.approveBySeller();
    }

    function test_ApproveBySeller_NoReleaseWhenSellerHasNotApproved() public {
        vm.prank(seller);
        escrow.approveBySeller();

        assertTrue(escrow.isSellerApproved());
        assertFalse(escrow.isBuyerApproved());
        assertEq(address(escrow).balance, AMOUNT);
        assertEq(seller.balance, 0);
    }

    /*/////////////////////////////////
                Release if agreed
    /////////////////////////////////*/

    function test_Release_WhenBuyerThenSellerApprove_TransferFundsToSeller() public {
        uint256 sellerBalanceBefore = seller.balance;

        vm.prank(buyer);
        escrow.approveByBuyer();

        vm.prank(seller);
        escrow.approveBySeller();

        assertEq(address(escrow).balance, 0);
        assertEq(seller.balance, sellerBalanceBefore + AMOUNT);
    }

    function test_Release_WhenSellerThenBuyerApprove_TransferFundsToSeller() public {
        uint256 sellerBalanceBefore = seller.balance;

        vm.prank(seller);
        escrow.approveBySeller();

        vm.prank(buyer);
        escrow.approveByBuyer();

        assertEq(address(escrow).balance, 0);
        assertEq(seller.balance, sellerBalanceBefore + AMOUNT);
    }

    function test_Release_DoesNotHappen_WhenDisputeRaised() public {
        uint256 sellerBalanceBefore = seller.balance;

        vm.prank(buyer);
        escrow.approveByBuyer();

        vm.prank(buyer);
        escrow.raiseDispute();

        vm.prank(seller);
        escrow.approveBySeller();

        assertTrue(escrow.isBuyerApproved());
        assertTrue(escrow.isSellerApproved());
        assertTrue(escrow.isDisputeRaised());
        assertEq(address(escrow).balance, AMOUNT);
        assertEq(seller.balance, sellerBalanceBefore);
    }

    function test_Release_RevertOnTransferFailed_WhenSellerCanNotReceiveEther() public {
        RejectEther badSeller = new RejectEther();

        Escrow badEscrow = new Escrow{value: AMOUNT}(buyer, address(badSeller), arbiter);

        vm.prank(buyer);
        badEscrow.approveByBuyer();

        vm.prank(address(badSeller));
        vm.expectRevert(Escrow.Escrow__TransferFailed.selector);
        badEscrow.approveBySeller();
    }

    /*/////////////////////////////////
                Raise Dispute
    /////////////////////////////////*/

    function test_RaiseDispute_RevertIfNotBuyerOrSeller() public {
        vm.prank(arbiter);
        vm.expectRevert(Escrow.Escrow__OnlyBuyerOrSeller.selector);
        escrow.raiseDispute();
    }

    function test_RaiseDispute_ByBuyer() public {
        vm.prank(buyer);
        escrow.raiseDispute();
        assertTrue(escrow.isDisputeRaised());
    }

    function test_RaiseDispute_BySeller() public {
        vm.prank(seller);
        escrow.raiseDispute();
        assertTrue(escrow.isDisputeRaised());
    }

    /*/////////////////////////////////
        Resolve Dispute
    /////////////////////////////////*/

    function test_ResolveDispute_RevertIfNotArbiter() public {
        vm.prank(buyer);
        escrow.raiseDispute();

        vm.prank(buyer);
        vm.expectRevert(Escrow.Escrow__OnlyArbiter.selector);
        escrow.resolveDispute(false);
    }

    function test_ResolveDispute_RevertIfNoDisputeRaised() public {
        vm.prank(arbiter);
        vm.expectRevert(Escrow.Escrow__NoDisputeRaised.selector);
        escrow.resolveDispute(true);
    }

    function test_ResolveDispute_ApproveForSeller() public {
        uint256 sellerBalanceBefore = seller.balance;

        vm.prank(buyer);
        escrow.raiseDispute();

        vm.prank(arbiter);
        escrow.resolveDispute(true);

        assertEq(address(escrow).balance, 0);
        assertEq(seller.balance, sellerBalanceBefore + AMOUNT);
    }

    function test_ResolveDispute_ApproveForBuyer() public {
        uint256 buyerBalanceBefore = buyer.balance;

        vm.prank(buyer);
        escrow.raiseDispute();

        vm.prank(arbiter);
        escrow.resolveDispute(false);

        assertEq(address(escrow).balance, 0);
        assertEq(buyer.balance, buyerBalanceBefore + AMOUNT);
    }

    function test_ResolveDispute_RevertOnTransferFailed_ToSeller() public {
        RejectEther badSeller = new RejectEther();

        Escrow badEscrow = new Escrow{value: AMOUNT}(buyer, address(badSeller), arbiter);

        vm.prank(buyer);
        badEscrow.raiseDispute();

        vm.prank(arbiter);
        vm.expectRevert(Escrow.Escrow__TransferFailed.selector);
        badEscrow.resolveDispute(true);
    }

    function test_ResolveDispute_RevertOnTransferFailed_ToBuyer() public {
        RejectEther badBuyer = new RejectEther();

        Escrow badEscrow = new Escrow{value: AMOUNT}(address(badBuyer), seller, arbiter);

        vm.prank(address(badBuyer));
        badEscrow.raiseDispute();

        vm.prank(arbiter);
        vm.expectRevert(Escrow.Escrow__TransferFailed.selector);
        badEscrow.resolveDispute(false);
    }
}
