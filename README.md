# Rigorous Solidity Smart Contract Verification with Foundry

The purpose of this repository is to document my process for rigorous Solidity smart contract verification using [Foundry Forge](https://book.getfoundry.sh/forge/tests).

I have used this process for verification of several real world smart contract protocols. I am documenting the process here, because it has been effective at identifying smart contract errors while being fast to implement.

## Motivation

It is well known that errors in smart contracts can result in significant financial losses. Therefore, smart contract correctness is commonly of high priority, as such errors can significantly damage the reputation of responsible entities.

The source code of a smart contract protocol is often small in size when compared to a traditional web2 backend system, which makes smart contract protocols an easier target for rigorous verification.

The high priority of correctness and small size of smart contract protocols make them well suited for formal verification and other rigorous verification techniques.

## Case Study

We will consider the `AuctionManager` contract [`src/AuctionManager.sol`](src/AuctionManager.sol), as a toy example of a smart contract that we want to verify for correctness.

The `AuctionManager` is a contract which manages English Auctions. The contract has three external functions.

1. Function `openAuction` for a user to open an auction, to sell an amount of ERC20 tokens (the auction item) in exchange for another ERC20 token.
2. Function `auctionBid` for a user to make a bid, offer an amount of ERC20 tokens for the auction item.
3. Function `settleAuction` to exchange ERC20 tokens after the auction has finished.

The Foundry Forge test for `AuctionManager` is located at [`test/AuctionManager.t.sol`](test/AuctionManager.t.sol). The next section (and subsections) explain how these tests have been implemented.

## A Process for Rigorous Verification with Foundry

The process for verifying a Solidity smart contract with Foundry Forge consists of the following 4 steps.

1. Code inspection of the smart contract
2. Invariants and function properties
3. A Foundry handler contract
4. A Foundry invariant test contract

For a medium sized contract ~500 lines of code, the process takes approximately 5 days to complete. The output of the process is a contract property specification together with a rigorous test implementation.

Typically the time needed to complete a step increases with the amount of errors that are identified during the step. Errors are normally identified in each step, and errors of increasing complexity as the step number increases.

The following 4 subsections detail the steps one by one.

### 1. Code inspection of the smart contract

This step is used to gather information about the smart contract with the aim of getting the ability to formulate a contract property specification in the next step.

In this step I read the source code of the smart contract multiple times. In the first read I skim the contract and typically cover more details for each read.

### 2. Invariants and function properties

In this step a contract property specification if formulated. The purpose of the contract property specification is not to be a complete contract specification, but rather to document the invariants that are required for the contract to function as expected. Functions properties are also often present in the contract property specification, but the focus is on specifying the primary purpose of the contract's function, and not getting into too many internal details.

#### Property Specification of the `AuctionManager` Contract

The contract property specification of the `AuctionManager` case study contract. 

We will use the following utility function to compute the minimum amount of `_token` ERC20 tokens required to settle the auctions,
```solidity
function minTokenBalance(address _token) public view returns (uint256) {
    uint256 total;
    for (uint256 i; i < auctions.length; ++i) {
        if (bestBids[i].bidder == address(0))
            continue; // This auction has been setteled
        if (auctions[i].itemToken == _token)
            total += auctions[i].amount;
        if (auctions[i].bidToken == _token)
            total += bestBids[i].amount;
    }
    return total;
}
```

We will also use a utility function to compute the amount of ERC20 tokens expected to be deposited into to `AuctionManager` by a given user address,
```solidity
function depositedTokenAmount(address _token, address _user) public view returns (uint256) {
    uint256 total;
    for (uint256 i; i < auctions.length; ++i) {
        if (bestBids[i].bidder == address(0))
            continue; // This auction has been setteled
        if (auctions[i].itemToken == _token && auctions[i].seller == _user)
            total += auctions[i].amount;
        if (auctions[i].bidToken == _token && bestBids[i].bidder == _user)
            total += bestBids[i].amount;
    }
    return total;
}
```

It is important to work on a high level of abstraction when specifying invariants and function properties. High level of abstraction allows for brevity while describing an essentially infinite number of scenarios.

**Invariants**

There are as many best bids as there are auctions,
> `auctions.length == bestBids.length`.

All of the auction manager's token amounts are accounted (solvency),
> For each `address t` which has been used as auction item token or auction bid token, `IERC20(t).balanceOf(address(this)) - minTokenBalance(t)` is constant and is `>=` 0.

The auction manager is in possession of the tokens of the correct users,
> For any `address a`, not equal to `address(this)` and for any ERC20 token `address t`, `IERC20(t).balanceOf(a) + depositedTokenAmount(t, a)` is a constant.

An auction can only be settled after the end time stamp,
> For any `i < auctions.length`, if `bestBids[i].bidder == address(0)` then `auctions[i].endTime >= block.timestamp`.

The best bid is lower bounded,
> For any `i < auctions.length`, if `bestBids[i].bidder != auctions[i].seller` then `bestBids[i].amount >= auctions[i].minBidAmount`.

Auction info is constant,
> For any `i < auctions.length`, the auction `auctions[i]` is a constant.

**Function Properties**

A non-reverting call `openAuction(amount, itemToken, endTime, bidToken, minBidAmount)` pushes the auction

```solidity
Auction({
    seller: msg.sender,
    amount: amount,
    itemToken: itemToken,
    endTime: endTime,
    bidToken: bidToken,
    minBidAmount: minBidAmount
})
```

and pushes the bid

```solidity
Bid({
    bidder: msg.sender,
    amount: 0
})
```

A non-reverting call `auctionBid(auctionId, amount)` updates the best bid

```
bestBids[auctionId].bidder == msg.sender
bestBids[auctionId].amount == amount
```

The call `auctionBid(auctionId, amount)` reverts if `amount <= bestBids[auctionId].amount`.

A non-reverting call `settleAuction(auctionId)` will update

```
bestBids[auctionId].bidder == address(0)
```
