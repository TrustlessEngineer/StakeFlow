// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/**
 * @title StakeFlowToken
 * @notice Reward token for StakeFlow staking protocol
 * @dev ERC20 with burn, permit (gasless approvals), and minting capabilities
 */
contract StakeFlowToken is ERC20, ERC20Burnable, Ownable, ERC20Permit {
    
    /// @notice Maximum total supply (100 million tokens)
    uint256 public constant MAX_SUPPLY = 100_000_000 * 10**18;
    
    /// @notice Current supply minted
    uint256 public totalMinted;
    
    /// @notice Minters authorized to mint tokens (staking contract, rewards distributor)
    mapping(address => bool) public minters;
    
    /// @notice Emitted when a minter is added or removed
    event MinterUpdated(address indexed minter, bool status);
    
    /// @notice Emitted when tokens are minted as rewards
    event RewardsMinted(address indexed to, uint256 amount);

    modifier onlyMinter() {
        require(minters[msg.sender], "StakeFlowToken: caller is not a minter");
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        address _initialOwner
    ) ERC20(_name, _symbol) Ownable(_initialOwner) ERC20Permit(_name) {
        // Mint initial supply to owner for liquidity provision
        uint256 initialSupply = 10_000_000 * 10**18; // 10M tokens
        _mint(_initialOwner, initialSupply);
        totalMinted = initialSupply;
    }
    
    /**
     * @notice Add or remove a minter
     * @param _minter Address to update
     * @param _status New minter status
     */
    function setMinter(address _minter, bool _status) external onlyOwner {
        require(_minter != address(0), "StakeFlowToken: invalid address");
        minters[_minter] = _status;
        emit MinterUpdated(_minter, _status);
    }
    
    /**
     * @notice Mint rewards for stakers (called by staking contract)
     * @param _to Address to mint to
     * @param _amount Amount to mint
     */
    function mintRewards(address _to, uint256 _amount) external onlyMinter {
        require(_to != address(0), "StakeFlowToken: mint to zero address");
        require(totalMinted + _amount <= MAX_SUPPLY, "StakeFlowToken: max supply exceeded");
        
        totalMinted += _amount;
        _mint(_to, _amount);
        emit RewardsMinted(_to, _amount);
    }
    
    /**
     * @notice Batch mint rewards to multiple users (gas efficient)
     * @param _recipients Array of recipient addresses
     * @param _amounts Array of amounts
     */
    function batchMintRewards(
        address[] calldata _recipients,
        uint256[] calldata _amounts
    ) external onlyMinter {
        require(_recipients.length == _amounts.length, "StakeFlowToken: length mismatch");
        require(_recipients.length <= 100, "StakeFlowToken: batch too large");
        
        uint256 totalAmount;
        for (uint256 i = 0; i < _amounts.length; i++) {
            totalAmount += _amounts[i];
        }
        require(totalMinted + totalAmount <= MAX_SUPPLY, "StakeFlowToken: max supply exceeded");
        
        for (uint256 i = 0; i < _recipients.length; i++) {
            address recipient = _recipients[i];
            require(recipient != address(0), "StakeFlowToken: mint to zero");
            _mint(recipient, _amounts[i]);
            emit RewardsMinted(recipient, _amounts[i]);
        }
        
        totalMinted += totalAmount;
    }
    
    /**
     * @notice Burn tokens from caller
     * @param _amount Amount to burn
     */
    function burn(uint256 _amount) public override {
        super.burn(_amount);
    }
    
    /**
     * @notice Burn tokens from an approved address
     * @param _from Address to burn from
     * @param _amount Amount to burn
     */
    function burnFrom(address _from, uint256 _amount) public override {
        super.burnFrom(_from, _amount);
    }
    
    /**
     * @notice Rescue tokens accidentally sent to contract
     * @param _token Token address
     * @param _amount Amount to rescue
     */
    function rescueTokens(address _token, uint256 _amount) external onlyOwner {
        require(_token != address(this), "StakeFlowToken: cannot rescue self");
        IERC20(_token).transfer(owner(), _amount);
    }
}

/// @dev Minimal ERC20 interface for rescue function
interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
}
