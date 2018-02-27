pragma solidity ^0.4.15;

import "./ITL.sol";

contract ReentrancyGuard {

  /**
   * @dev We use a single lock for the whole contract.
   */
  bool private rentrancy_lock = false;

  /**
   * @dev Prevents a contract from calling itself, directly or indirectly.
   * @notice If you mark a function `nonReentrant`, you should also
   * mark it `external`. Calling one nonReentrant function from
   * another is not supported. Instead, you can implement a
   * `private` function doing the actual work, and a `external`
   * wrapper marked as `nonReentrant`.
   */
  modifier nonReentrant() {
    require(!rentrancy_lock);
    rentrancy_lock = true;
    _;
    rentrancy_lock = false;
  }
}

contract Stateful {
  enum State {
  Private,
  PreSale,
  sellIsOver
  }
  State public state = State.Private;

  event StateChanged(State oldState, State newState);

  function setState(State newState) internal {
    State oldState = state;
    state = newState;
    StateChanged(oldState, newState);
  }
}

contract PreICO is ReentrancyGuard, Ownable, Stateful {
  using SafeMath for uint256;

  ITL public token;

  address public wallet;


  uint256 public startPreICOTime;
  uint256 public endPreICOTime;

  // how many token units a buyer gets per cent
  uint256 public rate; //

  uint256 public priceUSD; // wei in one USD

  // amount of raised money in wei
  uint256 public centRaised;

  uint256 public softCapPreSale; // IN USD CENT
  uint256 public hardCapPreSale; // IN USD CENT
  uint256 public hardCapPrivate; // IN USD CENT

  address public oracle;
  address public manager;

  // investors => amount of money
  mapping(address => uint) public balances;
  mapping(address => uint) public balancesInCent;

  event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);


  function PreICO(
  address _wallet,
  address _token,
  uint256 _priceUSD) public
  {
    require(_priceUSD != 0);
    require(_wallet != address(0));
    require(_token != address(0));
    priceUSD = _priceUSD;
    rate = 250000000000000000; // 0.25 * 1 ether per one cent
    wallet = _wallet;
    token = ITL(_token);
    hardCapPrivate = 40000000;
  }

  modifier saleIsOn() {
    bool withinPeriod = now >= startPreICOTime && now <= endPreICOTime;
    require(withinPeriod && state == State.PreSale || state == State.Private);
    _;
  }

  modifier isUnderHardCap() {
    bool underHardCap;
    if (state == State.Private){
      underHardCap = centRaised < hardCapPrivate;
    }
    else {
      underHardCap = centRaised < hardCapPreSale;
    }
    require(underHardCap);
    _;
  }

  modifier onlyOracle(){
    require(msg.sender == oracle);
    _;
  }

  modifier onlyOwnerOrManager(){
    require(msg.sender == manager || msg.sender == owner);
    _;
  }

  function hasEnded() public view returns (bool) {
    return now > endPreICOTime;
  }

  // Override this method to have a way to add business logic to your crowdsale when buying
  function getTokenAmount(uint256 centValue) internal view returns(uint256) {
    return centValue.mul(rate);
  }

  // send ether to the fund collection wallet
  // override to create custom fund forwarding mechanisms
  function forwardFunds(uint256 value) internal {
    wallet.transfer(value);
  }

  function startPreSale(uint256 _softCapPreSale,
  uint256 _hardCapPreSale,
  uint256 period) public onlyOwner
  {
    startPreICOTime = now;
    endPreICOTime = startPreICOTime + (period * 1 days);
    softCapPreSale = _softCapPreSale;
    hardCapPreSale = _hardCapPreSale;
    setState(State.PreSale);
  }

  function finishPreSale() public onlyOwner {
    require(centRaised > softCapPreSale);
    setState(State.sellIsOver);
    token.transferOwnership(owner);
    forwardFunds(this.balance);
  }

  function setOracle(address _oracle) public  onlyOwner {
    require(_oracle != address(0));
    oracle = _oracle;
  }

  // set manager's address
  function setManager(address _manager) public  onlyOwner {
    require(_manager != address(0));
    manager = _manager;
  }

  //set new rate
  function changePriceUSD(uint256 _priceUSD) public  onlyOracle {
    require(_priceUSD != 0);
    priceUSD = _priceUSD;
  }

  modifier refundAllowed()  {
    require(state != State.Private && centRaised < softCapPreSale && now > endPreICOTime);
    _;
  }

  function refund() public refundAllowed nonReentrant {
    uint valueToReturn = balances[msg.sender];
    balances[msg.sender] = 0;
    msg.sender.transfer(valueToReturn);
  }

  function manualTransfer(address _to, uint _valueUSD) public saleIsOn isUnderHardCap onlyOwnerOrManager {
    uint256 centValue = _valueUSD.mul(100);
    uint256 tokensAmount = getTokenAmount(centValue);
    centRaised = centRaised.add(centValue);
    token.mint(_to, tokensAmount);
    balancesInCent[_to] = balancesInCent[_to].add(centValue);
  }

  function buyTokens(address beneficiary) saleIsOn isUnderHardCap nonReentrant public payable {
    require(beneficiary != address(0) && msg.value != 0);
    uint256 weiAmount = msg.value;
    uint256 centValue = weiAmount.div(priceUSD);
    uint256 tokens = getTokenAmount(centValue);
    centRaised = centRaised.add(centValue);
    token.mint(beneficiary, tokens);
    balances[msg.sender] = balances[msg.sender].add(weiAmount);
    TokenPurchase(msg.sender, beneficiary, weiAmount, tokens);
    if (centRaised > softCapPreSale || state == State.Private) {
      forwardFunds(weiAmount);
    }
  }

  function () external payable {
    buyTokens(msg.sender);
  }
}
