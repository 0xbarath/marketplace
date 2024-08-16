import {ethers} from "hardhat";
import {loadFixture, time} from "@nomicfoundation/hardhat-network-helpers";
import {ILoanMarketplace, LoanMarketplace} from "../typechain-types/contracts/LoanMarketplace";
import {expect} from "chai";
import {SignerWithAddress} from "@nomicfoundation/hardhat-ethers/signers";
import {Pool, TestNFT, TestPaymentToken} from "../typechain-types";

describe("Basic marketplace Tests", function () {
    async function basicSetup() {
        const [operator, lender1, lender2, borrower1, borrower2] = await ethers.getSigners();

        const oracleFactory = await ethers.getContractFactory("SimplePriceOracle");
        const oracle = await oracleFactory.deploy(operator.address);
        await oracle.waitForDeployment();
        const oracleAddress = await oracle.getAddress();

        const paymentTokenFactory = await ethers.getContractFactory("TestPaymentToken");
        const paymentToken = await paymentTokenFactory.deploy();
        const paymentTokenAddress = await paymentToken.getAddress();

        const marketplaceFactoryFactory = await ethers.getContractFactory("LoanMarketplaceFactory");
        const factory = await marketplaceFactoryFactory.deploy();
        const factoryAddress = await factory.getAddress();

        const marketplaceFactory = await ethers.getContractFactory("LoanMarketplace");
        const marketplace = await marketplaceFactory.deploy(paymentTokenAddress, oracleAddress, factoryAddress);
        await marketplace.waitForDeployment();

        const TestNftFactory = await ethers.getContractFactory("TestNFT");
        const NFT1 = await TestNftFactory.deploy("NFT1", "NFT1");
        const NFT2 = await TestNftFactory.deploy("NFT2", "NFT2");
        const NFT3 = await TestNftFactory.deploy("NFT3", "NFT3");

        await oracle.updateSupportedAsset(await NFT1.getAddress(), true);
        await oracle.updateSupportedAsset(await NFT2.getAddress(), true);
        await oracle.updateSupportedAsset(await NFT3.getAddress(), true);

        await oracle.setAssetPrice(await NFT1.getAddress(), ethers.parseEther("200"));
        await oracle.setAssetPrice(await NFT2.getAddress(), ethers.parseEther("200"));
        await oracle.setAssetPrice(await NFT3.getAddress(), ethers.parseEther("200"));

        return {
            operator,
            lender1,
            lender2,
            borrower1,
            borrower2,
            oracle,
            marketplace,
            NFT1,
            NFT2,
            NFT3,
        };
    }

    it("Test basic loan and repay", async function () {
        const {marketplace, lender1, borrower1, NFT1} = await loadFixture(basicSetup);
        const paymentTokenAddress = await marketplace.paymentToken();
        const paymentToken = await ethers.getContractAt("TestPaymentToken", paymentTokenAddress);
        const poolAddress = await marketplace.pool();
        const pool = await ethers.getContractAt("Pool", poolAddress);
        const tokenId = 1;
        await NFT1.mint(borrower1.address, tokenId);
        await initiateSimpleLoan(
            borrower1,
            lender1,
            marketplace,
            pool,
            paymentToken,
            NFT1,
            tokenId);
        const loanId = await marketplace.lastLoanId();
        await marketplace.checkForDefault(loanId);
        await marketplace.checkForLTV(loanId);
        const loan = await marketplace.loans(loanId);
        expect(loan.status).to.eq(0);
        // repay loan
        await paymentToken.mint(borrower1.address, ethers.parseEther("10"));
        await paymentToken.connect(borrower1).approve(poolAddress, ethers.parseEther("10"));
        await pool.connect(borrower1).deposit(ethers.parseEther("10"));
        await marketplace.connect(borrower1).repay(loanId);

        const NFTOwner = await NFT1.ownerOf(tokenId);
        expect(NFTOwner).to.eq(borrower1.address);
        const balance = await pool.balance(lender1.address);
        expect(balance).to.eq(ethers.parseEther("110"));
        expect((await marketplace.loans(loanId)).status).to.eq(1);
    });

    it("Test basic loan and default", async function () {
        const {marketplace, lender1, borrower1, NFT1, oracle} = await loadFixture(basicSetup);
        const paymentTokenAddress = await marketplace.paymentToken();
        const paymentToken = await ethers.getContractAt("TestPaymentToken", paymentTokenAddress);
        const poolAddress = await marketplace.pool();
        const pool = await ethers.getContractAt("Pool", poolAddress);
        const tokenId = 1;
        await NFT1.mint(borrower1.address, tokenId);
        await initiateSimpleLoan(
            borrower1,
            lender1,
            marketplace,
            pool,
            paymentToken,
            NFT1,
            tokenId);
        // LTV default loan
        await forwardTime(60 * 60 * 24 * 30 + 1);
        const loanId = await marketplace.lastLoanId();
        await marketplace.checkForDefault(loanId);
        const loan = await marketplace.loans(loanId);
        expect(loan.status).to.eq(2);
    });

    it("Test basic loan and default for LTV", async function () {
        const {marketplace, lender1, borrower1, NFT1, oracle} = await loadFixture(basicSetup);
        const paymentTokenAddress = await marketplace.paymentToken();
        const paymentToken = await ethers.getContractAt("TestPaymentToken", paymentTokenAddress);
        const poolAddress = await marketplace.pool();
        const pool = await ethers.getContractAt("Pool", poolAddress);
        const tokenId = 1;
        await NFT1.mint(borrower1.address, tokenId);
        await initiateSimpleLoan(
            borrower1,
            lender1,
            marketplace,
            pool,
            paymentToken,
            NFT1,
            tokenId);

        // LTV default loan
        await oracle.setAssetPrice(await NFT1.getAddress(), ethers.parseEther("100"));
        const loanId = await marketplace.lastLoanId();
        await marketplace.checkForLTV(loanId);
        const loan = await marketplace.loans(loanId);
        expect(loan.status).to.eq(2);
    });
});

