// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/vrf/dev/libraries/VRFV2PlusClient.sol";

contract CoinFlip {
    error CoinFlip__AmountMustBeGreaterThanZero();
    error CoinFlip__MinimumWagerNotMet(uint256 minimumWager, uint256 wager);

    address private immutable i_owner;
    uint256 private constant MINIMUM_WAGER = 0.01 ether;

    event Received(address sender, uint256 amount);
    event FallbackCalled(address sender, uint256 amount);
    event CoinFlipped(address user, uint256 wager);

    // address user;

    // uint256 s_subscriptionId;
    // address vrfCoordinator;
    // bytes32 s_keyHash;
    // uint32 callbackGasLimit;
    // uint16 requestConfirmations;
    // uint32 numWords;

    mapping(address user => uint256 balance) private s_balances;

    // enum CoinFlipState {
    //     OPEN,
    //     CALCULATING
    // }

    constructor() {
        i_owner = msg.sender;
    }

    receive() external payable {
        addFunds();
        emit Received(msg.sender, msg.value);
    }

    fallback() external payable {
        addFunds();
        emit FallbackCalled(msg.sender, msg.value);
    }

    function addFunds() public payable {
        if (msg.value == 0) {
            revert CoinFlip__AmountMustBeGreaterThanZero();
        }
    }

    function flipCoin(address user, uint256 wager) public {
        if (wager < MINIMUM_WAGER) {
            revert CoinFlip__MinimumWagerNotMet(MINIMUM_WAGER, wager);
        }
        s_balances[user] = s_balances[user] + wager;
        emit CoinFlipped(user, wager);
    }

    // function fulfillRandomWords(
    //     uint256 /* requestId */,
    //     uint256[] calldata randomWords
    // ) internal override {}

    // function handleResult() private {}

    // function withdrawWinnings() public {}

    // function withdraw() public {}

    function getOwner() public view returns (address) {
        return i_owner;
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getUserBalance(address user) public view returns (uint256) {
        return s_balances[user];
    }

    function getMinimumWager() public pure returns (uint256) {
        return MINIMUM_WAGER;
    }
}
