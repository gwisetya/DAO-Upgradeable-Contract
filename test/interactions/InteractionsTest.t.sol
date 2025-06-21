// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {BoxV1} from "../../src/BoxV1.sol";
import {BoxV2} from "../../src/BoxV2.sol";
import {DeployBox, DeployBox2} from "../../script/DeployBox.s.sol";
import {UpgradeBox} from "../../script/UpgradeBox.s.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract InteractionTest is Test {
    BoxV1 box1;
    BoxV2 box2;
    DeployBox deployer;
    DeployBox2 deployer2;
    UpgradeBox upgrader;
    address proxy;
    address proxy2;

    function setUp() public {
        deployer = new DeployBox();
        deployer2 = new DeployBox2();
        proxy2 = deployer2.run();
        proxy = deployer.run();
        upgrader = new UpgradeBox();

        vm.startBroadcast();
        box2 = new BoxV2();
        box1 = new BoxV1();
        vm.stopBroadcast();
    }

    function testImplementationStartsAsBoxV1() public view {
        assertEq(BoxV1(proxy).version(), 1);
    }

    function testImplementationStartsAsBoxV2() public view {
        assertEq(BoxV2(proxy2).version(), 2);
    }

    function testCanUpgradeProperly() public {
        upgrader.upgradeBox(proxy, address(box2));

        assertEq(BoxV2(proxy).version(), 2);
    }

    function testCanUpgradeProperly2() public {
        upgrader.upgradeBox(proxy2, address(box1));

        assertEq(BoxV1(proxy2).version(), 1);
    }

    function testCanStoreNumberAfterUpgrade(uint256 number) public {
        upgrader.upgradeBox(proxy, address(box2));
        BoxV2(proxy).setNumber(number);

        assertEq(BoxV2(proxy).getNumber(), number);
    }
}
