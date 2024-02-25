// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AuctionManager} from "../src/AuctionManager.sol";

contract AuctionManagerMock is AuctionManager {
    function auctionCount() external view returns (uint256) {
        return auctions.length;
    }
    function bestBidCount() external view returns (uint256) {
        return bestBids.length;
    }
}
