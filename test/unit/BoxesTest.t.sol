// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {BoxV1} from "../../src/BoxV1.sol";
import {BoxV2} from "../../src/BoxV2.sol";

contract BoxesTest is Test {
    BoxV1 box1;
    BoxV2 box2;
    address owner = makeAddr("owner");

    function setUp() public {
        vm.startBroadcast();
        box1 = new BoxV1();
        box2 = new BoxV2();
        vm.stopBroadcast();
    }

    function testGetNumberWorks() public view {
        assertEq(box1.getNumber(), 0);
        assertEq(box2.getNumber(), 0);
    }

    function testVersionWorks() public view {
        assertEq(box1.version(), 1);
        assertEq(box2.version(), 2);
    }

    function testSetNumberWorks(uint256 number) public {
        box2.setNumber(number);
        assertEq(box2.getNumber(), number);
    }
}
