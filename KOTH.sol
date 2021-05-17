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
    uint256 private _betTime;
    uint256 private _winBlockNumber;
    uint256 private _currentPot;
    
    // Events
    event HadBet(address indexed sender, uint256 amount, uint256 betTime);
    event Withdrew(address indexed KOTH, uint256 newAmount, uint256 epochTime);
    event RefundAndBet(address indexed sender, uint256 refund, uint256 newBet, uint256 epochTime);
    
    // Constructor
    constructor(address owner_, uint256 winBlockNumber_) payable Ownable(owner_) {
        require(msg.value > 0, "KOTH: starting bet cannot be 0");
        require(owner_ != address(0), "KOTH: non-valid address");
        _winBlockNumber = winBlockNumber_;
        _owner = owner_;
        
        _balances[msg.sender] += msg.value;
        _betTime = block.number;
    }
    
    // Modifiers
    modifier goodBet() {
        _currentPot = address(this).balance - msg.value;
        require(msg.sender != address(0), "KOTH: Non-valid address.");
        require(msg.sender == _KOTH, "KOTH: Cannot bet on yourself.");
        require(msg.value >= _currentPot * 2, "KOTH: You must at least double the bet.");
        _;
    }
    
    modifier firstBet() {
        require(_KOTH != address(0), "KOTH: No bet yet.");
        _;
    }
    
    // Functions
    function deposit() public payable goodBet {
        _deposit(msg.sender, msg.value);
    }
    
    receive() external payable goodBet {
        _deposit(msg.sender, msg.value);
    }
    
    function _deposit(address sender, uint256 amount) private {
        if (block.number < _betTime + _winBlockNumber) {
            _balances[sender] += amount;
        } else {
            _paybackAndBet();
            _withdraw();
        }
        _KOTH = msg.sender; 
        _betTime = block.number;
        emit HadBet(sender, amount, _betTime);
    }
    
    function _withdraw() private firstBet() {
        uint256 newAmount = _currentPot - _tax() - _seed();
        payable(_owner).sendValue(_tax());
        payable(_KOTH).sendValue(newAmount);
        emit Withdrew(_KOTH, newAmount, block.timestamp);
    }
    
    function _paybackAndBet() private {
        uint256 refund = msg.value - (_seed() * 2);
        uint256 newBet = msg.value - refund;
        _balances[msg.sender] = newBet;
        payable(msg.sender).sendValue(refund);
        emit RefundAndBet(msg.sender, refund, newBet, block.number);
    }
    
    function _seed() private view returns (uint256) {
        return _currentPot * 10 / 100;
    }
    
    function _tax() private view returns (uint256) {
        return _currentPot * 10 / 100;
    }
    
    
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }
    
    function total() public view returns (uint256) {
        return address(this).balance;
    }
    
}