// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { VRFConsumerBaseV2Plus } from '@chainlink/contracts/vrf/dev/VRFConsumerBaseV2Plus.sol';
import { VRFV2PlusClient } from '@chainlink/contracts/vrf/dev/libraries/VRFV2PlusClient.sol';

/// @title Coin Flip Remake
/// @author Dustin Stacy
/// @notice This contract is for creating a sample coin flip contract
/// @dev This contract implements Chainlink VRF V2.5
contract CoinFlip is VRFConsumerBaseV2Plus {
    /* Type Declarations */
    enum Guesses {
        HEADS,
        TAILS
    }

    struct Wager {
        uint256 amount;
        Guesses guess;
        uint256 requestId;
        uint256 result;
    }

    address private immutable i_owner;
    uint256 private totalPlayerBalances;
    uint256 public constant MINIMUM_WAGER = 0.01 ether;
    Wager[] public wagers;

    /* VRF State Variables */
    uint256 public subscriptionId;
    address public vrfCoordinator;
    bytes32 public keyHash;
    uint32 public callbackGasLimit;
    uint16 public requestConfirmations;
    uint32 public numWords;

    mapping(address user => uint256 balance) private balances;
    mapping(address user => Wager wager) private currentWagers;
    mapping(uint256 requestId => address user) private requestIdToUser;

    event Received(address sender, uint256 amount);
    event FallbackCalled(address sender, uint256 amount);
    event CoinFlipped(address indexed user, uint256 indexed wager, Guesses indexed guess);

    error CoinFlip__AmountMustBeGreaterThanZero();
    error CoinFlip__MinimumWagerNotMet(uint256 minimumWager, uint256 wager);
    error CoinFlip__NoBalance();
    error CoinFlip__TransferFailed();
    error CoinFlip__YouAreNotTheOwner();
    error CoinFlip__NotEnoughFundsAvailable();

    /**
     * @dev Constructor initializes the contract with Chainlink VRF parameters.
     * @param _subscriptionId Chainlink VRF subscription ID
     * @param _vrfCoordinator Address of the Chainlink VRF coordinator
     * @param _keyHash Chainlink VRF key hash
     * @param _callbackGasLimit Gas limit for VRF callback
     * @param _requestConfirmations Number of confirmations required for VRF
     * @param _numWords Number of random words requested
     */
    constructor(
        uint256 _subscriptionId,
        address _vrfCoordinator,
        bytes32 _keyHash,
        uint32 _callbackGasLimit,
        uint16 _requestConfirmations,
        uint32 _numWords
    ) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        i_owner = msg.sender;
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

    function placeWager(Guesses guess) public payable {
        if (msg.value < MINIMUM_WAGER) {
            revert CoinFlip__MinimumWagerNotMet(MINIMUM_WAGER, msg.value);
        }
        // gas report user variable vs msg.sender
        address user = msg.sender;
        currentWagers[user].guess = guess;
        currentWagers[user].amount = msg.value;
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: keyHash,
                subId: subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({ nativePayment: false }))
            })
        );
        emit CoinFlipped(user, currentWagers[user].amount, currentWagers[user].guess);
        currentWagers[user].requestId = requestId;
        requestIdToUser[requestId] = user;
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        uint256 result = randomWords[0] % 2;
        address user = requestIdToUser[requestId];
        currentWagers[user].result = result;
        wagers.push(currentWagers[user]);
        uint256 currentWager = currentWagers[user].amount;
        Guesses currentGuess = currentWagers[user].guess;
        currentWagers[user].amount = 0;

        if (uint256(currentGuess) == result) {
            uint256 payout = currentWager * 2;
            balances[user] = balances[user] + payout;
            totalPlayerBalances = totalPlayerBalances + payout;
        }
    }

    function userWithdraw() public {
        uint256 balance = balances[msg.sender];
        if (balance <= 0) {
            revert CoinFlip__NoBalance();
        }
        balances[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{ value: balance }('');
        if (!success) {
            revert CoinFlip__TransferFailed();
        }
        totalPlayerBalances = totalPlayerBalances - balance;
    }

    function ownerWithdraw(uint256 amountRequested) public {
        if (msg.sender != i_owner) {
            revert CoinFlip__YouAreNotTheOwner();
        }
        if (address(this).balance - amountRequested < totalPlayerBalances) {
            revert CoinFlip__NotEnoughFundsAvailable();
        }
        (bool success, ) = payable(msg.sender).call{ value: amountRequested }('');
        if (!success) {
            revert CoinFlip__TransferFailed();
        }
    }

    /* Getter Functions */

    function getOwner() public view returns (address) {
        return i_owner;
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getUserCurrentWagerAmount(address user) public view returns (uint256) {
        return currentWagers[user].amount;
    }

    function getUserCurrentGuess(address user) public view returns (Guesses) {
        return currentWagers[user].guess;
    }

    function getUserCurrentRequestId(address user) public view returns (uint256) {
        return currentWagers[user].requestId;
    }

    function getUserCurrentResult(address user) public view returns (uint256) {
        return currentWagers[user].result;
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

    function getWager(uint256 index) public view returns (Wager memory) {
        return wagers[index];
    }
}
