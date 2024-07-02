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

    event Received(address sender, uint256 amount);
    event FallbackCalled(address sender, uint256 amount);

    function setUp() public {
        deployer = new DeployCoinFlip();
        coinFlip = deployer.run();
        coinFlipAddress = payable(address(coinFlip));
        vm.deal(USER, STARTING_USER_BALANCE);
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
        uint256 amountSent = 1 ether;
        uint256 contractStartingBalance = coinFlip.getBalance();

        // Act
        coinFlip.addFunds{value: amountSent}();

        // Assert
        uint256 contractEndingBalance = coinFlip.getBalance();
        assert(contractStartingBalance + amountSent == contractEndingBalance);
    }

    function testAddFundsRevertsWhenValueEqualsZero() public {
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
        uint256 amountSent = 1 ether;
        uint256 contractStartingBalance = coinFlip.getBalance();

        // Act /Assert
        vm.expectEmit(true, true, false, false, coinFlipAddress);
        emit Received(USER, amountSent);
        coinFlipAddress.transfer(amountSent);

        uint256 contractEndingBalance = coinFlip.getBalance();
        assert(contractStartingBalance + amountSent == contractEndingBalance);
    }

    function testFallbackAddsFundsWhenTriggered() public {
        // Arrange
        vm.prank(USER);
        uint256 amountSent = 1 ether;
        uint256 contractStartingBalance = coinFlip.getBalance();

        // Act /Assert
        vm.expectEmit(true, true, false, false, coinFlipAddress);
        emit FallbackCalled(USER, amountSent);
        (bool success, ) = coinFlipAddress.call{value: amountSent}(
            abi.encodeWithSignature("")
        );
        if (success) {
            console.log("you did it!");
        }

        uint256 contractEndingBalance = coinFlip.getBalance();
        assert(contractStartingBalance + amountSent == contractEndingBalance);
    }
}
