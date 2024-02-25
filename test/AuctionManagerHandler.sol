// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {StdAssertions} from "forge-std/StdAssertions.sol";

import {AuctionManager} from "../src/AuctionManager.sol";

import {ERC20Mock} from "./ERC20Mock.sol";

contract AuctionManagerHandler is
        CommonBase, StdCheats, StdUtils, StdAssertions {
    AuctionManager public manager;

    // AuctionManager users
    uint256 internal nextUserAddress;
    address[] public users;

    // Array of ERC20 tokens that may be used
    ERC20Mock[] public allTokens;

    // Current block timestamp
    uint256 blockTimestamp;

    // An array of auctions which have been created
    AuctionManager.Auction[] public allAuctions;

    constructor(AuctionManager _auctionManager) {
        manager = _auctionManager;

        allTokens = new ERC20Mock[](5);
        for (uint256 i; i < allTokens.length; ++i)
            allTokens[i] = new ERC20Mock();
    }

    /// @notice Fuzz increase block time stamp.
    function fuzz_increaseTimestamp(uint256 _seed) external {
        increaseTimestamp(_seed % 3 minutes);
    }

    /// @notice Generate valid input for calling `openAuction`.
    function prepare_openAuction(
        uint256 _seller,
        uint256 _amount,
        uint256 _itemToken,
        uint256 _endTime,
        uint256 _bidToken,
        uint256 _minBidAmount
    ) public returns (
        address seller,
        uint256 amount,
        address itemToken,
        uint256 endTime,
        address bidToken,
        uint256 minBidAmount
    ) {
        setTimestamp();

        itemToken = genToken(_itemToken);
        bidToken = genToken(_bidToken);
        endTime = 1 + block.timestamp + _endTime % 1 minutes;
        minBidAmount = _minBidAmount % (1 gwei / 10);
        seller = genUser(_seller);
        amount = _amount % 2 ether;

        vm.prank(seller);
        ERC20Mock(itemToken).approve(address(manager), amount);

        allAuctions.push(AuctionManager.Auction({
            seller: seller,
            amount: amount,
            itemToken: itemToken,
            endTime: endTime,
            bidToken: bidToken,
            minBidAmount: minBidAmount
        }));
    }

    /// @notice Fuzz call `openAuction`.
    function fuzz_openAuction(
        uint256 _seller,
        uint256 _amount,
        uint256 _itemToken,
        uint256 _endTime,
        uint256 _bidToken,
        uint256 _minBidAmount
    ) public returns (uint256) {
        (
            address seller,
            uint256 amount,
            address itemToken,
            uint256 endTime,
            address bidToken,
            uint256 minBidAmount
        ) = prepare_openAuction(
            _seller,
            _amount,
            _itemToken,
            _endTime,
            _bidToken,
            _minBidAmount
        );
        vm.prank(seller);
        uint256 auctionId = manager.openAuction(
            amount,
            itemToken,
            endTime,
            bidToken,
            minBidAmount
        );
        return auctionId;
    }

    /// @notice Generate valid input for calling `auctionBid`.
    function prepare_auctionBid(
        uint256 _bidder,
        uint256 _auctionId,
        uint256 _amount
    ) public returns (
        address bidder,
        uint256 auctionId,
        uint256 amount
    ) {
        setTimestamp();

        bidder = genUser(_bidder);

        auctionId = genActiveAuctionId(_auctionId);

        (, uint256 best) = manager.bestBids(auctionId);
        uint256 minBid = best == 0 && allAuctions[auctionId].minBidAmount > 0
            ? allAuctions[auctionId].minBidAmount
            : best + 1;
        amount = minBid + _amount % 0.1 ether;

        AuctionManager.Auction memory a = allAuctions[auctionId];

        vm.prank(bidder);
        ERC20Mock(a.bidToken).approve(address(manager), amount);
    }

    /// @notice Fuzz call `auctionBid`.
    function fuzz_auctionBid(
        uint256 _bidder,
        uint256 _auctionId,
        uint256 _amount
    ) public {
        (address bidder, uint256 auctionId, uint256 amount) =
            prepare_auctionBid(_bidder, _auctionId, _amount);
        vm.prank(bidder);
        manager.auctionBid(auctionId, amount);
    }

    /// @notice Generate valid input for calling `settleAuction`.
    function prepare_settleAuction(uint256 _sender, uint256 _auctionId)
    public returns (address sender, uint256 auctionId) {
        setTimestamp();

        sender = genUser(_sender);
        auctionId = genSettleReadyAuctionId(_auctionId);
    }

    /// @notice Fuzz call `settleAuction`.
    function fuzz_settleAuction(uint256 _sender, uint256 _auctionId) public {
        (address sender, uint256 auctionId) =
            prepare_settleAuction(_sender, _auctionId);
        vm.prank(sender);
        manager.settleAuction(auctionId);
    }

    ////////////////////////// Utility functions //////////////////////////////

    function userCount() external view returns (uint256) {
        return users.length;
    }

    function tokenCount() external view returns (uint256) {
        return allTokens.length;
    }

    function auctionCount() external view returns (uint256) {
        return allAuctions.length;
    }

    function genFreshUser() public returns (address) {
        address a = vm.addr(++nextUserAddress);
        for (uint256 i; i < allTokens.length; ++i)
            allTokens[i].mint(a, 1000 ether);
        users.push(a);
        return a;
    }

    function genUser(uint256 _seed) public returns (address) {
        uint256 i = _seed % (users.length + 1);
        if (i == users.length)
            return genFreshUser();
        return users[i];
    }

    function genToken(uint256 _seed) public view returns (address) {
        return address(allTokens[_seed % allTokens.length]);
    }

    function genActiveAuctionId(uint256 _seed) internal returns (uint256) {
        uint256 n = allAuctions.length > 5 ? 5 : allAuctions.length;
        for (uint256 i; allAuctions.length > 0 && i < n; ++i) {
            uint256 id = (i + _seed % allAuctions.length) % allAuctions.length;
            AuctionManager.Auction memory a = allAuctions[id];
            if (a.endTime > block.timestamp)
                return id;

        }
        return fuzz_openAuction(_seed, _seed, _seed, _seed, _seed, _seed);
    }

    function genSettleReadyAuctionId(uint256 _seed) internal returns (uint256) {
        uint256 seed = _seed;

        uint256 n = allAuctions.length > 5 ? 5 : allAuctions.length;

        for (uint256 i; allAuctions.length > 0 && i < n; ++i) {
            uint256 id = (i + seed % allAuctions.length) % allAuctions.length;
            AuctionManager.Auction memory a = allAuctions[id];
            if (a.endTime > block.timestamp)
                continue;
            (address bidder,) = manager.bestBids(id);
            if (bidder != address(0))
                return id;
        }

        seed = uint256(keccak256(abi.encode(seed)));

        for (uint256 i; allAuctions.length > 0 && i < n; ++i) {
            uint256 id = (i + seed % allAuctions.length) % allAuctions.length;
            (address bidder,) = manager.bestBids(id);
            if (bidder == address(0))
                continue;
            AuctionManager.Auction memory a = allAuctions[id];
            if (a.endTime > block.timestamp)
                increaseTimestamp(a.endTime - block.timestamp);
            return id;
        }

        uint256 auctionId =
            fuzz_openAuction(seed, seed, seed, seed, seed, seed);
        increaseTimestamp(allAuctions[auctionId].endTime - block.timestamp);

        return auctionId;
    }

    function setTimestamp() public {
        if (block.timestamp < blockTimestamp)
            vm.warp(blockTimestamp);
        blockTimestamp = block.timestamp;
    }

    function increaseTimestamp(uint256 _time) internal {
        blockTimestamp += _time;
        setTimestamp();
    }
}
