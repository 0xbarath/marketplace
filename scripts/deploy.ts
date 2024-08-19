import {ethers} from "hardhat";
import {SignerWithAddress} from "@nomicfoundation/hardhat-ethers/signers";
import {LoanMarketplace, Pool, TestNFT, TestPaymentToken} from "../typechain-types";
import {ILoanMarketplace} from "../typechain-types/contracts/LoanMarketplace";

async function main() {
    const operatorAddress = "0xa9fdc00274d32fc32e3105c416ab865ded621a72";
    const operator = await ethers.getSigner(operatorAddress);
    const oracleFactory = await ethers.getContractFactory("SimplePriceOracle");
    const oracle = await oracleFactory.deploy(operator.address);
    await oracle.waitForDeployment();
    const oracleAddress = await oracle.getAddress();
    console.log(`oracle deployed at ${oracleAddress}`);
    const paymentTokenFactory = await ethers.getContractFactory("TestPaymentToken");
    const paymentToken = await paymentTokenFactory.deploy();
    const paymentTokenAddress = await paymentToken.getAddress();
    await paymentToken.waitForDeployment();
    console.log(`payment token deployed at ${paymentTokenAddress}`);
    const marketplaceFactoryFactory = await ethers.getContractFactory("LoanMarketplaceFactory");
    const factory = await marketplaceFactoryFactory.deploy();
    const factoryAddress = await factory.getAddress();
    await factory.waitForDeployment();
    console.log(`factory deployed at ${factoryAddress}`);
    const marketplaceFactory = await ethers.getContractFactory("LoanMarketplace");
    const marketplace = await marketplaceFactory.deploy(paymentTokenAddress, oracleAddress, factoryAddress);
    await marketplace.waitForDeployment();
    console.log(`marketplace deployed at ${await marketplace.getAddress()}`);
    const TestNftFactory = await ethers.getContractFactory("TestNFT");
    const asset = await TestNftFactory.deploy("NFT1", "NFT1");
    await asset.waitForDeployment();
    console.log(`NFT1 deployed at ${await asset.getAddress()}`);
    const txn = await oracle.updateSupportedAsset(await asset.getAddress(), true);
    await txn.wait(1);
    await oracle.setAssetPrice(await asset.getAddress(), ethers.parseEther("200"));
    console.log(`NFT1 price set to 200`);
    await initiateDefaultSimpleLoan(operator, operator, marketplace, asset);
}

async function initiateDefaultSimpleLoan(
    borrower1: SignerWithAddress,
    lender1: SignerWithAddress,
    marketplace: LoanMarketplace,
    NFT1: TestNFT
) {
    const paymentTokenAddress = await marketplace.paymentToken();
    const paymentToken = await ethers.getContractAt("TestPaymentToken", paymentTokenAddress);
    const poolAddress = await marketplace.pool();
    const pool = await ethers.getContractAt("Pool", poolAddress);
    const tokenId = 1;
    const mintTXN = await NFT1.mint(borrower1.address, tokenId);
    await mintTXN.wait(1);
    await initiateSimpleLoan(
        borrower1,
        lender1,
        marketplace,
        pool,
        paymentToken,
        NFT1,
        tokenId);
    return {paymentToken, pool, tokenId};
}

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
    const loanDuration = 60 * 60 * 24;
    const mintTxn = await paymentToken.mint(lender.address, ethers.parseEther("100"));
    await mintTxn.wait(1);
    const approveTxn = await paymentToken.connect(lender).approve(await marketplace.pool(), loanAmount);
    await approveTxn.wait(1);
    const depositTxn = await pool.connect(lender).deposit(loanAmount);
    await depositTxn.wait(1);
    const maxLTV = 7000;
    console.log(`initiating loan`);
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
    const approveTxn  = await asset.connect(borrower).approve(escrowAddress, tokenId);
    await approveTxn.wait(1);
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
    const listTxn = await marketplace.connect(borrower).createListing(listing);
    await listTxn.wait(1);
    console.log(`listing created`);
    const listingId = await marketplace.lastListingId();
    console.log(`listing id: ${listingId}`);
    // TODO: uncomment for borrower flow
    // // make offer
    // const offerRequest: ILoanMarketplace.OfferRequestStruct = {
    //     lender: lender.address,
    //     listingId: listingId,
    //     loanAmount: loanAmount,
    //     repayAmount: repayAmount,
    //     loanDuration: loanDuration,
    //     maxLTV: maxLTV,
    //     listing: listing,
    // };
    // const offerTxn = await marketplace.connect(lender).makeOffer(offerRequest)
    // await offerTxn.wait(1);
    // console.log(`offer made`);
    // // accept offer
    // const offerId = await marketplace.lastOfferId();
    // const offer: ILoanMarketplace.OfferStruct = {
    //     offerId: offerId,
    //     lender: lender.address,
    //     borrower: borrower.address,
    //     assetContract: await asset.getAddress(),
    //     assetTokenId: tokenId,
    //     loanAmount: loanAmount,
    //     repayAmount: repayAmount,
    //     loanDuration: loanDuration,
    //     maxLTV: maxLTV,
    // };
    // const acceptTxn = await marketplace.connect(borrower).acceptOffer(offer);
    // await acceptTxn.wait(1);
    // console.log(`offer accepted`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
