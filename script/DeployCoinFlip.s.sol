// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {CoinFlip} from "src/CoinFlip.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployCoinFlip is Script {
    function deployCoinFlip() public returns (CoinFlip coinFlip) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        vm.startBroadcast(config.account);
        coinFlip = new CoinFlip(
            config.subscriptionId,
            config.vrfCoordinator,
            config.gasLane,
            config.callbackGasLimit,
            config.requestConfirmations,
            config.numWords
        );
        vm.stopBroadcast();

        return (coinFlip);
    }

    function run() external returns (CoinFlip) {
        return deployCoinFlip();
    }
}