async function initiateSimpleLoan(
    borrower: SignerWithAddress,
    lender: SignerWithAddress,
    marketplace: LoanMarketplace,
    pool: Pool,
    paymentToken: TestPaymentToken,
    asset: TestNFT,
    tokenId: number) {
    const loanAmount = ethers.parseEther("100");
    const repayAmount = ethers.parseEther("110");
    const loanDuration = 60 * 60 * 24 * 30;
    await paymentToken.mint(lender.address, ethers.parseEther("1000"));
    await paymentToken.connect(lender).approve(await marketplace.pool(), loanAmount);
    await pool.connect(lender).deposit(loanAmount);
    const maxLTV = 7000;

    await initiateLoan(
        borrower,
        lender,
        marketplace,
        pool,
        loanAmount,
        repayAmount,
        loanDuration,
        maxLTV,
        asset,
        tokenId);
}

async function initiateLoan(
    borrower: SignerWithAddress,
    lender: SignerWithAddress,
    marketplace: LoanMarketplace,
    pool: Pool,
    loanAmount: bigint,
    repayAmount: bigint,
    loanDuration: number,
    maxLTV: number,
    asset: TestNFT,
    tokenId: number) {

    const escrowAddress = await marketplace.escrow();
    await asset.connect(borrower).approve(escrowAddress, tokenId);
    //create listing
    const listing: ILoanMarketplace.ListingStruct = {
        borrower: borrower.address,
        assetContract: await asset.getAddress(),
        assetTokenId: tokenId,
        loanAmount: loanAmount,
        repayAmount: repayAmount,
        loanDuration: loanDuration,
        maxLTV: maxLTV,
    }
    await marketplace.connect(borrower).createListing(listing);

    const listingId = await marketplace.lastListingId();
    // make offer
    const offerRequest: ILoanMarketplace.OfferRequestStruct = {
        lender: lender.address,
        borrower: borrower.address,
        listingId: listingId,
        loanAmount: loanAmount,
        repayAmount: repayAmount,
        loanDuration: loanDuration,
        maxLTV: maxLTV,
        listing: listing,
    };
    await marketplace.connect(lender).makeOffer(offerRequest)

    // accept offer
    const offer: ILoanMarketplace.OfferStruct = {
        lender: lender.address,
        borrower: borrower.address,
        assetContract: await asset.getAddress(),
        assetTokenId: tokenId,
        loanAmount: loanAmount,
        repayAmount: repayAmount,
        loanDuration: loanDuration,
        maxLTV: maxLTV,
    };
    const offerId = await marketplace.lastOfferId();
    await marketplace.connect(borrower).acceptOffer(offerId, offer);

    const ownerAfterAccept = await asset.ownerOf(tokenId);
    expect(ownerAfterAccept).to.eq(await marketplace.escrow());
    const borrowerBalance = await pool.balance(borrower.address);
    expect(borrowerBalance).to.eq(loanAmount);
}

export async function forwardTime(timeInSeconds: number) {
    await time.increase(timeInSeconds);
}