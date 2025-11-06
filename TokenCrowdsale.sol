// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenCrowdsale is ReentrancyGuard, Ownable {
    IERC20 public token;         // SimpleToken
    address payable public wallet; // where ETH is forwarded when goal reached
    uint256 public rate;         // tokens per ETH (e.g., 1000)
    uint256 public weiRaised;
    uint256 public openingTime;
    uint256 public closingTime;
    uint256 public goalWei;      // minimum goal (wei)
    uint256 public capWei;       // maximum cap (wei)
    mapping(address => uint256) public contributions;
    bool public finalized;

    event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);
    event Finalized();

    constructor(
        IERC20 token_,
        address payable wallet_,
        uint256 rate_,
        uint256 openingTime_,
        uint256 closingTime_,
        uint256 goalWei_,
        uint256 capWei_
    ) {
        require(openingTime_ < closingTime_, "Invalid times");
        require(rate_ > 0, "Rate > 0");
        require(address(token_) != address(0), "Token required");
        token = token_;
        wallet = wallet_;
        rate = rate_;
        openingTime = openingTime_;
        closingTime = closingTime_;
        goalWei = goalWei_;
        capWei = capWei_;
    }

    modifier onlyWhileOpen {
        require(block.timestamp >= openingTime && block.timestamp <= closingTime, "Crowdsale closed");
        _;
    }

    receive() external payable {
        buyTokens(msg.sender);
    }

    function buyTokens(address beneficiary) public payable nonReentrant onlyWhileOpen {
        uint256 weiAmount = msg.value;
        require(weiAmount > 0, "Zero ETH");
        require(weiRaised + weiAmount <= capWei, "Cap reached");

        contributions[beneficiary] += weiAmount;
        weiRaised += weiAmount;

        uint256 tokens = weiAmount * rate;
        // The crowdsale contract must hold enough tokens beforehand or the owner mints/transfers them
        require(token.transfer(beneficiary, tokens), "Token transfer failed");

        emit TokenPurchase(msg.sender, beneficiary, weiAmount, tokens);
    }

    /// @notice Finalize: if goal reached, forward funds; otherwise allow refunds.
    function finalize() external onlyOwner {
        require(!finalized, "Already finalized");
        require(block.timestamp > closingTime, "Not closed");

        if (weiRaised >= goalWei) {
            // success: forward funds to wallet
            wallet.transfer(address(this).balance);
        }
        // otherwise, funds remain in contract so contributors may withdraw
        finalized = true;
        emit Finalized();
    }

    /// @notice Refund for contributors if goal not reached after finalize
    function claimRefund() external nonReentrant {
        require(finalized, "Not finalized");
        require(weiRaised < goalWei, "Goal reached");
        uint256 amount = contributions[msg.sender];
        require(amount > 0, "No contribution");
        contributions[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }
}
