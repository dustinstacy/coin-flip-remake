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
    uint256 public constant INITIAL_FUNDING_AMOUNT = 0.05 ether;
    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 public constant LINK_BALANCE = 100 ether;
    CoinFlip.Guesses public constant HEADS = CoinFlip.Guesses.HEADS;
    CoinFlip.Guesses public constant TAILS = CoinFlip.Guesses.TAILS;

    uint256 public minimumWager;

    event Received(address sender, uint256 amount);
    event FallbackCalled(address sender, uint256 amount);
    event CoinFlipped(address indexed user, uint256 indexed wager, CoinFlip.Guesses indexed guess);

    modifier placeWager(CoinFlip.Guesses guess) {
        vm.prank(USER);
        coinFlip.placeWager{ value: minimumWager }(guess);
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
        uint256 contractStartingBalance = coinFlip.getBalance();
        coinFlip.addFunds{ value: INITIAL_FUNDING_AMOUNT }();
        uint256 contractEndingBalance = coinFlip.getBalance();
        assert(contractStartingBalance + INITIAL_FUNDING_AMOUNT == contractEndingBalance);
    }

    function testAddFundsRevertsWithErrorWhenValueEqualsZero() public {
        vm.expectRevert(CoinFlip.CoinFlip__AmountMustBeGreaterThanZero.selector);
        coinFlip.addFunds();
    }

    function testReceiveAddsFundsWhenTriggered() public {
        uint256 contractStartingBalance = coinFlip.getBalance();
        vm.expectEmit(false, false, false, false, coinFlipAddress);
        emit Received(USER, INITIAL_FUNDING_AMOUNT);
        coinFlipAddress.transfer(INITIAL_FUNDING_AMOUNT);
        uint256 contractEndingBalance = coinFlip.getBalance();
        assert(contractStartingBalance + INITIAL_FUNDING_AMOUNT == contractEndingBalance);
    }

    function testFallbackAddsFundsWhenTriggered() public {
        uint256 startingContractBalance = coinFlip.getBalance();
        vm.expectEmit(false, false, false, false, coinFlipAddress);
        emit FallbackCalled(USER, INITIAL_FUNDING_AMOUNT);
        (bool success, ) = coinFlipAddress.call{ value: INITIAL_FUNDING_AMOUNT }(abi.encodeWithSignature(''));
        if (success) {
            console.log('you did it!');
        }
        uint256 endingContractBalance = coinFlip.getBalance();
        assert(endingContractBalance == startingContractBalance + INITIAL_FUNDING_AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                               PLACEWAGER
    //////////////////////////////////////////////////////////////*/

    function testPlaceWagerRevertsWithErrorIfMinimumWagerNotMet() public {
        uint256 wagerAmount = .001 ether;
        vm.expectRevert(
            abi.encodeWithSelector(CoinFlip.CoinFlip__MinimumWagerNotMet.selector, minimumWager, wagerAmount)
        );
        vm.prank(USER);
        coinFlip.placeWager{ value: wagerAmount }(HEADS);
    }

    function testPlaceWagerAddsAmountToUsersWager() public placeWager(HEADS) {
        uint256 currentWager = coinFlip.getUserCurrentWagerAmount(USER);
        assert(currentWager == minimumWager);
    }

    function testPlaceWagerReturnsAProperRequestId() public placeWager(HEADS) {
        uint256 requestId = coinFlip.getUserCurrentRequestId(USER);
        assert(requestId != 0);
    }

    function testPlaceWagerEmitsCoinFlippedEvent() public {
        vm.expectEmit(true, true, true, false, coinFlipAddress);
        emit CoinFlipped(USER, minimumWager, coinFlip.getUserCurrentGuess(USER));
        vm.prank(USER);
        coinFlip.placeWager{ value: minimumWager }(HEADS);
    }

    function testPlaceWagerAddsRequestIdToUsersWager() public placeWager(HEADS) {
        uint256 requestId = coinFlip.getUserCurrentRequestId(USER);
        assert(requestId == 1);
    }

    function testPlaceWagerSetsTheProperRequestIdToUser() public placeWager(HEADS) {
        uint256 requestId = coinFlip.getUserCurrentRequestId(USER);
        address requestIdToUser = coinFlip.getUserByRequestId(requestId);
        assert(requestIdToUser == USER);
    }

    /*//////////////////////////////////////////////////////////////
                          FULFILL RANDOM WORDS
    //////////////////////////////////////////////////////////////*/

    function testFulfillRandomWordsResultIsAlwaysInProperRange() public placeWager(HEADS) fulfillRandomWords {
        uint256 result = coinFlip.getUserCurrentResult(USER);
        assert(result == 1 || result == 2);
    }

    function testFulfillRandomWordsSetsTheUserProperly() public placeWager(HEADS) {
        address user = coinFlip.getUserByRequestId(1);
        assert(user == USER);
    }

    function testFulfillRandomWordsAddsResultToUsersWager() public placeWager(HEADS) fulfillRandomWords {
        uint256 result = coinFlip.getUserCurrentResult(USER);
        assert(result == 1 || result == 2);
    }

    function testFulfillRandomWordsResetsTheUsersCurrentWagerProperly() public placeWager(HEADS) fulfillRandomWords {
        uint256 currentWager = coinFlip.getUserCurrentWagerAmount(USER);
        assert(currentWager == 0);
    }

    function testFulfillRandomWordsIncreasesUserBalanceByProperAmountOnCorrectGuess(uint8 guess) public {
        vm.assume(guess < 2);
        CoinFlip.Guesses _guess = CoinFlip.Guesses(guess);
        vm.prank(USER);
        coinFlip.placeWager{ value: minimumWager }(_guess);
        uint256 startingBalance = coinFlip.getUserBalance(USER);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(1, coinFlipAddress);
        uint256 endingBalance = coinFlip.getUserBalance(USER);
        if (_guess == TAILS) {
            assert(endingBalance == startingBalance + (minimumWager * 2));
        } else if (_guess == HEADS) {
            assert(endingBalance == startingBalance);
        }
    }

    function testFulfillRandomWordsDoesNotIncreaseUserBalanceOnIncorrectGuess() public placeWager(HEADS) {
        uint256 startingBalance = coinFlip.getUserBalance(USER);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(1, coinFlipAddress);
        uint256 endingBalance = coinFlip.getUserBalance(USER);
        assert(endingBalance == startingBalance);
    }

    function testFullfillRandomWordsPushesWagerToTheWagersArray() public placeWager(HEADS) fulfillRandomWords {
        CoinFlip.Wager memory previousWager = coinFlip.getWager(0);
        assert(previousWager.amount == minimumWager);
        assert(previousWager.guess == HEADS);
        assert(previousWager.requestId == 1);
        assert(previousWager.result == 1);
    }

    /*//////////////////////////////////////////////////////////////
                             USER WITHDRAW
    //////////////////////////////////////////////////////////////*/

    function testUserWithdrawRevertsIfBalanceIsZero() public {
        vm.prank(USER);
        vm.expectRevert(CoinFlip.CoinFlip__NoBalance.selector);
        coinFlip.userWithdraw();
    }

    function testUserWithdrawSetsTheUsersBalanceToZero() public placeWager(TAILS) fulfillRandomWords {
        vm.prank(USER);
        coinFlip.userWithdraw();
        assert(coinFlip.getUserBalance(USER) == 0);
    }

    function testUserWithdrawSendsTheProperAmount() public placeWager(TAILS) {
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
        vm.startPrank(USER);
        coinFlip.placeWager{ value: INITIAL_FUNDING_AMOUNT }(TAILS);
        vm.stopPrank();
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(1, coinFlipAddress);
        vm.prank(FOUNDRY_DEFAULT_SENDER);
        vm.expectRevert(CoinFlip.CoinFlip__NotEnoughFundsAvailable.selector);
        coinFlip.ownerWithdraw(.0001 ether);
    }

    function testOwnerWithdrawWorkIfEnoughFundsAreAvailableAndIsCalledByOwner() public {
        vm.prank(FOUNDRY_DEFAULT_SENDER);
        coinFlip.ownerWithdraw(INITIAL_FUNDING_AMOUNT);
    }
}
