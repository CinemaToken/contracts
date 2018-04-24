pragma solidity ^0.4.19;

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
    
  address public owner;

  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  function Ownable() public {
    owner = msg.sender;
  }

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to.
   */
  function transferOwnership(address newOwner) onlyOwner public {
    require(newOwner != address(0));
    OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }

}

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }
 
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
     assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
     assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }
 
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a); 
    return a - b; 
  } 
  
  function add(uint256 a, uint256 b) internal pure returns (uint256) { 
    uint256 c = a + b; assert(c >= a);
    return c;
  }
}

contract CinemaTokenCrowdfunding is Ownable {
    
    using SafeMath for uint256;
    
    // general variables of crowdfunding
    address public fundRecipient;           // creator may be different than recipient
    address project = 0xdd870fa1b7c4700f2bd7f44238821c26f7392148;    // address where finelly will be transfer collected 
ether
    uint256 public minimumToRaise;          // required to reach at least this much, else everyone gets refund
    uint256 public maximumToRaise;          // required to achieve this in order to complete the collection of ether
    uint256 public totalRaised;             // amount of collected ether
    uint256 public amountRaised;            // current contract balance 
    uint256 public start;                   // time to start the crowdfunding
    uint256 public period;                  // duration
    uint256 public completeAt;              // time to stop collecting ether
    Contribution[] contributions;
    
    // time after which can transfer the some part of ether
    uint256 timeStageFinance1 = now + 10 * 1 seconds;
    uint256 timeStageFinance2 = now + 60 * 1 seconds;
    uint256 timeStageFinance3 = now + 90 * 1 seconds;
    uint256 timeStageFinance4 = now + 120 * 1 seconds;
    // start time to payd ether back
    uint256 timeToStartExpiredRefund;
    // duration of the refund received (1 week)
    uint256 periodOfExpiredRefund = 10 * 1 seconds;
    
    event LogFundingReceived(address addr, uint amount, uint currentTotal, uint contribution_id);
    event Transfer(address indexed _from, address indexed _to, uint _value);
    
    // paid the some part of the ether
    bool wasStageBePayd1 = false;                
    bool wasStageBePayd2 = false;
    bool wasStageBePayd3 = false;
    bool wasStageBePayd4 = false;
    
    // if true then may be start to removeContract
    bool contractClosed = false;
    
    // invesvestors
    struct Contribution {
        uint256 amount;
        address contributor;
        bool wasGetRefund;      // it need to get your money only once
        bool wasOpenVoting;     // it need to open voting only once
    }
    
    // states of the crowdfunding
    enum State {
        Fundraising,        // state of ether collection or before
        Successful,         // amountRaised was reached a minimumToRaise
        Closed,             // amountRaised was reached a maximumToRaise
        ExpiredRefund       // crowdfunding is failured or stopped from voting; payment ether back
    }
    
    State state = State.Fundraising; // initialize on create
    
    // check a state 
    modifier inState(State _state) {
        require (state == _state);
        _;
    }
    
    modifier notNull (address _address) {
        require(_address != 0x0);
        _;
    }
    
    // check for a voting
    modifier isNotVoting() {
        require (isVoting == false);
        _;
    }
    
    // Variables and events for the voting
    uint256 public minimumQuorum = 1;
    uint256 public debatingPeriodInMinutes = 15;
   
    event Voted(bool position, address voter, string justification);
    // proposal calculated
    event ProposalTallied(uint resultFor, uint resultAgainst, uint quorum, bool active);
    event ChangeOfRules(uint newMinimumQuorum, uint newDebatingPeriodInMinutes);

    // Variables of proposal
    string description;
    uint votingDeadline;
    bool public isVoting = false;           // is the voting in progress now
    uint numberOfVotes;
    uint currentResultFor;                  // number of votes FOR performing
    uint currentResultAgainst;               // number of votes AGAINST performing
    
    mapping (address => bool) voted;
    
    
    /** @dev Interface for creating a contract
     * 
     * param startInUnixTime time of start the crowdfunding
     * param durationInDays duration of the crowdfunding
     * param _minimumToRaise mimimum collected ether than crowdfunding was successful
     * param _maximumToRaise hardcap of crowdfunding
     * 1518220800, 30, 5000, 7000, "0xca35b7d915458ef540ade6068dfe2f44e8fa733c"
     */
    function CinemaTokenCrowdfunding (
        /*uint startInUnixTime,
        uint durationInDays,
        uint _minimumToRaise,
        uint _maximumToRaise,
        address _fundRecipient*/
        ) public payable {
            /*start = startInUnixTime;
            period = durationInDays;
            fundRecipient = _fundRecipient;
            minimumToRaise = _minimumToRaise;
            maximumToRaise = _maximumToRaise;*/
            start = now;
            period = 10 * 1 seconds;
            fundRecipient = 0xca35b7d915458ef540ade6068dfe2f44e8fa733c;
            minimumToRaise = 50 * 1 ether;
            maximumToRaise = 2000 * 1 ether;
            
            // add address of project
            contributions.push(
                Contribution({
                    amount: 0,
                    contributor: 0xdd870fa1b7c4700f2bd7f44238821c26f7392148,
                    wasGetRefund: false,
                    wasOpenVoting: false
                    })
                );
            
            //require (now < start);            // it allows don't start the crowdfunding before now
        }
        

    /**
     * @dev function from transferring an electronic's contribution to the project account
     * 
     * msg.value how many ether sented by the contribution
     * msg.sender address of contribution
     */
    function contribute() public payable
    {   
        // it allows collecting money only during fundraising
        require (state == State.Fundraising || state == State.Successful);
        
        // add record about transaction in struct
        contributions.push(
            Contribution({
                amount: msg.value,
                contributor: msg.sender,
                wasGetRefund: false,
                wasOpenVoting: false
                })
            );
        
        uint id = contributions.length - 1;      // id of sender
        
        //owner.transfer(msg.value);
        //transfer (owner, msg.value);
        //Transfer (msg.sender, owner, msg.value);
        amountRaised = amountRaised.add(msg.value);
        
        // call event from transaction means
        LogFundingReceived(msg.sender, msg.value, amountRaised, id);
        
        if (amountRaised >= minimumToRaise) {
           if (amountRaised >= maximumToRaise) {
                completeAt = now;
                // it's need to calculate the payments to the project 
                totalRaised = amountRaised;
                state = State.Closed;
            }
            else if (now > start.add(period)) {
                completeAt = now;
                totalRaised = amountRaised;
                state = State.Closed;
            }
            state = State.Successful;
        }
        else
            if (now > start.add(period)) {
                completeAt = now;
                timeToStartExpiredRefund = now;
                state = State.ExpiredRefund;
            }
    }
    
    /**
     * @dev return of ethers in case of an unsuccessful result crowdfunding
     * 
     * @param id allows to get back ether
     */
    function getRefund(uint256 id) public inState(State.ExpiredRefund) returns (bool)
    {
        require (id <= contributions.length && id > 0
            && contributions[id].amount > 0
            && contributions[id].wasGetRefund == false
            && msg.sender == contributions[id].contributor);    // check authenticity of spender
        
        uint amountToRefund = contributions[id].amount;
        contributions[id].amount = 0;

        if(!contributions[id].contributor.send(amountToRefund)) {
            // failure to send back ether
            contributions[id].amount = amountToRefund;
            return false;
        }
        else {
            // success to send back ether
            contributions[id].wasGetRefund = true;
            amountRaised = amountRaised.sub(amountToRefund);
        }
        return true;
    }
    
    
    /**
     * @dev transfers collected money to the project in parts
     * 
     * @param stage number of the stage that we want to pay
     */
    function transferToProject (uint256 stage) public inState(State.Closed) onlyOwner isNotVoting {
        
        uint amountToTransfer;      // amount of ether to transfer to the project
        
        // collected ethers are paid
        if (stage == 1) {
            require (now >= timeStageFinance1 && wasStageBePayd1 == false);
            amountToTransfer = totalRaised.mul(10).div(100);
            project.transfer (amountToTransfer);            // transfer 10% to project
            amountRaised = amountRaised.sub(amountToTransfer);
            wasStageBePayd1 = true;
            return;
        }
        if (stage == 2) {
            require (now >= timeStageFinance2 && wasStageBePayd2 == false);
            amountToTransfer = totalRaised.mul(30).div(100);
            project.transfer (amountToTransfer);            // transfer 30% to project
            amountRaised = amountRaised.sub(amountToTransfer);
            wasStageBePayd2 = true;
            return;
        }
        if (stage == 3) {
            require (now >= timeStageFinance3 && wasStageBePayd3 == false);
            amountToTransfer = totalRaised.mul(30).div(100);
            project.transfer (amountToTransfer);            // transfer 30% to project
            amountRaised = amountRaised.sub(amountToTransfer);
            wasStageBePayd3 = true;
            return;
        }
        if (stage == 4) {
            require (now >= timeStageFinance4 && wasStageBePayd4 == false);
            
            project.transfer (amountRaised);                 // transfer remaining to project
            amountRaised = 0;
            wasStageBePayd4 = true;
        }
    }
        
        // @dev creator gets all money that hasn't be claimed
        function removeContract() public onlyOwner() inState(State.ExpiredRefund) {
            require (now > timeToStartExpiredRefund.add(periodOfExpiredRefund));
            selfdestruct(owner);            
        }

    /**
     * @dev Fallback function
     *
     * The function without name is the default function that is called whenever anyone sends funds to a contract
     */
    function () external payable {
        contribute ();
    }
    
    /***************************************************************************************
    *                                  VOTING                                              *
    * *************************************************************************************/

    /**
     * Change voting rules
     *
     * Make so that proposals need to be discussed for at least `debatingPeriodInMinutes/60` hours,
     * have at least `minimumQuorum` votes to be executed
     *
     * @param _minimumQuorum how many members must vote on a proposal for it to be executed
     * @param _debatingPeriodInMinutes the minimum amount of delay between when a proposal is made and when it can be 
executed
     */
    function changeVotingRules(
        uint _minimumQuorum,
        uint _debatingPeriodInMinutes
    ) onlyOwner isNotVoting public {
        minimumQuorum = _minimumQuorum;
        debatingPeriodInMinutes = _debatingPeriodInMinutes;

        ChangeOfRules(minimumQuorum, debatingPeriodInMinutes);
    }

    /**
     * Open Proposal
     *
     * @param _description Description of job
     * @param yourId allows to prohibit the re-opening of a voting this contributor
     */
    function openProposal(string _description, uint256 yourId
    ) isNotVoting inState(State.Closed) public
    {
        require (msg.sender == contributions[yourId].contributor);  // check authenticity of spender
        
        votingDeadline = now.add(debatingPeriodInMinutes) * 1 seconds;  // for tests
        numberOfVotes = 0;
        description = _description;
        isVoting = true;
        contributions[yourId].wasOpenVoting = true;
        
        // change minimumQuorum knowing the number of invested
        // minimum 50% insvestors must to voting than voting will be perform, besides rest
        // condition allows to avoid the state when minimumQuorum is very small
        if (contributions.length / 2 > minimumQuorum)
            changeVotingRules(contributions.length / 2, debatingPeriodInMinutes);
        
        // vote of the creator proposal automatically add as true
        vote (yourId, true, description);
    }

    /**
     * Log a vote for a proposal
     *
     * Vote `supportsProposal? in support of : against` proposal #`proposalNumber`
     *
     * @param supportsProposal either in favor or against it
     * @param justificationText optional justification text
     */
    function vote (uint256 yourId,
        bool supportsProposal,
        string justificationText
    ) public returns (uint)
    {
        require (isVoting                                       // the voting must already begin
            && msg.sender == contributions[yourId].contributor  // voting must take place
            && !voted[msg.sender]);                             // If has already voted, cancel
        voted[msg.sender] = true;                               // Set this voter as having voted
        uint weightOfVote = contributions[yourId].amount;       // strength of voice depends from amount invested ether
        numberOfVotes ++;                                       // Increase the number of votes
        if (supportsProposal) {                                 // If they support the proposal
            currentResultFor = currentResultFor.add(weightOfVote);  // Increase FOR
        } else {                                                // If they don't
            currentResultAgainst = currentResultAgainst.add(weightOfVote); // Increase AGAINST
        }

        // Create a log of this event
        Voted(supportsProposal, msg.sender, justificationText);
        
        return numberOfVotes;
    }

    /**
     * Finish vote
     *
     * Count the votes proposal #`proposalNumber` and execute it if approved
     * 
     */
    function executeProposal() public {
        require(now > votingDeadline                // If it is past the voting deadline
            && isVoting                             // and it has not already been executed
            && numberOfVotes >= minimumQuorum);     // and a minimum quorum has been reached...
        
        // ...then execute result
        
        bool proposalPassed;                        // need for event
        
        if (currentResultFor > currentResultAgainst) {
            // Proposal successful
            proposalPassed = true;
            isVoting = false;
            completeAt = now;
            state = State.ExpiredRefund;
        } else {
            // Proposal failed
            proposalPassed = false;
            numberOfVotes = 0;
            isVoting = false;
        }

        // Fire Events
        ProposalTallied(currentResultFor, currentResultAgainst, numberOfVotes, proposalPassed);
    }
}
