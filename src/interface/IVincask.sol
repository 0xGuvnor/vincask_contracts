// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IVincask {
    error Vincask__MaxSupplyExceeded();
    error Vincask__MustMintAtLeastOne();
    error Vincask__MustApproveAtLeastOne();
    error Vincask__PaymentFailed();
    error Vincask__CallerNotAuthorised();
    error Vincask__MustSetDifferentPrice();
    error Vincask__MustSetDifferentStableCoin();
}
