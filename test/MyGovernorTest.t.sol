//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {BoxV1} from "../src/BoxV1.sol";
import {BoxV2} from "../src/BoxV2.sol";
import {GovToken} from "../src/GovToken.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {Timelock} from "../src/Timelock.sol";
import {DeployBox} from "../script/DeployBox.s.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UpgradeBox} from "../script/UpgradeBox.s.sol";

contract MyGovernorTest is Test {
    BoxV1 box;
    GovToken govToken;
    MyGovernor governor;
    Timelock timelock;
    DeployBox deployer;
    address proxy;
    UpgradeBox upgrader;

    address public USER = makeAddr("user");
    uint256 public constant INITIAL_SUPPLY = 100 ether;

    uint256 public constant MIN_DELAY = 3600; // 1 hour after a vote passes
    address[] proposers;
    address[] executors;

    uint256[] values;
    bytes[] calldatas;
    address[] targets;

    uint256 public constant VOTING_DELAY = 1;
    uint256 public constant VOTING_PERIOD = 50400;

    function setUp() public {
        govToken = new GovToken();
        govToken.mint(USER, INITIAL_SUPPLY);

        deployer = new DeployBox();
        upgrader = new UpgradeBox();
        proxy = deployer.run();

        vm.startBroadcast(USER);
        govToken.delegate(USER);

        timelock = new Timelock(MIN_DELAY, proposers, executors);
        governor = new MyGovernor(govToken, timelock);

        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.DEFAULT_ADMIN_ROLE();

        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(executorRole, address(0));
        timelock.revokeRole(adminRole, USER);

        vm.stopBroadcast();

        vm.startBroadcast();
        BoxV1(proxy).transferOwnership(address(timelock));
        vm.stopBroadcast();
    }

    function testCantUpgradeBoxWithoutGovernance() public {
        BoxV2 box2 = new BoxV2();

        vm.expectRevert();
        upgrader.upgradeBox(proxy, address(box2));
    }

    function testGovernanceUpdatesBox() public {
        BoxV2 boxV2 = new BoxV2();
        string memory description = "Upgrade to BoxV2";
        bytes memory encodedFunctionCall = abi.encodeWithSignature(
            "upgradeTo(address)",
            address(boxV2)
        );
        calldatas.push(encodedFunctionCall);
        values.push(0);
        targets.push(proxy);

        // 1. Propose
        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            description
        );

        // View the State
        console.log("Proposal State 1: ", uint256(governor.state(proposalId)));
        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);
        console.log("Proposal State 2: ", uint256(governor.state(proposalId)));

        // 2. Vote on Proposal
        string memory reason = "Add SetNumber Function";

        // Vote Types derived from GovernorCountingSimple:
        // enum VoteType {
        //   Against,
        //   For,
        //   Abstain
        //}
        vm.prank(USER);
        governor.castVoteWithReason(proposalId, 1, reason);

        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        // 3. Queue the Proposal
        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        governor.queue(targets, values, calldatas, descriptionHash);

        vm.warp(block.timestamp + MIN_DELAY + 1);
        vm.roll(block.number + MIN_DELAY + 1);

        // 4. Execute the Proposal
        governor.execute(targets, values, calldatas, descriptionHash);
        console.log("Box Version: ", BoxV2(proxy).version());
        assert(BoxV2(proxy).version() == 2);

        // 5. Assert that number can be set
        BoxV2(proxy).setNumber(420);
        assert(BoxV2(proxy).getNumber() == 420);
    }
}
