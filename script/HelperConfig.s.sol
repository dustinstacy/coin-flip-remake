// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

abstract contract CodeConstants {
    address public FOUNDRY_DEFAULT_SENDER =
        0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
}

contract HelperConfig is Script, CodeConstants {
    struct NetworkConfig {
        uint256 s_subscriptionId;
        address s_vrfCoordinator;
        bytes32 s_keyHash;
        uint32 s_callbackGasLimit;
        uint16 s_requestConfirmations;
        uint32 s_numWords;
        address account;
    }

    NetworkConfig public localNetworkConfig;

    constructor() {}

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
        localNetworkConfig = NetworkConfig({
            vrfCoordinator: address(vrfCoordinatorV2mock),
            gasLane: "",
            entranceFee: 1 ether,
            interval: 30,
            subscriptionId: 0,
            callbackGasLimit: 500000,
            link: address(linkToken),
            account: FOUNDRY_DEFAULT_SENDER
        });
        return localNetworkConfig;
    }
}
