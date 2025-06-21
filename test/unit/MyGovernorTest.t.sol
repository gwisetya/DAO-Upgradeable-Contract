// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {MyGovernor} from "../../src/MyGovernor.sol";
import {BoxV1} from "../../src/BoxV1.sol";
import {BoxV2} from "../../src/BoxV2.sol";
import {Timelock} from "../../src/Timelock.sol";
import {GovToken} from "../../src/GovToken.sol";
import {UpgradeBox} from "../../script/UpgradeBox.s.sol";
import {DeployBox} from "../../script/DeployBox.s.sol";

contract MyGovernorTest is Test {
    DeployBox deployer;
    UpgradeBox upgrader;
    MyGovernor governor;
    BoxV2 box2;
    Timelock timelock;
    GovToken govToken;
    address proxy;

    address public USER = makeAddr("user");
    uint256 public constant INITIAL_SUPPLY = 100 ether;

    uint256 public constant MIN_DELAY = 3600; // 1 hour after a vote passes
    uint256 public constant VOTING_DELAY = 1;
    uint256 public constant VOTING_PERIOD = 50400;
    address[] proposers;
    address[] executors;

    uint256[] values;
    bytes[] calldatas;
    address[] targets;

    function setUp() public {
        govToken = new GovToken();
        govToken.mint(USER, INITIAL_SUPPLY);
        upgrader = new UpgradeBox();
        deployer = new DeployBox();
        box2 = new BoxV2();
        proxy = deployer.run();

        vm.startPrank(USER);
        govToken.delegate(USER);
        timelock = new Timelock(MIN_DELAY, proposers, executors);
        governor = new MyGovernor(govToken, timelock);

        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.DEFAULT_ADMIN_ROLE();

        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(executorRole, address(0));
        timelock.revokeRole(adminRole, USER);

        vm.stopPrank();

        vm.startPrank(msg.sender);
        BoxV1(proxy).transferOwnership(address(timelock));
        vm.stopPrank();
    }

    function testCantUpdateBoxWithoutGovernance() public {
        vm.expectRevert();
        BoxV1(proxy).upgradeTo(address(box2));
    }

    function testGovernanceUpdatesBox() public {
        address box2Address = address(box2);
        string memory description = "Update Implementation to Box2";
        bytes memory encodedFunctionCall = abi.encodeWithSignature(
            "upgradeTo(address)",
            box2Address
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
        string memory reason = "We need a setNumber function";

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

        assertEq(BoxV2(proxy).version(), 2);
    }

    function testNonceReturnsTrue() public view {
        assertEq(govToken.nonces(USER), 0);
    }
}
