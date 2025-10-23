// SPDX-License-Identifier: NONE
pragma solidity 0.8.26;

import "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";
import "@balancer-labs/v2-interfaces/contracts/vault/IFlashLoanRecipient.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

//THIS CONTRACT IS FOR INHERITED USE IN A WALLET

interface IMToken {
    function mint(uint mintAmount) external returns (uint);
    function borrow(uint borrowAmount) external returns (uint);
    function repayBorrow(uint repayAmount) external returns (uint);
    function redeem(uint redeemTokens) external returns (uint);
    function borrowBalanceCurrent(address account) external returns (uint);
    function balanceOf(address owner) external view returns (uint);
}

interface IMultiRewardDistributor {
    struct RewardInfo {
        address emissionToken;
        uint totalAmount;
        uint supplySide;
        uint borrowSide;
    }

    function getOutstandingRewardsForUser(
        IMToken _mToken,
        address _user
    ) external view returns (RewardInfo[] memory);
}

interface IComptroller {
    function enterMarkets(
        address[] calldata
    ) external returns (uint256[] memory);

    function claimReward(address holder) external;

    function claimReward(address holder, address[] memory mTokens) external;
}

contract LoopR is Ownable, IFlashLoanRecipient{
    uint256 private balance;

    address constant USDC_ADDRESS = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    IERC20 constant USDC = IERC20(USDC_ADDRESS);

    address constant MOONWELL_USDC_ADDRESS =
        0xEdc817A28E8B93B03976FBd4a3dDBc9f7D176c22;
    IMToken constant MOONWELL_USDC = IMToken(MOONWELL_USDC_ADDRESS);

    address constant WELL_ADDRESS = 0xA88594D404727625A9437C3f886C7643872296AE;
    IERC20 constant WELL = IERC20(WELL_ADDRESS);

    IComptroller constant comptroller =
        IComptroller(0xfBb21d0380beE3312B33c4353c8936a0F13EF26C);

    IMultiRewardDistributor constant multiRewardDistributor =
        IMultiRewardDistributor(0xe9005b078701e2A0948D2EaC43010D35870Ad9d2);

    IVault constant vault = IVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);


    struct MyFlashData {
        address flashToken;
        uint256 flashAmount;
        uint256 totalAmount;
        bool isDeposit;
    }

    constructor(address _owner) Ownable(_owner) {
        address[] memory mTokens = new address[](1);
        mTokens[0] = MOONWELL_USDC_ADDRESS;
        uint256[] memory errors = comptroller.enterMarkets(mTokens);
        require(errors[0] == 0, "Comptroller.enterMarkets failed.");
    }

    fallback() external {
        revert();
    }

    function deposit(uint256 initialAmount) internal returns (bool) {
        require(initialAmount > 0, "Deposit amount must be greater than zero");

        uint256 totalAmount = (initialAmount * 10) / 3;
        uint256 flashLoanAmount = totalAmount - initialAmount;

        bool isDeposit = true;
        getFlashLoan(USDC_ADDRESS, flashLoanAmount, totalAmount, isDeposit);

        balance += initialAmount;

        return true;
    }

    function withdraw(uint256 amount) internal returns (bool) {

        uint256 totalAmount = (amount * 10) / 3;
        uint256 flashLoanAmount = totalAmount - amount;

        bool isDeposit = false;
        getFlashLoan(USDC_ADDRESS, flashLoanAmount, totalAmount, isDeposit);

        balance -= amount;

        return true;
    }

    function getFlashLoan(
        address flashToken,
        uint256 flashAmount,
        uint256 totalAmount,
        bool isDeposit
    ) internal {
        bytes memory userData = abi.encode(
            MyFlashData({
                flashToken: flashToken,
                flashAmount: flashAmount,
                totalAmount: totalAmount,
                isDeposit: isDeposit
            })
        );

        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = IERC20(flashToken);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = flashAmount;

        vault.flashLoan(this, tokens, amounts, userData);
    }

    function receiveFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external {
        require(msg.sender == address(vault), "LeveragedYieldFarm: Not Balancer!");

        MyFlashData memory data = abi.decode(userData, (MyFlashData));
        uint256 flashTokenBalance = IERC20(data.flashToken).balanceOf(address(this));

        // Ensure the contract has enough to cover the flash loan and the fees
        require(
            flashTokenBalance >= data.flashAmount + feeAmounts[0],
            "LeveragedYieldFarm: Not enough funds to repay Balancer loan!"
        );

        if (data.isDeposit) {
            handleDeposit(data.totalAmount, data.flashAmount);
        } else {
            handleWithdraw();
        }

        IERC20(data.flashToken).transfer(
            address(vault),
            data.flashAmount + feeAmounts[0]
        );
    }

    function handleDeposit(
        uint256 totalAmount,
        uint256 flashLoanAmount
    ) internal returns (bool) {
        USDC.approve(MOONWELL_USDC_ADDRESS, totalAmount);
        require(MOONWELL_USDC.mint(totalAmount) == 0, "Minting failed");

        require(MOONWELL_USDC.borrow(flashLoanAmount) == 0, "Borrow failed");
        return true;
    }

    function handleWithdraw() internal returns (bool) {
        uint256 borrowBalance = MOONWELL_USDC.borrowBalanceCurrent(address(this));
        USDC.approve(address(MOONWELL_USDC), borrowBalance);
        require(MOONWELL_USDC.repayBorrow(borrowBalance) == 0, "Repay borrow failed");

        uint256 tokenBalance = MOONWELL_USDC.balanceOf(address(this));
        require(MOONWELL_USDC.redeem(tokenBalance) == 0, "Redeem failed");

        return true;
    }

    function withdrawToken(address _tokenAddress) internal {
        uint256 newBalance = IERC20(_tokenAddress).balanceOf(address(this));
        IERC20(_tokenAddress).transfer(this.owner(), newBalance);
    }

    function getLoopBalance() public view returns (uint256) {
        return balance;
    } 

    function claimRewards(address _tokenAddress) internal {
        address[] memory mTokens = new address[](1);
        mTokens[0] = _tokenAddress;
        comptroller.claimReward(address(this), mTokens);
    }

    function getOutstandingRewards(
        address _tokenAddress
    ) public view returns (IMultiRewardDistributor.RewardInfo[] memory) {
        return
            multiRewardDistributor.getOutstandingRewardsForUser(
                IMToken(_tokenAddress),
                address(this)
            );
    }

}
