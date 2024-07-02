// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";

abstract contract CodeConstants {
    address public FOUNDRY_DEFAULT_SENDER =
        0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
}

contract HelperConfig is Script, CodeConstants {
    struct NetworkConfig {
        address account;
    }

    NetworkConfig public localNetworkConfig;

    constructor() {}

    function getConfig() public returns (NetworkConfig memory) {
        localNetworkConfig = NetworkConfig({account: FOUNDRY_DEFAULT_SENDER});
        return localNetworkConfig;
    }
}
