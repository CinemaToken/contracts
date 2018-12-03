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
  constructor () public {
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
    emit OwnershipTransferred(owner, newOwner);
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

contract CinemaCrowdsale is Ownable {
    
    using SafeMath for uint256;
    
    // general variables of crowdsale
    address public fundRecipient;           // creator may be different than recipient
    address constant public project = 0xdd870fa1b7c4700f2bd7f44238821c26f7392148;    // address where finelly will be 
transfer collected
    address public CinemaToken;
//ether
    uint256 public softcap;
    uint256 public hardcap;
    uint256 public totalRaised;             // amount of collected ether
    uint256 public amountRaised;            // current contract balance 
    uint256 public start;
    uint256 public period;
    uint256 public completeAt;              // time to stop collecting ether
    Contribution[] contributions;
    
    uint [] timeStageFinance;       // time after which can transfer the some part of ether
    uint [] percentStageFinance;    // percent of the stage
    bool [] wasStageBePayd;         // was the stage
	
    // start time to payd ether back
    uint256 timeToStartExpiredRefund;
    // duration of the refund received (1 week)
    uint256 periodOfExpiredRefund = 10 * 1 seconds;
    
    event LogFundingReceived(address addr, uint amount, uint currentTotal, uint contribution_id);
    event Transfer(address indexed _from, address indexed _to, uint _value);
        
    // if true then may be start to removeContract
    bool contractClosed = false;
    
    // investors
    struct Contribution {
        uint256 amount;
        address contributor;
        bool wasGetRefund;      // it need to get your money only once
        bool wasGetDict;        // it need to get your disctribution
        bool wasOpenVoting;     // it need to open voting only once
    }
    
    // states of the crowdsale
    enum State {
        Fundraising,        // state of ether collection or before
        Successful,         // amountRaised was reached a softcap
        Closed,             // amountRaised was reached a hardcap
        ExpiredRefund,       // crowdsale is failured or stopped from voting; payment ether back
        DivDistribution     // dividend payment to investors
    }
    State state = State.Fundraising; // initialize on create
    
    // check a state 
    modifier inState(State _state) {
        require (state == _state);
        _;
    }
    
    // financial models of dividend distribution
    enum DividendModels {
		fixReturn,
		fixReturnPerAbove,
		fullDividents,
		dividentsAutFee
	}
    DividendModels dividendModel;
    uint countInvestors;                // amout of investors at the end of ICO
    
    function setDividentModels (uint _dividendModel) private {
        if (_dividendModel == 1) {
            dividendModel = DividendModels.fixReturn;
        }
        else if (_dividendModel == 2) {
            dividendModel = DividendModels.fixReturnPerAbove;
        }
        else if (_dividendModel == 3) {
            dividendModel = DividendModels.fullDividents;
        }
        else if (_dividendModel == 4) {
            dividendModel = DividendModels.dividentsAutFee;
        }
        else {
            // code with incorrect data
        }
    }
    
    /**
    * @dev Throws if called by any dividendModel other than the current dividendModel.
    */
    modifier inDivModel(DividendModels _dividendModel) {
        require (dividendModel == _dividendModel);
        _;
    }
    
    modifier notNull (address _address) {
        require(_address != 0x0);
        _;
    }    
    
    /** @dev Interface for creating a contract
     * 
     * param startInUnixTime time of start the crowdsale
     * param durationInDays duration of the crowdsale
     * param _sopfcap mimimum collected ether than crowdsale was successful
     * param _hardcap hardcap of crowdsale
     * 1518220800, 30, 5000, 7000, "0xca35b7d915458ef540ade6068dfe2f44e8fa733c"
     */
    constructor (
        /*uint startInUnixTime,
        uint durationInDays,
        uint _softcap,
        uint _hardcap,
        address _fundRecipient*/
        uint _dividendModels
        ) public payable {
            /*start = startInUnixTime;
            period = durationInDays;
            fundRecipient = _fundRecipient;
            softcap = _softcap;
            hardcap = _hardcap;*/
            start = now;
            period = 10 * 1 days;
            fundRecipient = 0xca35b7d915458ef540ade6068dfe2f44e8fa733c;
            softcap = 50 * 1 ether;
            hardcap = 2000 * 1 ether;
            setDividentModels (_dividendModels);
            
            // add address of project
            contributions.push(
                Contribution({
                    amount: 0,
                    contributor: 0xdd870fa1b7c4700f2bd7f44238821c26f7392148,
                    wasGetRefund: false,
                    wasGetDict: false,
                    wasOpenVoting: false
                    })
                );
            
            //require (now < start);            // it allows don't start the crowdsale before now
        }
    
    /**
     * @dev add a time (stage) of payment money to the project
     * 
     * @param time time of payment
     * @param percent percent of the stage
     */
    function addTimeStageFinance (uint32 time, uint percent) public onlyOwner {
        timeStageFinance.push(time);
        wasStageBePayd.push(false);
        percentStageFinance.push(percent);
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
                wasGetDict: false,
                wasOpenVoting: false
                })
            );
        
        uint id = contributions.length - 1;      // id of sender
        
        //owner.transfer(msg.value);
        //transfer (owner, msg.value);
        emit Transfer (msg.sender, owner, msg.value);
        amountRaised = amountRaised.add(msg.value);
        
        // call event from transaction means
        emit LogFundingReceived(msg.sender, msg.value, amountRaised, id);
        
        if (amountRaised >= softcap) {
           if (amountRaised >= hardcap) {
                completeAt = now;
                // it's need to calculate the payments to the project 
                totalRaised = amountRaised;
                state = State.Closed;
            }
            else if (now > start.add(period)) {
                completeAt = now;
                totalRaised = amountRaised;
                state = State.Closed;
                countInvestors = contributions.length;
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
     * @dev return of ethers in case of an unsuccessful result crowdsale
     * 
     * @param id allows to get back ether
     */
    function getRefund(uint256 id) public inState(State.ExpiredRefund) returns (bool)
    {
        require (id <= contributions.length && id > 0
            && contributions[id].amount > 0
            && contributions[id].wasGetRefund == false
            && msg.sender == contributions[id].contributor);    // check authenticity of spender
        
        uint amountToRefund = contributions[id].amount * percentOfDeposit / 100;
        contributions[id].amount = 0;

        if(contributions[id].contributor.send(amountToRefund)) {
            // success to send back ether
            contributions[id].wasGetRefund = true;
            amountRaised = amountRaised.sub(amountToRefund);
            emit Transfer (msg.sender, contributions[id].contributor, amountToRefund);
        }
        else {
            // failure to send back ether
            contributions[id].amount = amountToRefund;
            return false;
        }
        return true;
    }
    
    /**
     * @dev transfers collected money to the project in parts
     * 
     * @param stage number of the stage that we want to pay
     */
    function transferToProject (uint256 stage) public inState(State.Closed) onlyOwner isNotVoting {
        require (stage <= timeStageFinance.length);
        require (now >= timeStageFinance[stage - 1] && wasStageBePayd[stage - 1] == false);
        
        uint amountToTransfer;      // amount of ether to transfer to the project
        
        if (stage != 1) {
            require (wasStageBePayd[stage - 2] == true);    // previos stage must be paid
        }
        
        uint percent = percentStageFinance [stage -1];
        
        amountToTransfer = totalRaised.mul(percent).div(100);
        project.transfer (amountToTransfer);                // transfer 25% to project
        emit Transfer (msg.sender, project, amountToTransfer);
        amountRaised = amountRaised.sub(amountToTransfer);
        wasStageBePayd[stage - 1] = false;
    }
    
    /**
     * @dev Fallback function
     *
     * The function without name is the default function that is called whenever anyone sends funds to a contract
     */
    function () external payable {
        contribute ();
    }
    
    /****************************************************************************************
    *                                   DIVIDENT DISTRIBUTION                               *
    * **************************************************************************************/
    uint durectShotFilmInDays = 365 * 1 days;       // how long will the film be shoting
    uint filmTotalGets;                             // how much the film collected in the rental
    uint constant percentToPlatform = 5;                     // how much from TotalGets goes to CinemaToken Team
    // start the divident disctribution and transfer 5% to CinemaToken
    function setStateDivDistribution () public onlyOwner payable {
        require(msg.sender == project);
        require (now > timeStageFinance[0] + durectShotFilmInDays); // film must be finished
        filmTotalGets = msg.value;
        if (totalRaised < filmTotalGets) {
            state = State.ExpiredRefund;
            timeToStartExpiredRefund = now;
        }
        else {
            uint partToCinemaToken = filmTotalGets / 100 * percentToPlatform;
            CinemaToken.transfer(partToCinemaToken);
            filmTotalGets -= partToCinemaToken;
            state = State.DivDistribution;
        }
    }
    
    /**
     * will there be enough money to pay them to investors at the current multiplier.
     * if no, that the multiplier decreases
     */
    function checkFixMultiplier (uint _multiplier) private returns (uint) {
        uint multiplier = _multiplier;
        if (filmTotalGets < totalRaised * multiplier) {
            multiplier = filmTotalGets / totalRaised;
        }
        return multiplier;
    }
    
    uint fixMultiplier;
    
    function setParamsFixReturn () public inState(State.DivDistribution) inDivModel(DividendModels.fixReturn) onlyOwner {
        fixMultiplier = 3;
        fixMultiplier = checkFixMultiplier(fixMultiplier);
        
    }
    
    // function for FIXED RETURN
    function fixReturn(uint256 id) public inState(State.DivDistribution) inDivModel(DividendModels.fixReturn) returns (bool)
    {
        require (id <= contributions.length && id > 0
            && contributions[id].amount > 0
            && contributions[id].wasGetDict == false
            && msg.sender == contributions[id].contributor);    // check authenticity of spender
        
        uint amountToDist = contributions[id].amount * fixMultiplier;
        contributions[id].amount = 0;

        if(contributions[id].contributor.send(amountToDist)) {
            // success to send back ether
            contributions[id].wasGetDict = true;
            amountRaised = amountRaised.sub(amountToDist);
            emit Transfer (msg.sender, contributions[id].contributor, amountToDist);
        }
        else {
            // failure to send back ether
            contributions[id].amount = amountToDist;
            return false;
        }
        return true;
    }
    
    uint perAbove;
    
    function setParamsFixReturnPerAbove () public inState(State.DivDistribution) inDivModel(DividendModels.fixReturnPerAbove) 
onlyOwner {
        fixMultiplier = 3;
        fixMultiplier = checkFixMultiplier(fixMultiplier);
        perAbove = 50;
        
    }
    
    // function for FIXED RETURN + PERCENTAGE ABOVE
    function fixReturnPerAbove(uint256 id) public inState(State.DivDistribution) inDivModel(DividendModels.fixReturnPerAbove) 
returns (bool)
    {
        require (id <= contributions.length && id > 0
            && contributions[id].amount > 0
            && contributions[id].wasGetDict == false
            && msg.sender == contributions[id].contributor);    // check authenticity of spender
        
        uint temp = contributions[id].amount * fixMultiplier;
        uint amountToDist = temp + (filmTotalGets - temp) / 100 * perAbove / countInvestors;
        contributions[id].amount = 0;

        if(contributions[id].contributor.send(amountToDist)) {
            // success to send back ether
            contributions[id].wasGetDict = true;
            amountRaised = amountRaised.sub(amountToDist);
            emit Transfer (msg.sender, contributions[id].contributor, amountToDist);
        }
        else {
            // failure to send back ether
            contributions[id].amount = amountToDist;
            return false;
        }
        return true;
    }
    
    // function for FULL DIVIDENTS
    function fullDividents(uint256 id) public inState(State.DivDistribution) inDivModel(DividendModels.fullDividents) returns 
(bool)
    {
        require (id <= contributions.length && id > 0
            && contributions[id].amount > 0
            && contributions[id].wasGetDict == false
            && msg.sender == contributions[id].contributor);    // check authenticity of spender
        
        uint multiplier = filmTotalGets / amountRaised;
        uint amountToDist = contributions[id].amount * multiplier;
        contributions[id].amount = 0;

        if(contributions[id].contributor.send(amountToDist)) {
            // success to send back ether
            contributions[id].wasGetDict = true;
            amountRaised = amountRaised.sub(amountToDist);
            emit Transfer (msg.sender, contributions[id].contributor, amountToDist);
        }
        else {
            // failure to send back ether
            contributions[id].amount = amountToDist;
            return false;
        }
        return true;
    }
    
    // function for DIVIDENTS + AUTHORS FEE
    function dividentsAutFee(uint256 id) public inState(State.DivDistribution) inDivModel(DividendModels.dividentsAutFee) 
returns (bool)
    {
        require (id <= contributions.length && id > 0
            && contributions[id].amount > 0
            && contributions[id].wasGetDict == false
            && msg.sender == contributions[id].contributor);    // check authenticity of spender
            
        uint percentToInvestors;            // what percentage of the proceeds goes to investors
        if (filmTotalGets < 1000000) {
            percentToInvestors = 50;
        }
        else if (filmTotalGets < 2000000) {
            percentToInvestors = 60;
        }
        else {
            percentToInvestors = 70;
        }
        
        uint multiplier = (filmTotalGets / 100 * percentToInvestors) / amountRaised;
        uint amountToDist = contributions[id].amount * multiplier;
        contributions[id].amount = 0;

        if(contributions[id].contributor.send(amountToDist)) {
            // success to send back ether
            contributions[id].wasGetDict = true;
            amountRaised = amountRaised.sub(amountToDist);
            emit Transfer (msg.sender, contributions[id].contributor, amountToDist);
        }
        else {
            // failure to send back ether
            contributions[id].amount = amountToDist;
            return false;
        }
        return true;
    }
        
    // @dev creator gets all money that hasn't be claimed
    function removeContract() public onlyOwner() inState(State.ExpiredRefund) {
        require (now > timeToStartExpiredRefund.add(periodOfExpiredRefund));
        selfdestruct(owner);            
    }

    /***************************************************************************************
    *                                  VOTING                                              *
    * *************************************************************************************/
	
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
        
        emit ChangeOfRules(minimumQuorum, debatingPeriodInMinutes);
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
        emit Voted(supportsProposal, msg.sender, justificationText);

        return numberOfVotes;
    }
    
    uint percentOfDeposit = 100;  // percent of the deposit is returned
    
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
            timeToStartExpiredRefund = now;
            state = State.ExpiredRefund;
            percentOfDeposit = amountRaised / totalRaised * 100;
            
        } else {
            // Proposal failed
            proposalPassed = false;
            numberOfVotes = 0;
            isVoting = false;
        }

        // Fire Events
        emit ProposalTallied(currentResultFor, currentResultAgainst, numberOfVotes, proposalPassed);
    }
}
