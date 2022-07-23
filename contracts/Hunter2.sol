// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

import "./libraries/UniswapV2Library.sol";

struct CallbackData {
    address tokenIn;
    uint256 amountIn;
    uint256 amountOut;
    address[] path;
    uint256[] fees;
    uint256[] reserves0;
    uint256[] reserves1;
}

contract Hunter2 is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address private _permissionedPairAddress;

    receive() external payable {}

    /// @dev Redirect uniswap callback function
    /// The callback function on different DEX are not same, so use a fallback to redirect to uniswapV2Call
    fallback() external {
        (
            address sender,
            uint256 amount0,
            uint256 amount1,
            bytes memory data
        ) = abi.decode(msg.data[4:], (address, uint256, uint256, bytes));
        uniswapV2Call(sender, amount0, amount1, data);
    }

    function withdraw(address[] calldata tokens) external {
        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20 token = IERC20(tokens[i]);
            uint256 balance = token.balanceOf(address(this));
            if (balance > 0) token.transfer(owner(), balance);
        }
    }

    function flashArbitrage(
        uint256 blockNumber,
        uint256 amountIn,
        address tokenIn,
        address[] memory pairs,
        uint256[] memory pairsFee
    ) external {
        require(block.number <= blockNumber, "#1");
        uint256 last = pairs.length - 1;

        // 检测是否有利润
        uint256 amountOut = UniswapV2Library.getLastAmountsOut(
            tokenIn,
            amountIn,
            pairs,
            pairsFee
        );

        require(amountOut > amountIn, "#2");

        // 交易对快照
        (
            uint256[] memory reserves0,
            uint256[] memory reserves1
        ) = UniswapV2Library.getSnapshots(pairs);

        CallbackData memory callbackData = CallbackData(
            tokenIn,
            amountIn,
            amountOut,
            pairs,
            pairsFee,
            reserves0,
            reserves1
        );

        _permissionedPairAddress = pairs[last];

        (uint256 amount0Out, uint256 amount1Out) = tokenIn ==
            IUniswapV2Pair(_permissionedPairAddress).token0()
            ? (amountOut, uint256(0))
            : (uint256(0), amountOut);

        IUniswapV2Pair(_permissionedPairAddress).swap(
            amount0Out,
            amount1Out,
            address(this),
            abi.encode(callbackData)
        );

        _permissionedPairAddress = address(0);
    }

    function uniswapV2Call(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes memory data
    ) public {
        require(
            msg.sender == _permissionedPairAddress && sender == address(this),
            "#3"
        );
        require(amount0 > 0 || amount1 > 0, "#4");

        CallbackData memory callbackData = abi.decode(data, (CallbackData));
        uint256 last = callbackData.path.length - 1;
        uint256 amount0Out;
        uint256 amount1Out;
        uint256 amountOut;
        address tokenIn;

        IERC20(callbackData.tokenIn).safeTransfer(
            callbackData.path[0],
            callbackData.amountIn
        );

        tokenIn = callbackData.tokenIn;

        for (uint256 i = 0; i < last; i++) {
            (tokenIn, amount0Out, amount1Out) = UniswapV2Library
                .getPairAmountOut(
                    tokenIn,
                    callbackData.path[i],
                    callbackData.fees[i],
                    callbackData.reserves0[i],
                    callbackData.reserves1[i]
                );

            IUniswapV2Pair(callbackData.path[i]).swap(
                amount0Out,
                amount1Out,
                callbackData.path[i + 1],
                new bytes(0)
            );
        }

        (, amount0Out, amount1Out) = UniswapV2Library.getPairAmountOut(
            tokenIn,
            callbackData.path[last],
            callbackData.fees[last],
            callbackData.reserves0[last],
            callbackData.reserves1[last]
        );

        amountOut = amount0Out > 0 ? amount0Out : amount1Out;

        require(amountOut > callbackData.amountIn, "#5");

        if (amountOut < callbackData.amountOut) {
            IERC20(callbackData.tokenIn).safeTransfer(
                callbackData.path[last],
                callbackData.amountOut.sub(amountOut)
            );
        }
    }
}
