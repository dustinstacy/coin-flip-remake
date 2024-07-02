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
    event CoinFlipped(address user, uint256 wager);

    function setUp() public {
        deployer = new DeployCoinFlip();
        coinFlip = deployer.run();
        coinFlipAddress = payable(address(coinFlip));
        vm.deal(USER, STARTING_USER_BALANCE);
        minimumWager = coinFlip.getMinimumWager();
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
        vm.expectEmit(true, true, false, false, coinFlipAddress);
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
        vm.expectEmit(true, true, false, false, coinFlipAddress);
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
                               FLIP COIN
    //////////////////////////////////////////////////////////////*/

    function testFlipCoinRevertsWithErrorIfMinimumWagerNotMet() public {
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
        coinFlip.flipCoin(USER, wagerAmount);
    }

    function testFlipCoinAddsWagerAmountToPlayersBalance() public {
        // Arrange
        vm.prank(USER);
        uint256 wagerAmount = 1 ether;
        uint256 startingUserBalance = coinFlip.getUserBalance(USER);

        // Act
        coinFlip.flipCoin(USER, wagerAmount);

        // Assert
        uint256 endingUserBalance = coinFlip.getUserBalance(USER);
        assert(endingUserBalance == startingUserBalance + wagerAmount);
    }

    function testFlipCoinEmitsCoinFlippedEvent() public {
        // Arrange
        vm.prank(USER);
        uint256 wagerAmount = 1 ether;

        // Act
        vm.expectEmit(false, false, false, false, coinFlipAddress);
        emit CoinFlipped(USER, wagerAmount);
        coinFlip.flipCoin(USER, wagerAmount);
    }
}
