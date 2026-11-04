// SPDX-License-Identifier:MIT
pragma solidity ^0.8.31;

contract Escrow {
    // custom errors
    error Escrow__OnlyBuyer();
    error Escrow__OnlySeller();
    error Escrow__OnlyBuyerOrSeller();
    error Escrow__OnlyArbiter();
    error Escrow__NoDisputeRaised();
    error Escrow__TransferFailed();

    address public buyer;
    address public seller;
    address public arbiter;

    uint256 public amount;

    bool public isBuyerApproved;
    bool public isSellerApproved;

    bool public isDisputeRaised;

    // constructor
    constructor(address _buyer, address _seller, address _arbiter) payable {
        buyer = _buyer;
        seller = _seller;
        arbiter = _arbiter;
        amount = msg.value;
    }

    // buyer approves the release of funds

    function approveByBuyer() external {
        if (msg.sender != buyer) revert Escrow__OnlyBuyer();
        isBuyerApproved = true;
        releasIfAgreed();
    }

    // seller approves the release of funds
    function approveBySeller() external {
        if (msg.sender != seller) revert Escrow__OnlySeller();
        isSellerApproved = true;
        releasIfAgreed();
    }

    // arbiter resolves the dispute
    function resolveDispute(bool _approveForSeller) external {
        if (msg.sender != arbiter) revert Escrow__OnlyArbiter();
        if (!isDisputeRaised) revert Escrow__NoDisputeRaised();

        if (_approveForSeller) {
            (bool success,) = seller.call{value: amount}("");
            if (!success) revert Escrow__TransferFailed();
        } else {
            (bool success,) = buyer.call{value: amount}("");
            if (!success) revert Escrow__TransferFailed();
        }
    }

    // if both parties approve, release funds
    function releasIfAgreed() internal {
        if (isBuyerApproved && isSellerApproved && !isDisputeRaised) {
            (bool success,) = seller.call{value: amount}("");
            if (!success) revert Escrow__TransferFailed();
        }
    }

    // if no agreement, raise dispute

    function raiseDispute() external {
        if (msg.sender != buyer && msg.sender != seller) revert Escrow__OnlyBuyerOrSeller();
        isDisputeRaised = true;
    }

    //
}
