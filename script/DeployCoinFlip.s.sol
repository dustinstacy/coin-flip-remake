// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Script } from 'forge-std/Script.sol';
import { CoinFlip } from 'src/CoinFlip.sol';
import { HelperConfig } from './HelperConfig.s.sol';
import { console } from 'forge-std/console.sol';
import { AddConsumer, CreateSubscription, FundSubscription } from './Interactions.s.sol';

contract DeployCoinFlip is Script {
    function run() external returns (CoinFlip coinFlip, HelperConfig helperConfig) {
        helperConfig = new HelperConfig();
        AddConsumer addConsumer = new AddConsumer();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        if (config.subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            (config.subscriptionId, config.vrfCoordinator) = createSubscription.createSubscription(
                config.vrfCoordinator,
                config.account
            );
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                config.vrfCoordinator,
                config.subscriptionId,
                config.link,
                config.account
            );
        }

        vm.startBroadcast(config.account);
        coinFlip = new CoinFlip(
            config.subscriptionId,
            config.vrfCoordinator,
            config.keyHash,
            config.callbackGasLimit,
            config.requestConfirmations,
            config.numWords
        );
        coinFlip.addFunds{ value: 0.05 ether }();
        vm.stopBroadcast();

        addConsumer.addConsumer(address(coinFlip), config.vrfCoordinator, config.subscriptionId, config.account);
        return (coinFlip, helperConfig);
    }
}
