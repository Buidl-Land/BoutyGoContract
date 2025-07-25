// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title BountyEscrow
 * @dev Smart contract for escrow management of bounty rewards
 * @notice Handles deposit, release, and refund of bounty rewards with dispute resolution
 * @notice Only supports USDC and Bounty token payments
 */
contract BountyEscrow is ReentrancyGuard, Ownable, Pausable {
    // Escrow status enumeration
    enum EscrowStatus {
        ACTIVE,      // Funds deposited and locked
        COMPLETED,   // Funds released to winner
        REFUNDED,    // Funds returned to sponsor
        DISPUTED     // Under dispute resolution
    }

    // Escrow task structure
    struct EscrowTask {
        uint256 taskId;
        address sponsor;
        uint256 amount;
        address token;
        uint256 deadline;
        address winner;
        uint256 depositTime;
        uint256 completionTime;
        EscrowStatus status;
        bool hasDispute;
        string disputeReason;
    }

    // Dispute structure
    struct Dispute {
        uint256 taskId;
        address initiator;
        string reason;
        uint256 timestamp;
        bool resolved;
        address resolver;
        string resolution;
    }

    // State variables
    mapping(uint256 => EscrowTask) public escrows;
    mapping(uint256 => Dispute) public disputes;
    mapping(address => bool) public supportedTokens;
    mapping(address => uint256[]) public sponsorTasks;
    mapping(address => uint256[]) public winnerTasks;
    mapping(address => bool) public disputeResolvers;
    
    uint256 public nextTaskId;
    uint256 public nextDisputeId;
    address public treasury;
    address public usdcToken;
    address public bountyToken;
    uint256 public platformFeePercent; // Fee in basis points (100 = 1%)
    uint256 public disputeWindow; // Time window for disputes after completion
    
    // Events
    event RewardDeposited(
        uint256 indexed taskId,
        address indexed sponsor,
        uint256 amount,
        address token,
        uint256 deadline
    );
    
    event RewardReleased(
        uint256 indexed taskId,
        address indexed winner,
        uint256 amount,
        uint256 platformFee
    );
    
    event RewardRefunded(
        uint256 indexed taskId,
        address indexed sponsor,
        uint256 amount
    );
    
    event DisputeCreated(
        uint256 indexed disputeId,
        uint256 indexed taskId,
        address indexed initiator,
        string reason
    );
    
    event DisputeResolved(
        uint256 indexed disputeId,
        uint256 indexed taskId,
        address indexed resolver,
        string resolution
    );
    
    event TokenAdded(address indexed token);
    event TokenRemoved(address indexed token);
    event ResolverAdded(address indexed resolver);
    event ResolverRemoved(address indexed resolver);
    event PlatformFeeUpdated(uint256 oldFee, uint256 newFee);
    event DisputeWindowUpdated(uint256 oldWindow, uint256 newWindow);

    constructor(
        address _treasury,
        address _usdcToken,
        address _bountyToken,
        uint256 _platformFeePercent,
        uint256 _disputeWindow
    ) Ownable(msg.sender) {
        require(_treasury != address(0), "Treasury cannot be zero address");
        require(_usdcToken != address(0), "USDC token cannot be zero address");
        require(_bountyToken != address(0), "Bounty token cannot be zero address");
        require(_platformFeePercent <= 1000, "Platform fee too high"); // Max 10%
        
        treasury = _treasury;
        usdcToken = _usdcToken;
        bountyToken = _bountyToken;
        platformFeePercent = _platformFeePercent;
        disputeWindow = _disputeWindow;
        nextTaskId = 1;
        nextDisputeId = 1;
        
        // Add supported tokens
        supportedTokens[_usdcToken] = true;
        supportedTokens[_bountyToken] = true;
        
        // Add owner as initial dispute resolver
        disputeResolvers[msg.sender] = true;
    }

    /**
     * @dev Deposit reward for a task with ERC20 token
     * @param taskId Unique identifier for the task
     * @param tokenAddress Address of the ERC20 token
     * @param amount Amount of tokens to deposit
     * @param deadline Deadline timestamp for the task
     */
    function depositReward(
        uint256 taskId,
        address tokenAddress,
        uint256 amount,
        uint256 deadline
    ) external nonReentrant whenNotPaused {
        require(supportedTokens[tokenAddress], "Token not supported");
        require(amount > 0, "Amount must be greater than 0");
        require(deadline > block.timestamp, "Deadline must be in the future");
        require(escrows[taskId].sponsor == address(0), "Task already exists");
        
        // Transfer tokens from sponsor to this contract
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);
        
        // Create escrow record
        escrows[taskId] = EscrowTask({
            taskId: taskId,
            sponsor: msg.sender,
            amount: amount,
            token: tokenAddress,
            deadline: deadline,
            winner: address(0),
            depositTime: block.timestamp,
            completionTime: 0,
            status: EscrowStatus.ACTIVE,
            hasDispute: false,
            disputeReason: ""
        });
        
        sponsorTasks[msg.sender].push(taskId);
        
        emit RewardDeposited(taskId, msg.sender, amount, tokenAddress, deadline);
    }

    /**
     * @dev Release reward to winner (only sponsor or owner)
     * @param taskId ID of the task
     * @param winner Address of the task winner
     */
    function releaseReward(
        uint256 taskId,
        address winner
    ) external nonReentrant {
        EscrowTask storage escrow = escrows[taskId];
        require(escrow.sponsor != address(0), "Task does not exist");
        require(!escrow.hasDispute, "Task under dispute");
        require(escrow.status == EscrowStatus.ACTIVE, "Task not active");
        require(winner != address(0), "Winner cannot be zero address");
        require(
            msg.sender == escrow.sponsor || msg.sender == owner(),
            "Only sponsor or owner can release"
        );
        
        // Calculate platform fee
        uint256 platformFee = (escrow.amount * platformFeePercent) / 10000;
        uint256 winnerAmount = escrow.amount - platformFee;
        
        // Update escrow status
        escrow.winner = winner;
        escrow.completionTime = block.timestamp;
        escrow.status = EscrowStatus.COMPLETED;
        
        winnerTasks[winner].push(taskId);
        
        // Transfer funds
        if (platformFee > 0) {
            IERC20(escrow.token).transfer(treasury, platformFee);
        }
        IERC20(escrow.token).transfer(winner, winnerAmount);
        
        emit RewardReleased(taskId, winner, winnerAmount, platformFee);
    }

    /**
     * @dev Refund reward to sponsor after deadline or by owner
     * @param taskId ID of the task to refund
     */
    function refundExpired(uint256 taskId) external nonReentrant {
        EscrowTask storage escrow = escrows[taskId];
        require(escrow.sponsor != address(0), "Task does not exist");
        require(!escrow.hasDispute, "Task under dispute");
        require(escrow.status == EscrowStatus.ACTIVE, "Task not active");
        require(
            block.timestamp > escrow.deadline || msg.sender == owner(),
            "Task not expired and caller not owner"
        );
        
        // Update escrow status
        escrow.status = EscrowStatus.REFUNDED;
        
        // Transfer funds back to sponsor
        IERC20(escrow.token).transfer(escrow.sponsor, escrow.amount);
        
        emit RewardRefunded(taskId, escrow.sponsor, escrow.amount);
    }

    /**
     * @dev Create a dispute for a task
     * @param taskId ID of the task to dispute
     * @param reason Reason for the dispute
     */
    function createDispute(
        uint256 taskId,
        string calldata reason
    ) external {
        EscrowTask storage escrow = escrows[taskId];
        require(escrow.sponsor != address(0), "Task does not exist");
        require(
            msg.sender == escrow.sponsor || msg.sender == escrow.winner,
            "Only sponsor or winner can create dispute"
        );
        require(!escrow.hasDispute, "Dispute already exists");
        
        // For completed tasks, check dispute window
        if (escrow.status == EscrowStatus.COMPLETED) {
            require(
                block.timestamp <= escrow.completionTime + disputeWindow,
                "Dispute window expired"
            );
        }
        
        uint256 disputeId = nextDisputeId++;
        
        disputes[disputeId] = Dispute({
            taskId: taskId,
            initiator: msg.sender,
            reason: reason,
            timestamp: block.timestamp,
            resolved: false,
            resolver: address(0),
            resolution: ""
        });
        
        escrow.hasDispute = true;
        escrow.disputeReason = reason;
        escrow.status = EscrowStatus.DISPUTED;
        
        emit DisputeCreated(disputeId, taskId, msg.sender, reason);
    }

    /**
     * @dev Resolve a dispute (only dispute resolvers)
     * @param disputeId ID of the dispute
     * @param resolution Resolution description
     * @param releaseToWinner Whether to release funds to winner (true) or refund to sponsor (false)
     * @param winner Address of winner (if releaseToWinner is true)
     */
    function resolveDispute(
        uint256 disputeId,
        string calldata resolution,
        bool releaseToWinner,
        address winner
    ) external nonReentrant {
        require(disputeResolvers[msg.sender], "Not authorized to resolve disputes");
        
        Dispute storage dispute = disputes[disputeId];
        require(!dispute.resolved, "Dispute already resolved");
        
        EscrowTask storage escrow = escrows[dispute.taskId];
        require(escrow.hasDispute, "Task not under dispute");
        
        // Update dispute
        dispute.resolved = true;
        dispute.resolver = msg.sender;
        dispute.resolution = resolution;
        
        // Update escrow
        escrow.hasDispute = false;
        
        if (releaseToWinner) {
            require(winner != address(0), "Winner cannot be zero address");
            
            // Calculate platform fee
            uint256 platformFee = (escrow.amount * platformFeePercent) / 10000;
            uint256 winnerAmount = escrow.amount - platformFee;
            
            escrow.winner = winner;
            escrow.completionTime = block.timestamp;
            escrow.status = EscrowStatus.COMPLETED;
            
            winnerTasks[winner].push(dispute.taskId);
            
            // Transfer funds
            if (platformFee > 0) {
                IERC20(escrow.token).transfer(treasury, platformFee);
            }
            IERC20(escrow.token).transfer(winner, winnerAmount);
            
            emit RewardReleased(dispute.taskId, winner, winnerAmount, platformFee);
        } else {
            // Refund to sponsor
            escrow.status = EscrowStatus.REFUNDED;
            
            IERC20(escrow.token).transfer(escrow.sponsor, escrow.amount);
            
            emit RewardRefunded(dispute.taskId, escrow.sponsor, escrow.amount);
        }
        
        emit DisputeResolved(disputeId, dispute.taskId, msg.sender, resolution);
    }

    /**
     * @dev Add supported token (only owner)
     * @param tokenAddress Address of the token to add
     */
    function addSupportedToken(address tokenAddress) external onlyOwner {
        require(tokenAddress != address(0), "Token cannot be zero address");
        supportedTokens[tokenAddress] = true;
        emit TokenAdded(tokenAddress);
    }

    /**
     * @dev Remove supported token (only owner)
     * @param tokenAddress Address of the token to remove
     */
    function removeSupportedToken(address tokenAddress) external onlyOwner {
        supportedTokens[tokenAddress] = false;
        emit TokenRemoved(tokenAddress);
    }

    /**
     * @dev Add dispute resolver (only owner)
     * @param resolver Address to add as dispute resolver
     */
    function addDisputeResolver(address resolver) external onlyOwner {
        require(resolver != address(0), "Resolver cannot be zero address");
        disputeResolvers[resolver] = true;
        emit ResolverAdded(resolver);
    }

    /**
     * @dev Remove dispute resolver (only owner)
     * @param resolver Address to remove as dispute resolver
     */
    function removeDisputeResolver(address resolver) external onlyOwner {
        disputeResolvers[resolver] = false;
        emit ResolverRemoved(resolver);
    }

    /**
     * @dev Update platform fee (only owner)
     * @param newFeePercent New fee percentage in basis points
     */
    function updatePlatformFee(uint256 newFeePercent) external onlyOwner {
        require(newFeePercent <= 1000, "Platform fee too high"); // Max 10%
        uint256 oldFee = platformFeePercent;
        platformFeePercent = newFeePercent;
        emit PlatformFeeUpdated(oldFee, newFeePercent);
    }

    /**
     * @dev Update dispute window (only owner)
     * @param newWindow New dispute window in seconds
     */
    function updateDisputeWindow(uint256 newWindow) external onlyOwner {
        uint256 oldWindow = disputeWindow;
        disputeWindow = newWindow;
        emit DisputeWindowUpdated(oldWindow, newWindow);
    }

    /**
     * @dev Update treasury address (only owner)
     * @param newTreasury New treasury address
     */
    function updateTreasury(address newTreasury) external onlyOwner {
        require(newTreasury != address(0), "Treasury cannot be zero address");
        treasury = newTreasury;
    }

    /**
     * @dev Pause the contract (only owner)
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause the contract (only owner)
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Get escrow details
     * @param taskId ID of the task
     * @return EscrowTask struct
     */
    function getEscrow(uint256 taskId) external view returns (EscrowTask memory) {
        return escrows[taskId];
    }

    /**
     * @dev Get dispute details
     * @param disputeId ID of the dispute
     * @return Dispute struct
     */
    function getDispute(uint256 disputeId) external view returns (Dispute memory) {
        return disputes[disputeId];
    }

    /**
     * @dev Get all task IDs for a sponsor
     * @param sponsor Address of the sponsor
     * @return Array of task IDs
     */
    function getSponsorTasks(address sponsor) external view returns (uint256[] memory) {
        return sponsorTasks[sponsor];
    }

    /**
     * @dev Get all task IDs for a winner
     * @param winner Address of the winner
     * @return Array of task IDs
     */
    function getWinnerTasks(address winner) external view returns (uint256[] memory) {
        return winnerTasks[winner];
    }

    /**
     * @dev Check if a task is active and not expired
     * @param taskId ID of the task
     * @return Whether the task is active
     */
    function isTaskActive(uint256 taskId) external view returns (bool) {
        EscrowTask memory escrow = escrows[taskId];
        return escrow.status == EscrowStatus.ACTIVE && 
               block.timestamp <= escrow.deadline &&
               !escrow.hasDispute;
    }

    /**
     * @dev Emergency withdrawal function (only owner)
     * @param tokenAddress Address of token to withdraw
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(address tokenAddress, uint256 amount) external onlyOwner {
        require(tokenAddress != address(0), "Token cannot be zero address");
        IERC20(tokenAddress).transfer(owner(), amount);
    }

    /**
     * @dev Get the supported token addresses
     * @return usdcToken address and bountyToken address
     */
    function getSupportedTokens() external view returns (address, address) {
        return (usdcToken, bountyToken);
    }
}