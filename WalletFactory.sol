// SPDX-License-Identifier: None
pragma solidity 0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Wallet.sol";

interface myIERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract WalletFactory is Ownable {
    mapping(address => address) private userWallets;
    address private feeTo;
    uint256 private ownerFeePercent;
    uint256 private feeFactor; // number the feePercent is divided by

    event WalletCreated(address indexed owner, address wallet);

    constructor() Ownable(msg.sender) {
        ownerFeePercent = 3;
        feeFactor = 100;
    }

    function createWallet() external {
        require(userWallets[msg.sender] == address(0), "Wallet already exists");
        bool gift = false;

        Wallet newWallet = new Wallet(msg.sender, address(this), gift);
        userWallets[msg.sender] = address(newWallet);

        emit WalletCreated(msg.sender, address(newWallet));
    }

    function giftWallet(address _user) external onlyOwner {
        require(userWallets[_user] == address(0), "Wallet already exists");
        bool gift = true;

        Wallet newWallet = new Wallet(_user, address(this), gift);
        userWallets[_user] = address(newWallet);

        emit WalletCreated(_user, address(newWallet));
    }

    function getWallet(address user) external view returns (address) {
        return userWallets[user];
    }

    function setOwnerFeePercent(uint256 _feePercent) external onlyOwner {
        require(_feePercent <= 10, "Fee percent cannot exceed 10");
        ownerFeePercent = _feePercent;
    }

    function getFee() public view returns (uint256) {
        return ownerFeePercent;
    }

    function setFeeTo(address _feeTo) external onlyOwner {
        feeTo = _feeTo;
    }

    function getFeeTo() public view returns (address) {
        return feeTo;
    }

    function setFeeFactor(uint256 _feeFactor) external onlyOwner {
        require(_feeFactor <= 10000, "Fee percent cannot exceed 10000");
        feeFactor = _feeFactor;
    }

    function getFeeFactor() public view returns (uint256) {
        return feeFactor;
    }

    function withdrawToken(address _tokenAddress) public onlyOwner {
        uint256 balance = myIERC20(_tokenAddress).balanceOf(address(this));
        myIERC20(_tokenAddress).transfer(this.owner(), balance);
    }
}
