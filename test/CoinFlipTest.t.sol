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

    modifier addFunds() {
        vm.prank(FOUNDRY_DEFAULT_SENDER);
        coinFlip.addFunds{ value: 10 ether }();
        _;
    }

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

    modifier fulfillRandomWords() {
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(1, coinFlipAddress);
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
        minimumWager = coinFlip.MINIMUM_WAGER();

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
        address expectedOwner = FOUNDRY_DEFAULT_SENDER;
        address owner = coinFlip.getOwner();
        assert(expectedOwner == owner);
    }

    function testConstructSetsSubscriptionIdProperly() public view {
        assert(coinFlip.subscriptionId() == subscriptionId);
    }

    function testConstructSetsVrfCoordinatorAddressProperly() public view {
        assert(coinFlip.vrfCoordinator() == vrfCoordinator);
    }

    function testConstructSetsKeyHashProperly() public view {
        assert(coinFlip.keyHash() == keyHash);
    }

    function testConstructSetsCallBackGasLimitProperly() public view {
        assert(coinFlip.callbackGasLimit() == callbackGasLimit);
    }

    function testConstructSetsRequestConfirmationsProperly() public view {
        assert(coinFlip.requestConfirmations() == requestConfirmations);
    }

    function testConstructSetsNumWordsProperly() public view {
        assert(coinFlip.numWords() == numWords);
    }

    /*//////////////////////////////////////////////////////////////
                               ADD FUNDS
    //////////////////////////////////////////////////////////////*/
    function testAddFundsIncreasesContractBalance() public {
        vm.prank(USER);
        uint256 contractStartingBalance = coinFlip.getBalance();
        coinFlip.addFunds{ value: minimumWager }();
        uint256 contractEndingBalance = coinFlip.getBalance();
        assert(contractStartingBalance + minimumWager == contractEndingBalance);
    }

    function testAddFundsRevertsWithErrorWhenValueEqualsZero() public {
        vm.prank(USER);
        vm.expectRevert(CoinFlip.CoinFlip__AmountMustBeGreaterThanZero.selector);
        coinFlip.addFunds();
    }

    function testReceiveAddsFundsWhenTriggered() public {
        vm.prank(USER);
        uint256 contractStartingBalance = coinFlip.getBalance();
        vm.expectEmit(false, false, false, false, coinFlipAddress);
        emit Received(USER, minimumWager);
        coinFlipAddress.transfer(minimumWager);
        uint256 contractEndingBalance = coinFlip.getBalance();
        assert(contractStartingBalance + minimumWager == contractEndingBalance);
    }

    function testFallbackAddsFundsWhenTriggered() public {
        vm.prank(USER);
        uint256 startingContractBalance = coinFlip.getBalance();
        vm.expectEmit(false, false, false, false, coinFlipAddress);
        emit FallbackCalled(USER, minimumWager);
        (bool success, ) = coinFlipAddress.call{ value: minimumWager }(abi.encodeWithSignature(''));
        if (success) {
            console.log('you did it!');
        }
        uint256 endingContractBalance = coinFlip.getBalance();
        assert(endingContractBalance == startingContractBalance + minimumWager);
    }

    /*//////////////////////////////////////////////////////////////
                            GUESS HEADS/TAILS
    //////////////////////////////////////////////////////////////*/

    function testGuessHeadsAddsGuessToUsersWager() public guessHeads {
        CoinFlip.Guesses currentGuess = coinFlip.getUserCurrentGuess(USER);
        assert(currentGuess == CoinFlip.Guesses.HEADS);
    }

    function testGuessTailsAddsGuessToUsersWager() public guessTails {
        CoinFlip.Guesses currentGuess = coinFlip.getUserCurrentGuess(USER);
        assert(currentGuess == CoinFlip.Guesses.TAILS);
    }

    /*//////////////////////////////////////////////////////////////
                               PLACEWAGER
    //////////////////////////////////////////////////////////////*/

    function testPlaceWagerRevertsWithErrorIfNoGuessIsMade() public {
        vm.prank(USER);
        vm.expectRevert(CoinFlip.CoinFlip__PleaseMakeAGuessFirst.selector);
        coinFlip.placeWager();
    }

    function testPlaceWagerRevertsWithErrorIfMinimumWagerNotMet() public guessHeads {
        uint256 wagerAmount = .001 ether;
        vm.expectRevert(
            abi.encodeWithSelector(CoinFlip.CoinFlip__MinimumWagerNotMet.selector, minimumWager, wagerAmount)
        );
        vm.prank(USER);
        coinFlip.placeWager{ value: wagerAmount }();
    }

    function testPlaceWagerAddsAmountToUsersWager() public guessHeads placeWager {
        uint256 currentWager = coinFlip.getUserCurrentWagerAmount(USER);
        assert(currentWager == minimumWager);
    }

    function testPlaceWagerAddsAmountToUsersBalance() public guessHeads {
        uint256 startingBalance = coinFlip.getUserBalance(USER);
        vm.prank(USER);
        coinFlip.placeWager{ value: minimumWager }();
        uint256 endingBalance = coinFlip.getUserBalance(USER);
        assert(endingBalance == startingBalance + minimumWager);
    }

    function testPlaceWagerReturnsAProperRequestId() public guessHeads placeWager {
        vm.prank(USER);
        uint256 requestId = coinFlip.getUserCurrentRequestId(USER);
        assert(requestId != 0);
    }

    function testPlaceWagerEmitsCoinFlippedEvent() public guessHeads {
        vm.expectEmit(true, true, true, false, coinFlipAddress);
        emit CoinFlipped(USER, minimumWager, coinFlip.getUserCurrentGuess(USER));
        vm.prank(USER);
        coinFlip.placeWager{ value: minimumWager }();
    }

    function testPlaceWagerAddsRequestIdToUsersWager() public guessHeads placeWager {
        uint256 requestId = coinFlip.getUserCurrentRequestId(USER);
        assert(requestId == 1);
    }

    function testPlaceWagerSetsTheProperRequestIdToUser() public guessHeads placeWager {
        uint256 requestId = coinFlip.getUserCurrentRequestId(USER);
        address requestIdToUser = coinFlip.getUserByRequestId(requestId);
        assert(requestIdToUser == USER);
    }

    /*//////////////////////////////////////////////////////////////
                          FULFILL RANDOM WORDS
    //////////////////////////////////////////////////////////////*/

    function testFulfillRandomWordsResultIsAlwaysInProperRange() public guessHeads placeWager fulfillRandomWords {
        uint256 result = coinFlip.getUserCurrentResult(USER);
        assert(result == 1 || result == 2);
    }

    function testFulfillRandomWordsSetsTheUserProperly() public guessTails placeWager {
        address user = coinFlip.getUserByRequestId(1);
        assert(user == USER);
    }

    function testFulfillRandomWordsAddsResultToUsersWager() public guessHeads placeWager fulfillRandomWords {
        uint256 result = coinFlip.getUserCurrentResult(USER);
        assert(result == 1 || result == 2);
    }

    function testFulfillRandomWordsResetsTheUsersCurrentWagerProperly()
        public
        guessTails
        placeWager
        fulfillRandomWords
    {
        uint256 currentWager = coinFlip.getUserCurrentWagerAmount(USER);
        CoinFlip.Guesses currentGuess = coinFlip.getUserCurrentGuess(USER);

        assert(currentWager == 0);
        assert(currentGuess == CoinFlip.Guesses.NONE);
    }

    function testFulfillRandomWordsIncreasesUserBalanceByProperAmountOnCorrectGuess() public guessTails placeWager {
        vm.prank(USER);
        uint256 startingBalance = coinFlip.getUserBalance(USER);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(1, coinFlipAddress);
        vm.prank(USER);
        uint256 endingBalance = coinFlip.getUserBalance(USER);
        assert(endingBalance == startingBalance + minimumWager);
    }

    function testFulfillRandomWordsDoesNotIncreaseUserBalanceOnIncorrectGuess() public guessHeads placeWager {
        vm.prank(USER);
        uint256 startingBalance = coinFlip.getUserBalance(USER);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(1, coinFlipAddress);
        vm.prank(USER);
        uint256 endingBalance = coinFlip.getUserBalance(USER);
        assert(endingBalance == startingBalance);
    }

    /*//////////////////////////////////////////////////////////////
                             USER WITHDRAW
    //////////////////////////////////////////////////////////////*/

    function testUserWithdrawRevertsIfBalanceIsZero() public {
        vm.prank(USER);
        vm.expectRevert(CoinFlip.CoinFlip__NoBalance.selector);
        coinFlip.userWithdraw();
    }

    function testUserWithdrawSetsTheUsersBalanceToZero() public guessTails placeWager {
        vm.prank(USER);
        coinFlip.userWithdraw();
        assert(coinFlip.getUserBalance(USER) == 0);
    }

    function testUserWithdrawSendsTheProperAmount() public addFunds guessTails placeWager {
        vm.prank(USER);
        uint256 startingUserAddressBalance = address(USER).balance;
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(1, coinFlipAddress);
        vm.prank(USER);
        coinFlip.userWithdraw();
        uint256 endingUserAddressBalance = address(USER).balance;
        assert(endingUserAddressBalance == startingUserAddressBalance + (minimumWager * 2));
    }

    /*//////////////////////////////////////////////////////////////
                             OWNER WITHDRAW
    //////////////////////////////////////////////////////////////*/

    function testOwnerWithdrawCanOnlyBeCalledByTheOwner() public {
        vm.prank(USER);
        vm.expectRevert(CoinFlip.CoinFlip__YouAreNotTheOwner.selector);
        coinFlip.ownerWithdraw(10000 ether);
    }

    function testOwnerWithdrawRevertsWhenBalanceDoesNotExceedPlayerBalances() public {
        coinFlip.addFunds{ value: 0.01 ether }();
        vm.startPrank(USER);
        coinFlip.guessTails();
        coinFlip.placeWager{ value: minimumWager }();
        vm.stopPrank();
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(1, coinFlipAddress);
        vm.prank(FOUNDRY_DEFAULT_SENDER);
        vm.expectRevert(CoinFlip.CoinFlip__NotEnoughFundsAvailable.selector);
        coinFlip.ownerWithdraw(.0001 ether);
    }

    function testOwnerWithdrawWorkIfEnoughFundsAreAvailableAndIsCalledByOwner() public addFunds {
        vm.prank(FOUNDRY_DEFAULT_SENDER);
        coinFlip.ownerWithdraw(10 ether);
    }
}
