// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./RandomInterface.sol";

interface IRandomRequester {
    function submitRandomness(uint _tokenId, uint _randomness) external;
}

interface IERC20 {
    function allowance(address owner, address spender) external view returns (uint);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);
}

interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint) external;
}

library LHelper {
    IWETH constant internal weth = IWETH(address(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    bytes4 private constant SWAP_SELECTOR = 
        bytes4(keccak256(bytes('swapExactTokensForTokens(uint256,uint256,address[],address,uint256)')));
    bytes4 private constant WBNB_DEPOSIT_SELECTOR = 
        bytes4(keccak256(bytes('deposit()')));

    function toWbnb()
        internal
        returns(bool success)
    {
        uint amount = address(this).balance;
        (success, ) = address(weth).call{value: amount}((abi.encodeWithSelector(
            WBNB_DEPOSIT_SELECTOR
        )));  
    }

    function thisTokenBalance(
        address token_
    )
        internal
        view
        returns(uint)
    {
        return IERC20(token_).balanceOf(address(this));
    }

    function thisBnbBalance()
        internal
        view
        returns(uint)
    {
        return address(this).balance + thisTokenBalance(address(weth));
    }

    function approve(
        address token_,
        address to_
    )
        internal
    {
        if (IERC20(token_).allowance(address(this), to_) == 0) {
            IERC20(token_).approve(to_, ~uint256(0));
        }
    }

    function swap(
        address router_,
        address fromCurrency_,
        address toCurrency_,
        uint amount_,
        address to_
    )
        internal
        returns(bool success)
    {
        address[] memory path = new address[](2);
        path[0] = fromCurrency_;
        path[1] = toCurrency_;

        approve(fromCurrency_, router_);

        (success, ) = router_.call((abi.encodeWithSelector(
            SWAP_SELECTOR,
            amount_,
            0,
            path,
            to_,
            block.timestamp
        )));
    }
}

contract RandomFee {
    event SetBnbFee(
        uint amount
    );

    address private _linkAddress;

    uint private _bnbFee;
    uint private _lastWbnbBalance;

    constructor(
        address linkAddress_
    )
    {
        _linkAddress = linkAddress_;
    }

    function _setBnbFee(
        uint bnbFee_
    )
        internal
    {
        _bnbFee = bnbFee_;
        emit SetBnbFee(bnbFee_);
    }

    function _updateWbnbBalance()
        internal
        returns(uint added)
    {
        currentWbnbBalance = LHelper.thisBnbBalance();
        if (currentWbnbBalance > _lastWbnbBalance) {
            added = currentWbnbBalance - _lastWbnbBalance;
        } else {
            added = 0;
        }
        _lastWbnbBalance = currentWbnbBalance;
    }

    function _takeFee()
        internal
        returns(uint)
    {
        uint added = _updateWbnbBalance();
        require(added >= _bnbFee, "RandomFee: not enough for fee");
    }

    function buyLink()
        public
    {
        LHelper.toWbnb();
        LHelper.swap(
            address(0x10ED43C718714eb63d5aA57B78B54704E256024E),
            address(LHelper.weth),
            _linkAddress,
            LHelper.thisBnbBalance(),
            address(this)
        );
        _updateWbnbBalance();
    }
}

contract Random is VRFConsumerBase, RandomInterface, RandomFee {
    using SafeMath for uint256;
    
    uint256 private constant IN_PROGRESS = 42;

    bytes32 public keyHash;
    
    uint256 public fee;
    
    mapping(bytes32 => uint256) tokens;
    
    mapping(uint256 => uint256) results;
    
    event RandomNumberGenerated(uint256 tokenId);
    
    IRandomRequester private _randomRequester;
    
    // constructor(address _vrfCoordinator, address _link, bytes32 _keyHash, uint256 _fee)
    //     VRFConsumerBase(
    //         _vrfCoordinator,
    //         _link
    //     ) public
    // {
    //     keyHash = _keyHash;
    //     fee = _fee;
    //     _randomRequester = IRandomRequester(msg.sender);
    // }

    constructor()
        RandomFee(address(LINK))
        VRFConsumerBase(
            0xa555fC018435bef5A13C6c6870a9d4C11DEC329C,
            0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06
        ) public
    {
        keyHash = 0xcaf3c3727e033261d383b315559476f48034c13b18f8cafed4d871abe5049186;
        fee = 0.1 * 10 ** 18;
        _randomRequester = IRandomRequester(msg.sender);
    }

    receive() external payable {
    }
    
    function requestRandomNumber(uint256 tokenId) external override {
        _takeFee();
        require(msg.sender == address(_randomRequester), "Only NFT contract call");
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK");
        bytes32 requestId = requestRandomness(keyHash, fee);
        tokens[requestId] = tokenId;
        results[tokenId] = IN_PROGRESS; 
    }
    
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        uint256 tokenId = tokens[requestId];
        results[tokenId] = randomness;
        emit RandomNumberGenerated(tokenId);
        _randomRequester.submitRandomness(tokenId, randomness);
    }
    
    function getResultByTokenId(uint256 tokenId) external view override returns (uint256) {
        return results[tokenId];
    }

    function setBnbFee(
        uint bnbFee_
    )
        external
    {
        require(msg.sender == address(_randomRequester), "Only NFT contract call");
        _setBnbFee(bnbFee_);
    }
}