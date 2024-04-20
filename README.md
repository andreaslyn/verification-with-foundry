# Rigorous Solidity Smart Contract Verification with Foundry

The purpose of this repository is to document my process for rigorous Solidity smart contract verification using [Foundry Forge](https://book.getfoundry.sh/forge/tests). The process is based on property based testing and touring-machine testing, and inspired by my background in type theory and formal verification. I refer to this process as rigorous, because the resulting tests are written with a high level of abstraction. All resulting tests are parametrised by the state and inputs, which allows for generality instead of testing specific scenarios.

I have used this process for verification of several real world smart contract protocols. I am documenting the process here, because it has been effective at identifying smart contract errors while being fast to implement.

## Motivation

It is well known that errors in smart contracts can result in significant financial losses. Therefore, smart contract correctness is commonly of high priority, as such errors can significantly damage the reputation of responsible entities.

The source code of a smart contract protocol is often small in size when compared to a traditional web2 backend system, which makes smart contract protocols an easier target for comprehensive verification.

The high priority of correctness and relatively small size of smart contract protocols make them well suited for formal verification and other rigorous verification techniques.

## Case Study

We will consider the `AuctionManager` contract [`src/AuctionManager.sol`](src/AuctionManager.sol), as a toy example of a smart contract that we want to verify for correctness.

The `AuctionManager` is a contract which manages English Auctions. The contract has three external functions.

1. Function `openAuction` for a user to open an auction, to sell an amount of ERC20 tokens (the auction item) in exchange for another ERC20 token.
2. Function `auctionBid` for a user to make a bid, offer an amount of ERC20 tokens for the auction item.
3. Function `settleAuction` to exchange ERC20 tokens after the auction has finished.

The Foundry Forge test for `AuctionManager` is located at [`test/AuctionManager.t.sol`](test/AuctionManager.t.sol). The next section (and subsections) explain how these tests have been implemented.

## A Process for Rigorous Verification with Foundry

The process for verifying a Solidity smart contract with Foundry Forge consists of the following 4 stages.

1. Code inspection of the smart contract
2. A contract properties specification
3. A Foundry handler contract
4. A Foundry invariant test contract

For a medium sized contract ~500 lines of code without complex dependencies, the process takes approximately 5 days to complete. The output of the process is a contract properties specification together with a test suite.

Typically complex contract dependencies increase the time need to complete the process. The time needed to complete a stage tends increase with the amount of errors that are identified. Errors are can be identified in each stage, and errors of increasing complexity as the stage number increases.

The following 4 subsections detail the stages one by one.

### 1. Code inspection of the smart contract

This stage is used to gather information about the smart contract. The aim is to get an overview and identify internal contract assumptions, which will be used to formulate a contract properties specification in the next stage.

In this stage I read the source code of the smart contract multiple times. In the first read I skim the contract and typically cover more details for each read.

### 2. A contract properties specification

In this stage a contract properties specification is formulated, for specifying invariants and function properties. The purpose of the contract properties specification is not to be a complete contract specification, but rather to document the invariants that are required for the contract to function as expected. More specific function properties are also often present in the contract properties specification, but the focus is on specifying the primary purpose of the contract functions, and not getting into too many internal details. This can commonly be achieved with strong invariants and a few quality function properties.

Contract properties specification for the `AuctionManager` contract can be found here [`properties-spec/properties-spec.pdf`](properties-spec/properties-spec.pdf).

### 3. A Foundry handler contract

The Foundry handler contract `AuctionManagerHandler` at [`test/AuctionManagerHandler.sol`](test/AuctionManagerHandler.sol) is responsible for generating inputs to test the `AuctionManager` contract. The Foundry handler contract is also used during the Foundry Forge invariant fuzzing campaign. The invariant fuzzing campaign will repeatedly bring the `AuctionManager` into an arbitrary state and run all of the tests in this arbitrary state. This allows us to avoid being scenario specific when specifying tests.

The `AuctionManagerHandler` contract has functions to generate arbitrary valid input to `openAuction`, `auctionBid` and `settleAuction`, which is used during the foundry invariant fuzzing campaign. The `AuctionManagerHandler` contract also specifies a function `fuzz_increaseTimestamp` to increase the block time stamp during the invariant fuzzing campaign, which is done because the `AuctionManager` contract depends on the block time stamp.

### 4. A Foundry invariant test contract

The Foundry invariant test file [`test/AuctionManager.t.sol`](test/AuctionManager.t.sol) is using an [auction manager mock contract](test/AuctionManagerMock.sol), which is equivalent to `AuctionManager` except that it provides convenient access to some additional storage fields that we need for testing purposes.

The Foundry invariant test contract `AuctionManagerTest` tells foundry to use 2 contracts for the invariant fuzzing campaign.

1. An input contract `AuctionManagerInput` to generate random values, and
2. the `AuctionManagerHandler` contract.

All tests are invariant tests from Foundry's point of view, even the tests for function properties. The input contract is used to obtain random inputs for the function property tests as well as most of the tests for invariants.

The tests can be executed with the command
```
forge test
```

The tests are passing with `forge 0.2.0 (ac80261 2024-02-24T00:17:06.154246094Z)`.

## Conclusion

The `AcutionManager` case study exemplifies the process for smart contract verification. We have developed a contract properties specification and a corresponding test suite.

I refer to this process as *rigorous*, because both the contract properties specification and the test suite is written in a high level of abstraction, parametrised by state and inputs, so avoids being scenario specific. The way that the test suite is kept at this high level of abstraction is by having a Foundry handler contract to put the `AuctionManager` in arbitrary states and use an input contract to generate random test inputs.

The formal verification tools that I have used for verifying smart contracts have limitations that often force me to write properties at a lower level of abstraction. While SMT based tools like Certora may work well on the `AuctionManager` contract, for real world smart contracts they tend to struggle with the high level of abstraction that my contract properties specifications are written in. I am more confident with using Foundry Forge for verification, because I am able to write the tests using the same high level of abstraction as the contract properties specification.
