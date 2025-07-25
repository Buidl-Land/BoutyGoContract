// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title PromotionPayment
 * @dev Smart contract for handling cryptocurrency payments for promotion services
 * @notice Handles payments for various promotion services on the BountyGo platform
 * @notice Only supports USDC and Bounty token payments
 */
contract PromotionPayment is ReentrancyGuard, Ownable, Pausable {
    // Service types enumeration
    enum ServiceType {
        TASK_TOP,           // Task top recommendation
        PRECISION_PUSH,     // Precision user push
        BANNER_DISPLAY,     // Homepage banner display
        TAG_PRIORITY        // Tag page priority display
    }

    // Service status enumeration
    enum ServiceStatus {
        PENDING,    // Payment received, service not activated
        ACTIVE,     // Service is currently active
        COMPLETED,  // Service completed successfully
        CANCELLED   // Service cancelled/refunded
    }

    // Service price structure
    struct ServicePrice {
        uint256 pricePerDay;    // Price per day in token units
        uint256 pricePerUser;   // Price per user in token units (for precision push)
        bool isActive;          // Whether this service is available
    }

    // Service order structure
    struct ServiceOrder {
        uint256 orderId;
        address customer;
        ServiceType serviceType;
        uint256 duration;       // Duration in days (or user count for precision push)
        address paymentToken;
        uint256 amount;
        uint256 timestamp;
        uint256 activationTime;
        uint256 completionTime;
        ServiceStatus status;
        string metadata;        // Additional service-specific data
    }

    // State variables
    mapping(ServiceType => ServicePrice) public servicePrices;
    mapping(uint256 => ServiceOrder) public orders;
    mapping(address => bool) public supportedTokens;
    mapping(address => uint256[]) public customerOrders;
    mapping(ServiceType => uint256[]) public serviceOrders;
    
    uint256 public nextOrderId;
    address public treasury;
    address public usdcToken;
    address public bountyToken;
    
    // Events
    event PaymentReceived(
        uint256 indexed orderId,
        address indexed customer,
        ServiceType indexed serviceType,
        uint256 duration,
        address paymentToken,
        uint256 amount
    );
    
    event ServiceActivated(
        uint256 indexed orderId,
        address indexed customer,
        ServiceType indexed serviceType,
        uint256 activationTime
    );
    
    event ServiceCompleted(
        uint256 indexed orderId,
        address indexed customer,
        ServiceType indexed serviceType,
        uint256 completionTime
    );
    
    event ServiceCancelled(
        uint256 indexed orderId,
        address indexed customer,
        uint256 refundAmount
    );
    
    event ServicePriceUpdated(
        ServiceType indexed serviceType,
        uint256 pricePerDay,
        uint256 pricePerUser
    );
    
    event TokenAdded(address indexed token);
    event TokenRemoved(address indexed token);

    constructor(
        address _treasury,
        address _usdcToken,
        address _bountyToken
    ) Ownable(msg.sender) {
        require(_treasury != address(0), "Treasury cannot be zero address");
        require(_usdcToken != address(0), "USDC token cannot be zero address");
        require(_bountyToken != address(0), "Bounty token cannot be zero address");
        
        treasury = _treasury;
        usdcToken = _usdcToken;
        bountyToken = _bountyToken;
        nextOrderId = 1;
        
        // Add supported tokens
        supportedTokens[_usdcToken] = true;
        supportedTokens[_bountyToken] = true;
        
        // Initialize default service prices (in USDC with 6 decimals)
        servicePrices[ServiceType.TASK_TOP] = ServicePrice({
            pricePerDay: 10 * 10**6,    // 10 USDC per day
            pricePerUser: 0,
            isActive: true
        });
        
        servicePrices[ServiceType.PRECISION_PUSH] = ServicePrice({
            pricePerDay: 0,
            pricePerUser: 100000,       // 0.1 USDC per user (100000 = 0.1 * 10^6)
            isActive: true
        });
        
        servicePrices[ServiceType.BANNER_DISPLAY] = ServicePrice({
            pricePerDay: 50 * 10**6,    // 50 USDC per day
            pricePerUser: 0,
            isActive: true
        });
        
        servicePrices[ServiceType.TAG_PRIORITY] = ServicePrice({
            pricePerDay: 20 * 10**6,    // 20 USDC per day
            pricePerUser: 0,
            isActive: true
        });
    }

    /**
     * @dev Pay for promotion service with ERC20 token
     * @param serviceType Type of service to purchase
     * @param duration Duration in days (or user count for precision push)
     * @param paymentToken Address of the payment token
     * @param amount Amount of tokens to pay
     * @param metadata Additional service-specific metadata
     */
    function payForPromotion(
        ServiceType serviceType,
        uint256 duration,
        address paymentToken,
        uint256 amount,
        string calldata metadata
    ) external nonReentrant whenNotPaused {
        require(supportedTokens[paymentToken], "Payment token not supported");
        require(duration > 0, "Duration must be greater than 0");
        require(amount > 0, "Amount must be greater than 0");
        require(servicePrices[serviceType].isActive, "Service not available");
        
        // Calculate expected payment amount
        uint256 expectedAmount = calculateServiceCost(serviceType, duration, paymentToken);
        require(amount >= expectedAmount, "Insufficient payment amount");
        
        // Transfer payment from customer
        IERC20(paymentToken).transferFrom(msg.sender, treasury, amount);
        
        // Create service order
        uint256 orderId = nextOrderId++;
        orders[orderId] = ServiceOrder({
            orderId: orderId,
            customer: msg.sender,
            serviceType: serviceType,
            duration: duration,
            paymentToken: paymentToken,
            amount: amount,
            timestamp: block.timestamp,
            activationTime: 0,
            completionTime: 0,
            status: ServiceStatus.PENDING,
            metadata: metadata
        });
        
        // Update mappings
        customerOrders[msg.sender].push(orderId);
        serviceOrders[serviceType].push(orderId);
        
        emit PaymentReceived(orderId, msg.sender, serviceType, duration, paymentToken, amount);
    }

    /**
     * @dev Activate a service (only owner)
     * @param orderId ID of the order to activate
     */
    function activateService(uint256 orderId) external onlyOwner {
        ServiceOrder storage order = orders[orderId];
        require(order.customer != address(0), "Order does not exist");
        require(order.status == ServiceStatus.PENDING, "Order not pending");
        
        order.status = ServiceStatus.ACTIVE;
        order.activationTime = block.timestamp;
        
        emit ServiceActivated(orderId, order.customer, order.serviceType, block.timestamp);
    }

    /**
     * @dev Complete a service (only owner)
     * @param orderId ID of the order to complete
     */
    function completeService(uint256 orderId) external onlyOwner {
        ServiceOrder storage order = orders[orderId];
        require(order.customer != address(0), "Order does not exist");
        require(order.status == ServiceStatus.ACTIVE, "Order not active");
        
        order.status = ServiceStatus.COMPLETED;
        order.completionTime = block.timestamp;
        
        emit ServiceCompleted(orderId, order.customer, order.serviceType, block.timestamp);
    }

    /**
     * @dev Cancel a service and refund (only owner)
     * @param orderId ID of the order to cancel
     */
    function cancelService(uint256 orderId) external onlyOwner nonReentrant {
        ServiceOrder storage order = orders[orderId];
        require(order.customer != address(0), "Order does not exist");
        require(order.status == ServiceStatus.PENDING || order.status == ServiceStatus.ACTIVE, "Cannot cancel completed order");
        
        order.status = ServiceStatus.CANCELLED;
        
        // Refund the customer
        IERC20(order.paymentToken).transferFrom(treasury, order.customer, order.amount);
        
        emit ServiceCancelled(orderId, order.customer, order.amount);
    }

    /**
     * @dev Calculate the cost for a service
     * @param serviceType Type of service
     * @param duration Duration in days (or user count for precision push)
     * @param paymentToken Payment token address
     * @return Expected payment amount
     */
    function calculateServiceCost(
        ServiceType serviceType,
        uint256 duration,
        address paymentToken
    ) public view returns (uint256) {
        ServicePrice memory price = servicePrices[serviceType];
        require(price.isActive, "Service not available");
        
        uint256 baseAmount;
        if (serviceType == ServiceType.PRECISION_PUSH) {
            baseAmount = price.pricePerUser * duration; // duration = user count
        } else {
            baseAmount = price.pricePerDay * duration; // duration = days
        }
        
        // Convert price if paying with different token
        if (paymentToken == bountyToken && paymentToken != usdcToken) {
            // For simplicity, assume 1:1 conversion rate
            // In production, you might want to use an oracle for conversion
            baseAmount = baseAmount * 10**12; // Convert from 6 decimals to 18 decimals
        }
        
        return baseAmount;
    }

    /**
     * @dev Update service price (only owner)
     * @param serviceType Type of service to update
     * @param pricePerDay New price per day
     * @param pricePerUser New price per user
     * @param isActive Whether the service is active
     */
    function updateServicePrice(
        ServiceType serviceType,
        uint256 pricePerDay,
        uint256 pricePerUser,
        bool isActive
    ) external onlyOwner {
        servicePrices[serviceType] = ServicePrice({
            pricePerDay: pricePerDay,
            pricePerUser: pricePerUser,
            isActive: isActive
        });
        
        emit ServicePriceUpdated(serviceType, pricePerDay, pricePerUser);
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
     * @dev Get service price details
     * @param serviceType Type of service
     * @return ServicePrice struct
     */
    function getServicePrice(ServiceType serviceType) external view returns (ServicePrice memory) {
        return servicePrices[serviceType];
    }

    /**
     * @dev Get order details
     * @param orderId ID of the order
     * @return ServiceOrder struct
     */
    function getOrder(uint256 orderId) external view returns (ServiceOrder memory) {
        return orders[orderId];
    }

    /**
     * @dev Get all order IDs for a customer
     * @param customer Address of the customer
     * @return Array of order IDs
     */
    function getCustomerOrders(address customer) external view returns (uint256[] memory) {
        return customerOrders[customer];
    }

    /**
     * @dev Get all order IDs for a service type
     * @param serviceType Type of service
     * @return Array of order IDs
     */
    function getServiceOrders(ServiceType serviceType) external view returns (uint256[] memory) {
        return serviceOrders[serviceType];
    }

    /**
     * @dev Get the supported token addresses
     * @return usdcToken address and bountyToken address
     */
    function getSupportedTokens() external view returns (address, address) {
        return (usdcToken, bountyToken);
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
}