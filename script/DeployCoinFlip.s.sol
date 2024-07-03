// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Script } from 'forge-std/Script.sol';
import { CoinFlip } from 'src/CoinFlip.sol';
import { HelperConfig } from './HelperConfig.s.sol';
import { console } from 'forge-std/console.sol';

contract DeployCoinFlip is Script {
    function run() external returns (CoinFlip coinFlip, HelperConfig helperConfig) {
        helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        vm.startBroadcast(config.account);
        coinFlip = new CoinFlip(
            config.subscriptionId,
            config.vrfCoordinator,
            config.keyHash,
            config.callbackGasLimit,
            config.requestConfirmations,
            config.numWords
        );
        vm.stopBroadcast();

        return (coinFlip, helperConfig);
    }
}
