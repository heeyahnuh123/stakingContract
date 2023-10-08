// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "./utils/IERC20.sol";
import {IWETH} from "./utils/IWETH.sol";
import {IReceiptToken} from "./utils/IReceiptToken.sol";

contract Staking {
    IWETH public immutable wethToken;
    IERC20 public immutable rewardsToken;
    IReceiptToken public immutable receiptToken;
    address public owner;
    uint256 public duration;
    uint256 public finishAt;
    uint256 public updatedAt;
    uint256 public rewardRate;
    uint256 public rewardPerTokenStored;
    uint256 public minStakingPeriod;
    uint256 public annualInterestRate;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public userStakingStartTimestamp;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    // New variables for auto compounding
    bool public autoCompoundingEnabled;
    uint256 public autoCompoundingFeeRate; // Fee rate for auto compounding (1% as 1e16)
    address public feeCollectionContract; // Address to collect auto compounding fees
    uint256 public totalAutoCompoundingFees; // Total fees collected from auto compounding

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier updateReward(address _account) {
        rewardPerTokenStored = rewardPerToken();
        updatedAt = lastTimeRewardApplicable();
        if (_account != address(0)) {
            rewards[_account] = earned(_account);
            userRewardPerTokenPaid[_account] = rewardPerTokenStored;
        }
        _;
    }

    modifier minStakePeriodNotReached() {
        require(
            block.timestamp <
                userStakingStartTimestamp[msg.sender] + minStakingPeriod,
            "Cannot unstake now"
        );
        _;
    }

    modifier autoCompoundingEnabledOnly() {
        require(autoCompoundingEnabled, "Auto compounding is not enabled");
        _;
    }

    constructor(
        address _wethToken,
        address _rewardsToken,
        address _receiptToken,
        uint256 _minStakePeriod,
        uint256 _annualInterestRate
    ) {
        owner = msg.sender;
        wethToken = IWETH(_wethToken);
        rewardsToken = IERC20(_rewardsToken);
        receiptToken = IReceiptToken(_receiptToken);
        minStakingPeriod = _minStakePeriod;
        annualInterestRate = _annualInterestRate;

        // Initialize auto compounding variables
        autoCompoundingEnabled = false;
        autoCompoundingFeeRate = 1e16; // 1% fee rate (1e16 is 1%)
        feeCollectionContract = address(0); // Initialize to an address

        // Set the initial finishAt timestamp
        finishAt = block.timestamp;
    }

    function setRewardsDuration(uint256 _duration) external onlyOwner {
        require(
            finishAt < block.timestamp && _duration > minStakingPeriod,
            "Reward duration not finished"
        );
        duration = _duration;
    }

    function notifyRewardAmount(
        uint256 _amount
    ) external onlyOwner updateReward(address(0)) {
        if (block.timestamp > finishAt) {
            rewardRate = _amount / duration;
        } else {
            uint256 remainingRewards = rewardRate *
                (finishAt - block.timestamp);
            rewardRate = (remainingRewards + _amount) / duration;
        }

        require(rewardRate > 0, "Reward rate = 0");
        require(
            rewardRate * duration <= rewardsToken.balanceOf(address(this)),
            "Reward amount > balance"
        );

        finishAt = block.timestamp + duration;
        updatedAt = block.timestamp;
    }

    function stake() external payable updateReward(msg.sender) {
        uint256 _amount = msg.value;
        require(_amount > 0, "Amount = 0");

        wethToken.deposit{value: _amount}();
        balanceOf[msg.sender] += _amount;
        totalSupply += _amount;

        // Record the staking start timestamp
        userStakingStartTimestamp[msg.sender] = block.timestamp;

        // Mint receipt tokens with interest
        uint256 receiptAmount = calculateInterest(_amount);
        receiptToken.mint(msg.sender, receiptAmount);

        // Collect auto compounding fees
        collectAutoCompoundingFees();
    }

    function collectAutoCompoundingFees() internal {
        if (autoCompoundingEnabled) {
            uint256 feeAmount = (balanceOf[msg.sender] *
                autoCompoundingFeeRate) / 1e18;
            if (feeAmount > 0) {
                totalAutoCompoundingFees += feeAmount;
                require(
                    IERC20(address(wethToken)).transferFrom(
                        msg.sender,
                        feeCollectionContract,
                        feeAmount
                    ),
                    "Fee transfer failed"
                );
            }
        }
    }

    function calculateInterest(
        uint256 _amount
    ) internal view returns (uint256) {
        uint256 timeStaked = block.timestamp -
            userStakingStartTimestamp[msg.sender];
        uint256 annualInterest = (_amount * annualInterestRate) / 100;
        uint256 interestEarned = (annualInterest * timeStaked) / 365 days;

        return _amount + interestEarned;
    }

    function unstake()
        external
        updateReward(msg.sender)
        minStakePeriodNotReached
    {
        require(balanceOf[msg.sender] > 0, "No balance to unstake");

        uint256 stakedAmount = balanceOf[msg.sender];
        uint256 rewardAmount = rewards[msg.sender];

        // Reset user data
        balanceOf[msg.sender] = 0;
        rewards[msg.sender] = 0;
        totalSupply -= stakedAmount;
        userStakingStartTimestamp[msg.sender] = 0;

        // Withdraw staked tokens and rewards
        wethToken.withdraw(stakedAmount);
        payable(msg.sender).transfer(stakedAmount);
        if (rewardAmount > 0) {
            rewardsToken.transfer(msg.sender, rewardAmount);
        }
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return _min(block.timestamp, finishAt);
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }

        return
            rewardPerTokenStored +
            (rewardRate * (lastTimeRewardApplicable() - updatedAt) * 1e18) /
            totalSupply;
    }

    function earned(address _account) public view returns (uint256) {
        return
            (balanceOf[_account] *
                (rewardPerToken() - userRewardPerTokenPaid[_account])) /
            1e18 +
            rewards[_account];
    }

    function getReward() external updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];

        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardsToken.transfer(msg.sender, reward);
        }
    }

    function updateCanUnstakeTime() internal {
        userStakingStartTimestamp[msg.sender] =
            block.timestamp +
            minStakingPeriod;
    }

    function _min(uint256 x, uint256 y) internal pure returns (uint256) {
        return x <= y ? x : y;
    }

    // Enable or disable auto compounding
    function setAutoCompounding(bool _enabled) external onlyOwner {
        autoCompoundingEnabled = _enabled;
    }

    // Allow users to opt-in for auto compounding
    function optInAutoCompounding() external {
        require(autoCompoundingEnabled, "Auto compounding is not enabled");
        collectAutoCompoundingFees();
    }

    // Trigger auto compounding externally
    function triggerAutoCompounding() external onlyOwner {
        uint256 feesToDistribute = totalAutoCompoundingFees;
        totalAutoCompoundingFees = 0;

        if (feesToDistribute > 0) {
            rewardsToken.transfer(msg.sender, feesToDistribute);
        }
    }
}
