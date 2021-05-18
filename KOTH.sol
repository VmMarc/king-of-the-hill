// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

//Imports
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Address.sol";
import "./Ownable.sol";

//Contract
contract KOTH is Ownable {
    
    // library usage
    using Address for address payable;
    
    // State variables
    mapping(address => uint256) private _balances;
    address private _owner;
    address private _KOTH;
    bool private _isStarted;
    uint256 private _betTime;
    uint256 private _winBlockNumber;
    uint256 private _currentPot;
    
    // Events
    /** @dev These events show that the steps are well executed like :
     * 
     *       -When someone bet (address, amount and the block number of the bet).
     * 
     *       -When the winner gets the prize 
     *       (winner's address, the final amount of the prize and the block number).
     * 
     *       -When the owner gets the _tax (owner's address and _tax amount).
     * 
     *       -When the first player in a new turn gets his refund and put a new bet on the winner's seed 
     *       ( first player's address, refund amount, new bet amount and block number)
    */
    event HadBet(address indexed sender, uint256 amount, uint256 betTime);
    event Withdrew(address indexed KOTH, uint256 newAmount, uint256 epochTime);
    event WithdrewTax(address indexed owner, uint256 tax);
    event RefundAndBet(address indexed sender, uint256 refund, uint256 newBet, uint256 epochTime);
    
    // Constructor
    /** @dev Here we check the owner's address and set the games variables.
     * The owner also put the very first "seed" so people can start to bet.
    */
    constructor(address owner_, uint256 winBlockNumber_) payable Ownable(owner_) {
        require(msg.value > 0, "KOTH: starting bet cannot be 0");
        require(owner_ != address(0), "KOTH: non-valid address");
        _winBlockNumber = winBlockNumber_;
        _owner = owner_;
        _balances[msg.sender] += msg.value;
        _betTime = block.number;
    }
    
    // Modifiers
    /** @dev This modifiers are security check for _deposit and _withdraw functions.
     * Check for valid address, that you do not bet on yourself 
     * and that your bet is twice the bet before you.
    */
    modifier goodBet() {
        _currentPot = address(this).balance - msg.value;
        require(msg.sender != address(0), "KOTH: Non-valid address.");
        require(msg.sender != _KOTH, "KOTH: Cannot bet on yourself.");
        require(msg.value >= _currentPot * 2, "KOTH: You must at least double the bet.");
        _;
    }
    
    /** @dev I use a boolean in the _deposit function to check if the first bet is done
     * but I kept this modifier for double security in the _withdraw function.
    */
    modifier firstBet() {
        require(_KOTH != address(0), "KOTH: No bet yet.");
        _;
    }
    
    // Functions
    receive() external payable goodBet {
        _deposit(msg.sender, msg.value);
    }
    
    fallback() external {}
    
    // @dev This is my main function where I call all the others function.
    function deposit() public payable goodBet {
        _deposit(msg.sender, msg.value);
    }
    
    /** @dev This function is used to bet and to check if there is a winner (block.number checks).
     * This function also calls the _withdraw function if there is a winner.
    */
    function _deposit(address sender, uint256 amount) private {
        if (_isStarted == false) {
            _balances[sender] += amount;
            _isStarted = true;
        } else if (block.number < _betTime + _winBlockNumber) {
            _balances[sender] += amount;
        } else {
            _withdraw();
            _paybackAndBet();
        }
        _KOTH = msg.sender;
        _betTime = block.number;
        emit HadBet(sender, amount, _betTime);
    }
    
    /** @dev This function pays out the winner (80%), the contract owner(10%).
     * It also put 10% of the prize(_seed) back in the pot for the next turn.
    */
    function _withdraw() private firstBet() {
        uint256 newAmount = _currentPot - _tax() - _seed();
        payable(_owner).sendValue(_tax());
        emit WithdrewTax(_owner, _tax());
        payable(_KOTH).sendValue(newAmount);
        emit Withdrew(_KOTH, newAmount, block.timestamp);
    }
    
    /** @dev This function is used to payback the first player in the next turn.
     * It also makes this player bet on the _seed (twice the _seed's amount).
    */
    function _paybackAndBet() private {
        uint256 refund = msg.value - (_seed() * 2);
        uint256 newBet = msg.value - refund;
        _balances[msg.sender] += newBet;
        payable(msg.sender).sendValue(refund);
        emit RefundAndBet(msg.sender, refund, newBet, block.number);
    }
    
    // @dev This function calculate de _seed for de new turn.
    function _seed() private view returns (uint256) {
        return _currentPot * 10 / 100;
    }
    
    // @dev This function calculate de _tax for the contract's owner.
    function _tax() private view returns (uint256) {
        return _currentPot * 10 / 100;
    }
    
    /** @dev These function are getters to check important variables like :
     * How many blocks left before the end of the turn, the current block number,
     * the balance of an account and the total amount in the smart contract.
    */
    function blocksLeft() public view returns (uint256) {
        if (block.number >= _betTime + _winBlockNumber) {
            return 0;
        } else {
            return (_betTime + _winBlockNumber) - block.number;
        }
    }
    
    function currentBlock() public view returns (uint256) {
        return block.number;
    }
    
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }
    
    function total() public view returns (uint256) {
        return address(this).balance;
    }
}