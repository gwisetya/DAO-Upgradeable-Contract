// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BoxV1} from "../src/BoxV1.sol";
import {BoxV2} from "../src/BoxV2.sol";
import {Script} from "forge-std/Script.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract UpgradeBox is Script {
    function run() public returns (address) {
        address mostRecentDeployment = DevOpsTools.get_most_recent_deployment(
            "ERC1967Proxy",
            block.chainid
        );

        vm.startBroadcast();
        BoxV2 box2 = new BoxV2();
        vm.stopBroadcast();

        address proxy = upgradeBox(mostRecentDeployment, address(box2));
        return proxy;
    }

    function upgradeBox(
        address proxyAddress,
        address box2
    ) public returns (address) {
        vm.startBroadcast();
        BoxV1(proxyAddress).upgradeTo(box2);
        vm.stopBroadcast();
        return proxyAddress;
    }
}
