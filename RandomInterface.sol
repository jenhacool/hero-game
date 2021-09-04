// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface RandomInterface {
    function setBnbFee(uint bnbFee_)external;

    function requestRandomNumber(uint256 tokenId) external;
    
    function getResultByTokenId(uint256 tokenId) external returns(uint256);
}