// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

interface ILoanMarketplace {

    event ListingCreated(uint listingId, address borrower, address assetContract, uint assetTokenId, uint loanAmount, uint repayAmount, uint loanDuration, uint maxLTV);
    event OfferCreated(uint offerId, uint listingId, address lender, address borrower, address assetContract, uint assetTokenId, uint loanAmount, uint repayAmount, uint loanDuration, uint maxLTV);
    event LoanCreated(uint loanId, uint offerId);
    event LoanRepaid(uint loanId);
    event LoanRepaymentDefaulted(uint loanId);
    event LoanLTVDefault(uint loanId);
    event LoanLiquidated(uint loanId);
    event LoanMarketplaceCreated(address loanMarketplace);

    enum LoanStatus {
        ACTIVE,
        REPAID,
        DEFAULTED,
        LIQUIDATED
    }

    struct Listing {
        address borrower;
        address assetContract;
        uint assetTokenId;
        uint loanAmount;
        uint repayAmount;
        uint loanDuration;
        uint maxLTV;
    }

    struct OfferRequest {
        address lender;
        uint listingId;
        uint loanAmount;
        uint repayAmount;
        uint loanDuration;
        uint maxLTV;
        Listing listing;
    }

    struct Offer {
        address lender;
        address borrower;
        address assetContract;
        uint offerId;
        uint assetTokenId;
        uint loanAmount;
        uint repayAmount;
        uint loanDuration;
        uint maxLTV;
    }

    struct Loan {
        address lender;
        address borrower;
        address assetContract;
        uint assetTokenId;
        uint loanAmount;
        uint repayAmount;
        uint maxLTV;
        uint loanStartTime;
        uint loanEndTime;
        LoanStatus status;
    }

    function createListing(Listing memory listing) external returns (uint listingId);

    function makeOffer(OfferRequest memory offerRequest) external returns (uint offerId);

    function acceptOffer(Offer memory offer) external returns (uint loanId);

    function repay(uint loanId) external;

    function checkForDefault(uint loanId) external;

    function checkForLTV(uint loanId) external;

    function liquidate(uint loanId) external;

}
