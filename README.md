# Rigorous Solidity Smart Contract Verification with Foundry

The purpose of this repository is to document my process for rigorous
Solidity smart contract verification using [Foundry Forge](https://book.getfoundry.sh/forge/tests).

I have used this process for verification of several real world smart contract protocols.
I am documenting the process here, because it has been effective at identifying smart
contract errors while being fast to implement.

## Motivation

It is well known that errors in smart contracts can result in significant financial losses.
Therefore, smart contract correctness is commonly of high priority, as such errors can
significantly damage the reputation of responsible entities.

The source code of a smart contract protocol is often small in size when compared to a traditional
web2 backend system, which makes smart contract protocols an easier target for rigorous verification.

The high priority of correctness and small size of smart contract protocols make them
well suited for formal verification and other rigorous verification techniques.

## A Process for Rigorous Verification with Foundry

The process for verifying a Solidity smart contract with Foundry Forge consists of the following 4 steps.

1. Code review of the smart contract
2. Invariants and function properties
3. A Foundry handler contract
4. A Foundry invariant test contract

For a medium sized contract ~500 lines of code, the process takes approximately 5 days to complete.
The output of the process is a contract property specification together with a rigorous tests implementation.

Typically the time needed to complete a step increases with the amount of errors that are identified
during the step. Errors are normally identified in each step, and errors of increasing complexity
as the step number increases.

The following 4 subsections detail the steps one by one.

### 1. Code review of the smart contract

This step is used to gather information about the smart contract with the aim of getting the
ability to formulate a contract property specification in the next step.

In this step I read the source code of the smart contract multiple times.
In the first read I skim the contract and typically cover more details for each read.

### 2. Invariants and function properties


