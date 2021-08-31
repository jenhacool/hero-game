// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract NftUpgrader {
    function getStarFromRandomness(
        uint256 _randomness
    )
        external
        pure
        returns(uint8)
    {
        /*
            example logic only
        */
        uint seed = _randomness % 100;
        if (seed < 60) {
            return 1;
        }
        if (seed < 80) {
            return 2;
        }
        if (seed < 95) {
            return 3;
        }
        if (seed < 99) {
            return 4;
        }
        return 5;
    }
}