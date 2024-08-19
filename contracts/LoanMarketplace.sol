// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/ILoanMarketplace.sol";
import "./interfaces/IPriceOracle.sol";
import "./interfaces/IPool.sol";
import "./interfaces/IEscrow.sol";
import "./LoanMarketplaceFactory.sol";

contract LoanMarketplace is ILoanMarketplace {
    using SafeERC20 for IERC20;
    using Math for uint256;

    uint public constant BIPS = 10000;

    IERC20 public paymentToken;
    IPriceOracle public priceOracle;
    IPool public pool;
    IEscrow public escrow;
    uint public lastListingId;
    uint public lastOfferId;
    uint public lastLoanId;
    mapping(uint256 => bytes32) public listings;
    mapping(uint256 => bytes32) public offers;
    mapping(uint256 => Loan) public loans;

    constructor(address _paymentToken, address _priceOracle, address factory) {
        require(_paymentToken != address(0), "Invalid payment token address");
        require(_priceOracle != address(0), "Invalid price oracle address");
        require(factory != address(0), "Invalid factory address");
        paymentToken = IERC20(_paymentToken);
        priceOracle = IPriceOracle(_priceOracle);
        pool = LoanMarketplaceFactory(factory).deployPool(address(this), _paymentToken);
        escrow = LoanMarketplaceFactory(factory).deployEscrow(address(this));
        emit LoanMarketplaceCreated(address(this));
    }

    function createListing(Listing memory listing) external override returns (uint listingId) {
        require(listing.borrower == msg.sender, "Borrower must create listing");
        require(priceOracle.isSupportedAsset(listing.assetContract), "Asset not supported");
        require(IERC721(listing.assetContract).ownerOf(listing.assetTokenId) == listing.borrower, "Borrower does not own asset");
        require(IERC721(listing.assetContract).getApproved(listing.assetTokenId) == address(escrow), "Contract not approved to transfer asset");
        require(isAssetUnderMaxLTV(listing.assetContract, listing.maxLTV, listing.loanAmount), "Loan amount exceeds LTV");
        listingId = ++lastListingId;
        listings[listingId] = keccak256(abi.encode(listing));
        emit ListingCreated(listingId, listing.borrower, listing.assetContract, listing.assetTokenId, listing.loanAmount, listing.repayAmount, listing.loanDuration, listing.maxLTV);
    }

    function makeOffer(OfferRequest memory offerRequest) external override returns (uint offerId) {
        require(offerRequest.lender == msg.sender, "Lender must create offer");
        bytes32 expectedListingHash = keccak256(abi.encode(offerRequest.listing));
        require(listings[offerRequest.listingId] == expectedListingHash, "Loan does not exist");
        require(offerRequest.lender != offerRequest.listing.borrower, "Lender cannot be borrower");
        require(pool.balance(offerRequest.lender) >= offerRequest.loanAmount, "Insufficient funds");
        require(isAssetUnderMaxLTV(offerRequest.listing.assetContract, offerRequest.maxLTV, offerRequest.loanAmount), "Loan amount exceeds LTV");
        offerId = ++lastOfferId;
        Offer memory offer = Offer({
            offerId: offerId,
            lender: offerRequest.lender,
            borrower: offerRequest.listing.borrower,
            assetContract: offerRequest.listing.assetContract,
            assetTokenId: offerRequest.listing.assetTokenId,
            loanAmount: offerRequest.loanAmount,
            repayAmount: offerRequest.repayAmount,
            loanDuration: offerRequest.loanDuration,
            maxLTV: offerRequest.maxLTV
        });
        offers[offerId] = keccak256(abi.encode(offer));
        emit OfferCreated(offerId, offerRequest.listingId, offer.lender, offer.borrower, offer.assetContract, offer.assetTokenId, offer.loanAmount, offer.repayAmount, offer.loanDuration, offer.maxLTV);
    }

    function acceptOffer(Offer memory offer) external override returns (uint loanId) {
        require(offer.borrower == msg.sender, "Borrower must accept offer");
        bytes32 expectedOfferHash = keccak256(abi.encode(offer));
        require(offers[offer.offerId] == expectedOfferHash, "Offer does not exist");
        require(pool.balance(offer.lender) >= offer.loanAmount, "Insufficient funds");
        require(isAssetUnderMaxLTV(offer.assetContract, offer.maxLTV, offer.loanAmount), "Loan amount exceeds LTV");
        loanId = ++lastLoanId;
        Loan memory loan = Loan({
            lender: offer.lender,
            borrower: offer.borrower,
            assetContract: offer.assetContract,
            assetTokenId: offer.assetTokenId,
            loanAmount: offer.loanAmount,
            repayAmount: offer.repayAmount,
            maxLTV: offer.maxLTV,
            loanStartTime: block.timestamp,
            loanEndTime: block.timestamp + offer.loanDuration,
            status: LoanStatus.ACTIVE
        });
        loans[loanId] = loan;
        pool.transfer(loan.lender, loan.borrower, loan.loanAmount);
        escrow.depositToEscrow(loanId, loan.assetContract, loan.assetTokenId, offer.borrower);
        emit LoanCreated(loanId, offer.offerId);
    }

    function repay(uint loanId) external override {
        require(loanId <= lastLoanId, "Loan does not exist");
        Loan memory loan = loans[loanId];
        require(loan.borrower == msg.sender, "Borrower must repay loan");
        require(loan.status == LoanStatus.ACTIVE, "Loan not active");
        require(block.timestamp >= loan.loanStartTime, "Loan has ended");
        require(block.timestamp <= loan.loanEndTime, "Loan has ended");
        loans[loanId].status = LoanStatus.REPAID;
        pool.transfer(loan.borrower, loan.lender, loan.repayAmount);
        escrow.releaseFromEscrow(loanId, loan.assetContract, loan.assetTokenId, loan.borrower);
        emit LoanRepaid(loanId);
    }

    function checkForDefault(uint loanId) external override {
        require(loanId <= lastLoanId, "Loan does not exist");
        Loan memory loan = loans[loanId];
        require(loan.status == LoanStatus.ACTIVE, "Loan not active");
        require(block.timestamp >= loan.loanStartTime, "Loan has ended");
        if (loan.loanEndTime <= block.timestamp) {
            loans[loanId].status = LoanStatus.DEFAULTED;
            emit LoanRepaymentDefaulted(loanId);
        }
    }

    function checkForLTV(uint loanId) external override {
        require(loanId <= lastLoanId, "Loan does not exist");
        Loan memory loan = loans[loanId];
        require(loan.status == LoanStatus.ACTIVE, "Loan not active");
        if (!isAssetUnderMaxLTV(loan.assetContract, loan.maxLTV, loan.repayAmount)) {
            loans[loanId].status = LoanStatus.DEFAULTED;
            emit LoanLTVDefault(loanId);
        }
    }

    function isAssetUnderMaxLTV(address asset, uint maxLTV, uint amount) internal view returns (bool) {
        uint assetPrice = priceOracle.getAssetPrice(asset);
        uint maxValueForLoan = assetPrice.mulDiv(maxLTV, BIPS);
        return maxValueForLoan > amount;
    }

    function liquidate(uint loanId) external override {
        require(loanId <= lastLoanId, "Loan does not exist");
        Loan memory loan = loans[loanId];
        require(loan.lender == msg.sender, "Lender must liquidate loan");
        require(loan.status == LoanStatus.DEFAULTED, "Loan hasn't defaulted");
        loans[loanId].status = LoanStatus.LIQUIDATED;
        escrow.releaseFromEscrow(loanId, loan.assetContract, loan.assetTokenId, loan.lender);
        emit LoanLiquidated(loanId);
    }

}