// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {AuctionManagerMock} from "./AuctionManagerMock.sol";
import {AuctionManagerHandler} from "./AuctionManagerHandler.sol";
import {ERC20Mock} from "./ERC20Mock.sol";

contract AuctionManagerInput {
    uint256[6] public arg;
    uint256 public immutable argCount;

    constructor() {
        argCount = 6;
    }

    function set(uint256[6] memory _arg) external {
        arg = _arg;
    }
}

contract AuctionManagerTest is Test {
    AuctionManagerMock manager;
    AuctionManagerHandler handler;
    AuctionManagerInput input;

    function setUp() external {
        manager = new AuctionManagerMock();
        handler = new AuctionManagerHandler(manager);
        input = new AuctionManagerInput();

        targetContract(address(input));
        targetContract(address(handler));

        bytes4[] memory selectors = new bytes4[](4);
        uint256 n;
        selectors[n++] = AuctionManagerHandler.fuzz_increaseTimestamp.selector;
        selectors[n++] = AuctionManagerHandler.fuzz_openAuction.selector;
        selectors[n++] = AuctionManagerHandler.fuzz_auctionBid.selector;
        selectors[n++] = AuctionManagerHandler.fuzz_settleAuction.selector;
        targetSelector(
            FuzzSelector({addr: address(handler), selectors: selectors})
        );
    }

    /// @notice There are as many best bids as there are auctions
    function invariant_lengths() external {
        handler.setTimestamp();

        assertEq(manager.auctionCount(), manager.bestBidCount(),
                 "invalid lengths");
    }

    /// @notice All of the auction manager's token amounts are accounted (solvency)
    function invariant_solvency() external {
        handler.setTimestamp();

        for (uint256 i; i < handler.tokenCount(); ++i) {
            ERC20Mock t = handler.allTokens(i);
            assertEq(t.balanceOf(address(manager)), tokenBalance(address(t)),
                    "solvency");
        }
    }

    /// @notice An auction can only be settled after the end time stamp
    function invariant_settleAfterEndTime() external {
        handler.setTimestamp();

        if (manager.auctionCount() == 0) return;

        for (uint256 i; i < input.argCount(); ++i) {
            uint256 auctionId = input.arg(i) % manager.auctionCount();
            (address bidder,) = manager.bestBids(auctionId);
            (,,, uint256 endTime,,) = manager.auctions(auctionId);
            if (bidder == address(0)) {
                assertLe(endTime, block.timestamp, "settled before end time");
            }
        }
    }

    /// @notice For unsettled auction, if best bid is 0 then best bidder is the seller
    function invariant_bestBidZeroIsSeller() external {
        handler.setTimestamp();

        if (manager.auctionCount() == 0) return;

        for (uint256 i; i < input.argCount(); ++i) {
            uint256 auctionId = input.arg(i) % manager.auctionCount();
            (address bidder, uint256 bamount) =
                manager.bestBids(auctionId);
            (address seller,,,,,) = manager.auctions(auctionId);
            if (bamount == 0 && bidder != address(0)) {
                assertEq(bidder, seller, "best bit zero, but bidder is not the seller");
            }
        }
    }

    /// @notice For unsettled auction, the best bid is lower bounded
    function invariant_bestBidIsLowerBounded() external {
        handler.setTimestamp();

        if (manager.auctionCount() == 0) return;

        for (uint256 i; i < input.argCount(); ++i) {
            uint256 auctionId = input.arg(i) % manager.auctionCount();
            (address bidder, uint256 bamount) =
                manager.bestBids(auctionId);
            (address seller,,,,, uint256 minBidAmount) = manager.auctions(auctionId);
            if (bidder != address(0) && (bidder != seller || bamount > 0)) {
                assertGe(bamount, minBidAmount,
                        "best bid is out of lower bound");
            }
        }
    }

    /// @notice Auction info is constant
    function invariant_auctionIsConstant() external {
        handler.setTimestamp();

        assertEq(manager.auctionCount(), handler.auctionCount(),
                "unexpected auction count");

        if (manager.auctionCount() == 0) return;

        for (uint256 i; i < input.argCount(); ++i) {
            uint256 auctionId = input.arg(i) % manager.auctionCount();

            (address seller1,,,,,) = handler.allAuctions(auctionId);
            (address seller2,,,,,) = manager.auctions(auctionId);
            assertEq(seller1, seller2, "unexpected auction seller");

            (,uint256 amount1,,,,) = handler.allAuctions(auctionId);
            (,uint256 amount2,,,,) = manager.auctions(auctionId);
            assertEq(amount1, amount2, "unexpected auction amount");

            (,,address itemToken1,,,) = handler.allAuctions(auctionId);
            (,,address itemToken2,,,) = manager.auctions(auctionId);
            assertEq(itemToken1, itemToken2, "unexpected auction item token");

            (,,,uint256 endTime1,,) = handler.allAuctions(auctionId);
            (,,,uint256 endTime2,,) = manager.auctions(auctionId);
            assertEq(endTime1, endTime2, "unexpected auction end time");

            (,,,,address bidToken1,) = handler.allAuctions(auctionId);
            (,,,,address bidToken2,) = manager.auctions(auctionId);
            assertEq(bidToken1, bidToken2, "unexpected auction bid token");

            (,,,,,uint256 minBidAmount1) = handler.allAuctions(auctionId);
            (,,,,,uint256 minBidAmount2) = manager.auctions(auctionId);
            assertEq(minBidAmount1, minBidAmount2, "unexpected auction min bid amount");
        }
    }

    /// @notice Function properties of `openAuction`
    function invariant_openAuctionProperties() external {
        (
            address seller,
            uint256 amount,
            address itemToken,
            uint256 endTime,
            address bidToken,
            uint256 minBidAmount
        ) = handler.prepare_openAuction(
            input.arg(0),
            input.arg(1),
            input.arg(2),
            input.arg(3),
            input.arg(4),
            input.arg(5)
        );
        vm.prank(seller);
        uint256 auctionId =
            manager.openAuction(amount, itemToken, endTime, bidToken, minBidAmount);

        assertEq(auctionId, manager.auctionCount() - 1,
                 "unexpected auction ID returned from openAuction");

        (address seller2,,,,,) = manager.auctions(auctionId);
        assertEq(seller, seller2, "unexpected seller pushed");

        (,uint256 amount2,,,,) = manager.auctions(auctionId);
        assertEq(amount, amount2, "unexpected item amount pushed");

        (,,address itemToken2,,,) = manager.auctions(auctionId);
        assertEq(itemToken, itemToken2, "unexpected item token pushed");

        (,,,uint256 endTime2,,) = manager.auctions(auctionId);
        assertEq(endTime, endTime2, "unexpected end time pushed");

        (,,,,address bidToken2,) = manager.auctions(auctionId);
        assertEq(bidToken, bidToken2, "unexpected bid token pushed");

        (,,,,,uint256 minBidAmount2) = manager.auctions(auctionId);
        assertEq(minBidAmount, minBidAmount2, "unexpected min bid amount pushed");

        (address bidder,) = manager.bestBids(auctionId);
        assertEq(bidder, seller, "unexpected best bid address pushed");

        (,uint256 bamount) = manager.bestBids(auctionId);
        assertEq(bamount, 0, "unexpected best bid amount pushed");
    }

    /// @notice Function properties of `auctionBid`
    function invariant_auctionBidProperties() external {
        (address bidder, uint256 auctionId, uint256 amount) =
            handler.prepare_auctionBid(input.arg(0), input.arg(1), input.arg(2));

        (address prevBidder, uint256 prevAmount) = manager.bestBids(auctionId);
        (,,,,address bidToken,) = manager.auctions(auctionId);

        uint256 prevBidderBalance = ERC20Mock(bidToken).balanceOf(prevBidder);

        vm.prank(bidder);
        manager.auctionBid(auctionId, amount);

        if (prevBidder != bidder) {
            assertEq(
                ERC20Mock(bidToken).balanceOf(prevBidder),
                prevBidderBalance + prevAmount,
                "previous bidder balance did not increase correctly after bid"
            );
        } else {
            assertEq(
                ERC20Mock(bidToken).balanceOf(prevBidder),
                prevBidderBalance + prevAmount - amount,
                "previous bidder balance did not decrease correctly after bid"
            );
        }

        (address newBidder, uint256 newAmount) = manager.bestBids(auctionId);
        assertEq(newBidder, bidder, "unexpected new best bidder");
        assertEq(newAmount, amount, "unexpected new best bid amount");
    }

    /// @notice Function properties of `settleAuction`
    function invariant_settleAuctionProperties() external {
        (address sender, uint256 auctionId) =
            handler.prepare_settleAuction(input.arg(0), input.arg(1));

        (address bidder, uint256 bidAmount) = manager.bestBids(auctionId);
        (address seller, uint256 itemAmount, address itemToken,, address bidToken,) =
            manager.auctions(auctionId);

        uint256 sellerBalanceBefore =
            ERC20Mock(bidToken).balanceOf(seller);
        uint256 bidderBalanceBefore =
            ERC20Mock(itemToken).balanceOf(bidder);

        vm.prank(sender);
        manager.settleAuction(auctionId);

        if (seller != bidder || itemToken != bidToken) {
            assertEq(
                ERC20Mock(bidToken).balanceOf(seller),
                sellerBalanceBefore + bidAmount,
                "seller balance not increased correctly after settle"
            );
            assertEq(
                ERC20Mock(itemToken).balanceOf(bidder),
                bidderBalanceBefore + itemAmount,
                "bidder balance not increased correctly after settle"
            );
        } else {
            assertEq(
                ERC20Mock(itemToken).balanceOf(seller),
                sellerBalanceBefore + itemAmount + bidAmount,
                "seller=bidder balance not increased correctly after settle"
            );
        }

        (address newBidder,) = manager.bestBids(auctionId);
        assertEq(newBidder, address(0), "auction not settled");
    }

    /////////////////////////// Utility functions ////////////////////////

    function tokenBalance(address _token) public view returns (uint256) {
        uint256 total;
        for (uint256 i; i < manager.auctionCount(); ++i) {
            (address bidder, uint256 bamount) = manager.bestBids(i);
            if (bidder == address(0))
                continue; // This auction has been settled
            (,uint256 aamount, address itemToken,, address bidToken,) =
                manager.auctions(i);
            if (itemToken == _token)
                total += aamount;
            if (bidToken == _token)
                total += bamount;
        }
        return total;
    }

    function depositedTokenAmount(address _token, address _user)
    public view returns (uint256) {
        uint256 total;
        for (uint256 i; i < manager.auctionCount(); ++i) {
            (address bidder, uint256 bamount) = manager.bestBids(i);
            if (bidder == address(0))
                continue; // This auction has been settled
            (address seller, uint256 aamount, address itemToken,, address bidToken,) =
                manager.auctions(i);
            if (itemToken == _token && seller == _user)
                total += aamount;
            if (bidToken == _token && bidder == _user)
                total += bamount;
        }
        return total;
    }
}
