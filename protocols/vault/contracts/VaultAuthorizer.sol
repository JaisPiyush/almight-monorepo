//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;


import "@almight/contract-utils/contracts/authorizers/AccessAuthorizer.sol";
import "@almight/contract-utils/contracts/helpers/TemporarilyPausable.sol";

import "@almight/modules/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

abstract contract VaultAuthorizer is 
    ReentrancyGuard,
    AccessAuthorizer,
    TemporarilyPausable {




}