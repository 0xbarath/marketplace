# Marketplace


Progress so far:

- [x] First Draft of Marketplace
- [x] Basic Tests for Marketplace with 100% code coverage not branch coverage
- [x] deployment scripts and initial version deployed in Holesky
- [x] subgraphs : https://github.com/0xbarath/marketplace-subgraph
  - Query URL : [Query url with sample query](https://api.studio.thegraph.com/proxy/65656/loan-market-place/version/latest/graphql?query=%7B%0A++loans%28first%3A+5%29+%7B%0A++++id%0A++++borrower%0A++++assetContract%0A++++assetTokenId%0A++++loanAmount%0A++++loanStartTime%0A++++loanEndTime%0A++++status%0A++++maxLTV%0A++++repayAmount%0A++++offer+%7B%0A++++++id%0A++++++lender%0A++++++listing+%7B%0A++++++++id%0A++++++++borrower%0A++++++%7D%0A++++%7D%0A++%7D%0A%7D)
- [x] basic documentation
- [ ] internal audit : **In Progress**
- [ ] extended test coverage with close to 100% branch coverage
- [ ] gas optimization




Current Deployment :
Network : Holesky
```
oracle deployed at 0x2D972CEAD94c0b04444749b5415957d3962e2721
payment token deployed at 0x218b4433203F00dcf167DC216bCC314fC34fcFD8
factory deployed at 0x9D816059fB7F8464Eb24EDe99292A4407B08dBA1
marketplace deployed at 0xe87ca5b5f12DD9Bf726a22D2F6F33bb23Af869eB
NFT1 deployed at 0x8559E69C8b05b690c5D9a4475fd89107F81F38Bd
```

## Overview

The Marketplace contract is a decentralized marketplace for collateralized loans. Borrowers can get loans by collateralizing their asset (NFTs). Lenders can find the listings from borrowers and provide their offers for loans after depositing funds in the pool that will be used to fund the collateralized loans. On loan default, the collateral asset can be liquidated and retrieved by the lenders. On proper repayment of loan with interest the collateral asset is returned to the borrower

A typical loan lifecycle consists of the following stages:
* **Listing**: Borrower creates a loan listing, specifying the collateral token, the loan amount, the loan duration, and the maximum loan-to-value (LTV) ratio.
* **Offer**: Lender makes an offer on a loan listing, specifying the amount they are willing to lend and the interest rate.
* **AcceptOffer**: Borrower accepts an offer, creating a loan agreement.
* **Repay**: Borrower repays the loan, including the principal and interest.

The loan marketplace also consists of a Escrow, Pool and Price Oracle. The Escrow is used to escrow the collateral asset and can only be operated by marketplace. Lenders deposit the funds for lending in the pool and the borrowers fund is also deposited in the pool

There are two different ways the loan default:
1. If the loan is not repaid before the loan end time
2. If the LTV of the loan goes above the maxLTV

Any loan that has triggered one of the default condition can be moved from `Active` state to `Defaulted` state by invoking the `checkForLTV(loanId)` and `checkForDefault(loanId)` functions. The loan can then be liquidated by invoking `liquidate` function which transfers the collateral to lender

For limiting scope the project uses a simple price oracle and the price is a floor price of the NFT. A better approach is to integrate with existing NFT floor price oracles from Chainlink and Redstone. The two main methodology that oracles use are Time weighted average price (TWAP) and Volume weighted average price (VWAP)

There are several market manipulation methods like Spoofing, wash trading, cross-market manipulation that needs to be considered while adopting a price oracle strategy

### Installation

```yarn install```

### compile contracts
```yarn compile```

### tests
```yarn test```

### test coverage
```yarn coverage```







