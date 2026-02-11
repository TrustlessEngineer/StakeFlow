// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/StakeFlowToken.sol";

/**
 * @title StakeFlowTokenTest
 * @notice Test suite for StakeFlow reward token
 */
contract StakeFlowTokenTest is Test {
    
    StakeFlowToken public token;
    address public owner;
    address public minter;
    address public alice;
    address public bob;
    
    uint256 constant INITIAL_SUPPLY = 10_000_000 * 10**18;
    uint256 constant MAX_SUPPLY = 100_000_000 * 10**18;

    function setUp() public {
        owner = makeAddr("owner");
        minter = makeAddr("minter");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        
        vm.prank(owner);
        token = new StakeFlowToken("StakeFlow Token", "SFT", owner);
    }

    function test_InitialState() public {
        assertEq(token.name(), "StakeFlow Token");
        assertEq(token.symbol(), "SFT");
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY);
        assertEq(token.totalMinted(), INITIAL_SUPPLY);
        assertEq(token.MAX_SUPPLY(), MAX_SUPPLY);
    }

    function test_SetMinter() public {
        vm.prank(owner);
        token.setMinter(minter, true);
        assertTrue(token.minters(minter));
        
        vm.prank(owner);
        token.setMinter(minter, false);
        assertFalse(token.minters(minter));
    }

    function test_MintRewards() public {
        vm.prank(owner);
        token.setMinter(minter, true);
        
        uint256 mintAmount = 1000 * 10**18;
        
        vm.prank(minter);
        token.mintRewards(alice, mintAmount);
        
        assertEq(token.balanceOf(alice), mintAmount);
        assertEq(token.totalMinted(), INITIAL_SUPPLY + mintAmount);
    }

    function test_BatchMintRewards() public {
        vm.prank(owner);
        token.setMinter(minter, true);
        
        address[] memory recipients = new address[](3);
        recipients[0] = alice;
        recipients[1] = bob;
        recipients[2] = owner;
        
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 100 * 10**18;
        amounts[1] = 200 * 10**18;
        amounts[2] = 300 * 10**18;
        
        vm.prank(minter);
        token.batchMintRewards(recipients, amounts);
        
        assertEq(token.balanceOf(alice), 100 * 10**18);
        assertEq(token.balanceOf(bob), 200 * 10**18);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY + 300 * 10**18);
    }

    function test_RevertMintNotMinter() public {
        vm.prank(alice);
        vm.expectRevert("StakeFlowToken: caller is not a minter");
        token.mintRewards(alice, 1000 * 10**18);
    }

    function test_RevertExceedMaxSupply() public {
        vm.prank(owner);
        token.setMinter(minter, true);
        
        vm.prank(minter);
        vm.expectRevert("StakeFlowToken: max supply exceeded");
        token.mintRewards(alice, MAX_SUPPLY); // Way over limit
    }

    function test_Burn() public {
        uint256 burnAmount = 1000 * 10**18;
        uint256 balanceBefore = token.balanceOf(owner);
        
        vm.prank(owner);
        token.burn(burnAmount);
        
        assertEq(token.balanceOf(owner), balanceBefore - burnAmount);
    }

    function test_Permit() public {
        uint256 privateKey = 0x1234;
        address signer = vm.addr(privateKey);
        
        // Send some tokens to signer
        vm.prank(owner);
        token.transfer(signer, 1000 * 10**18);
        
        uint256 value = 500 * 10**18;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = token.nonces(signer);
        
        // Create permit signature
        bytes32 structHash = keccak256(abi.encode(
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
            signer,
            alice,
            value,
            nonce,
            deadline
        ));
        
        bytes32 hash = keccak256(abi.encodePacked(
            "\x19\x01",
            token.DOMAIN_SEPARATOR(),
            structHash
        ));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, hash);
        
        // Execute permit
        token.permit(signer, alice, value, deadline, v, r, s);
        
        assertEq(token.allowance(signer, alice), value);
    }

    function test_RescueTokens() public {
        // Deploy a mock token and send to StakeFlowToken
        MockTokenForRescue mockToken = new MockTokenForRescue();
        mockToken.transfer(address(token), 1000 * 10**18);
        
        vm.prank(owner);
        token.rescueTokens(address(mockToken), 1000 * 10**18);
        
        assertEq(mockToken.balanceOf(owner), 1000 * 10**18);
    }

    function test_RevertRescueSelf() public {
        vm.prank(owner);
        vm.expectRevert("StakeFlowToken: cannot rescue self");
        token.rescueTokens(address(token), 1000 * 10**18);
    }
}

contract MockTokenForRescue is ERC20 {
    constructor() ERC20("Mock", "MCK") {
        _mint(msg.sender, 1000000 * 10**18);
    }
}
