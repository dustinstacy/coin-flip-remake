// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/vrf/dev/libraries/VRFV2PlusClient.sol";

contract CoinFlip is VRFConsumerBaseV2Plus {
    address private immutable i_owner;
    address player;

    uint256 s_subscriptionId;
    address vrfCoordinator;
    bytes32 s_keyHash;
    uint32 callbackGasLimit;
    uint16 requestConfirmations;
    uint32 numWords;

    mapping(address player => uint256 balance) private s_balances;

    enum CoinFlipState {
        OPEN,
        CALCULATING
    }

    constructor() VRFConsumerBaseV2Plus(vrfCoordinator) {}

    function flipCoin() public {}

    function fulfillRandomWords(
        uint256 /* requestId */,
        uint256[] calldata randomWords
    ) internal override {}

    function handleResult() private {}

    function withdrawWinnings() public {}

    function addFunds() public payable {}

    function withdraw() public {}

    receive() external payable {
        addFunds();
    }

    fallback() external payable {
        addFunds();
    }
}
