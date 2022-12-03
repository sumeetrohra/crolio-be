// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

error UNAUTHORIZED();
error UNEQUAL_TOKENS_AND_WEIGHTS();
error WEIGHTAGE_NOT_100();
error INVESTED_AMOUNT_0();
error INSUFFICIENT_FEES();

contract Crolio {

    address private immutable _admin;
    address private immutable _USDCContract;
    ISwapRouter private immutable _swapRouter;

    uint24 private constant poolFee = 100;

    constructor(address swapRouter, address USDCContract) {
        _swapRouter = ISwapRouter(swapRouter);
        _USDCContract = USDCContract;
        _admin = msg.sender;
    }

    // struct to store a bucket details
    struct Bucket {
        string name;
        string description;
        address[] tokens;
        uint256[] weightages;
        address creator;
    }

    // struct to maintain User Investments
    struct UserInvestment {
        uint256 totalUSDCInvested;
        uint256[] holdings;
    }

    // mapping to track user investments, username -> bucketId -> investment struct
    mapping (address => mapping(uint256 => UserInvestment)) private _userInvestments;

    // mapping to track every bucket
    mapping (uint256 => Bucket) public bucketDetails;

    // private counter to maintain the number of buckets
    uint256 private _counter = 0;

    // array of supported tokens
    address[] public supportedTokens;

    // event for bucket creation
    event BucketCreated(uint256 bucketId, string bucketName, string description, address[] tokens, uint256[] weightages, address creator);
    event InvestedInBucket(uint256 bucketId, uint256 amountInvested, address investorAddress, address[] tokens, uint256[] holdingsBought);
    event WithdrawnFromBucket(uint256 bucketId, uint256 amountOut, address investorAddress, address[] tokens, uint256[] holdingsSold);

    // function to create a bucket - onlyOwner
    function createBucket(string memory name, string memory description, address[] memory tokens, uint256[] memory weightage) external returns (bool) {
        if (tokens.length != weightage.length) {
            revert UNEQUAL_TOKENS_AND_WEIGHTS();
        }

        uint256 totalWeightage = 0;

        for (uint256 i = 0; i < weightage.length; i++) {
            totalWeightage += weightage[i];
        }

        if (totalWeightage != 10000) {
            revert WEIGHTAGE_NOT_100();
        }

        bucketDetails[_counter] = Bucket({
            name: name,
            description: description,
            tokens: tokens,
            weightages: weightage,
            creator: msg.sender
        });

        emit BucketCreated(_counter, name, description, tokens, weightage, msg.sender);

        _counter++;
        return true;
    }

    // fetch a bucket - return struct
    function fetchBucketDetails(uint256 _bucketId) external view returns (Bucket memory) {
        return bucketDetails[_bucketId];
    }

    // Invest util
    function swapUSDCToToken(uint256 amountIn, address _tokenOut) internal returns (uint256 amountOut) {
        // Naively set amountOutMinimum to 0. In production, use an oracle or other data source to choose a safer value for amountOutMinimum.
        // We also set the sqrtPriceLimitx96 to be 0 to ensure we swap our exact input amount.
        ISwapRouter.ExactInputSingleParams memory params =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: _USDCContract,
                tokenOut: _tokenOut,
                fee: poolFee,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });
        // The call to `exactInputSingle` executes the swap.
        amountOut = _swapRouter.exactInputSingle(params);
    }

    // Withdraw util
    function swapTokenToUSDC(uint256 amountIn, address _tokenIn) internal returns (uint256 amountOut) {
        // Approve the router to spend _tokenIn.
        TransferHelper.safeApprove(_tokenIn, address(_swapRouter), amountIn);

        // Naively set amountOutMinimum to 0. In production, use an oracle or other data source to choose a safer value for amountOutMinimum.
        // We also set the sqrtPriceLimitx96 to be 0 to ensure we swap our exact input amount.
        ISwapRouter.ExactInputSingleParams memory params =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: _tokenIn,
                tokenOut: _USDCContract,
                fee: poolFee,
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        // The call to `exactInputSingle` executes the swap.
        amountOut = _swapRouter.exactInputSingle(params);
    }

    // function usdcFraction
    function calculateInvestedAmountForToken(uint256 weightage, uint256 investedAmount) internal pure returns (uint256) {
        return (investedAmount / 10000) * weightage;
    }

    // Invest function
    function invest(uint256 _bucketId, uint256 _investValue, uint256 _deadline, uint8 v, bytes32 r, bytes32 s) external returns (bool) {
        IERC20Permit(_USDCContract).permit(msg.sender, address(this), _investValue, _deadline, v, r, s);
        // TransferHelper.safeTransferFrom(_USDCContract, msg.sender, address(this), _investValue);
        TransferHelper.safeTransferFrom(_USDCContract, msg.sender, address(this), _investValue);
        TransferHelper.safeApprove(_USDCContract, address(_swapRouter), _investValue);

        Bucket memory bucket = bucketDetails[_bucketId];
        address[] memory tokens = bucket.tokens;
        uint256[] memory weights = bucket.weightages;

        uint256[] memory holdings = new uint256[](tokens.length);

        for (uint256 i = 0; i < tokens.length; i += 1) {
            uint256 usdcInvestAmountForToken = calculateInvestedAmountForToken(weights[i], _investValue);
            holdings[i] = swapUSDCToToken(usdcInvestAmountForToken, tokens[i]);
        }

        uint256[] memory currentHoldings = _userInvestments[msg.sender][_bucketId].holdings;

        if (_userInvestments[msg.sender][_bucketId].totalUSDCInvested == 0) {
            _userInvestments[msg.sender][_bucketId].totalUSDCInvested = _investValue;
            _userInvestments[msg.sender][_bucketId].holdings = holdings;
        } else {
            _userInvestments[msg.sender][_bucketId].totalUSDCInvested += _investValue;
            uint256 _bucket = _bucketId;
            uint256[] memory updatedHoldings = new uint256[](currentHoldings.length);
            for (uint256 j = 0; j < currentHoldings.length; j += 1) {
                updatedHoldings[j] = currentHoldings[j] + holdings[j];
            }
            _userInvestments[msg.sender][_bucket].holdings = updatedHoldings;
        }

        emit InvestedInBucket(_bucketId, _investValue, msg.sender, tokens, holdings);
        return true;
    }

    // Withdraw function
    function withdraw(uint256 _bucketId) external returns (bool) {
        if (_userInvestments[msg.sender][_bucketId].totalUSDCInvested <= 0) {
            revert INVESTED_AMOUNT_0();
        }

        Bucket memory bucket = bucketDetails[_bucketId];
        address[] memory tokens = bucket.tokens;

        UserInvestment memory investment = _userInvestments[msg.sender][_bucketId];
        uint256[] memory holdings = investment.holdings;

        uint256 amountOut = 0;

        for (uint256 i = 0; i < holdings.length; i += 1) {
            amountOut += swapTokenToUSDC(holdings[i], tokens[i]);
        }

        delete _userInvestments[msg.sender][_bucketId];
        emit WithdrawnFromBucket(_bucketId, amountOut, msg.sender, tokens, holdings);
        return true;
    }

    // get user investment details
    function getAllUserInvestmentDetails(uint256 _bucketId) external view returns (UserInvestment memory) {
        return _userInvestments[msg.sender][_bucketId];
    }
}