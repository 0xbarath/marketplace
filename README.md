# Marketplace


Progress so far:

- [x] First Draft of Marketplace
- [x] Basic Tests for Marketplace with 100% code coverage not branch coverage
- [x] deployment scripts and initial version deployed in Holesky
- [x] subgraphs : https://github.com/0xbarath/marketplace-subgraph
  - Query URL : [Query url with sample query](https://api.studio.thegraph.com/proxy/65656/loan-market-place/version/latest/graphql?query=%7B%0A++loans%28first%3A+5%29+%7B%0A++++id%0A++++borrower%0A++++assetContract%0A++++assetTokenId%0A++++loanAmount%0A++++loanStartTime%0A++++loanEndTime%0A++++status%0A++++maxLTV%0A++++repayAmount%0A++++offer+%7B%0A++++++id%0A++++++lender%0A++++++listing+%7B%0A++++++++id%0A++++++++borrower%0A++++++%7D%0A++++%7D%0A++%7D%0A%7D)
- [ ] basic documentation : In progress
- [ ] internal audit
- [ ] extended test coverage with close to 100% branch coverage
- [ ] gas optimization
