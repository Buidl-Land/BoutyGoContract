// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MockUSDC
 * @dev Mock USDC token for testing and development purposes
 * @notice This is a test token that mimics USDC behavior with 6 decimals
 */
contract MockUSDC is ERC20, ERC20Burnable, Ownable {
    uint8 private constant _DECIMALS = 6;
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10**_DECIMALS; // 1 billion USDC
    
    // Minting control
    mapping(address => bool) public minters;
    
    // Events
    event MinterAdded(address indexed minter);
    event MinterRemoved(address indexed minter);
    
    /**
     * @dev Constructor that creates a mock USDC token
     * @param initialSupply Initial supply of tokens to mint to deployer
     */
    constructor(uint256 initialSupply) ERC20("Mock USD Coin", "USDC") Ownable(msg.sender) {
        require(initialSupply <= MAX_SUPPLY, "Initial supply exceeds maximum supply");
        
        if (initialSupply > 0) {
            _mint(msg.sender, initialSupply);
        }
        
        // Add deployer as initial minter
        minters[msg.sender] = true;
        emit MinterAdded(msg.sender);
    }
    
    /**
     * @dev Returns the number of decimals used to get its user representation
     * USDC uses 6 decimals
     */
    function decimals() public pure override returns (uint8) {
        return _DECIMALS;
    }
    
    /**
     * @dev Mint tokens to a specific address
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) external {
        require(minters[msg.sender], "Not authorized to mint");
        require(totalSupply() + amount <= MAX_SUPPLY, "Would exceed maximum supply");
        _mint(to, amount);
    }
    
    /**
     * @dev Add a new minter (only owner)
     * @param minter Address to add as minter
     */
    function addMinter(address minter) external onlyOwner {
        require(minter != address(0), "Minter cannot be zero address");
        require(!minters[minter], "Address is already a minter");
        
        minters[minter] = true;
        emit MinterAdded(minter);
    }
    
    /**
     * @dev Remove a minter (only owner)
     * @param minter Address to remove as minter
     */
    function removeMinter(address minter) external onlyOwner {
        require(minters[minter], "Address is not a minter");
        
        minters[minter] = false;
        emit MinterRemoved(minter);
    }
    
    /**
     * @dev Faucet function for easy testing - allows anyone to mint small amounts
     * @param amount Amount to mint (max 1000 USDC per call)
     */
    function faucet(uint256 amount) external {
        require(amount <= 1000 * 10**_DECIMALS, "Amount too large for faucet");
        require(totalSupply() + amount <= MAX_SUPPLY, "Would exceed maximum supply");
        _mint(msg.sender, amount);
    }
    
    /**
     * @dev Emergency withdrawal function (only owner)
     * @param token Address of token to withdraw (address(0) for ETH)
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        if (token == address(0)) {
            (bool success, ) = owner().call{value: amount}("");
            require(success, "ETH withdrawal failed");
        } else {
            IERC20(token).transfer(owner(), amount);
        }
    }
    
    /**
     * @dev Check if an address is a minter
     * @param account Address to check
     * @return Whether the address is a minter
     */
    function isMinter(address account) external view returns (bool) {
        return minters[account];
    }
}