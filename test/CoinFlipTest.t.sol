// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Test, console } from 'forge-std/Test.sol';
import { CoinFlip } from 'src/CoinFlip.sol';
import { DeployCoinFlip } from 'script/DeployCoinFlip.s.sol';
import { HelperConfig, CodeConstants } from 'script/HelperConfig.s.sol';
import { LinkToken } from './mocks/LinkToken.sol';
import { VRFCoordinatorV2_5Mock } from '@chainlink/contracts/vrf/mocks/VRFCoordinatorV2_5Mock.sol';
import { Vm } from 'forge-std/Vm.sol';

contract CoinFlipTest is Test, CodeConstants {
    CoinFlip coinFlip;
    HelperConfig helperConfig;
    DeployCoinFlip deployer;

    address vrfCoordinator;
    bytes32 keyHash;
    uint256 subscriptionId;
    uint32 callbackGasLimit;
    uint16 requestConfirmations;
    uint32 numWords;
    LinkToken link;

    address payable coinFlipAddress;
    address public USER = makeAddr('user');
    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 public constant LINK_BALANCE = 100 ether;

    uint256 public minimumWager;

    event Received(address sender, uint256 amount);
    event FallbackCalled(address sender, uint256 amount);
    event CoinFlipped(address indexed user, uint256 indexed wager, CoinFlip.Guesses indexed guess);

    modifier guessHeads() {
        vm.prank(USER);
        coinFlip.guessHeads();
        _;
    }

    modifier guessTails() {
        vm.prank(USER);
        coinFlip.guessTails();
        _;
    }

    modifier placeWager() {
        vm.prank(USER);
        coinFlip.placeWager{ value: minimumWager }();
        _;
    }

    function setUp() public {
        deployer = new DeployCoinFlip();
        (coinFlip, helperConfig) = deployer.run();
        vm.deal(USER, STARTING_USER_BALANCE);

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        subscriptionId = config.subscriptionId;
        vrfCoordinator = config.vrfCoordinator;
        keyHash = config.keyHash;
        callbackGasLimit = config.callbackGasLimit;
        requestConfirmations = config.requestConfirmations;
        numWords = config.numWords;
        link = LinkToken(config.link);
        coinFlipAddress = payable(address(coinFlip));
        minimumWager = coinFlip.getMinimumWager();

        vm.startPrank(msg.sender);
        if (block.chainid == LOCAL_CHAIN_ID) {
            link.mint(msg.sender, LINK_BALANCE);
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, LINK_BALANCE);
            link.approve(vrfCoordinator, LINK_BALANCE);
            vm.stopPrank();
        }
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    function testConstructorSetsTheOwnerProperly() public view {
        // Arrange
        address expectedOwner = FOUNDRY_DEFAULT_SENDER;
        address owner = coinFlip.getOwner();

        // Assert
        assert(expectedOwner == owner);
    }

    function testConstructorSetsCoinFlipStateToOpen() public view {
        // Assert
        assert(coinFlip.getCoinFlipState() == CoinFlip.CoinFlipState.OPEN);
    }

    /*//////////////////////////////////////////////////////////////
                               ADD FUNDS
    //////////////////////////////////////////////////////////////*/
    function testAddFundsIncreasesContractBalance() public {
        // Arrange
        vm.prank(USER);
        uint256 contractStartingBalance = coinFlip.getBalance();

        // Act
        coinFlip.addFunds{ value: minimumWager }();

        // Assert
        uint256 contractEndingBalance = coinFlip.getBalance();
        assert(contractStartingBalance + minimumWager == contractEndingBalance);
    }

    function testAddFundsRevertsWithErrorWhenValueEqualsZero() public {
        // Arrange
        vm.prank(USER);

        // Act / Assert
        vm.expectRevert(CoinFlip.CoinFlip__AmountMustBeGreaterThanZero.selector);
        coinFlip.addFunds();
    }

    function testReceiveAddsFundsWhenTriggered() public {
        // Arrange
        vm.prank(USER);
        uint256 contractStartingBalance = coinFlip.getBalance();

        // Act
        vm.expectEmit(false, false, false, false, coinFlipAddress);
        emit Received(USER, minimumWager);
        coinFlipAddress.transfer(minimumWager);

        // Assert
        uint256 contractEndingBalance = coinFlip.getBalance();
        assert(contractStartingBalance + minimumWager == contractEndingBalance);
    }

    function testFallbackAddsFundsWhenTriggered() public {
        // Arrange
        vm.prank(USER);
        uint256 startingContractBalance = coinFlip.getBalance();

        // Act
        vm.expectEmit(false, false, false, false, coinFlipAddress);
        emit FallbackCalled(USER, minimumWager);
        (bool success, ) = coinFlipAddress.call{ value: minimumWager }(abi.encodeWithSignature(''));
        if (success) {
            console.log('you did it!');
        }

        // Assert
        uint256 endingContractBalance = coinFlip.getBalance();
        assert(endingContractBalance == startingContractBalance + minimumWager);
    }

    /*//////////////////////////////////////////////////////////////
                            GUESS HEADS/TAILS
    //////////////////////////////////////////////////////////////*/

    function testGuessHeadsAddsGuessToUsersWager() public guessHeads {
        // Arrange
        CoinFlip.Guesses currentGuess = coinFlip.getUserCurrentGuess(USER);

        // Assert
        assert(currentGuess == CoinFlip.Guesses.HEADS);
    }

    function testGuessTailsAddsGuessToUsersWager() public guessTails {
        // Arrange
        CoinFlip.Guesses currentGuess = coinFlip.getUserCurrentGuess(USER);

        // Assert
        assert(currentGuess == CoinFlip.Guesses.TAILS);
    }

    /*//////////////////////////////////////////////////////////////
                               PLACEWAGER
    //////////////////////////////////////////////////////////////*/

    function testPlaceWagerRevertsWithErrorIfNoGuessIsMade() public {
        // Act / Assert
        vm.prank(USER);
        vm.expectRevert(abi.encodeWithSelector(CoinFlip.CoinFlip__PleaseMakeAGuessFirst.selector));
        coinFlip.placeWager{ value: minimumWager }();
    }

    function testPlaceWagerRevertsWithErrorIfMinimumWagerNotMet() public guessHeads {
        // Arrange
        uint256 wagerAmount = .001 ether;

        // Act / Assert
        vm.prank(USER);
        vm.expectRevert(
            abi.encodeWithSelector(CoinFlip.CoinFlip__MinimumWagerNotMet.selector, minimumWager, wagerAmount)
        );
        coinFlip.placeWager{ value: wagerAmount }();
    }

    function testPlaceWagerRevertsWhenCoinFlipNotOpen() public guessHeads {
        // Act / Assert
        vm.prank(USER);
        vm.expectRevert(CoinFlip.CoinFlip__StillCalculatingResults.selector);
        coinFlip.placeWager{ value: minimumWager }();
    }

    function testPlaceWagerAddsAmountToUsersWager() public guessHeads placeWager {
        // Arrange
        uint256 currentWager = coinFlip.getUserCurrentWagerAmount(USER);

        // Assert
        assert(currentWager == minimumWager);
    }

    function testPlaceWagerChangesTheCoinFlipStateToCalculating() public guessHeads placeWager {
        // Arrange
        CoinFlip.CoinFlipState coinFlipState = coinFlip.getCoinFlipState();

        // Assert
        assert(coinFlipState == CoinFlip.CoinFlipState.CALCULATING);
    }

    function testPlaceWagerEmitsCoinFlippedEvent() public guessHeads {
        vm.expectEmit(true, true, true, false, coinFlipAddress);
        emit CoinFlipped(USER, minimumWager, coinFlip.getUserCurrentGuess(USER));
        vm.prank(USER);
        coinFlip.placeWager{ value: minimumWager }();
    }

    /*//////////////////////////////////////////////////////////////
                          FULFILL RANDOM WORDS
    //////////////////////////////////////////////////////////////*/

    function testFulfillRandomWordsResultIsAlwaysInProperRange() public guessHeads {
        vm.prank(USER);
        vm.recordLogs();
        coinFlip.placeWager{ value: minimumWager }();
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[0].topics[3];

        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), coinFlipAddress);

        // Act / Assert
        uint256 result = coinFlip.getLastResult();
        console.log(result);
        assert(result == 1 || result == 2);
    }

    /*//////////////////////////////////////////////////////////////
                             HANDLE RESULT
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                             USER WITHDRAW
    //////////////////////////////////////////////////////////////*/

    function testUserWithdrawRevertsIfBalanceIsZero() public {
        vm.prank(USER);

        vm.expectRevert(CoinFlip.CoinFlip__NoBalance.selector);
        coinFlip.userWithdraw();
    }

    /*//////////////////////////////////////////////////////////////
                             OWNER WITHDRAW
    //////////////////////////////////////////////////////////////*/

    function testOwnerWithdrawCanOnlyBeCalledByTheOwner() public {
        vm.prank(USER);

        vm.expectRevert(CoinFlip.CoinFlip__YouAreNotTheOne.selector);
        coinFlip.ownerWithdraw(10000 ether);
    }

    function testOwnerWithdrawWorkIfEnoughFundsAreAvailableAndIsCalledByOwner() public {
        coinFlip.addFunds{ value: 10 ether }();
        vm.prank(FOUNDRY_DEFAULT_SENDER);
        coinFlip.ownerWithdraw(10 ether);
        assert(coinFlip.getBalance() == 0);
    }

    /////////////////////////////////////////////////////////////////////////////////////////
    ///Tests refactored up to here///
    /////////////////////////////////////////////////////////////////////////////////////////

    function testUserWithdrawSetsTheUsersBalanceAndCurrentWagerToZero() public guessTails placeWager {
        coinFlip.addFunds{ value: 10 ether }();
        vm.prank(USER);
        coinFlip.userWithdraw();

        assert(coinFlip.getUserBalance(USER) == 0);
        assert(coinFlip.getUserCurrentWagerAmount(USER) == 0);
    }

    function testUserWithdrawSendsTheProperAmount() public guessTails {
        coinFlip.addFunds{ value: 10 ether }();
        uint256 startingUserAddressBalance = address(USER).balance;

        vm.prank(USER);
        coinFlip.placeWager{ value: minimumWager }();

        vm.prank(USER);
        coinFlip.userWithdraw();

        uint256 endingUserAddressBalance = address(USER).balance;
        assert(endingUserAddressBalance == startingUserAddressBalance + minimumWager);
    }

    function testOwnerWithdrawRevertsWhenBalanceDoesNotExceedPlayerBalances() public guessTails {
        coinFlip.addFunds{ value: 0.0001 ether }();

        vm.startPrank(USER);
        coinFlip.placeWager{ value: minimumWager }();
        vm.stopPrank();

        vm.prank(FOUNDRY_DEFAULT_SENDER);
        vm.expectRevert(CoinFlip.CoinFlip__YouInTrouble.selector);
        coinFlip.ownerWithdraw(.0001 ether);
    }
}
