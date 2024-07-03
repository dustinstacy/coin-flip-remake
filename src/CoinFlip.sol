// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { VRFConsumerBaseV2Plus } from '@chainlink/contracts/vrf/dev/VRFConsumerBaseV2Plus.sol';
import { VRFV2PlusClient } from '@chainlink/contracts/vrf/dev/libraries/VRFV2PlusClient.sol';

contract CoinFlip is VRFConsumerBaseV2Plus {
    enum CoinFlipState {
        OPEN,
        CALCULATING
    }

    enum Guesses {
        NONE,
        HEADS,
        TAILS
    }

    struct Wager {
        uint256 amount;
        Guesses guess;
    }

    address private immutable i_owner;
    uint256 private constant MINIMUM_WAGER = 0.01 ether;
    uint256 private totalPlayerBalances;
    CoinFlipState coinFlipState;
    uint256 subscriptionId;
    address vrfCoordinator;
    bytes32 keyHash;
    uint32 callbackGasLimit;
    uint16 requestConfirmations;
    uint32 numWords;
    uint256 lastResult;

    mapping(address user => uint256 balance) private balances;
    mapping(address user => Wager wager) private currentWagers;
    mapping(uint256 requestId => address user) private requestIdToUser;

    event Received(address sender, uint256 amount);
    event FallbackCalled(address sender, uint256 amount);
    event CoinFlipped(address indexed user, uint256 indexed wager, Guesses indexed guess);

    error CoinFlip__AmountMustBeGreaterThanZero();
    error CoinFlip__MinimumWagerNotMet(uint256 minimumWager, uint256 wager);
    error CoinFlip__StillCalculatingResults();
    error CoinFlip__NoBalance();
    error CoinFlip__TransferFailed();
    error CoinFlip__YouAreNotTheOne();
    error CoinFlip__YouInTrouble();
    error CoinFlip__PleaseMakeAGuessFirst();

    modifier onlyOnwer() {
        if (msg.sender != i_owner) {
            revert CoinFlip__YouAreNotTheOne();
        }
        _;
    }

    modifier checkWager() {
        if (currentWagers[msg.sender].guess == Guesses.NONE) {
            revert CoinFlip__PleaseMakeAGuessFirst();
        }
        if (coinFlipState != CoinFlipState.OPEN) {
            revert CoinFlip__StillCalculatingResults();
        }
        if (currentWagers[msg.sender].amount < MINIMUM_WAGER) {
            revert CoinFlip__MinimumWagerNotMet(MINIMUM_WAGER, currentWagers[msg.sender].amount);
        }
        _;
    }

    constructor(
        uint256 _subscriptionId,
        address _vrfCoordinator,
        bytes32 _keyHash,
        uint32 _callbackGasLimit,
        uint16 _requestConfirmations,
        uint32 _numWords
    ) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        i_owner = msg.sender;
        coinFlipState = CoinFlipState.OPEN;
        subscriptionId = _subscriptionId;
        vrfCoordinator = _vrfCoordinator;
        keyHash = _keyHash;
        callbackGasLimit = _callbackGasLimit;
        requestConfirmations = _requestConfirmations;
        numWords = _numWords;
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

    function guessHeads() public {
        currentWagers[msg.sender].guess = Guesses.HEADS;
    }

    function guessTails() public {
        currentWagers[msg.sender].guess = Guesses.TAILS;
    }

    function placeWager() public payable {
        currentWagers[msg.sender].amount = msg.value;
        balances[msg.sender] = balances[msg.sender] + msg.value;
    }

    function flipCoin() public checkWager returns (uint256 requestId) {
        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: keyHash,
                subId: subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({ nativePayment: false }))
            })
        );
        emit CoinFlipped(msg.sender, currentWagers[msg.sender].amount, currentWagers[msg.sender].guess);
        coinFlipState = CoinFlipState.CALCULATING;
        requestIdToUser[requestId] = msg.sender;
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        lastResult = (randomWords[0] % 2) + 1;
        address user = requestIdToUser[requestId];
        uint256 currentWager = currentWagers[user].amount;
        Guesses currentGuess = currentWagers[user].guess;
        currentWagers[user].amount = 0;
        currentWagers[user].guess = Guesses.NONE;
        if (uint256(currentGuess) == lastResult) {
            balances[user] = balances[user] + currentWager;
            totalPlayerBalances = totalPlayerBalances + (currentWager * 2);
        }
        coinFlipState = CoinFlipState.OPEN;
    }

    function userWithdraw() public {
        uint256 balance = balances[msg.sender];
        if (balance <= 0) {
            revert CoinFlip__NoBalance();
        }
        balances[msg.sender] = 0;
        currentWagers[msg.sender].amount = 0;
        (bool success, ) = payable(msg.sender).call{ value: balance }('');
        if (!success) {
            revert CoinFlip__TransferFailed();
        }
    }

    function ownerWithdraw(uint256 amountRequested) public onlyOnwer {
        if (address(this).balance - amountRequested < totalPlayerBalances) {
            revert CoinFlip__YouInTrouble();
        }
        (bool success, ) = payable(msg.sender).call{ value: amountRequested }('');
        if (!success) {
            revert CoinFlip__TransferFailed();
        }
    }

    function getOwner() public view returns (address) {
        return i_owner;
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getMinimumWager() public pure returns (uint256) {
        return MINIMUM_WAGER;
    }

    function getUserCurrentWagerAmount(address user) public view returns (uint256) {
        return currentWagers[user].amount;
    }

    function getUserCurrentGuess(address user) public view returns (Guesses) {
        return currentWagers[user].guess;
    }

    function getUserByRequestId(uint256 reqId) public view returns (address) {
        return requestIdToUser[reqId];
    }

    function getUserBalance(address user) public view returns (uint256) {
        return balances[user];
    }

    function getTotalPlayerBalances() public view returns (uint256) {
        return totalPlayerBalances;
    }

    function getCoinFlipState() public view returns (CoinFlipState) {
        return coinFlipState;
    }

    function getLastResult() public view returns (uint256) {
        return lastResult;
    }
}
