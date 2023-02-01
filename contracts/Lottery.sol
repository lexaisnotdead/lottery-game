// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";

contract Lottery is VRFConsumerBase, Ownable {
    address payable[] public players;
    address payable public recentWinner;
    uint256 public randomness;
    uint public usdEntryFee;
    AggregatorV3Interface internal ethUsdPriceFeed;
    
    enum LOTTERY_STATE {
        OPEN,
        CLOSED,
        CALCULATING_WINNER
    }

    LOTTERY_STATE public lotteryState;
    uint internal fee;
    uint internal keyHash;
    event RequestedRandomness(bytes32 requestId);

    constructor(address _priceFeedAddress,
                address _vrfCoordinator,
                address _link,
                uint _fee,
                bytes32 _keyHash
    ) VRFConsumerBase(_vrfCoordinator, _link) {
        usdEntryFee = 50 * (10 ** 18);
        ethUsdPriceFeed = AggregatorV3Interface(_priceFeedAddress);
        fee = _fee;
        keyHash = _keyHash;
    }

    function enter() external payable {
        require(lotteryState == LOTTERY_STATE.OPEN, "Lottery is closed");
        require(msg.value >= getEntranceFee(), "Insuficcient funds");
        players.push(payable(msg.sender));
        lotteryState = LOTTERY_STATE.CLOSED;
    }

    function getEntranceFee() internal view returns(uint) {
        (, int256 price, , , ) = ethUsdPriceFeed.latestRoundData();
        uint256 priceAdjusted = uint256(price) * 10**10; // 8 to 18 decimals
        uint entranceFee = (usdEntryFee * 10**18) / priceAdjusted;
        return entranceFee;
    }

    function startLottery() external onlyOwner {
        require(lotteryState == LOTTERY_STATE.CLOSED, "A new lottery cannot be opened");
        lotteryState = LOTTERY_STATE.OPEN;

    }

    function endLottery() external onlyOwner {
        lottery_state = LOTTERY_STATE.CALCULATING_WINNER;
        bytes32 requestId = requestRandomness(keyhash, fee);
        emit RequestedRandomness(requestId);
    }

    function fulfillRandomness(bytes32 _requestId, uint256 _randomness) internal override {
        require(lottery_state == LOTTERY_STATE.CALCULATING_WINNER, "You aren't there yet");
        require(_randomness > 0, "random not found");
        uint256 indexOfWinner = _randomness % players.length;
        recentWinner = players[indexOfWinner];
        recentWinner.transfer(address(this).balance);

        players = new address payable[](0);
        lottery_state = LOTTERY_STATE.CLOSED;
        randomness = _randomness;
    }

}