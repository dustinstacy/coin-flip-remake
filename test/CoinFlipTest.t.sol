// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {CoinFlip} from "src/CoinFlip.sol";
import {DeployCoinFlip} from "script/DeployCoinFlip.s.sol";
import {CodeConstants} from "script/HelperConfig.s.sol";

contract CoinFlipTest is Test, CodeConstants {
    CoinFlip coinFlip;
    address payable coinFlipAddress;
    DeployCoinFlip deployer;

    address public USER = makeAddr("user");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    uint256 public minimumWager;

    event Received(address sender, uint256 amount);
    event FallbackCalled(address sender, uint256 amount);
    event CoinFlipped(address user, uint256 wager, CoinFlip.Guesses guess);

    function setUp() public {
        deployer = new DeployCoinFlip();
        coinFlip = deployer.run();
        coinFlipAddress = payable(address(coinFlip));
        vm.deal(USER, STARTING_USER_BALANCE);
        minimumWager = coinFlip.getMinimumWager();
    }

    modifier wagerEntered() {
        vm.prank(USER);
        coinFlip.enterWager(minimumWager);
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    function testConstructorSetsTheOwnerProperly() public view {
        // Arrange / Act / Assert
        address expectedOwner = FOUNDRY_DEFAULT_SENDER;
        address owner = coinFlip.getOwner();
        assert(expectedOwner == owner);
    }

    function testConstructorSetsCoinFlipStateToOpen() public view {
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
        coinFlip.addFunds{value: minimumWager}();

        // Assert
        uint256 contractEndingBalance = coinFlip.getBalance();
        assert(contractStartingBalance + minimumWager == contractEndingBalance);
    }

    function testAddFundsRevertsWithErrorWhenValueEqualsZero() public {
        // Arrange
        vm.prank(USER);

        // Act / Assert
        vm.expectRevert(
            CoinFlip.CoinFlip__AmountMustBeGreaterThanZero.selector
        );
        coinFlip.addFunds();
    }

    function testReceiveAddsFundsWhenTriggered() public {
        // Arrange
        vm.prank(USER);
        uint256 contractStartingBalance = coinFlip.getBalance();

        // Act /Assert
        vm.expectEmit(false, false, false, false, coinFlipAddress);
        emit Received(USER, minimumWager);
        coinFlipAddress.transfer(minimumWager);

        uint256 contractEndingBalance = coinFlip.getBalance();
        assert(contractStartingBalance + minimumWager == contractEndingBalance);
    }

    function testFallbackAddsFundsWhenTriggered() public {
        // Arrange
        vm.prank(USER);
        uint256 startingContractBalance = coinFlip.getBalance();

        // Act /Assert
        vm.expectEmit(false, false, false, false, coinFlipAddress);
        emit FallbackCalled(USER, minimumWager);
        (bool success, ) = coinFlipAddress.call{value: minimumWager}(
            abi.encodeWithSignature("")
        );
        if (success) {
            console.log("you did it!");
        }

        uint256 endingContractBalance = coinFlip.getBalance();
        assert(endingContractBalance == startingContractBalance + minimumWager);
    }

    /*//////////////////////////////////////////////////////////////
                               ENTER WAGER
    //////////////////////////////////////////////////////////////*/

    function testEnterWagerRevertsWithErrorIfMinimumWagerNotMet() public {
        // Arrange
        vm.prank(USER);
        uint256 wagerAmount = .001 ether;

        // Act / Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                CoinFlip.CoinFlip__MinimumWagerNotMet.selector,
                minimumWager,
                wagerAmount
            )
        );
        coinFlip.enterWager(wagerAmount);
    }

    function testEnterWagerAddsWagerAmountToUsersBalance() public {
        // Arrange
        vm.prank(USER);
        uint256 startingUserBalance = coinFlip.getUserBalance(USER);

        // Act
        vm.prank(USER);
        coinFlip.enterWager(minimumWager);

        // Assert
        uint256 endingUserBalance = coinFlip.getUserBalance(USER);
        assert(endingUserBalance == startingUserBalance + minimumWager);
    }

    function testEnterWagerAddsWagerAmountToUsersCurrentWager() public {
        // Arrange
        vm.prank(USER);
        uint256 startingUserWager = coinFlip.getUserCurrentWager(USER);

        // Act
        vm.prank(USER);
        coinFlip.enterWager(minimumWager);

        // Assert
        uint256 endingUserWager = coinFlip.getUserCurrentWager(USER);
        assert(startingUserWager == 0);
        assert(endingUserWager == minimumWager);
    }

    /*//////////////////////////////////////////////////////////////
                       GUESS HEADS / GUESS TAILS
    //////////////////////////////////////////////////////////////*/

    function testGuessHeadsRevertsIfThereIsNoValidWager() public {
        // Arrange
        vm.prank(USER);

        // Act / Assert
        vm.expectRevert(CoinFlip.CoinFlip__YouMustEnterAValidWager.selector);
        coinFlip.guessHeads();
    }

    function testGuessTailsRevertsIfThereIsNoValidWager() public {
        // Arrange
        vm.prank(USER);

        // Act / Assert
        vm.expectRevert(CoinFlip.CoinFlip__YouMustEnterAValidWager.selector);
        coinFlip.guessTails();
    }

    function testGuessHeadsEmitsCoinFlippedEventWithHeadsAsGuess()
        public
        wagerEntered
    {
        // Act
        vm.expectEmit(false, false, false, false, coinFlipAddress);
        emit CoinFlipped(
            USER,
            coinFlip.getUserCurrentWager(USER),
            CoinFlip.Guesses.HEADS
        );
        vm.prank(USER);
        coinFlip.guessHeads();
    }

    function testGuessTailsEmitsCoinFlippedEventWithTailsAsGuess()
        public
        wagerEntered
    {
        // Act
        vm.expectEmit(false, false, false, false, coinFlipAddress);
        emit CoinFlipped(
            USER,
            coinFlip.getUserCurrentWager(USER),
            CoinFlip.Guesses.TAILS
        );
        vm.prank(USER);
        coinFlip.guessTails();
    }

    /*//////////////////////////////////////////////////////////////
                             CHICKEN DINNER
    //////////////////////////////////////////////////////////////*/

    function testChickenDinnerAddsTheUsersCurrentWagerToTheirBalance()
        public
        wagerEntered
    {
        uint256 userStartingBalance = coinFlip.getUserBalance(USER);

        vm.prank(USER);
        coinFlip.chickenDinner();
        uint256 userEndingBalance = coinFlip.getUserBalance(USER);
        assert(userEndingBalance == userStartingBalance + minimumWager);
    }

    /*//////////////////////////////////////////////////////////////
                      THANKS FOR THE CONTRIBUTIONS
    //////////////////////////////////////////////////////////////*/

    function testThanksForTheContributionsDeductsTheUsersCurrentWagerFromTheirBalance()
        public
        wagerEntered
    {
        uint256 userStartingBalance = coinFlip.getUserBalance(USER);

        vm.prank(USER);
        coinFlip.thanksForTheContributions();
        uint256 userEndingBalance = coinFlip.getUserBalance(USER);
        assert(userEndingBalance == userStartingBalance - minimumWager);
    }

    /*//////////////////////////////////////////////////////////////
                           FAKE INTERGRATION
    //////////////////////////////////////////////////////////////*/

    function testUserBalanceIncreasesWhenGuessingCorrectly()
        public
        wagerEntered
    {
        uint256 userStartingBalance = coinFlip.getUserBalance(USER);

        vm.prank(USER);
        coinFlip.guessTails();
        uint256 userEndingBalance = coinFlip.getUserBalance(USER);
        assert(userEndingBalance == userStartingBalance + minimumWager);
    }

    function testUserBalanceDecreasesWhenGuessingIncorrectly()
        public
        wagerEntered
    {
        uint256 userStartingBalance = coinFlip.getUserBalance(USER);

        vm.prank(USER);
        coinFlip.guessHeads();
        uint256 userEndingBalance = coinFlip.getUserBalance(USER);
        assert(userEndingBalance == userStartingBalance - minimumWager);
    }

    /*//////////////////////////////////////////////////////////////
                             USER WITHDRAW
    //////////////////////////////////////////////////////////////*/

    function testUserWithdrawRevertsIfBalanceIsZero() public {
        vm.prank(USER);

        vm.expectRevert(CoinFlip.CoinFlip__NoBalance.selector);
        coinFlip.userWithdraw();
    }

    function testUserWithdrawSetsTheUsersBalanceAndCurrentWagerToZero()
        public
        wagerEntered
    {
        coinFlip.addFunds{value: 10 ether}();
        vm.prank(USER);
        coinFlip.userWithdraw();

        assert(coinFlip.getUserBalance(USER) == 0);
        assert(coinFlip.getUserCurrentWager(USER) == 0);
    }

    function testUserWithdrawSendsTheProperAmount() public {
        coinFlip.addFunds{value: 10 ether}();
        vm.prank(USER);
        uint256 startingUserAddressBalance = address(USER).balance;
        coinFlip.enterWager(minimumWager);

        vm.prank(USER);
        coinFlip.userWithdraw();

        uint256 endingUserAddressBalance = address(USER).balance;
        assert(
            endingUserAddressBalance ==
                startingUserAddressBalance + minimumWager
        );
    }

    /*//////////////////////////////////////////////////////////////
                             OWNER WITHDRAW
    //////////////////////////////////////////////////////////////*/

    function testOwnerWithdrawCanOnlyBeCalledByTheOwner() public {
        vm.prank(USER);

        vm.expectRevert(CoinFlip.CoinFlip__YouAreNotTheOne.selector);
        coinFlip.ownerWithdraw(10000 ether);
    }

    function testOwnerWithdrawRevertsWhenBalanceDoesNotExceedPlayerBalances()
        public
        wagerEntered
    {
        coinFlip.addFunds{value: 0.0001 ether}();

        vm.startPrank(USER);
        coinFlip.guessTails();
        vm.stopPrank();

        vm.prank(FOUNDRY_DEFAULT_SENDER);
        vm.expectRevert(CoinFlip.CoinFlip__YouInTrouble.selector);
        coinFlip.ownerWithdraw(.0001 ether);
    }

    function testOwnerWithdrawWorkIfEnoughFundsAreAvailableAndIsCalledByOwner()
        public
    {
        coinFlip.addFunds{value: 10 ether}();
        vm.prank(FOUNDRY_DEFAULT_SENDER);
        coinFlip.ownerWithdraw(10 ether);
        assert(coinFlip.getBalance() == 0);
    }
}
