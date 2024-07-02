// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/vrf/dev/libraries/VRFV2PlusClient.sol";

contract CoinFlip {
    // error CoinFlip__AmountMustBeGreaterThanZero();

    address private immutable i_owner;

    // address player;

    // uint256 s_subscriptionId;
    // address vrfCoordinator;
    // bytes32 s_keyHash;
    // uint32 callbackGasLimit;
    // uint16 requestConfirmations;
    // uint32 numWords;

    // mapping(address player => uint256 balance) private s_balances;

    // enum CoinFlipState {
    //     OPEN,
    //     CALCULATING
    // }

    constructor() {
        i_owner = msg.sender;
    }

    // receive() external payable {
    //     addFunds(msg.value);
    // }

    // fallback() external payable {
    //     addFunds(msg.value);
    // }

    // function addFunds(uint256 amount) public payable {
    //     if (amount == 0) {
    //         revert CoinFlip__AmountMustBeGreaterThanZero();
    //     }
    // }

    // function flipCoin() public {}

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
}
