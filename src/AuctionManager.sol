// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice An auction manager for opening and interacting with auctions.
contract AuctionManager {
    /// @notice An auction.
    struct Auction {
        /// @notice The address who opened the auction
        address seller;
        /// @notice The auction item, which is an ERC20 tokens amount
        uint256 amount;
        /// @notice Address of the ERC20 token which the auction item denotes an amount of
        address amountToken;
        /// @notice End time stamp of the auction
        uint256 endTime;
        /// @notice Address of the ERC20 token for auction bids
        address bidToken;
    }

    /// @notice Event emitted when a new acution is opened.
    event NewAuction(uint256 indexed auctionId);

    /// @notice An auction bid.
    struct Bid {
        /// @notice Address of bidder or address 0 if the auction has been settled
        address bidder;
        /// @notice Bid amount of the auction's bid token
        uint256 amount;
    }

    /// @notice Event emitted when a new best bid has been given for an auction item.
    event NewBestBid(uint256 indexed auctionId);

    /// @notice Event emitted when an auction is settled.
    event AuctionSettled(uint256 indexed auctionId, address winner);

    /// @notice History of all opened auctions.
    Auction[] public auctions;

    /// @notice Best bids, such that bid at index `i` is the best bid of the auction `auctions[i]`.
    Bid[] public bestBids;

    /// @notice Open a new auction.
    /// @param _amount The auction item, denoting an amount of ERC20 token `_amountToken`
    /// @param _amountToken Address of the token which `_amount` denotes
    /// @param _endTime The end time stamp of the auction
    /// @param _paymentToken Address of the ERC20 which is accepted as payment
    /// @return Auction ID, index of the auction in `auctions` array
    function openAuction(
        uint256 _amount,
        address _amountToken,
        uint256 _endTime,
        address _paymentToken
    ) external returns (uint256) {
        address seller = msg.sender;

        IERC20(_amountToken).transferFrom(seller, address(this), _amount);

        uint256 auctionId = auctions.length;

        auctions.push(Auction({
            seller: seller,
            amount: _amount,
            amountToken: _amountToken,
            endTime: _endTime,
            bidToken: _paymentToken
        }));

        bestBids.push(Bid({
            bidder: seller,
            amount: 0
        }));

        emit NewAuction(auctionId);

        return auctionId;
    }

    /// @notice Make an auction bid.
    /// @param _auctionId ID of the auction
    /// @param _amount The bid amount, denoting an amount of the auction's of bid token
    function auctionBid(uint256 _auctionId, uint256 _amount) external {
        require(_auctionId < auctions.length, "invalid auction id");

        Auction memory auction = auctions[_auctionId];

        require(auction.endTime < block.timestamp, "auction has finished");
        
        Bid memory bestBid = bestBids[_auctionId];

        require(_amount > bestBid.amount, "bid is too small");

        address prevBidder = bestBids[_auctionId].bidder;
        uint256 prevAmount = bestBids[_auctionId].amount;
        IERC20(auction.bidToken).transfer(prevBidder, prevAmount);

        address bidder = msg.sender;

        IERC20(auction.bidToken).transferFrom(bidder, address(this), _amount);

        bestBids[_auctionId].bidder = bidder;
        bestBids[_auctionId].amount = _amount;

        emit NewBestBid(_auctionId);
    }

    /// @notice Settle auction by exchanging ERC20 tokens between seller and winner.
    /// @param _auctionId ID of the auction.
    function settleAuction(uint256 _auctionId) external {
        require(_auctionId < auctions.length, "invalid auction id");

        Auction memory auction = auctions[_auctionId];

        require(auction.endTime >= block.timestamp, "auction is still accepting bids");

        Bid memory bestBid = bestBids[_auctionId];

        address bidder = bestBid.bidder;

        require(bidder != address(0), "auction has already been settled");

        IERC20(auction.amountToken).transfer(bidder, auction.amount);
        IERC20(auction.bidToken).transfer(auction.seller, bestBid.amount);

        bestBids[_auctionId].bidder = address(0);

        emit AuctionSettled(_auctionId, bidder);
    }
}
