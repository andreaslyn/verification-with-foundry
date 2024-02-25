# Rigorous Solidity Smart Contract Verification with Foundry

The purpose of this repository is to document my process for rigorous Solidity smart contract verification using [Foundry Forge](https://book.getfoundry.sh/forge/tests). The process is inspired by my background as formal verification engineer and type theorist. The conclusion of the document explains why I refer to this process as "rigorous".

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

For a medium sized contract ~500 lines of code without complex dependencies, the process takes approximately 5 days to complete. The output of the process is a contract property specification together with a test suite.

Typically complex contract dependencies increase the time need to complete the process. The time needed to complete a step tends increase with the amount of errors that are identified during the step. Errors are can be identified in each step, and errors of increasing complexity as the step number increases.

The following 4 subsections detail the steps one by one.

### 1. Code inspection of the smart contract

This step is used to gather information about the smart contract with the aim of getting the ability to formulate a contract property specification in the next step.

In this step I read the source code of the smart contract multiple times. In the first read I skim the contract and typically cover more details for each read.

### 2. Invariants and function properties

In this step a contract property specification is formulated. The purpose of the contract property specification is not to be a complete contract specification, but rather to document the invariants that are required for the contract to function as expected. Function properties are also often present in the contract property specification, but the focus is on specifying the primary purpose of the contract's function, and not getting into too many internal details.

#### Property Specification of the `AuctionManager` Contract

We will use the following utility function to compute the expected amount of `_token` ERC20 tokens in `AccountManager`,
```solidity
function tokenBalance(address _token) public view returns (uint256) {
    uint256 total;
    for (uint256 i; i < auctions.length; ++i) {
        if (bestBids[i].bidder == address(0))
            continue; // This auction has been settled
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
function depositedTokenAmount(address _token, address _user)
public view returns (uint256) {
    uint256 total;
    for (uint256 i; i < auctions.length; ++i) {
        if (bestBids[i].bidder == address(0))
            continue; // This auction has been settled
        if (auctions[i].itemToken == _token && auctions[i].seller == _user)
            total += auctions[i].amount;
        if (auctions[i].bidToken == _token && bestBids[i].bidder == _user)
            total += bestBids[i].amount;
    }
    return total;
}
```

It is important to work on a high level of abstraction when specifying invariants and function properties. High level of abstraction allows for brevity while describing an essentially infinite number of scenarios. The focus is on having a strong collection of invariants with a minimal number of key function properties.

##### Invariants

There are as many best bids as there are auctions,
> *auctions.length == bestBids.length*.

All of the auction manager's token amounts are accounted (solvency),
> For each *address t* which is the address of an ERC20 token, *IERC20(t).balanceOf(address(this)) == tokenBalance(t)*.

An auction can only be settled after the end time stamp,
> For any *i < auctions.length*, if *bestBids[i].bidder == address(0)* then *auctions[i].endTime <= block.timestamp*.

For unsettled auction, if best bid is 0 then best bidder is the seller,
> For any *i < auctions.length*, if *bestBids[i].amount == 0* and *bestBids[i].bidder != address(0)* then *bestBids[i].bidder == auctions[i].seller*.

For unsettled auction, the best bid is lower bounded,
> For any *i < auctions.length*, if *bestBids[i].bidder != address(0)* and either *bestBids[i].bidder != auctions[i].seller* or *bestBids[i].amount > 0*, then *bestBids[i].amount >= auctions[i].minBidAmount*.

Auction info is constant,
> For any *i < auctions.length*, the auction *auctions[i]* is a constant.

##### Function Properties of *openAuction*

A non-reverting call *openAuction(amount, itemToken, endTime, bidToken, minBidAmount)* returns *auctions.length-1* and the auction at index *auctions.length-1* is

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

and the best bid at index *auctions.length-1* is

```solidity
Bid({
    bidder: msg.sender,
    amount: 0
})
```

##### Function Properties of *auctionBid*

Before calling *auctionBid*, let *prevBid = bestBids[auctionId]*. A non-reverting call *auctionBid(auctionId, amount)* updates the best bid

```
bestBids[auctionId].bidder == msg.sender
bestBids[auctionId].amount == amount
```

If *prevBib.bidder != bestBids[auctionId].bidder* then *IERC20(auctions[auctionId].bidToken).balanceOf(prevBid.bidder)* is increased by *prevBid.amount*.

If *prevBib.bidder == bestBids[auctionId].bidder* then *IERC20(auctions[auctionId].bidToken).balanceOf(prevBid.bidder)* is decreased by *bestBids[auctionId].amount - prevBid.amount*.

The call *auctionBid(auctionId, amount)* reverts if *amount <= bestBids[auctionId].amount*.

##### Function Properties of *settleAuction*

Before calling *settleAuction*, let *bid = bestBids[auctionId]*. A non-reverting call *settleAuction(auctionId)* will update

```
bestBids[auctionId].bidder == address(0)
```

and transfer *bid.amount* to *auctions[i].seller* and transfer *autions[i].amount* to *bid.bidder*.

### 3. A Foundry handler contract

The Foundry handler contract `AuctionManagerHandler` at [`test/AuctionManagerHandler.sol`](test/AuctionManagerHandler.sol) is responsible for generating inputs to test the `AuctionManager` contract. The Foundry handler contract is also used during the Foundry Forge invariant fuzzing campaign. The invariant fuzzing campaign will repeatedly bring the `AuctionManager` into an arbitrary state and run all of the tests in this arbitrary state. This allows us to avoid being scenario specific when testing.

The `AuctionManagerHandler` contract has functions to generate arbitrary valid input to `openAuction`, `auctionBid` and `settleAuction`, which is used during the foundry invariant fuzzing campaign. The `AuctionManagerHandler` contract also specifies a function `fuzz_increaseTimestamp` to increase the block time stamp during the invariant fuzzing campaign, which is done because the `AuctionManager` contract depends on the block time stamp.

### 4. A Foundry invariant test contract

The Foundry invariant test file [`test/AuctionManager.t.sol`](test/AuctionManager.t.sol) is using an [auction manager mock contract](test/AuctionManagerMock.sol), which is equivalent to `AuctionManager` except that it provides convenient access to some additional storage fields that we need for testing purposes.

The Foundry invariant test contract `AuctionManagerTest` tells foundry to use 2 contracts for the invariant fuzzing campaign.

1. An input contract `AuctionManagerInput` to generate arbitrary inputs for function calls, and
2. the `AuctionManagerHandler` contract.

All tests are invariant tests from Foundry's point of view, even the tests for function properties. The input contract is used to generate arbitrary inputs for the function property tests as well as most of the tests for invariants.

The tests can be executed with the command
```
forge test
```

The tests are passing with `forge 0.2.0 (ac80261 2024-02-24T00:17:06.154246094Z)`.

## Conclusion

The `AcutionManager` case study exemplifies the process for smart contract verification. We have developed a contract property specification and a corresponding test suite.

I refer to this process as *rigorous*, because both the contract property specification and the test suite is working on a high level of abstraction, avoids being scenario specific. The way that the test suite is kept at a high level of abstraction is by having a Foundry handler contract to put the `AuctionManager` in arbitrary states and use an input contract to generate arbitrary function inputs.

You may wonder why I am not using a formal verification tool like Certora. The formal verification tools that I have used for verifying smart contracts have limitations that often force me to write properties at a lower level of abstraction. While Certora may work well on the `AuctionManager` contract, for real world smart contracts it tends to struggle with the high level of abstraction that my contract property specifications are written in. I am more confident with using Foundry Forge for verification, because I am able to write the tests using the same high level of abstraction as the contract property specification.
