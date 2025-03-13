// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IUniswapV2Router {
    function getAmountsOut(uint256 amountIn, address[] memory path) external view returns (uint256[] memory amounts);
    function swapExactTokensForTokens(
        uint256 amountIn, 
        uint256 amountOutMin, 
        address[] calldata path, 
        address to, 
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

contract ArbBot is Ownable {
    using SafeERC20 for IERC20;

    event ArbitrageExecuted(uint256 profit);
    event TokensRecovered(address token, uint256 amount);
    event ETHRecovered(uint256 amount);

    /**
     * @dev Executes a token swap on a given DEX router
     */
    function swap(
        address router,
        address tokenIn,
        address tokenOut,
        uint256 amount
    ) private {
        require(amount > 0, "Swap amount must be greater than zero");
        IERC20(tokenIn).safeApprove(router, amount);

        address;
        path[0] = tokenIn;
        path[1] = tokenOut;

        uint deadline = block.timestamp + 300; // 5 minutes
        IUniswapV2Router(router).swapExactTokensForTokens(amount, 1, path, address(this), deadline);
    }

    /**
     * @dev Fetches the minimum output amount for a token swap on a given router
     */
    function getAmountOutMin(
        address router,
        address tokenIn,
        address tokenOut,
        uint256 amount
    ) public view returns (uint256) {
        require(amount > 0, "Amount must be greater than zero");
        
        address;
        path[0] = tokenIn;
        path[1] = tokenOut;

        uint256[] memory amounts = IUniswapV2Router(router).getAmountsOut(amount, path);
        return amounts[path.length - 1];
    }

    /**
     * @dev Estimates potential arbitrage profit across two DEXs
     */
    function estimateDualDexTrade(
        address router1,
        address router2,
        address token1,
        address token2,
        uint256 amount
    ) external view returns (uint256) {
        require(amount > 0, "Amount must be greater than zero");

        uint256 amountOut1 = getAmountOutMin(router1, token1, token2, amount);
        uint256 amountOut2 = getAmountOutMin(router2, token2, token1, amountOut1);

        return amountOut2;
    }

    /**
     * @dev Executes an arbitrage trade between two DEXs
     */
    function dualDexTrade(
        address router1,
        address router2,
        address token1,
        address token2,
        uint256 amount
    ) external onlyOwner {
        require(amount > 0, "Trade amount must be greater than zero");

        uint256 initialBalance = IERC20(token1).balanceOf(address(this));
        uint256 token2InitialBalance = IERC20(token2).balanceOf(address(this));

        swap(router1, token1, token2, amount);
        uint256 token2Balance = IERC20(token2).balanceOf(address(this));

        require(token2Balance > token2InitialBalance, "Trade failed: No token gain");

        uint256 tradeableAmount = token2Balance - token2InitialBalance;
        swap(router2, token2, token1, tradeableAmount);

        uint256 finalBalance = IERC20(token1).balanceOf(address(this));
        require(finalBalance > initialBalance, "Trade reverted: No profit made");

        emit ArbitrageExecuted(finalBalance - initialBalance);
    }

    /**
     * @dev Retrieves the contract's balance for a specific token
     */
    function getBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    /**
     * @dev Allows the owner to recover accidentally sent ETH
     */
    function recoverEth() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH to recover");
        payable(msg.sender).transfer(balance);

        emit ETHRecovered(balance);
    }

    /**
     * @dev Allows the owner to recover accidentally sent tokens
     */
    function recoverTokens(address token) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        require(balance > 0, "No tokens to recover");

        IERC20(token).safeTransfer(msg.sender, balance);
        emit TokensRecovered(token, balance);
    }

    receive() external payable {}
}
