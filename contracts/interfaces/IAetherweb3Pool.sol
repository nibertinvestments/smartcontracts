// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import './pool/IAetherweb3PoolImmutables.sol';
import './pool/IAetherweb3PoolState.sol';
import './pool/IAetherweb3PoolDerivedState.sol';
import './pool/IAetherweb3PoolActions.sol';
import './pool/IAetherweb3PoolOwnerActions.sol';
import './pool/IAetherweb3PoolEvents.sol';

/// @title The interface for a Aetherweb3 Pool
/// @notice A Aetherweb3 pool facilitates swapping and automated market making between any two assets that strictly conform
/// to the ERC20 specification
/// @dev The pool interface is broken up into many smaller pieces
interface IAetherweb3Pool is
    IAetherweb3PoolImmutables,
    IAetherweb3PoolState,
    IAetherweb3PoolDerivedState,
    IAetherweb3PoolActions,
    IAetherweb3PoolOwnerActions,
    IAetherweb3PoolEvents
{

}
