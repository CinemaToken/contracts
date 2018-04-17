pragma solidity ^0.4.21;

contract owned {
    address public owner;

    function owned() public {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address newOwner) onlyOwner public {
        owner = newOwner;
    }
}

interface token {
    function transfer(address receiver, uint amount);
}

contract Crowdsale is owned {
    address public beneficiary;
    uint public fundingGoal;
    uint public amountRaised;
    uint public durationOfStage;
    uint public priceStage1;
    uint public priceStage2;
    token public tokenReward;
    mapping(address => uint256) public balanceOf;
    uint deadlineOfStage;
    bool fundingGoalReached = false;
    bool stage1End = false;
    bool stage2End = false;
    bool crowdsaleClosed = false;

    event GoalReached(address recipient, uint totalAmountRaised);
    event FundTransfer(address backer, uint amount, bool isContribution);

    /**
     * Constructor function
     *
     * Setup the owner
     */
    function Crowdsale(
        address ifSuccessfulSendTo,
        uint fundingGoalInEthers,
        uint durationInMinutes,
        uint tokenCostInEthStg1,
        uint tokenCostInEthStg2,
        address addressOfTokenUsedAsReward
    ) {
        beneficiary = ifSuccessfulSendTo;
        fundingGoal = fundingGoalInEthers * 1 ether;
        durationOfStage = durationInMinutes * 1 minutes;
        priceStage1 = tokenCostInEthStg1 * 1 ether;
        priceStage2 = tokenCostInEthStg2 * 1 ether;
        tokenReward = token(addressOfTokenUsedAsReward);
        deadlineOfStage = now + durationInMinutes * 1 minutes;
    }

    /**
     * Fallback function
     *
     * The function without name is the default function that is called whenever anyone sends funds to a contract
     */
    function () payable {
        require(!crowdsaleClosed);
        require(!stage1End || !stage2End);
        if(!stage1End)
        {
        uint amount = msg.value;
        balanceOf[msg.sender] += amount;
        amountRaised += amount;
        tokenReward.transfer(msg.sender, amount / priceStage1);
        emit FundTransfer(msg.sender, amount, true);
        }
        else
        {
        uint amount = msg.value;
        balanceOf[msg.sender] += amount;
        amountRaised += amount;
        tokenReward.transfer(msg.sender, amount / priceStage2);
        emit FundTransfer(msg.sender, amount, true);
        }
        if(amountRaised >= fundingGoal)
        {
        fundingGoalReached = true;
        }
    }

    modifier afterDeadline() { if (stage1End && stage2End) _; }

    /**
     * Change stage if deadline reached
     *
     * Checks if the deadline of any stage reached and changes stage, if both reached - crowdsale close
     */
    function changeStage() onlyOwner {
        require(!(stage1End && stage2End));
        if (!stage1End){
            if(now >= deadlineOfStage)
            {
            stage1End = true;
            deadlineOfStage = now + durationOfStage;
            }
        else{}
        }
        crowdsaleClosed = true;
    }


    /**
     * Withdraw the funds
     *
     * Checks to see if goal or time limit has been reached, and if so, and the funding goal was reached,
     * sends the entire amount to the beneficiary. If goal was not reached, each contributor can withdraw
     * the amount they contributed.
     */
    function safeWithdrawal() afterDeadline {
        if (!fundingGoalReached) {
            uint amount = balanceOf[msg.sender];
            balanceOf[msg.sender] = 0;
            if (amount > 0) {
                if (msg.sender.send(amount)) {
                    emit FundTransfer(msg.sender, amount, false);
                } else {
                    balanceOf[msg.sender] = amount;
                }
            }
        }

        if (fundingGoalReached && beneficiary == msg.sender) {
            if (beneficiary.send(amountRaised)) {
                emit FundTransfer(beneficiary, amountRaised, false);
            } else {
                //If we fail to send the funds to beneficiary, unlock funders balance
                fundingGoalReached = false;
            }
        }
    }
}

