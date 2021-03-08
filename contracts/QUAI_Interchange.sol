// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.7.5;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract QUAI_Interchange is Ownable {
    using SafeMath for uint256;

    address public constant uniswapV2router =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    IUniswapV2Router02 router = IUniswapV2Router02(uniswapV2router);

    mapping(address => bool) approvedTokens; //keeps track of ERC20 tokens approved by owner as purchase methods

    //internally adds purchase option
    function addPurchaseOption(address tokenAddress) internal {
        approvedTokens[tokenAddress] = true;
        IERC20(tokenAddress).approve(uniswapV2router, uint256(-1));
    }

    //adds an ERC20 token as a purchase option
    function newPurchaseOption(address tokenAddress) external onlyOwner() {
        require(
            approvedTokens[tokenAddress] == false,
            "newPurchaseOption: token already added"
        );
        addPurchaseOption(tokenAddress);
    }

    //gets expected amount of ETH from input amount of ERC20 token
    function getExpectedEth(address tokenAddress, uint256 amountIn)
        public
        view
        returns (uint256)
    {
        address[] memory _path = new address[](2);
        _path[0] = tokenAddress;
        _path[1] = router.WETH();
        uint256[] memory _amts = router.getAmountsOut(amountIn, _path);
        return _amts[1];
    }

    function purchaseWithERC20(address tokenAddress, uint256 amountIn)
        external
    {
        require(
            approvedTokens[tokenAddress] == true,
            "token is not approved as payment option"
        );
        require(
            IERC20(tokenAddress).allowance(msg.sender, address(this)) >=
                amountIn,
            "token approval is insufficent for purchase"
        );
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), amountIn);
        address[] memory path = new address[](2);
        path[0] = tokenAddress;
        path[1] = router.WETH();
        uint256 deadline = (block.timestamp + 1200); //20min window for transaction to be confirmed, otherwise it will revert
        uint256[] memory _amts =
            router.swapExactTokensForETH(
                amountIn,
                uint256(0),
                path,
                address(this),
                deadline
            );
        processPurchase(_amts[1], msg.sender);
    }

    function buyTokens() external payable {
        processPurchase(msg.value, msg.sender);
    }

    function processPurchase(uint256 etherValue, address user) internal {
        require(
            block.timestamp >= presaleStart,
            "processPurchase: presale has not yet started"
        );
        require(
            block.timestamp <= presaleEnd,
            "processPurchase: presale has ended"
        );
        require(!endedEarly, "processPurchase: presale was ended early");
        etherWaterfall(etherValue);
        getTokensFromEth(etherValue, user);
    }

    function etherWaterfall(uint256 etherValue) internal {
        uint256 ethToTarget = ethTargets[currentEthTarget] - totalEthReceived;
        uint256 etherRemaining = etherValue;

        //ether waterfall -- while loop covers all cases where purchase value overflows one or more ether targets
        while (etherRemaining >= ethToTarget) {
            //move to next level of token waterfall
            uniswapPoolEth += (ethToTarget.mul(percentLevels[currentEthTarget]))
                .div(percentPrecision);
            etherRemaining -= ethToTarget;
            currentEthTarget += 1;
            //get ETH size for next level of waterfall
            ethToTarget =
                ethTargets[currentEthTarget] -
                ethTargets[(currentEthTarget - 1)];
        }

        //get uniswapPool amount for current waterfall level -- this is the only part of the logic that will be called when the purchase does not overflow a level
        uniswapPoolEth += (etherRemaining.mul(percentLevels[currentEthTarget]))
            .div(percentPrecision);

        //update total ether received
        totalEthReceived += etherValue;
    }

    function getTokensFromEth(uint256 ethInput, address user) internal {
        uint256 tokensToCeiling =
            tokenCeilings[currentPriceLevel] - totalTokensSold;
        uint256 valueRemaining = ethInput;
        uint256 tokens = 0;

        //token waterfall -- while loop covers all cases where purchase value overflows one or more token levels
        while (
            valueRemaining.mul(tokensPerEth[currentPriceLevel]).div(
                uint256(1e18)
            ) >= tokensToCeiling
        ) {
            //move to next level of LP waterfall
            require(
                currentPriceLevel < (tokenCeilings.length - 1),
                "getTokensFromEth: purchase would exceed max token ceiling"
            );
            tokens += tokensToCeiling;
            valueRemaining -= tokensToCeiling.mul(uint256(1e18)).div(
                tokensPerEth[currentPriceLevel]
            );
            currentPriceLevel += 1;
            //get token size for next level of waterfall
            tokensToCeiling =
                tokenCeilings[currentPriceLevel] -
                tokenCeilings[(currentPriceLevel - 1)];
        }

        //get tokens for current waterfall level -- this is the only part of the logic that will be called when the purchase does not overflow a level
        tokens += valueRemaining.mul(tokensPerEth[currentPriceLevel]).div(
            uint256(1e18)
        );

        //store token balance for msg.sender to be withdrawn later
        totalTokensSold += tokens;
        balances[user] += tokens;
        emit Sold(user, tokens);
    }
}
