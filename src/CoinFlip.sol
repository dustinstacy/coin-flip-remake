// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/vrf/dev/libraries/VRFV2PlusClient.sol";

contract CoinFlip is VRFConsumerBaseV2Plus {
    enum CoinFlipState {
        OPEN,
        CALCULATING
    }

    enum Guesses {
        HEADS,
        TAILS
    }

    address private immutable i_owner;
    uint256 private constant MINIMUM_WAGER = 0.01 ether;

    uint256 private s_totalPlayerBalances;
    CoinFlipState s_coinFlipState;

    uint256 s_subscriptionId;
    address vrfCoordinator;
    bytes32 s_keyHash;
    uint32 callbackGasLimit;
    uint16 requestConfirmations;
    uint32 numWords;

    mapping(address user => uint256 balance) private s_balances;
    mapping(address user => uint256 wager) private s_currentWagers;

    event Received(address sender, uint256 amount);
    event FallbackCalled(address sender, uint256 amount);
    event CoinFlipped(address user, uint256 wager, Guesses guess);

    error CoinFlip__AmountMustBeGreaterThanZero();
    error CoinFlip__MinimumWagerNotMet(uint256 minimumWager, uint256 wager);
    error CoinFlip__YouMustEnterAValidWager();
    error CoinFlip__NoBalance();
    error CoinFlip__TransferFailed();
    error CoinFlip__YouAreNotTheOne();
    error CoinFlip__YouInTrouble();

    constructor() VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_owner = msg.sender;
        s_coinFlipState = CoinFlipState.OPEN;
    }

    receive() external payable {
        addFunds();
        emit Received(msg.sender, msg.value);
    }

    fallback() external payable {
        addFunds();
        emit FallbackCalled(msg.sender, msg.value);
    }

    function addFunds() public payable {
        if (msg.value == 0) {
            revert CoinFlip__AmountMustBeGreaterThanZero();
        }
    }

    function enterWager(uint256 wager) public {
        if (wager < MINIMUM_WAGER) {
            revert CoinFlip__MinimumWagerNotMet(MINIMUM_WAGER, wager);
        }
        s_balances[msg.sender] = s_balances[msg.sender] + wager;
        s_currentWagers[msg.sender] = wager;
    }

    function guessHeads() public {
        if (s_currentWagers[msg.sender] == 0) {
            revert CoinFlip__YouMustEnterAValidWager();
        }
        emit CoinFlipped(
            msg.sender,
            s_currentWagers[msg.sender],
            Guesses.HEADS
        );
        uint256 randomWords = 1;
        bool result = randomWords == uint256(Guesses.HEADS);
        handleResult(result);
    }

    function guessTails() public {
        if (s_currentWagers[msg.sender] == 0) {
            revert CoinFlip__YouMustEnterAValidWager();
        }
        emit CoinFlipped(
            msg.sender,
            s_currentWagers[msg.sender],
            Guesses.TAILS
        );
        uint256 randomWords = 1;
        bool result = randomWords == uint256(Guesses.TAILS);
        handleResult(result);
    }

    function handleResult(bool winner) private {
        if (winner) {
            chickenDinner();
        } else {
            thanksForTheContributions();
        }
    }

    function chickenDinner() public {
        uint256 currentWager = s_currentWagers[msg.sender];
        s_currentWagers[msg.sender] = 0;
        s_balances[msg.sender] = s_balances[msg.sender] + currentWager;
        s_totalPlayerBalances = s_totalPlayerBalances + (currentWager * 2);
    }

    function thanksForTheContributions() public {
        uint256 currentWager = s_currentWagers[msg.sender];
        s_currentWagers[msg.sender] = 0;
        s_balances[msg.sender] = s_balances[msg.sender] - currentWager;
    }

    function userWithdraw() public {
        uint256 balance = s_balances[msg.sender];
        if (balance <= 0) {
            revert CoinFlip__NoBalance();
        }
        s_balances[msg.sender] = 0;
        s_currentWagers[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: balance}("");
        if (!success) {
            revert CoinFlip__TransferFailed();
        }
    }

    function ownerWithdraw(uint256 amountRequested) public {
        if (msg.sender != i_owner) {
            revert CoinFlip__YouAreNotTheOne();
        }
        if (address(this).balance - amountRequested < s_totalPlayerBalances) {
            revert CoinFlip__YouInTrouble();
        }
        (bool success, ) = payable(msg.sender).call{value: amountRequested}("");
        if (!success) {
            revert CoinFlip__TransferFailed();
        }
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {}

    function getOwner() public view returns (address) {
        return i_owner;
    }

    function getCoinFlipState() public view returns (CoinFlipState) {
        return s_coinFlipState;
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getUserBalance(address user) public view returns (uint256) {
        return s_balances[user];
    }

    function getUserCurrentWager(address user) public view returns (uint256) {
        return s_currentWagers[user];
    }

    function getMinimumWager() public pure returns (uint256) {
        return MINIMUM_WAGER;
    }

    function getTotalPlayerBalances() public view returns (uint256) {
        return s_totalPlayerBalances;
    }
}
