//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./ITickerdPoolAction.sol";
import "./ITickerdPoolDerivedState.sol";
import "./ITickerdPoolEvents.sol";
import "./ITickerdPoolImmutables.sol";
import "./ITickerdPoolState.sol";

//solhint-disable-next-line no-empty-blocks
interface ITickerdPool is 
    ITickerdPoolImmutables,
    ITickerdPoolState,
    ITickerdPoolDerivedState,
    ITickerdPoolActions,
    ITickerdPoolEvents {}