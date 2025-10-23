// SPDX-License-Identifier: NONE
pragma solidity 0.8.26;

import "./LoopR.sol";
import "./WalletFactory.sol";

contract Wallet is LoopR {
    bool private gift = false;
    WalletFactory private wf;

    constructor(address _owner, address _walletFactory, bool _gift) LoopR(_owner) {
        gift = _gift;
        wf = WalletFactory(_walletFactory);
    }

    function loop(uint256 amount) public onlyOwner {
        uint256 newAmount = fund(amount);
        deposit(newAmount);
    }

    function unLoop(uint256 amount) public onlyOwner {
        withdraw(amount);
        claimRewards(MOONWELL_USDC_ADDRESS);
        cleanOutRewards();
    }

    function reLoop(address _mToken) public onlyOwner { //marked for access control to be performed on behalf of user
        uint256 priorBal = USDC.balanceOf(address(this));
        claimRewards(_mToken);
        uint256 reBal = USDC.balanceOf(address(this)) - priorBal;
        deposit(reBal);
        withdrawToken(WELL_ADDRESS);
    }

    function fund(uint256 amount) internal returns (uint256) {
        require(USDC.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        if(!gift) {
            uint256 feePercent = wf.getFee();
            uint256 feeFactor = wf.getFeeFactor();
            address feeTo = wf.getFeeTo();
            uint256 feeAmount = (feePercent * amount) / feeFactor; // 1 / 100 = 1%
            require(USDC.transfer(feeTo, feeAmount));
        }

        uint256 newAmount;
        newAmount = USDC.balanceOf(address(this)) - 1000000;
        return newAmount;
    }

    function defund(uint256 amount) internal {
        require(USDC.balanceOf(address(this)) >= amount, "Contract has insufficient USDC");
        require(USDC.transfer(msg.sender, amount), "Transfer failed");
    }

    function withdrawLeaveChange() internal {
        uint256 newBalance = USDC.balanceOf(address(this)) - 1000000;
        USDC.transfer(this.owner(), newBalance);
    }

    function withdrawRewards(address _mToken) public onlyOwner { //marked for access control to be performed on behalf of user
        claimRewards(_mToken);
        withdrawToken(WELL_ADDRESS);
        withdrawLeaveChange();
    }

    function cleanOutRewards() public onlyOwner {
        withdrawToken(WELL_ADDRESS);
        withdrawToken(USDC_ADDRESS);
    }

    function withdrawWell() public onlyOwner {
        withdrawToken(WELL_ADDRESS);
    }

    function getThisBalance() public view returns (uint256) {
        return USDC.balanceOf(address(this));
    } 

    function getIsGift() public view returns (bool) {
        return gift;
    }
}
