// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Script, console } from 'forge-std/Script.sol';
import { CoinFlip } from 'src/CoinFlip.sol';
import { HelperConfig, CodeConstants } from 'script/HelperConfig.s.sol';
import { DevOpsTools } from '@foundry-devops/DevOpsTools.sol';
import { VRFCoordinatorV2_5Mock } from '@chainlink/contracts/vrf/mocks/VRFCoordinatorV2_5Mock.sol';
import { LinkToken } from 'test/mocks/LinkToken.sol';

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint256 subId, address vrfCoordinatorV2_5) {
        HelperConfig helperConfig = new HelperConfig();
        vrfCoordinatorV2_5 = helperConfig.getConfigByChainId(block.chainid).vrfCoordinator;
        address account = helperConfig.getConfigByChainId(block.chainid).account;
        return createSubscription(vrfCoordinatorV2_5, account);
    }

    function createSubscription(address vrfV2CoordinatorV2_5, address account) public returns (uint256, address) {
        console.log('Creating a subscription on chainId: ', block.chainid);
        vm.startBroadcast(account);
        uint256 subId = VRFCoordinatorV2_5Mock(vrfV2CoordinatorV2_5).createSubscription();
        vm.stopBroadcast();
        console.log('Your subscription Id is : ', subId);
        console.log('Please update the subscriptionId in HelperConfig.s.sol');
        return (subId, vrfV2CoordinatorV2_5);
    }

    function run() external returns (uint256, address) {
        return createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script, CodeConstants {
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        uint256 subId = helperConfig.getConfig().subscriptionId;
        address vrfCoordinatorV2_5 = helperConfig.getConfig().vrfCoordinator;
        address link = helperConfig.getConfig().link;
        address account = helperConfig.getConfig().account;

        if (subId == 0) {
            CreateSubscription createSub = new CreateSubscription();
            (uint256 updatedSubId, address updatedVRFv2) = createSub.run();
            subId = updatedSubId;
            vrfCoordinatorV2_5 = updatedVRFv2;
            console.log('New SubId Created! ', subId, 'VRF Address: ', vrfCoordinatorV2_5);
        }

        fundSubscription(vrfCoordinatorV2_5, subId, link, account);
    }

    function fundSubscription(address vrfCoordinatorV2_5, uint256 subId, address link, address account) public {
        console.log('Funding Subscription: ', subId);
        console.log('Using vrfCoordinator: ', vrfCoordinatorV2_5);
        console.log('On ChainId: ', block.chainid);
        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast(account);
            VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fundSubscription(subId, FUND_AMOUNT);
        } else {
            console.log(LinkToken(link).balanceOf(msg.sender));
            console.log(msg.sender);
            console.log(LinkToken(link).balanceOf(address(this)));
            console.log(address(this));
            vm.startBroadcast(account);
            LinkToken(link).transferAndCall(vrfCoordinatorV2_5, FUND_AMOUNT, abi.encode(subId));
        }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumer(address contractToAddToVrf, address vrfCoordinator, uint256 subId, address account) public {
        console.log('Adding consumer contract: ', contractToAddToVrf);
        console.log('Using vrfCoordinator: ', vrfCoordinator);
        console.log('On ChainId: ', block.chainid);
        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, contractToAddToVrf);
        vm.stopBroadcast();
    }

    function addConsumerUsingConfig(address mostRecentlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        uint256 subId = helperConfig.getConfig().subscriptionId;
        address vrfCoordinatorV2_5 = helperConfig.getConfig().vrfCoordinator;
        address account = helperConfig.getConfig().account;

        addConsumer(mostRecentlyDeployed, vrfCoordinatorV2_5, subId, account);
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment('CoinFlip', block.chainid);
        addConsumerUsingConfig(mostRecentlyDeployed);
    }
}
