// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {CoinFlip} from "src/CoinFlip.sol";
import {DeployCoinFlip} from "script/DeployCoinFlip.s.sol";
import {CodeConstants} from "script/HelperConfig.s.sol";

contract CoinFlipTest is Test, CodeConstants {
    CoinFlip coinFlip;
    DeployCoinFlip deployer;

    function setUp() public {
        deployer = new DeployCoinFlip();
        coinFlip = deployer.run();
    }

    function testConstructorSetsTheOwnerProperly() public view {
        address expectedOwner = FOUNDRY_DEFAULT_SENDER;
        address owner = coinFlip.getOwner();
        assert(expectedOwner == owner);
    }
}
