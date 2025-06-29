// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {CodeConstants} from "script/HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "script/Interactions.s.sol";

contract InteractionsTest is CodeConstants, Test {
    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.deployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;

        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    //////////////////////////////////  Testing Create Subscription //////////////////////////////

    function testCreateSubscription() public {
        //Arrange
        CreateSubscription createSubscription = new CreateSubscription();
        //Act
        (uint256 subIdForTesting, ) = createSubscription
            .createSubscriptionUsingConfig();
        //Assert
        assert(subIdForTesting != 0);
    }

    //////////////////////////////////  Testing Fund Subscription //////////////////////////////

    function testFundSubscription() public {
        // Arrange
        CreateSubscription creator = new CreateSubscription(); // You have to create new one to get subid because helperConfig is returning 0 in subId
        (uint256 newSubId, address newVrfCoordinator) = creator
            .createSubscriptionUsingConfig();

        subscriptionId = newSubId;
        vrfCoordinator = newVrfCoordinator;

        FundSubscription funder = new FundSubscription();

        // Act
        funder.fundSubscription(
            vrfCoordinator,
            subscriptionId,
            helperConfig.getConfig().link,
            helperConfig.getConfig().account
        );

        // Assert
        (uint96 balance, , , , ) = VRFCoordinatorV2_5Mock(vrfCoordinator)
            .getSubscription(subscriptionId);
        assert(balance > 0);
    }

    function testFundSubscriptionFailsWithInvalidSubId() public {
        // Arrange
        address coordinator = helperConfig.getConfig().vrfCoordinator;
        address linkToken = helperConfig.getConfig().link;
        address account = helperConfig.getConfig().account;

        // Act
        uint256 fakeSubId = 999999;

        // Assert
        FundSubscription funder = new FundSubscription();
        vm.expectRevert(); // VRFCoordinator should revert for unknown subId
        funder.fundSubscription(coordinator, fakeSubId, linkToken, account);
    }

    //////////////////////////////////  Testing Add Consumer //////////////////////////////

    function testConsumerAdded() public {
        // Arrange
        CreateSubscription creator = new CreateSubscription();
        (uint256 subId, address vrfCoordinatorAddr) = creator
            .createSubscriptionUsingConfig();

        // Deploy a dummy consumer contract (Raffle already deployed in setUp)
        address mostRecentlyDeployed = address(raffle);
        // Act
        AddConsumer addConsumerScript = new AddConsumer();
        addConsumerScript.addConsumer(
            mostRecentlyDeployed,
            vrfCoordinatorAddr,
            subId,
            helperConfig.getConfig().account
        );

        // Assert
        VRFCoordinatorV2_5Mock mock = VRFCoordinatorV2_5Mock(
            vrfCoordinatorAddr
        );
        bool consumerAdded = mock.consumerIsAdded(subId, mostRecentlyDeployed);
        assert(consumerAdded == true);
    }

    function testingWrongConsumerCantBeAdded() public {
        // Arrange
        CreateSubscription creator = new CreateSubscription();
        (uint256 subId, address vrfCoordinatorAddr) = creator
            .createSubscriptionUsingConfig();
        address dummyAddr = address(0);

        // Act
        AddConsumer addConsumerScript = new AddConsumer();
        addConsumerScript.addConsumer(
            dummyAddr,
            vrfCoordinatorAddr,
            subId,
            helperConfig.getConfig().account
        );

        // Assert
        vm.expectRevert();
        addConsumerScript.addConsumerUsingConfig(dummyAddr);
    }
}
