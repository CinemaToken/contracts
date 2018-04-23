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
    bool stage1End = false;
    bool stage2End = false;
    bool crowdsaleClosed = false;

    event Closed(address recipient, uint totalAmountRaised);
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
        uint amount;
        if(!stage1End)
        {
        amount = msg.value;
        balanceOf[msg.sender] += amount;
        amountRaised += amount;
        tokenReward.transfer(msg.sender, amount / priceStage1);
        emit FundTransfer(msg.sender, amount, true);
        }
        else
        {
        amount = msg.value;
        balanceOf[msg.sender] += amount;
        amountRaised += amount;
        tokenReward.transfer(msg.sender, amount / priceStage2);
        emit FundTransfer(msg.sender, amount, true);
        }
        if(amountRaised >= fundingGoal)
        {
        crowdsaleClosed = true;
        emit Closed(beneficiary, amountRaised);
        }
    }

    /**
     * Change stage if deadline reached
     *
     * Checks if the deadline of any stage reached and changes stage, if both reached - crowdsale close
     */
    function changeStage() onlyOwner {
        require(!crowdsaleClosed);
        if (!stage1End){
            if(now >= deadlineOfStage){
            stage1End = true;
            deadlineOfStage = now + durationOfStage;
            }
            }
        else {
        if(now >= deadlineOfStage) stage2End = true;
        }
        if(stage1End && stage2End){
           crowdsaleClosed = true;
           emit Closed(beneficiary, amountRaised);
        }
    }


    /**
     * Withdraw the funds
     *
     * Checks if crowdsale was closed (hardcap or time limit has been reached) and if so
     * sends the entire amount to the beneficiary. Contributors can't withdraw the amount
     * they contributed - preICO does not provide refund.
     */
    function withdrawal() {
        if (crowdsaleClosed && (beneficiary == msg.sender)) {
            if (beneficiary.send(amountRaised)) {
                emit FundTransfer(beneficiary, amountRaised, false);
            }
        }
}

